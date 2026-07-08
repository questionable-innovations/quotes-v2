import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:quota/contants.dart';
import 'package:quota/state/books_model.dart';
import 'package:quota/widgets/book_args.dart';

class NewBookWidget extends StatefulWidget {
  const NewBookWidget({
    super.key,
  });

  @override
  State<NewBookWidget> createState() => _NewBookState();
}

class _NewBookState extends State<NewBookWidget> {
  final _bookNameController = TextEditingController();

  @override
  void dispose() {
    _bookNameController.dispose();
    super.dispose();
  }

  Future<void> _createBook(String name) async {
    try {
      final book = await api.createBook(name);
      if (!mounted) return;
      await Provider.of<BooksModel>(context, listen: false).refresh(context);
      if (!mounted) return;
      Navigator.pushNamed(context, "/book", arguments: BookArgs(book.id));
    } catch (ex) {
      log("Could not create book", error: ex);
      if (mounted) {
        context.showErrorSnackBar(
            message: errorMessage(ex, "Could not create book"));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.extended(
      onPressed: () {
        showDialog<bool>(
                context: context,
                builder: (context) =>
                    NewBookDialog(bookNameController: _bookNameController))
            .then(
          (result) async {
            if (result ?? false) {
              final name = _bookNameController.text.trim();
              _bookNameController.clear();
              if (name == "") {
                if (context.mounted) {
                  context.showErrorSnackBar(
                      message: "Book name must not be empty");
                }
                return;
              }
              await _createBook(name);
            } else {
              _bookNameController.clear();
            }
          },
        );
      },
      label: const Text("Create Book"),
    );
  }
}

class NewBookDialog extends StatefulWidget {
  const NewBookDialog({
    super.key,
    required this.bookNameController,
  });

  final TextEditingController bookNameController;

  @override
  State<NewBookDialog> createState() => _NewBookDialogState();
}

class _NewBookDialogState extends State<NewBookDialog> {
  bool isBookNameEmpty = true;

  void _textUpdate() {
    setState(() {
      isBookNameEmpty = widget.bookNameController.text.trim().isEmpty;
    });
  }

  @override
  void initState() {
    super.initState();
    widget.bookNameController.addListener(_textUpdate);
  }

  @override
  void dispose() {
    widget.bookNameController.removeListener(_textUpdate);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("New Book"),
      content: TextField(
        decoration: const InputDecoration(label: Text("Book name")),
        controller: widget.bookNameController,
        autofocus: true,
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel")),
        TextButton(
          onPressed:
              isBookNameEmpty ? null : () => Navigator.pop(context, true),
          child: const Text("Ok"),
        ),
      ],
    );
  }
}
