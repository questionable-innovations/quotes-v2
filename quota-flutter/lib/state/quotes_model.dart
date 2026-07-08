import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:quota/api/models.dart';
import 'package:quota/contants.dart';

class QuotesModel extends ChangeNotifier {
  final Map<String, List<Quote>> _quotesPerBook = {};

  bool loading = false;

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
    await refresh(context, bookId);
  }

  Future<void> refresh(BuildContext context, String bookId) async {
    if (!api.hasSession) {
      return;
    }

    loading = true;
    notifyListeners();

    try {
      _quotesPerBook[bookId] = await api.listQuotes(bookId);
    } catch (ex) {
      log("Could not fetch quotes", error: ex);
      if (context.mounted) {
        context.showErrorSnackBar(
            message: errorMessage(ex, "Failed to fetch quotes"));
      }
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> addQuote(
      String bookId, String person, String quote, DateTime date) async {
    final created = await api.createQuote(bookId, person, quote, date);
    (_quotesPerBook[bookId] ??= []).add(created);
    notifyListeners();
  }

  Future<void> deleteQuote(Quote quote) async {
    await api.deleteQuote(quote.book, quote.id);
    _quotesPerBook[quote.book]?.removeWhere((q) => q.id == quote.id);
    notifyListeners();
  }

  void clear() {
    _quotesPerBook.clear();
    notifyListeners();
  }
}
