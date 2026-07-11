import 'package:flutter/material.dart';
import 'package:quota/contants.dart';

/// Nag banner shown while the signed-in user's email is unverified.
/// Checks the server once on mount so verification done elsewhere clears it.
class VerifyEmailBanner extends StatefulWidget {
  const VerifyEmailBanner({super.key});

  @override
  State<VerifyEmailBanner> createState() => _VerifyEmailBannerState();
}

class _VerifyEmailBannerState extends State<VerifyEmailBanner> {
  bool _sending = false;
  bool _dismissed = false;

  @override
  void initState() {
    super.initState();
    if (api.currentUser?.emailVerified == false) {
      api.refreshUser().then((_) {
        if (mounted) setState(() {});
      }).catchError((_) {});
    }
  }

  Future<void> _resend() async {
    setState(() => _sending = true);
    try {
      await api.resendVerification();
      if (mounted) {
        context.showSnackBar(message: "Verification email sent!");
      }
    } catch (ex) {
      if (mounted) {
        context.showErrorSnackBar(
            message: errorMessage(ex, "Could not send verification email"));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = api.currentUser;
    if (_dismissed || user == null || user.emailVerified) {
      return const SizedBox.shrink();
    }
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 15.0),
        child: Row(
          children: [
            Icon(Icons.mark_email_unread_outlined,
                size: 18, color: colorScheme.onSecondaryContainer),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                "Your email isn't verified yet.",
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSecondaryContainer),
              ),
            ),
            TextButton(
              onPressed: _sending ? null : _resend,
              child: const Text("Resend"),
            ),
            IconButton(
              iconSize: 18,
              icon: const Icon(Icons.close),
              onPressed: () => setState(() => _dismissed = true),
            ),
          ],
        ),
      ),
    );
  }
}
