import 'package:flutter/material.dart';
import 'package:quota/api/models.dart';
import 'package:quota/contants.dart';
import 'package:quota/widgets/quote_remove.dart';

class QuoteWidget extends StatelessWidget {
  const QuoteWidget({
    super.key,
    required this.quote,
    required this.book,
  });

  final Quote quote;
  final Book book;

  // Backend allows delete for the book owner or the quote's creator.
  bool get _canDelete =>
      book.isOwner || quote.createdBy == api.currentUser?.id;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20.0, horizontal: 15.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              flex: 3,
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
                  const Padding(padding: EdgeInsets.symmetric(vertical: 10.0)),
                  RichText(
                    text: TextSpan(
                      style: DefaultTextStyle.of(context).style,
                      children: [
                        TextSpan(
                            text: quote.person,
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                        TextSpan(
                            text:
                                " - ${quote.date.day}/${quote.date.month}/${quote.date.year}")
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (_canDelete) QuoteRemoveWidget(quote: quote),
          ],
        ),
      ),
    );
  }
}
