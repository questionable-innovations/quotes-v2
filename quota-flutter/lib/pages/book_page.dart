import 'package:flutter/material.dart';
import 'package:fuzzywuzzy/fuzzywuzzy.dart';
import 'package:provider/provider.dart';
import 'package:quota/api/models.dart';
import 'package:quota/contants.dart';
import 'package:quota/state/books_model.dart';
import 'package:quota/state/quotes_model.dart';
import 'package:quota/widgets/book_args.dart';
import 'package:quota/widgets/quote.dart';

class BookPage extends StatefulWidget {
  final String bookId;
  const BookPage({super.key, required this.bookId});

  @override
  State<BookPage> createState() => _BookPageState();
}

class _BookPageState extends State<BookPage> {
  bool _search = false;
  late final TextEditingController _searchText;

  @override
  void initState() {
    super.initState();
    _searchText = TextEditingController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<QuotesModel>(context, listen: false)
          .ensure(context, widget.bookId);
    });
  }

  @override
  void dispose() {
    _searchText.dispose();
    super.dispose();
  }

  List<Quote> _filterQuotes(List<Quote> quotes) {
    if (!_search || _searchText.text.trim().isEmpty) {
      return quotes;
    }
    final matches = extractAllSorted<Quote>(
        query: _searchText.text,
        choices: quotes,
        getter: (e) => "${e.person} ${e.quote}",
        cutoff: 65);
    return matches.map((e) => e.choice).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<BooksModel, QuotesModel>(
      builder: (context, booksModel, quotesModel, child) {
        final Book? book = booksModel.bookById(widget.bookId);
        if (book == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        List<Quote> quotes = List.of(quotesModel.quotesForBook(book.id));
        quotes.sort((a, b) => b.date.compareTo(a.date));
        final filteredQuotes = _filterQuotes(quotes);

        return Scaffold(
          appBar: AppBar(
            title: Text(book.name),
            actions: [
              IconButton(
                icon: Icon(_search ? Icons.search_off : Icons.search),
                onPressed: () {
                  setState(() {
                    _search = !_search;
                    if (!_search) {
                      _searchText.clear();
                    }
                  });
                },
              ),
              if (book.isOwner)
                IconButton(
                    onPressed: () {
                      Navigator.of(context)
                          .pushNamed("/settings", arguments: BookArgs(book.id));
                    },
                    icon: const Icon(Icons.settings)),
            ],
            bottom: _search
                ? PreferredSize(
                    preferredSize: const Size(double.infinity, 45),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 15.0, vertical: 5.0),
                      child: TextField(
                        controller: _searchText,
                        autofocus: true,
                        decoration: const InputDecoration(
                            hintText: "Search",
                            icon: Icon(Icons.search),
                            isDense: true),
                        onChanged: (_) => setState(() {}),
                      ),
                    ))
                : null,
          ),
          floatingActionButton: FloatingActionButton(
            child: const Icon(Icons.create),
            onPressed: () {
              Navigator.of(context)
                  .pushNamed("/new-quote", arguments: BookArgs(book.id));
            },
          ),
          body: quotesModel.loading && !quotesModel.hasQuotesForBook(book.id)
              ? SizedBox(
                  width: MediaQuery.of(context).size.width,
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [CircularProgressIndicator(), Text("Loading")],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () async {
                    final model =
                        Provider.of<QuotesModel>(context, listen: false);
                    await model.refresh(context, book.id);
                    if (context.mounted) {
                      context.showSnackBar(
                          message:
                              "Refreshed! Found ${model.quotesForBook(book.id).length} quotes.");
                    }
                  },
                  child: Scrollbar(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(
                          vertical: 10.0, horizontal: 15.0),
                      itemBuilder: (BuildContext context, int i) =>
                          QuoteWidget(quote: filteredQuotes[i], book: book),
                      itemCount: filteredQuotes.length,
                    ),
                  ),
                ),
        );
      },
    );
  }
}
