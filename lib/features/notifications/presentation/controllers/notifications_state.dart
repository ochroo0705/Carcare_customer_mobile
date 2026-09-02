import 'package:carcare_customer_mobile/features/notifications/domain/app_notification.dart';

enum NotificationsStatus { initial, loading, data, empty, error }

class NotificationsState {
  const NotificationsState({
    this.status = NotificationsStatus.initial,
    this.notifications = const [],
    this.message,
  });

  final NotificationsStatus status;
  final List<AppNotification> notifications;
  final String? message;

  bool get isLoading =>
      status == NotificationsStatus.initial ||
      status == NotificationsStatus.loading;
}
