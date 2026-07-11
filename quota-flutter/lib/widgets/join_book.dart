import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:quota/api/client.dart';
import 'package:quota/contants.dart';
import 'package:quota/state/books_model.dart';

/// Pull a token out of a pasted share link / invite link, or accept raw input.
String extractToken(String input) {
  final trimmed = input.trim();
  final uri = Uri.tryParse(trimmed);
  if (uri != null) {
    final queryToken = uri.queryParameters['token'];
    if (queryToken != null && queryToken.isNotEmpty) return queryToken;
    final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    if (segments.length > 1) return segments.last;
  }
  return trimmed;
}

/// "Join a book" flow: paste a share link or invite token, preview when
/// possible, then join. Share-link tokens are tried first, then invites.
Future<void> showJoinBookDialog(BuildContext context) async {
  final controller = TextEditingController();
  final input = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text("Join a book"),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: const InputDecoration(
          label: Text("Share link or invite code"),
          hintText: "Paste a link or code",
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel")),
        TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text("Next")),
      ],
    ),
  );
  controller.dispose();
  if (input == null || input.trim().isEmpty || !context.mounted) return;

  final token = extractToken(input);
  try {
    // Share-link tokens support a preview; confirm before joining.
    final preview = await api.previewShareLink(token);
    if (!context.mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Join book?"),
        content: Text(
            'Join "${preview.bookName ?? 'Untitled'}" by ${preview.ownerEmail}?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Cancel")),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text("Join")),
        ],
      ),
    );
    if (!(confirmed ?? false) || !context.mounted) return;
    await api.acceptShareLink(token);
  } on ApiException catch (shareError) {
    // Not a share link — it may be an email invite token.
    try {
      await api.acceptInvite(token);
    } catch (inviteError) {
      if (context.mounted) {
        context.showErrorSnackBar(
            message: errorMessage(shareError, "Could not join book"));
      }
      return;
    }
  } catch (ex) {
    if (context.mounted) {
      context.showErrorSnackBar(
          message: errorMessage(ex, "Could not join book"));
    }
    return;
  }

  if (context.mounted) {
    context.showSnackBar(message: "Joined!");
    await Provider.of<BooksModel>(context, listen: false).refresh(context);
  }
}
