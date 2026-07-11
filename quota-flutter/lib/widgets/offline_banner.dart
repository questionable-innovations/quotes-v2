import 'package:flutter/material.dart';

/// Slim banner shown when the app is displaying cached data because the
/// server is unreachable.
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: colorScheme.tertiaryContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 15.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cloud_off,
                size: 16, color: colorScheme.onTertiaryContainer),
            const SizedBox(width: 8),
            Text(
              "Offline — showing saved data",
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: colorScheme.onTertiaryContainer),
            ),
          ],
        ),
      ),
    );
  }
}
