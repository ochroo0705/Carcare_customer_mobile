import 'package:carcare_customer_mobile/app/theme/app_theme.dart';
import 'package:carcare_customer_mobile/features/auth/presentation/auth_controller.dart';
import 'package:carcare_customer_mobile/features/discovery/presentation/widgets/discovery_map.dart';
import 'package:carcare_customer_mobile/features/notifications/presentation/controllers/notifications_controller.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// A bare, unobtrusive spinner over the map's top-left corner, shown while a
/// filter/search change is re-fetching markers for the on-screen viewport.
/// Deliberately not a banner with text — the map itself is the content here.
class MapRefreshSpinner extends StatelessWidget {
  const MapRefreshSpinner({super.key});

  @override
  Widget build(BuildContext context) => Container(
    key: const ValueKey('discovery-map-refreshing'),
    width: 30,
    height: 30,
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.9),
      shape: BoxShape.circle,
      boxShadow: [
        BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 6),
      ],
    ),
    padding: const EdgeInsets.all(6),
    child: const CircularProgressIndicator(strokeWidth: 2.5),
  );
}

/// Everything that would otherwise be Google Maps' own platform controls
/// (zoom, locate-me) plus the shell's notifications bell and map/list
/// toggle, combined into one compact stack — the platform controls can't be
/// repositioned or restyled, and with the AppBar hidden in map mode the
/// notifications bell needs a new home anyway.
class MapActionStack extends StatelessWidget {
  const MapActionStack({
    required this.mapKey,
    required this.onNotificationsRequested,
    required this.onToggleList,
    super.key,
  });

  final GlobalKey<DiscoveryMapState> mapKey;
  final VoidCallback onNotificationsRequested;
  final VoidCallback onToggleList;

  @override
  Widget build(BuildContext context) {
    // Scoped to the two values the stack shows, so an unread-count push or
    // an account change rebuilds this stack and never the map behind it.
    final showNotifications = context.select<AuthController, bool>(
      (auth) => auth.account != null,
    );
    final unreadCount = context.select<NotificationsController, int>(
      (notifications) => notifications.unreadCount,
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showNotifications) ...[
          RoundMapButton(
            key: const ValueKey('discovery-map-notifications'),
            icon: Icons.notifications_outlined,
            badgeCount: unreadCount,
            onPressed: onNotificationsRequested,
          ),
          const SizedBox(height: 10),
        ],
        RoundMapButton(
          key: const ValueKey('discovery-map-list-toggle'),
          icon: Icons.view_list_outlined,
          onPressed: onToggleList,
        ),
        const SizedBox(height: 10),
        MapZoomButtonGroup(mapKey: mapKey),
        const SizedBox(height: 10),
        RoundMapButton(
          key: const ValueKey('discovery-map-locate-me'),
          icon: Icons.my_location_rounded,
          onPressed: () => mapKey.currentState?.locateMe(),
        ),
      ],
    );
  }
}

class RoundMapButton extends StatelessWidget {
  const RoundMapButton({
    required this.icon,
    required this.onPressed,
    this.badgeCount = 0,
    super.key,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final int badgeCount;

  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.surface,
    shape: const CircleBorder(),
    elevation: 4,
    child: InkWell(
      customBorder: const CircleBorder(),
      onTap: onPressed,
      child: SizedBox(
        width: 48,
        height: 48,
        child: Center(
          child: Badge(
            isLabelVisible: badgeCount > 0,
            label: Text(badgeCount > 9 ? '9+' : '$badgeCount'),
            child: Icon(icon, size: 22),
          ),
        ),
      ),
    ),
  );
}

/// Stand-in for the platform zoom control, which Google Maps always pins to
/// the bottom-right and can't be moved or restyled.
class MapZoomButtonGroup extends StatelessWidget {
  const MapZoomButtonGroup({required this.mapKey, super.key});

  final GlobalKey<DiscoveryMapState> mapKey;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface,
      elevation: 4,
      borderRadius: BorderRadius.circular(AppRadii.extraLarge),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            key: const ValueKey('discovery-map-zoom-in'),
            onTap: () => mapKey.currentState?.zoomIn(),
            child: const SizedBox(
              width: 48,
              height: 48,
              child: Center(child: Icon(Icons.add, size: 20)),
            ),
          ),
          Divider(height: 1, color: scheme.outlineVariant),
          InkWell(
            key: const ValueKey('discovery-map-zoom-out'),
            onTap: () => mapKey.currentState?.zoomOut(),
            child: const SizedBox(
              width: 48,
              height: 48,
              child: Center(child: Icon(Icons.remove, size: 20)),
            ),
          ),
        ],
      ),
    );
  }
}
