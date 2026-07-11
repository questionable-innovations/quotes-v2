import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:quota/api/models.dart';
import 'package:quota/contants.dart';
import 'package:quota/state/quotes_model.dart';
import 'package:quota/utils/pick_images.dart';
import 'package:quota/utils/scenic_image.dart';
import 'package:quota/widgets/attachments.dart';
import 'package:quota/widgets/quote.dart';

/// Immersive, swipeable "poster" view of a book's quotes: each quote is
/// typeset over its own photo (or a random scenic backdrop when it has none).
class QuoteFullscreenPage extends StatefulWidget {
  final Book book;
  final String initialQuoteId;

  const QuoteFullscreenPage(
      {super.key, required this.book, required this.initialQuoteId});

  @override
  State<QuoteFullscreenPage> createState() => _QuoteFullscreenPageState();
}

class _QuoteFullscreenPageState extends State<QuoteFullscreenPage> {
  PageController? _controller;
  int _currentPage = 0;

  bool _canDelete(Quote quote) =>
      widget.book.isOwner || quote.createdBy == api.currentUser?.id;

  List<Quote> _sortedQuotes(QuotesModel model) {
    final quotes = List.of(model.quotesForBook(widget.book.id));
    quotes.sort((a, b) => b.date.compareTo(a.date));
    return quotes;
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _copy(Quote quote) async {
    await Clipboard.setData(
        ClipboardData(text: '"${quote.quote}" — ${quote.person}'));
    if (mounted) {
      context.showSnackBar(message: "Copied to clipboard");
    }
  }

  Future<void> _attach(Quote quote) async {
    final images = await pickCompressedImages(context);
    if (images.isEmpty || !mounted) return;
    final model = Provider.of<QuotesModel>(context, listen: false);
    try {
      for (final XFile image in images) {
        final bytes = await image.readAsBytes();
        await model.uploadAttachment(quote, image.name, bytes);
      }
      if (mounted) {
        context.showSnackBar(
            message:
                "Attached ${images.length} ${images.length == 1 ? 'image' : 'images'}");
      }
    } catch (ex) {
      if (mounted) {
        context.showErrorSnackBar(
            message: errorMessage(ex, "Could not upload attachment"));
      }
    }
  }

  Future<void> _deleteAttachment(Quote quote, Attachment attachment) async {
    try {
      await Provider.of<QuotesModel>(context, listen: false)
          .deleteAttachment(quote, attachment);
    } catch (ex) {
      if (mounted) {
        context.showErrorSnackBar(
            message: errorMessage(ex, "Could not delete attachment"));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<QuotesModel>(builder: (context, quotesModel, child) {
      final quotes = _sortedQuotes(quotesModel);
      if (quotes.isEmpty) {
        // Last quote was deleted from under us.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) Navigator.of(context).pop();
        });
        return const Scaffold(body: SizedBox.shrink());
      }

      if (_controller == null) {
        final initial =
            quotes.indexWhere((q) => q.id == widget.initialQuoteId);
        _currentPage = initial < 0 ? 0 : initial;
        _controller = PageController(initialPage: _currentPage);
      }
      final page = _currentPage.clamp(0, quotes.length - 1);
      final quote = quotes[page];

      return Scaffold(
        backgroundColor: Colors.black,
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          title: Text(widget.book.name),
          actions: [
            IconButton(
              icon: const Icon(Icons.copy),
              tooltip: "Copy quote",
              onPressed: () => _copy(quote),
            ),
            IconButton(
              icon: const Icon(Icons.add_photo_alternate_outlined),
              tooltip: "Attach image",
              onPressed: () => _attach(quote),
            ),
            if (_canDelete(quote))
              IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: "Delete quote",
                onPressed: () => confirmDeleteQuote(context, quote),
              ),
          ],
        ),
        body: Stack(
          children: [
            PageView.builder(
              controller: _controller,
              itemCount: quotes.length,
              onPageChanged: (page) => setState(() => _currentPage = page),
              itemBuilder: (context, i) => _QuoteSlide(
                quote: quotes[i],
                canManageAttachments: _canDelete(quotes[i]),
                onDeleteAttachment: (attachment) =>
                    _deleteAttachment(quotes[i], attachment),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 12,
              child: SafeArea(
                top: false,
                child: Text(
                  "${page + 1} / ${quotes.length}",
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .labelLarge
                      ?.copyWith(color: Colors.white70),
                ),
              ),
            ),
          ],
        ),
      );
    });
  }
}

class _QuoteSlide extends StatelessWidget {
  final Quote quote;
  final bool canManageAttachments;
  final void Function(Attachment) onDeleteAttachment;

  const _QuoteSlide(
      {required this.quote,
      required this.canManageAttachments,
      required this.onDeleteAttachment});

  Attachment? get _backdropAttachment {
    for (final attachment in quote.attachments) {
      if (attachment.isImage) return attachment;
    }
    return null;
  }

  /// Quote's own photo when it has one, otherwise a random scenic shot.
  Widget _backdrop() {
    final own = _backdropAttachment;
    if (own != null) {
      return AttachmentImage(attachment: own, fit: BoxFit.cover);
    }
    return FutureBuilder<Uint8List?>(
      future: scenicImageFor(quote.id),
      builder: (context, snapshot) {
        final bytes = snapshot.data;
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 500),
          child: bytes == null
              ? const _FallbackBackdrop()
              : Image.memory(bytes,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                  gaplessPlayback: true),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Stack(
      fit: StackFit.expand,
      children: [
        _backdrop(),
        // Scrim so the type stays legible over any photo.
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.black54, Colors.black38, Colors.black87],
            ),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 30.0),
            child: Center(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.format_quote,
                        size: 60, color: Colors.white70),
                    const SizedBox(height: 10),
                    Text(
                      quote.quote,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        color: Colors.white,
                        fontFamily: 'Georgia',
                        fontFamilyFallback: const ['serif'],
                        fontStyle: FontStyle.italic,
                        fontWeight: FontWeight.w500,
                        height: 1.35,
                        shadows: const [
                          Shadow(blurRadius: 12, color: Colors.black87)
                        ],
                      ),
                    ),
                    const SizedBox(height: 30),
                    Row(
                      children: [
                        Container(
                          width: 40,
                          height: 3,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                quote.person,
                                style: theme.textTheme.titleLarge?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold),
                              ),
                              Text(
                                "${quote.date.day}/${quote.date.month}/${quote.date.year}",
                                style: theme.textTheme.bodyMedium
                                    ?.copyWith(color: Colors.white70),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (quote.attachments.isNotEmpty) ...[
                      const SizedBox(height: 30),
                      AttachmentStrip(
                        // Include the backdrop photo too so it can be
                        // opened full-size or deleted.
                        attachments: quote.attachments,
                        onTap: (attachment) =>
                            showAttachmentViewer(context, attachment),
                        onDelete:
                            canManageAttachments ? onDeleteAttachment : null,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Dark gradient shown while the scenic photo loads (or offline).
class _FallbackBackdrop extends StatelessWidget {
  const _FallbackBackdrop();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2C1B47), Color(0xFF1A1A2E), Color(0xFF0F2027)],
        ),
      ),
    );
  }
}
