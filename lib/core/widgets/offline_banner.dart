import 'package:flutter/material.dart';

/// Shown above a screen's data when it is displaying a locally cached list
/// because the most recent load attempt failed (e.g. no network) — one of
/// the deliberate screen states `CUSTOMER_FLUTTER_PRINCIPLES.md` §3.7
/// requires ("offline with cached data" / "refreshing existing data").
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({
    required this.message,
    required this.semanticsLabel,
    required this.onRetry,
    this.retryKey,
    super.key,
  });

  final String message;
  final String semanticsLabel;
  final Future<void> Function() onRetry;
  final Key? retryKey;

  @override
  Widget build(BuildContext context) {
    final largeText = MediaQuery.textScalerOf(context).scale(1) >= 1.4;
    final messageText = Text(
      message,
      style: Theme.of(context).textTheme.bodySmall
          ?.copyWith(fontWeight: FontWeight.w600),
    );
    final action = TextButton(
      key: retryKey,
      onPressed: onRetry,
      child: const Text('Дахин оролдох'),
    );
    return Semantics(
      container: true,
      liveRegion: true,
      label: semanticsLabel,
      child: Material(
        color: Theme.of(context).colorScheme.surface,
        elevation: 5,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
          child: largeText
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.cloud_off_outlined,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 9),
                        Expanded(child: messageText),
                      ],
                    ),
                    Align(alignment: Alignment.centerRight, child: action),
                  ],
                )
              : Row(
                  children: [
                    Icon(
                      Icons.cloud_off_outlined,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 9),
                    Expanded(child: messageText),
                    action,
                  ],
                ),
        ),
      ),
    );
  }
}
