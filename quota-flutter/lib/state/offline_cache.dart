import 'dart:convert';

import 'package:quota/api/models.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists the last successful API responses so the app can keep showing
/// books and quotes while the network is unreachable.
class OfflineCache {
  static const _booksKey = 'quota_cache_books';
  static const _quotesKeyPrefix = 'quota_cache_quotes_';

  Future<List<Book>?> loadBooks() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_booksKey);
    if (raw == null) return null;
    try {
      return (jsonDecode(raw) as List<dynamic>)
          .map((e) => Book.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      await prefs.remove(_booksKey);
      return null;
    }
  }

  Future<void> saveBooks(List<Book> books) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _booksKey, jsonEncode(books.map((b) => b.toJson()).toList()));
  }

  Future<List<Quote>?> loadQuotes(String bookId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_quotesKeyPrefix$bookId');
    if (raw == null) return null;
    try {
      return (jsonDecode(raw) as List<dynamic>)
          .map((e) => Quote.fromJson(e as Map<String, dynamic>, bookId: bookId))
          .toList();
    } catch (_) {
      await prefs.remove('$_quotesKeyPrefix$bookId');
      return null;
    }
  }

  Future<void> saveQuotes(String bookId, List<Quote> quotes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_quotesKeyPrefix$bookId',
        jsonEncode(quotes.map((q) => q.toJson()).toList()));
  }

  /// Drop everything, e.g. on sign-out.
  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    for (final key in prefs.getKeys().toList()) {
      if (key == _booksKey || key.startsWith(_quotesKeyPrefix)) {
        await prefs.remove(key);
      }
    }
  }
}
