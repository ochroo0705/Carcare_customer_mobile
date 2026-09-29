import 'package:carcare_customer_mobile/app/theme/app_theme.dart';
import 'package:carcare_customer_mobile/app/theme/app_surfaces.dart';
import 'package:carcare_customer_mobile/core/widgets/animations.dart';
import 'package:carcare_customer_mobile/core/widgets/coming_soon_view.dart';
import 'package:carcare_customer_mobile/core/widgets/skeletons.dart';
import 'package:carcare_customer_mobile/features/notifications/domain/app_notification.dart';
import 'package:carcare_customer_mobile/features/notifications/presentation/controllers/notifications_controller.dart';
import 'package:carcare_customer_mobile/features/notifications/presentation/controllers/notifications_state.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:carcare_customer_mobile/core/widgets/state_views.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({
    required this.onBack,
    required this.onOpen,
    super.key,
  });

  final VoidCallback onBack;

  /// Deep-links the tapped notification (router wiring decides where, from the
  /// same `data` map a push tap carries). A notification with nothing routable
  /// — a broadcast, say — simply stays on this screen.
  final void Function(AppNotification notification) onOpen;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<NotificationsController>();
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: onBack),
        title: const Text('Мэдэгдэл'),
        actions: [
          // The server's unread total, not the loaded page's: with more than
          // one page of notifications the unread ones can all sit below the
          // first page, which would show a bell badge with no way to clear it.
          if (controller.unreadCount > 0)
            TextButton(
              onPressed: controller.markAllRead,
              child: const Text('Бүгдийг уншсан'),
            ),
        ],
      ),
      body: AppShellBackground(
        child: SafeArea(
          top: false,
          child: _Body(controller: controller, onOpen: onOpen),
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.controller, required this.onOpen});

  final NotificationsController controller;
  final void Function(AppNotification notification) onOpen;

  @override
  Widget build(BuildContext context) {
    final state = controller.state;
    return switch (state.status) {
      NotificationsStatus.initial ||
      NotificationsStatus.loading => const SkeletonNotificationList(),
      NotificationsStatus.error => ErrorView(
        message: state.message ?? 'Тодорхойгүй алдаа гарлаа.',
        onRetry: controller.load,
      ),
      NotificationsStatus.empty => const EmptyView(
        icon: Icons.notifications_none_rounded,
        title: 'Мэдэгдэл алга',
      ),
      NotificationsStatus.unavailable => const ComingSoonView(
        icon: Icons.notifications_none_rounded,
        title: 'Тун удахгүй',
        message: 'Мэдэгдлийн жагсаалт удахгүй нэмэгдэнэ.',
      ),
      NotificationsStatus.data => _NotificationsList(
        controller: controller,
        onOpen: onOpen,
      ),
    };
  }
}

class _NotificationsList extends StatelessWidget {
  const _NotificationsList({required this.controller, required this.onOpen});

  final NotificationsController controller;
  final void Function(AppNotification notification) onOpen;

  @override
  Widget build(BuildContext context) {
    final notifications = controller.state.notifications;
    return RefreshIndicator(
      onRefresh: controller.load,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 96),
        itemCount: notifications.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final notification = notifications[index];
          return RiseIn(
            index: index,
            child: _NotificationCard(
              notification: notification,
              // Read rows stay tappable — opening the thing a notification is
              // about is useful long after it has been read.
              onTap: () {
                if (!notification.isRead) controller.markRead(notification.id);
                onOpen(notification);
              },
            ),
          );
        },
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({required this.notification, this.onTap});

  final AppNotification notification;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      key: ValueKey('notification-${notification.id}'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.extraLarge),
      child: GlassSurface(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!notification.isRead)
              Container(
                margin: const EdgeInsets.only(top: 6, right: 10),
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: scheme.primary,
                  shape: BoxShape.circle,
                ),
              ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    notification.title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: notification.isRead
                          ? FontWeight.w600
                          : FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    notification.message,
                    style: Theme.of(context).textTheme.bodyMedium
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _formatRelative(notification.createdAt),
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatRelative(DateTime value) {
  final diff = DateTime.now().difference(value);
  if (diff.inMinutes < 1) return 'дөнгөж сая';
  if (diff.inHours < 1) return '${diff.inMinutes} минутын өмнө';
  if (diff.inDays < 1) return '${diff.inHours} цагийн өмнө';
  return '${diff.inDays} өдрийн өмнө';
}
