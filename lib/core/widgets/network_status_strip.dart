import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// App-wide "no connection" strip pinned above every route. Unlike
/// [OfflineBanner] (a per-screen "showing cached data" notice), this reflects
/// live reachability of the customer API, so the customer learns they are
/// offline before a load fails. The child's top inset is removed while the
/// strip is shown, since the strip already sits under the status bar.
class NetworkStatusStrip extends StatelessWidget {
  const NetworkStatusStrip({
    required this.isOnline,
    required this.child,
    super.key,
  });

  final ValueListenable<bool> isOnline;
  final Widget child;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<bool>(
    valueListenable: isOnline,
    builder: (context, online, _) {
      final scheme = Theme.of(context).colorScheme;
      return Column(
        children: [
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            child: online
                ? const SizedBox(width: double.infinity)
                : Semantics(
                    key: const ValueKey('network-status-offline'),
                    container: true,
                    liveRegion: true,
                    label:
                        'Интернэт холболт алга. Холболт сэргэхэд '
                        'автоматаар шинэчлэгдэнэ.',
                    excludeSemantics: true,
                    child: Material(
                      color: scheme.inverseSurface,
                      child: SafeArea(
                        bottom: false,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 6,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.wifi_off_rounded,
                                size: 18,
                                color: scheme.onInverseSurface,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Интернэт холболт алга',
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: scheme.onInverseSurface,
                                        fontWeight: FontWeight.w600,
                                      ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
          ),
          Expanded(
            child: online
                ? child
                : MediaQuery.removePadding(
                    context: context,
                    removeTop: true,
                    child: child,
                  ),
          ),
        ],
      );
    },
  );
}
