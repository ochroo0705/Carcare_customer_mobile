import 'package:carcare_customer_mobile/features/notifications/domain/notification_type.dart';

class AppNotification {
  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    required this.createdAt,
    required this.isRead,
    this.data = const {},
  });

  final String id;
  final NotificationType type;
  final String title;
  final String message;
  final DateTime createdAt;
  final bool isRead;

  /// The server's raw `data` payload (`appointmentId`, `orderId`, …) — the
  /// same map an FCM push carries, so a tap on a list row can deep-link
  /// through exactly the same router path as a tap on a push banner.
  final Map<String, String> data;

  AppNotification copyWith({bool? isRead}) => AppNotification(
    id: id,
    type: type,
    title: title,
    message: message,
    createdAt: createdAt,
    isRead: isRead ?? this.isRead,
    data: data,
  );
}
