import 'package:flutter/material.dart';
import 'package:quota/api/models.dart';
import 'package:quota/widgets/book_args.dart';

class BookWidget extends StatelessWidget {
  const BookWidget({
    super.key,
    required this.book,
  });

  final Book book;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 15.0, vertical: 6.0),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Navigator.pushNamed(context, "/book", arguments: BookArgs(book.id));
        },
        child: Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 20.0, vertical: 18.0),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      book.name,
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (!book.isOwner) ...[
                      const SizedBox(height: 2),
                      Text(
                        book.ownerEmail,
                        style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurface
                                .withValues(alpha: 0.6)),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                "${book.quoteCount} ${book.quoteCount == 1 ? 'quote' : 'quotes'}",
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right,
                  size: 20,
                  color: colorScheme.onSurface.withValues(alpha: 0.4)),
            ],
          ),
        ),
      ),
    );
  }
}
