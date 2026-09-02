import 'package:carcare_customer_mobile/core/errors/app_failure.dart';
import 'package:carcare_customer_mobile/features/notifications/domain/app_notification.dart';
import 'package:carcare_customer_mobile/features/notifications/domain/notification_type.dart';
import 'package:carcare_customer_mobile/features/notifications/domain/notifications_repository.dart';

class FakeNotificationsRepository implements NotificationsRepository {
  FakeNotificationsRepository() : _now = DateTime.now();

  final DateTime _now;
  var _sequence = 0;

  late final List<AppNotification> _notifications = [
    AppNotification(
      id: 'seed-notification-1',
      type: NotificationType.appointmentConfirmed,
      title: 'Цаг баталгаажлаа',
      message: 'Инфосистемс — Үндсэн салбар дахь таны цаг баталгаажлаа.',
      createdAt: _now.subtract(const Duration(hours: 3)),
      isRead: false,
    ),
    AppNotification(
      id: 'seed-notification-2',
      type: NotificationType.appointmentReminder,
      title: 'Сануулга',
      message: 'Маргааш 10:00 цагт Тэсо Моторс дээр цаг захиалгатай байна.',
      createdAt: _now.subtract(const Duration(days: 1)),
      isRead: false,
    ),
    AppNotification(
      id: 'seed-notification-3',
      type: NotificationType.broadcast,
      title: 'Мэдэгдэл',
      message: 'Carservice апп шинэчлэгдлээ — шинэ боломжуудыг үзээрэй.',
      createdAt: _now.subtract(const Duration(days: 6)),
      isRead: true,
    ),
  ];

  @override
  Future<List<AppNotification>> getNotifications() async =>
      List.unmodifiable(_notifications);

  @override
  Future<void> markRead(String id) async {
    final index = _notifications.indexWhere(
      (notification) => notification.id == id,
    );
    if (index == -1) throw const NotFoundFailure();
    _notifications[index] = _notifications[index].copyWith(isRead: true);
  }

  @override
  Future<void> markAllRead() async {
    for (var i = 0; i < _notifications.length; i++) {
      _notifications[i] = _notifications[i].copyWith(isRead: true);
    }
  }

  @override
  Future<AppNotification> simulateIncoming() async {
    _sequence += 1;
    final notification = AppNotification(
      id: 'fake-notification-$_sequence',
      type: NotificationType.broadcast,
      title: 'Тест мэдэгдэл',
      message: 'Энэ бол туршилтын мэдэгдэл #$_sequence.',
      createdAt: DateTime.now(),
      isRead: false,
    );
    _notifications.insert(0, notification);
    return notification;
  }

  @override
  Future<void> addExternal(AppNotification notification) async {
    _notifications.insert(0, notification);
  }
}
