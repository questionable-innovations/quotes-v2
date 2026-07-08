import 'package:flutter/material.dart';

class BookArgs {
  final String bookId;

  BookArgs(this.bookId);
}

class BookArgsExtractor extends StatelessWidget {
  final Function(String bookId, BuildContext context) create;
  const BookArgsExtractor({super.key, required this.create});

  @override
  Widget build(BuildContext context) {
    var args = ModalRoute.of(context)!.settings.arguments as BookArgs;
    return create(args.bookId, context);
  }
}
