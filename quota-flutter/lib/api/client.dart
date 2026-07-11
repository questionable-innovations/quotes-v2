import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

/// Backend base URL. Override at build time with
/// `flutter run --dart-define=API_BASE_URL=http://localhost:8080`.
const String apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'https://quote-db.qinnovate.nz',
);

class ApiException implements Exception {
  final int statusCode;
  final String message;

  ApiException(this.statusCode, this.message);

  @override
  String toString() => 'ApiException($statusCode): $message';
}

/// HTTP client for the quotes-v2 backend: manages the JWT session
/// (persisted, auto-refreshed on 401) and wraps every endpoint.
class ApiClient {
  final String baseUrl;
  final http.Client _http = http.Client();

  String? _accessToken;
  String? _refreshToken;
  User? currentUser;

  final StreamController<User?> _authState = StreamController.broadcast();
  Stream<User?> get onAuthStateChange => _authState.stream;

  bool get hasSession => _refreshToken != null;

  ApiClient({this.baseUrl = apiBaseUrl});

  static const _prefsKey = 'quota_session';

  /// Restore a persisted session, if any. Call once before runApp.
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null) return;
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      _accessToken = data['access_token'] as String?;
      _refreshToken = data['refresh_token'] as String?;
      currentUser = User.fromJson(data['user'] as Map<String, dynamic>);
    } catch (_) {
      await prefs.remove(_prefsKey);
    }
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    if (_refreshToken == null) {
      await prefs.remove(_prefsKey);
    } else {
      await prefs.setString(
          _prefsKey,
          jsonEncode({
            'access_token': _accessToken,
            'refresh_token': _refreshToken,
            'user': currentUser?.toJson(),
          }));
    }
  }

  Future<void> _clearSession() async {
    _accessToken = null;
    _refreshToken = null;
    currentUser = null;
    await _persist();
    _authState.add(null);
  }

  // ---- Low-level request plumbing ------------------------------------------

  Future<dynamic> _request(
    String method,
    String path, {
    Object? body,
    bool auth = true,
  }) async {
    var response = await _send(method, path, body: body, auth: auth);

    // Access token expired: refresh once and retry.
    if (response.statusCode == 401 && auth && _refreshToken != null) {
      final refreshed = await _tryRefresh();
      if (!refreshed) {
        await _clearSession();
        throw ApiException(401, 'Session expired, please sign in again');
      }
      response = await _send(method, path, body: body, auth: auth);
    }

    final decoded =
        response.body.isEmpty ? null : jsonDecode(utf8.decode(response.bodyBytes));
    if (response.statusCode >= 400) {
      final message = (decoded is Map && decoded['error'] is String)
          ? decoded['error'] as String
          : 'Request failed (${response.statusCode})';
      throw ApiException(response.statusCode, message);
    }
    return decoded;
  }

  Future<http.Response> _send(
    String method,
    String path, {
    Object? body,
    required bool auth,
  }) {
    final headers = <String, String>{
      if (body != null) 'Content-Type': 'application/json',
      if (auth && _accessToken != null)
        'Authorization': 'Bearer $_accessToken',
    };
    final uri = Uri.parse('$baseUrl/api$path');
    final encoded = body == null ? null : jsonEncode(body);
    switch (method) {
      case 'GET':
        return _http.get(uri, headers: headers);
      case 'POST':
        return _http.post(uri, headers: headers, body: encoded);
      case 'PATCH':
        return _http.patch(uri, headers: headers, body: encoded);
      case 'DELETE':
        return _http.delete(uri, headers: headers, body: encoded);
      default:
        throw ArgumentError('Unsupported method $method');
    }
  }

  Future<bool> _tryRefresh() async {
    try {
      final response = await _send('POST', '/auth/refresh',
          body: {'refresh_token': _refreshToken}, auth: false);
      if (response.statusCode >= 400) return false;
      _applyAuthResponse(
          jsonDecode(response.body) as Map<String, dynamic>);
      return true;
    } catch (_) {
      return false;
    }
  }

  void _applyAuthResponse(Map<String, dynamic> data) {
    _accessToken = data['access_token'] as String;
    _refreshToken = data['refresh_token'] as String;
    currentUser = User.fromJson(data['user'] as Map<String, dynamic>);
    _persist();
    _authState.add(currentUser);
  }

  // ---- Auth -----------------------------------------------------------------

  Future<User> signUp(String email, String password,
      {String? inviteToken}) async {
    final data = await _request('POST', '/auth/signup',
        auth: false,
        body: {
          'email': email,
          'password': password,
          if (inviteToken != null) 'invite_token': inviteToken,
        }) as Map<String, dynamic>;
    _applyAuthResponse(data);
    return currentUser!;
  }

  Future<User> signIn(String email, String password) async {
    final data = await _request('POST', '/auth/login',
        auth: false,
        body: {'email': email, 'password': password}) as Map<String, dynamic>;
    _applyAuthResponse(data);
    return currentUser!;
  }

  Future<void> signOut() async {
    final token = _refreshToken;
    await _clearSession();
    if (token != null) {
      try {
        await _request('POST', '/auth/logout',
            auth: false, body: {'refresh_token': token});
      } catch (_) {
        // Best-effort server-side revocation; local session is already gone.
      }
    }
  }

  /// Re-fetch the current user (e.g. to pick up email verification).
  Future<User> refreshUser() async {
    final data = await _request('GET', '/auth/me') as Map<String, dynamic>;
    currentUser = User.fromJson(data);
    await _persist();
    return currentUser!;
  }

  Future<void> requestPasswordReset(String email) =>
      _request('POST', '/auth/request-password-reset',
          auth: false, body: {'email': email});

  Future<void> resendVerification() =>
      _request('POST', '/auth/resend-verification');

  Future<void> acceptInvite(String token) =>
      _request('POST', '/invites/${Uri.encodeComponent(token)}/accept');

  // ---- Books ----------------------------------------------------------------

  Future<List<Book>> listBooks() async {
    final data = await _request('GET', '/books') as List<dynamic>;
    return data
        .map((e) => Book.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Book> createBook(String name) async {
    final data =
        await _request('POST', '/books', body: {'name': name});
    return Book.fromJson(data as Map<String, dynamic>);
  }

  Future<Book> renameBook(String bookId, String name) async {
    final data =
        await _request('PATCH', '/books/$bookId', body: {'name': name});
    return Book.fromJson(data as Map<String, dynamic>);
  }

  Future<void> deleteBook(String bookId) => _request('DELETE', '/books/$bookId');

  // ---- Quotes ---------------------------------------------------------------

  Future<List<Quote>> listQuotes(String bookId) async {
    final data =
        await _request('GET', '/books/$bookId/quotes') as List<dynamic>;
    return data
        .map((e) => Quote.fromJson(e as Map<String, dynamic>, bookId: bookId))
        .toList();
  }

  Future<Quote> createQuote(
      String bookId, String person, String quote, DateTime date) async {
    final data = await _request('POST', '/books/$bookId/quotes', body: {
      'person': person,
      'quote': quote,
      'date': date.toIso8601String(),
    });
    return Quote.fromJson(data as Map<String, dynamic>, bookId: bookId);
  }

  Future<void> deleteQuote(String bookId, String quoteId) =>
      _request('DELETE', '/books/$bookId/quotes/$quoteId');

  // ---- Members & invites ------------------------------------------------------

  Future<List<Member>> listMembers(String bookId) async {
    final data =
        await _request('GET', '/books/$bookId/members') as List<dynamic>;
    return data
        .map((e) => Member.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<AddMemberResult> addMember(String bookId, String email) async {
    final data = await _request('POST', '/books/$bookId/members',
        body: {'email': email});
    return AddMemberResult.fromJson(data as Map<String, dynamic>);
  }

  Future<void> removeMember(String bookId, String userId) =>
      _request('DELETE', '/books/$bookId/members/$userId');

  Future<List<Invite>> listInvites(String bookId) async {
    final data =
        await _request('GET', '/books/$bookId/invites') as List<dynamic>;
    return data
        .map((e) => Invite.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> deleteInvite(String bookId, String inviteId) =>
      _request('DELETE', '/books/$bookId/invites/$inviteId');

  // ---- Share links ------------------------------------------------------------

  Future<List<ShareLink>> listShareLinks(String bookId) async {
    final data =
        await _request('GET', '/books/$bookId/share-links') as List<dynamic>;
    return data
        .map((e) => ShareLink.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<ShareLink> createShareLink(String bookId,
      {DateTime? expiresAt, int? maxUses}) async {
    final data = await _request('POST', '/books/$bookId/share-links', body: {
      'expires_at': expiresAt?.toUtc().toIso8601String(),
      'max_uses': maxUses,
    });
    return ShareLink.fromJson(data as Map<String, dynamic>);
  }

  Future<void> deleteShareLink(String bookId, String linkId) =>
      _request('DELETE', '/books/$bookId/share-links/$linkId');

  Future<SharePreview> previewShareLink(String token) async {
    final data = await _request(
        'GET', '/share-links/${Uri.encodeComponent(token)}',
        auth: false);
    return SharePreview.fromJson(data as Map<String, dynamic>);
  }

  Future<void> acceptShareLink(String token) => _request(
      'POST', '/share-links/${Uri.encodeComponent(token)}/accept');

  // ---- Attachments --------------------------------------------------------------

  Future<Attachment> uploadAttachment(
      String quoteId, String filename, Uint8List bytes,
      {String? contentType}) async {
    Future<http.StreamedResponse> send() {
      final request = http.MultipartRequest(
          'POST', Uri.parse('$baseUrl/api/quotes/$quoteId/attachments'));
      if (_accessToken != null) {
        request.headers['Authorization'] = 'Bearer $_accessToken';
      }
      request.files.add(http.MultipartFile.fromBytes('file', bytes,
          filename: filename,
          contentType:
              MediaType.parse(contentType ?? _guessContentType(filename))));
      return _http.send(request);
    }

    var response = await http.Response.fromStream(await send());
    if (response.statusCode == 401 && _refreshToken != null) {
      if (!await _tryRefresh()) {
        await _clearSession();
        throw ApiException(401, 'Session expired, please sign in again');
      }
      response = await http.Response.fromStream(await send());
    }
    final decoded = response.body.isEmpty
        ? null
        : jsonDecode(utf8.decode(response.bodyBytes));
    if (response.statusCode >= 400) {
      final message = (decoded is Map && decoded['error'] is String)
          ? decoded['error'] as String
          : 'Upload failed (${response.statusCode})';
      throw ApiException(response.statusCode, message);
    }
    return Attachment.fromJson(decoded as Map<String, dynamic>);
  }

  /// Download an attachment's raw bytes (authenticated).
  Future<Uint8List> getAttachmentBytes(String attachmentId) async {
    var response = await _send('GET', '/attachments/$attachmentId', auth: true);
    if (response.statusCode == 401 && _refreshToken != null) {
      if (!await _tryRefresh()) {
        await _clearSession();
        throw ApiException(401, 'Session expired, please sign in again');
      }
      response = await _send('GET', '/attachments/$attachmentId', auth: true);
    }
    if (response.statusCode >= 400) {
      throw ApiException(
          response.statusCode, 'Could not load attachment');
    }
    return response.bodyBytes;
  }

  Future<void> deleteAttachment(String attachmentId) =>
      _request('DELETE', '/attachments/$attachmentId');

  static String _guessContentType(String filename) {
    final ext = filename.contains('.')
        ? filename.split('.').last.toLowerCase()
        : '';
    switch (ext) {
      case 'jpg' || 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      case 'heic':
        return 'image/heic';
      default:
        return 'application/octet-stream';
    }
  }
}
