import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

/// Random inspirational backdrop photos for the fullscreen quote view.
///
/// Uses the Unsplash API when an access key is provided at build time
/// (`--dart-define-from-file=secrets.json`), otherwise falls back to
/// loremflickr. Cached per quote for the session; returns null when
/// offline so the caller can fall back to a gradient.

const _unsplashKey = String.fromEnvironment('UNSPLASH_ACCESS_KEY');

const _themes = [
  'sunset sky',
  'sunrise landscape',
  'mountain landscape',
  'ocean waves',
  'starry night sky',
  'misty forest',
  'dramatic clouds',
];

// Session salt so each app run gets a fresh set of photos.
final _salt = DateTime.now().millisecondsSinceEpoch ~/ 1000;

final Map<String, Future<Uint8List?>> _cache = {};

Future<Uint8List?> scenicImageFor(String quoteId) =>
    _cache.putIfAbsent(quoteId, () async {
      final seed = (quoteId.hashCode ^ _salt).abs();
      try {
        final bytes = _unsplashKey.isEmpty
            ? await _fetchLoremFlickr(seed)
            : await _fetchUnsplash(seed);
        if (bytes != null) return bytes;
      } catch (_) {
        // Offline or fetch failed; caller falls back to a gradient.
      }
      _cache.remove(quoteId);
      return null;
    });

Future<Uint8List?> _fetchUnsplash(int seed) async {
  final theme = _themes[seed % _themes.length];
  final meta = await http.get(
    Uri.parse('https://api.unsplash.com/photos/random').replace(
        queryParameters: {
          'query': theme,
          'orientation': 'portrait',
          'content_filter': 'high',
        }),
    headers: {'Authorization': 'Client-ID $_unsplashKey'},
  ).timeout(const Duration(seconds: 10));
  if (meta.statusCode != 200) return null;

  final url = ((jsonDecode(meta.body) as Map<String, dynamic>)['urls']
      as Map<String, dynamic>)['regular'] as String?;
  if (url == null) return null;

  final image =
      await http.get(Uri.parse(url)).timeout(const Duration(seconds: 15));
  return image.statusCode == 200 ? image.bodyBytes : null;
}

Future<Uint8List?> _fetchLoremFlickr(int seed) async {
  final theme = _themes[seed % _themes.length].split(' ').first;
  final response = await http
      .get(Uri.parse(
          'https://loremflickr.com/1080/1920/$theme?lock=${seed % 10000}'))
      .timeout(const Duration(seconds: 10));
  return response.statusCode == 200 && response.bodyBytes.isNotEmpty
      ? response.bodyBytes
      : null;
}
