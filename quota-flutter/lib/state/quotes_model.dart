import 'dart:developer';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:quota/api/client.dart';
import 'package:quota/api/models.dart';
import 'package:quota/contants.dart';
import 'package:quota/state/offline_cache.dart';

class QuotesModel extends ChangeNotifier {
  final OfflineCache _cache = OfflineCache();
  final Map<String, List<Quote>> _quotesPerBook = {};

  bool loading = false;

  /// True when the last fetch failed to reach the server and we're
  /// showing cached data instead.
  bool _offline = false;
  bool get offline => _offline;

  List<Quote> quotesForBook(String bookId) {
    return _quotesPerBook[bookId] ?? [];
  }

  bool hasQuotesForBook(String bookId) {
    return _quotesPerBook.containsKey(bookId);
  }

  /// Fetch quotes for [bookId] if not cached yet (or when [force] is set).
  Future<void> ensure(BuildContext context, String bookId,
      {bool force = false}) async {
    if (hasQuotesForBook(bookId) && !force) return;

    // Show persisted quotes immediately while the network fetch runs.
    final cached = await _cache.loadQuotes(bookId);
    if (cached != null && !hasQuotesForBook(bookId)) {
      _quotesPerBook[bookId] = cached;
      notifyListeners();
    }

    if (context.mounted) {
      await refresh(context, bookId);
    }
  }

  Future<void> refresh(BuildContext context, String bookId) async {
    if (!api.hasSession) {
      return;
    }

    loading = true;
    notifyListeners();

    try {
      _quotesPerBook[bookId] = await api.listQuotes(bookId);
      _offline = false;
      _cache.saveQuotes(bookId, _quotesPerBook[bookId]!);
    } catch (ex) {
      log("Could not fetch quotes", error: ex);
      if (ex is ApiException) {
        if (context.mounted) {
          context.showErrorSnackBar(
              message: errorMessage(ex, "Failed to fetch quotes"));
        }
      } else {
        // Network unreachable: keep showing whatever we have cached.
        _offline = true;
      }
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<Quote> addQuote(
      String bookId, String person, String quote, DateTime date) async {
    final created = await api.createQuote(bookId, person, quote, date);
    final quotes = _quotesPerBook[bookId] ??= [];
    quotes.add(created);
    _cache.saveQuotes(bookId, quotes);
    notifyListeners();
    return created;
  }

  Future<Attachment> uploadAttachment(
      Quote quote, String filename, Uint8List bytes) async {
    final attachment = await api.uploadAttachment(quote.id, filename, bytes);
    _replaceQuote(quote.withAttachments([...quote.attachments, attachment]));
    return attachment;
  }

  Future<void> deleteAttachment(Quote quote, Attachment attachment) async {
    await api.deleteAttachment(attachment.id);
    _replaceQuote(quote.withAttachments(
        quote.attachments.where((a) => a.id != attachment.id).toList()));
  }

  void _replaceQuote(Quote updated) {
    final quotes = _quotesPerBook[updated.book];
    if (quotes == null) return;
    final index = quotes.indexWhere((q) => q.id == updated.id);
    if (index < 0) return;
    quotes[index] = updated;
    _cache.saveQuotes(updated.book, quotes);
    notifyListeners();
  }

  Future<void> deleteQuote(Quote quote) async {
    await api.deleteQuote(quote.book, quote.id);
    final quotes = _quotesPerBook[quote.book];
    if (quotes != null) {
      quotes.removeWhere((q) => q.id == quote.id);
      _cache.saveQuotes(quote.book, quotes);
    }
    notifyListeners();
  }

  void clear() {
    _quotesPerBook.clear();
    _offline = false;
    notifyListeners();
  }
}
