import 'package:carcare_customer_mobile/features/notifications/domain/app_notification.dart';
import 'package:carcare_customer_mobile/features/notifications/domain/notifications_page.dart';

abstract interface class NotificationsRepository {
  Future<NotificationsPage> getNotifications();

  Future<void> markRead(String id);

  Future<void> markAllRead();

  /// Appends a notification received from a real push (FCM foreground
  /// message) to the in-app list — the caller supplies the real data.
  Future<void> addExternal(AppNotification notification);
}
