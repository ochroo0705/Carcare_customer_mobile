import 'package:carcare_customer_mobile/features/notifications/domain/app_notification.dart';

abstract interface class NotificationsRepository {
  Future<List<AppNotification>> getNotifications();

  Future<void> markRead(String id);

  Future<void> markAllRead();

  /// Demo-only: appends a new unread notification, simulating one arriving
  /// from a backend that doesn't exist yet. Returns the notification so the
  /// caller can surface a local device notification for it.
  Future<AppNotification> simulateIncoming();

  /// Appends a notification received from a real push (FCM foreground
  /// message) to the in-app list. Unlike [simulateIncoming], the caller
  /// supplies real data rather than the repository synthesizing it.
  Future<void> addExternal(AppNotification notification);
}
