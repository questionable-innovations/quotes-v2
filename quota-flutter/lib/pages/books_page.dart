import 'package:flutter/material.dart';
import 'package:provider/provider.dart' as provider;
import 'package:quota/api/models.dart';
import 'package:quota/state/books_model.dart';
import 'package:quota/state/quotes_model.dart';
import 'package:quota/widgets/book.dart';
import 'package:quota/widgets/join_book.dart';
import 'package:quota/widgets/new_book.dart';
import 'package:quota/widgets/offline_banner.dart';
import 'package:quota/widgets/verify_email_banner.dart';

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

  Widget _header(BuildContext context, BooksModel booksModel) {
    final theme = Theme.of(context);
    final totalQuotes =
        booksModel.books.fold<int>(0, (sum, b) => sum + b.quoteCount);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20.0, 20.0, 20.0, 10.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Welcome back",
            style: theme.textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          if (api.currentUser != null)
            Text(
              api.currentUser!.email,
              style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
            ),
          const SizedBox(height: 4),
          Text(
            "${booksModel.books.length} books · $totalQuotes quotes",
            style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String title) => Padding(
        padding: const EdgeInsets.fromLTRB(20.0, 15.0, 20.0, 5.0),
        child: Text(
          title,
          style: Theme.of(context)
              .textTheme
              .titleSmall
              ?.copyWith(color: Theme.of(context).colorScheme.primary),
        ),
      );

  Widget _booksView(
      BuildContext context, BooksModel booksModel, Widget? child) {
    if (booksModel.loading && booksModel.books.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    List<Book> books = List.of(booksModel.books);
    books.sort((a, b) => a.name.compareTo(b.name));
    final ownBooks = books.where((b) => b.isOwner).toList();
    final sharedBooks = books.where((b) => !b.isOwner).toList();

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        _header(context, booksModel),
        if (books.isEmpty)
          Padding(
            padding: const EdgeInsets.all(40.0),
            child: Column(
              children: [
                Icon(Icons.menu_book,
                    size: 60,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.3)),
                const SizedBox(height: 10),
                const Text("No books yet — create one to get started!",
                    textAlign: TextAlign.center),
              ],
            ),
          ),
        if (ownBooks.isNotEmpty) _sectionTitle(context, "Your books"),
        ...ownBooks.map((book) => BookWidget(book: book)),
        if (sharedBooks.isNotEmpty) _sectionTitle(context, "Shared with you"),
        ...sharedBooks.map((book) => BookWidget(book: book)),
        const SizedBox(height: 90),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Quota"),
        actions: [
          IconButton(
            onPressed: () => showJoinBookDialog(context),
            icon: const Icon(Icons.group_add_outlined),
            tooltip: "Join a book",
          ),
          IconButton(
            onPressed: _signOut,
            icon: const Icon(Icons.logout),
            tooltip: "Logout",
          ),
        ],
      ),
      floatingActionButton: const NewBookWidget(),
      body: provider.Consumer<BooksModel>(
        builder: (context, booksModel, child) => Column(
          children: [
            if (booksModel.offline) const OfflineBanner(),
            const VerifyEmailBanner(),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => booksModel.refresh(context),
                child: SizedBox(
                  width: MediaQuery.of(context).size.width,
                  child: _booksView(context, booksModel, child),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
