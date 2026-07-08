import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:quota/api/models.dart';
import 'package:quota/contants.dart';

class BooksModel extends ChangeNotifier {
  List<Book> _books = [];
  List<Book> get books => _books;

  bool _loading = false;
  bool get loading => _loading;

  BooksModel(BuildContext context) {
    refresh(context);
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
    } catch (ex) {
      log("Could not fetch books", error: ex);
      if (context.mounted) {
        context.showErrorSnackBar(
            message: errorMessage(ex, "Could not fetch books"));
      }
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  void clear() {
    _books = [];
    notifyListeners();
  }
}
