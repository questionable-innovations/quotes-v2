import 'package:flutter/material.dart';
import 'package:provider/provider.dart' as provider;
import 'package:quota/api/models.dart';
import 'package:quota/state/books_model.dart';
import 'package:quota/state/quotes_model.dart';
import 'package:quota/widgets/book.dart';
import 'package:quota/widgets/new_book.dart';

import '../contants.dart';

class BooksPage extends StatefulWidget {
  const BooksPage({super.key});

  @override
  State<BooksPage> createState() => _BooksPageState();
}

class _BooksPageState extends State<BooksPage> {
  Future<void> _signOut() async {
    provider.Provider.of<BooksModel>(context, listen: false).clear();
    provider.Provider.of<QuotesModel>(context, listen: false).clear();
    try {
      await api.signOut();
    } catch (error) {
      if (mounted) {
        context.showErrorSnackBar(
            message: errorMessage(error, 'Unexpected error occurred'));
      }
    }
    if (mounted) {
      Navigator.of(context).pushReplacementNamed('/');
    }
  }

  Widget _booksView(BuildContext context, BooksModel booksModel, Widget? child) {
    if (booksModel.loading) {
      return SizedBox(
          width: MediaQuery.of(context).size.width,
          child: const Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                Text(
                  "Loading",
                  style: TextStyle(fontWeight: FontWeight.bold),
                )
              ]));
    }

    List<Book> books = List.of(booksModel.books);
    // Sort first putting the books owned by the user first, then alphabetically
    books.sort((a, b) {
      if (a.isOwner != b.isOwner) {
        return a.isOwner ? -1 : 1;
      }
      return a.name.compareTo(b.name);
    });

    return ListView(
      children: [
        ...books.map((book) => BookWidget(book: book)),
        const SizedBox(
          height: 50,
        )
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Select book"), actions: [
        Padding(
          padding: const EdgeInsets.all(10.0),
          child: OutlinedButton.icon(
            onPressed: _signOut,
            icon: const Icon(Icons.logout),
            label: const Text("Logout"),
          ),
        ),
      ]),
      floatingActionButton: const NewBookWidget(),
      body: RefreshIndicator(
        onRefresh: () =>
            provider.Provider.of<BooksModel>(context, listen: false)
                .refresh(context),
        child: SizedBox(
          width: MediaQuery.of(context).size.width,
          child: provider.Consumer<BooksModel>(
            builder: _booksView,
          ),
        ),
      ),
    );
  }
}
