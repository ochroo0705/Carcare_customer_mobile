import 'package:carcare_customer_mobile/features/notifications/domain/app_notification.dart';

enum NotificationsStatus { initial, loading, data, empty, error, unavailable }

class NotificationsState {
  const NotificationsState({
    this.status = NotificationsStatus.initial,
    this.notifications = const [],
    this.unreadCount = 0,
    this.message,
  });

  final NotificationsStatus status;
  final List<AppNotification> notifications;

  /// The account's unread total as the server reports it — may exceed the
  /// unread rows in [notifications], which is only the first page.
  final int unreadCount;
  final String? message;

  bool get isLoading =>
      status == NotificationsStatus.initial ||
      status == NotificationsStatus.loading;
}
