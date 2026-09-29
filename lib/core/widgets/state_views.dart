import 'package:flutter/material.dart';

/// Shared full-area error state with a retry button.
class ErrorView extends StatelessWidget {
  const ErrorView({
    required this.message,
    required this.onRetry,
    this.icon = Icons.cloud_off_outlined,
    this.retryKey,
    super.key,
  });

  final String message;
  final VoidCallback onRetry;
  final IconData icon;
  final Key? retryKey;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Semantics(
      liveRegion: true,
      container: true,
      label: message,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 52, color: muted),
              const SizedBox(height: 16),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              OutlinedButton(
                key: retryKey,
                onPressed: onRetry,
                child: const Text('Дахин оролдох'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shared full-area empty state.
class EmptyView extends StatelessWidget {
  const EmptyView({
    required this.icon,
    required this.title,
    this.message,
    this.action,
    super.key,
  });

  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 52, color: muted),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            if (message != null) ...[
              const SizedBox(height: 8),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(color: muted),
              ),
            ],
            if (action != null) ...[const SizedBox(height: 16), action!],
          ],
        ),
      ),
    );
  }
}
