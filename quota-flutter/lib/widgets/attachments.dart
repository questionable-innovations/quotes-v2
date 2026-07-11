import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:quota/api/models.dart';
import 'package:quota/contants.dart';

/// Session-scoped cache so swiping between quotes doesn't re-download images.
final Map<String, Future<Uint8List>> _bytesCache = {};

Future<Uint8List> attachmentBytes(String attachmentId) =>
    _bytesCache.putIfAbsent(
        attachmentId,
        () => api.getAttachmentBytes(attachmentId).onError((e, st) {
              _bytesCache.remove(attachmentId);
              throw e!;
            }));

/// Renders an image attachment, downloading it with auth.
class AttachmentImage extends StatelessWidget {
  final Attachment attachment;
  final BoxFit fit;

  const AttachmentImage(
      {super.key, required this.attachment, this.fit = BoxFit.cover});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List>(
      future: attachmentBytes(attachment.id),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Icon(Icons.broken_image));
        }
        if (!snapshot.hasData) {
          return const Center(
              child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2)));
        }
        return Image.memory(snapshot.data!, fit: fit, gaplessPlayback: true);
      },
    );
  }
}

String formatBytes(int bytes) {
  if (bytes < 1024) return "$bytes B";
  if (bytes < 1024 * 1024) return "${(bytes / 1024).toStringAsFixed(1)} KB";
  return "${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB";
}

/// Horizontal strip of a quote's attachments: image thumbnails plus
/// filename chips for non-image files.
class AttachmentStrip extends StatelessWidget {
  final List<Attachment> attachments;
  final void Function(Attachment)? onTap;
  final void Function(Attachment)? onDelete;

  const AttachmentStrip(
      {super.key, required this.attachments, this.onTap, this.onDelete});

  @override
  Widget build(BuildContext context) {
    if (attachments.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 90,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: attachments.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final attachment = attachments[i];
          return _AttachmentThumb(
            attachment: attachment,
            onTap: onTap == null ? null : () => onTap!(attachment),
            onDelete: onDelete == null ? null : () => onDelete!(attachment),
          );
        },
      ),
    );
  }
}

class _AttachmentThumb extends StatelessWidget {
  final Attachment attachment;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  const _AttachmentThumb({required this.attachment, this.onTap, this.onDelete});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final child = attachment.isImage
        ? SizedBox(
            width: 90,
            height: 90,
            child: AttachmentImage(attachment: attachment))
        : Container(
            width: 110,
            height: 90,
            padding: const EdgeInsets.all(8),
            color: colorScheme.surfaceContainerHighest,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.insert_drive_file),
                const SizedBox(height: 4),
                Text(attachment.filename,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall),
                Text(formatBytes(attachment.sizeBytes),
                    style: Theme.of(context).textTheme.labelSmall),
              ],
            ),
          );

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Stack(
        children: [
          InkWell(onTap: onTap, child: child),
          if (onDelete != null)
            Positioned(
              top: 0,
              right: 0,
              child: Material(
                color: Colors.black45,
                borderRadius:
                    const BorderRadius.only(bottomLeft: Radius.circular(10)),
                child: InkWell(
                  onTap: onDelete,
                  child: const Padding(
                    padding: EdgeInsets.all(4.0),
                    child:
                        Icon(Icons.close, size: 16, color: Colors.white),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Fullscreen zoomable viewer for an image attachment.
void showAttachmentViewer(BuildContext context, Attachment attachment) {
  if (!attachment.isImage) return;
  Navigator.of(context).push(MaterialPageRoute(
    builder: (_) => Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        title: Text(attachment.filename),
      ),
      body: Center(
        child: InteractiveViewer(
          maxScale: 5,
          child:
              AttachmentImage(attachment: attachment, fit: BoxFit.contain),
        ),
      ),
    ),
  ));
}
