import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:quota/api/models.dart';
import 'package:quota/contants.dart';
import 'package:quota/pages/quote_fullscreen_page.dart';
import 'package:quota/widgets/attachments.dart';
import 'package:quota/state/books_model.dart';
import 'package:quota/state/quotes_model.dart';

enum _QuoteAction { copy, delete }

class QuoteWidget extends StatelessWidget {
  const QuoteWidget({
    super.key,
    required this.quote,
    required this.book,
    this.onTap,
  });

  final Quote quote;
  final Book book;
  final VoidCallback? onTap;

  // Backend allows delete for the book owner or the quote's creator.
  bool get _canDelete =>
      book.isOwner || quote.createdBy == api.currentUser?.id;

  Future<void> _copy(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: '"${quote.quote}" — ${quote.person}'));
    if (context.mounted) {
      context.showSnackBar(message: "Copied to clipboard");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap ??
            () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) =>
                    QuoteFullscreenPage(book: book, initialQuoteId: quote.id))),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(15.0, 20.0, 5.0, 20.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      quote.quote,
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 18.0,
                      ),
                    ),
                    const Padding(
                        padding: EdgeInsets.symmetric(vertical: 10.0)),
                    RichText(
                      overflow: TextOverflow.ellipsis,
                      text: TextSpan(
                        style: DefaultTextStyle.of(context).style,
                        children: [
                          TextSpan(
                              text: quote.person,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold)),
                          TextSpan(
                              text:
                                  " - ${quote.date.day}/${quote.date.month}/${quote.date.year}")
                        ],
                      ),
                    ),
                    if (quote.attachments.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      AttachmentStrip(
                        attachments: quote.attachments,
                        onTap: (attachment) =>
                            showAttachmentViewer(context, attachment),
                      ),
                    ],
                  ],
                ),
              ),
              PopupMenuButton<_QuoteAction>(
                tooltip: "Quote options",
                onSelected: (action) {
                  switch (action) {
                    case _QuoteAction.copy:
                      _copy(context);
                    case _QuoteAction.delete:
                      confirmDeleteQuote(context, quote);
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: _QuoteAction.copy,
                    child: ListTile(
                      leading: Icon(Icons.copy),
                      title: Text("Copy"),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  if (_canDelete)
                    const PopupMenuItem(
                      value: _QuoteAction.delete,
                      child: ListTile(
                        leading: Icon(Icons.delete_outline),
                        title: Text("Delete"),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Ask for confirmation, then delete [quote] and refresh the book counts.
Future<bool> confirmDeleteQuote(BuildContext context, Quote quote) async {
  final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Confirm delete'),
          content: Text(
              'Are you sure you wanna delete the quote\n"${quote.quote}"\nby ${quote.person}'),
          actions: <Widget>[
            TextButton(
              style: TextButton.styleFrom(
                textStyle: Theme.of(context).textTheme.labelLarge,
              ),
              child: const Text('NOPE!'),
              onPressed: () {
                Navigator.of(context).pop(false);
              },
            ),
            TextButton(
              style: TextButton.styleFrom(
                textStyle: Theme.of(context).textTheme.labelLarge,
              ),
              child: const Text('Go ahead!'),
              onPressed: () {
                Navigator.of(context).pop(true);
              },
            ),
          ],
        );
      });

  if (!(confirmed ?? false) || !context.mounted) return false;

  try {
    await Provider.of<QuotesModel>(context, listen: false).deleteQuote(quote);
    if (context.mounted) {
      Provider.of<BooksModel>(context, listen: false).refresh(context);
    }
    return true;
  } catch (ex) {
    if (context.mounted) {
      context.showErrorSnackBar(
          message: errorMessage(ex, "Could not delete quote"));
    }
    return false;
  }
}
