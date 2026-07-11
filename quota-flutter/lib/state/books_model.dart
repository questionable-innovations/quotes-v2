import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:quota/api/client.dart';
import 'package:quota/api/models.dart';
import 'package:quota/contants.dart';
import 'package:quota/state/offline_cache.dart';

class BooksModel extends ChangeNotifier {
  final OfflineCache _cache = OfflineCache();

  List<Book> _books = [];
  List<Book> get books => _books;

  bool _loading = false;
  bool get loading => _loading;

  /// True when the last fetch failed to reach the server and we're
  /// showing cached data instead.
  bool _offline = false;
  bool get offline => _offline;

  BooksModel(BuildContext context) {
    _init(context);
  }

  Future<void> _init(BuildContext context) async {
    final cached = await _cache.loadBooks();
    if (cached != null && _books.isEmpty) {
      _books = cached;
      notifyListeners();
    }
    if (context.mounted) {
      await refresh(context);
    }
  }

  Book? bookById(String id) {
    for (final book in _books) {
      if (book.id == id) return book;
    }
    return null;
  }

  Future<void> refresh(BuildContext context) async {
    if (!api.hasSession) {
      return;
    }

    _loading = true;
    notifyListeners();

    try {
      _books = await api.listBooks();
      _offline = false;
      _cache.saveBooks(_books);
    } catch (ex) {
      log("Could not fetch books", error: ex);
      if (ex is ApiException) {
        if (context.mounted) {
          context.showErrorSnackBar(
              message: errorMessage(ex, "Could not fetch books"));
        }
      } else {
        // Network unreachable: keep showing whatever we have cached.
        _offline = true;
      }
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  void clear() {
    _books = [];
    _offline = false;
    _cache.clear();
    notifyListeners();
  }
}
