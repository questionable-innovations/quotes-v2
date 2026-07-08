import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:quota/api/models.dart';
import 'package:quota/contants.dart';
import 'package:quota/state/books_model.dart';
import 'package:quota/state/quotes_model.dart';

class QuoteRemoveWidget extends StatelessWidget {
  const QuoteRemoveWidget({
    super.key,
    required this.quote,
  });

  final Quote quote;

  Future<void> _confirmDelete(BuildContext context) async {
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

    if ((confirmed ?? false) && context.mounted) {
      try {
        await Provider.of<QuotesModel>(context, listen: false)
            .deleteQuote(quote);
        if (context.mounted) {
          Provider.of<BooksModel>(context, listen: false).refresh(context);
        }
      } catch (ex) {
        if (context.mounted) {
          context.showErrorSnackBar(
              message: errorMessage(ex, "Could not delete quote"));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(
        Icons.delete_outline,
        size: 20.0,
      ),
      tooltip: "Delete quote",
      onPressed: () => _confirmDelete(context),
    );
  }
}
