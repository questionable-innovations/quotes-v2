import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:quota/api/models.dart';
import 'package:quota/contants.dart';

/// Owner-only card for managing a book's share links.
class ShareLinksSection extends StatefulWidget {
  final String bookId;

  const ShareLinksSection({super.key, required this.bookId});

  @override
  State<ShareLinksSection> createState() => _ShareLinksSectionState();
}

class _ShareLinksSectionState extends State<ShareLinksSection> {
  List<ShareLink> _links = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final links = await api.listShareLinks(widget.bookId);
      if (mounted) {
        setState(() {
          _links = links;
          _loading = false;
        });
      }
    } catch (ex) {
      log("Could not fetch share links", error: ex);
      if (mounted) {
        setState(() => _loading = false);
        context.showErrorSnackBar(
            message: errorMessage(ex, "Could not fetch share links"));
      }
    }
  }

  Future<void> _create() async {
    final options = await showDialog<_ShareLinkOptions>(
        context: context, builder: (_) => const _CreateShareLinkDialog());
    if (options == null || !mounted) return;

    try {
      final link = await api.createShareLink(widget.bookId,
          expiresAt: options.expiresAt, maxUses: options.maxUses);
      await _load();
      if (mounted) {
        // The full URL is only available at creation time, so offer it now.
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text("Share link created"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                    "Anyone with this link can join the book. It won't be shown again:"),
                const SizedBox(height: 10),
                SelectableText(link.url,
                    style: const TextStyle(fontFamily: 'monospace')),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: link.url));
                  if (context.mounted) {
                    Navigator.pop(context);
                    context.showSnackBar(message: "Link copied");
                  }
                },
                child: const Text("Copy & close"),
              ),
            ],
          ),
        );
      }
    } catch (ex) {
      log("Could not create share link", error: ex);
      if (mounted) {
        context.showErrorSnackBar(
            message: errorMessage(ex, "Could not create share link"));
      }
    }
  }

  Future<void> _revoke(ShareLink link) async {
    try {
      await api.deleteShareLink(widget.bookId, link.id);
      await _load();
    } catch (ex) {
      log("Could not revoke share link", error: ex);
      if (mounted) {
        context.showErrorSnackBar(
            message: errorMessage(ex, "Could not revoke share link"));
      }
    }
  }

  String _linkSubtitle(ShareLink link) {
    final parts = <String>[
      link.maxUses == null
          ? "${link.uses} uses"
          : "${link.uses}/${link.maxUses} uses",
      if (link.expiresAt != null)
        "expires ${link.expiresAt!.day}/${link.expiresAt!.month}/${link.expiresAt!.year}",
      if (link.revoked) "revoked",
    ];
    return parts.join(" · ");
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Text(
          "Share links",
          style: TextStyle(fontSize: 25.0, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        if (_loading)
          const Padding(
            padding: EdgeInsets.all(10.0),
            child: CircularProgressIndicator(),
          )
        else if (_links.isEmpty)
          const Padding(
            padding: EdgeInsets.all(10.0),
            child: Text("No share links yet."),
          )
        else
          ..._links.map((link) => ListTile(
                dense: true,
                leading: Icon(link.revoked ? Icons.link_off : Icons.link),
                title: Text("Link ${link.id.substring(0, 8)}…"),
                subtitle: Text(_linkSubtitle(link)),
                trailing: link.revoked
                    ? null
                    : TextButton.icon(
                        onPressed: () => _revoke(link),
                        icon: const Icon(Icons.cancel_outlined),
                        label: const Text("Revoke"),
                      ),
              )),
        Padding(
          padding: const EdgeInsets.all(10.0),
          child: ElevatedButton.icon(
            onPressed: _create,
            icon: const Icon(Icons.add_link),
            label: const Text("Create share link"),
          ),
        ),
      ],
    );
  }
}

class _ShareLinkOptions {
  final DateTime? expiresAt;
  final int? maxUses;

  _ShareLinkOptions({this.expiresAt, this.maxUses});
}

class _CreateShareLinkDialog extends StatefulWidget {
  const _CreateShareLinkDialog();

  @override
  State<_CreateShareLinkDialog> createState() => _CreateShareLinkDialogState();
}

class _CreateShareLinkDialogState extends State<_CreateShareLinkDialog> {
  int? _expiresInDays;
  final _maxUsesController = TextEditingController();

  @override
  void dispose() {
    _maxUsesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("New share link"),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<int?>(
            initialValue: _expiresInDays,
            decoration: const InputDecoration(label: Text("Expires")),
            items: const [
              DropdownMenuItem(value: null, child: Text("Never")),
              DropdownMenuItem(value: 1, child: Text("In 1 day")),
              DropdownMenuItem(value: 7, child: Text("In 7 days")),
              DropdownMenuItem(value: 30, child: Text("In 30 days")),
            ],
            onChanged: (value) => setState(() => _expiresInDays = value),
          ),
          TextField(
            controller: _maxUsesController,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration:
                const InputDecoration(label: Text("Max uses (optional)")),
          ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel")),
        TextButton(
          onPressed: () => Navigator.pop(
              context,
              _ShareLinkOptions(
                expiresAt: _expiresInDays == null
                    ? null
                    : DateTime.now().add(Duration(days: _expiresInDays!)),
                maxUses: int.tryParse(_maxUsesController.text),
              )),
          child: const Text("Create"),
        ),
      ],
    );
  }
}
