import 'package:carcare_customer_mobile/app/theme/app_surfaces.dart';
import 'package:carcare_customer_mobile/features/notifications/domain/app_notification.dart';
import 'package:carcare_customer_mobile/features/notifications/presentation/controllers/notifications_controller.dart';
import 'package:carcare_customer_mobile/features/notifications/presentation/controllers/notifications_state.dart';
import 'package:flutter/material.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({
    required this.controller,
    required this.onBack,
    super.key,
  });

  final NotificationsController controller;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      leading: BackButton(onPressed: onBack),
      title: const Text('Мэдэгдэл'),
      actions: [
        if (controller.state.notifications.any((n) => !n.isRead))
          TextButton(
            onPressed: controller.markAllRead,
            child: const Text('Бүгдийг уншсан'),
          ),
      ],
    ),
    body: AppShellBackground(
      child: SafeArea(top: false, child: _Body(controller: controller)),
    ),
    floatingActionButton: FloatingActionButton.extended(
      key: const ValueKey('notifications-send-test'),
      onPressed: controller.isSendingTest
          ? null
          : controller.sendTestNotification,
      icon: controller.isSendingTest
          ? const SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.notifications_active_outlined),
      label: const Text('Тест мэдэгдэл илгээх'),
    ),
  );
}

class _Body extends StatelessWidget {
  const _Body({required this.controller});

  final NotificationsController controller;

  @override
  Widget build(BuildContext context) {
    final state = controller.state;
    return switch (state.status) {
      NotificationsStatus.initial || NotificationsStatus.loading =>
        const Center(child: CircularProgressIndicator()),
      NotificationsStatus.error => _ErrorView(
        message: state.message ?? 'Тодорхойгүй алдаа гарлаа.',
        onRetry: controller.load,
      ),
      NotificationsStatus.empty => const _EmptyNotifications(),
      NotificationsStatus.data => _NotificationsList(controller: controller),
    };
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.error_outline_rounded,
            size: 52,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(height: 16),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: onRetry,
            child: const Text('Дахин оролдох'),
          ),
        ],
      ),
    ),
  );
}

class _EmptyNotifications extends StatelessWidget {
  const _EmptyNotifications();

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.notifications_none_rounded,
            size: 58,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 18),
          Text(
            'Мэдэгдэл алга',
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    ),
  );
}

class _NotificationsList extends StatelessWidget {
  const _NotificationsList({required this.controller});

  final NotificationsController controller;

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
          return _NotificationCard(
            notification: notification,
            onTap: notification.isRead
                ? null
                : () => controller.markRead(notification.id),
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
      borderRadius: BorderRadius.circular(20),
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
