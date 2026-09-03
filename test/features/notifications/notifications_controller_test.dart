import 'package:carcare_customer_mobile/features/notifications/data/fake_notifications_repository.dart';
import 'package:carcare_customer_mobile/features/notifications/domain/notification_type.dart';
import 'package:carcare_customer_mobile/features/notifications/presentation/controllers/notifications_controller.dart';
import 'package:carcare_customer_mobile/features/notifications/presentation/controllers/notifications_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('loads the seeded notifications and reports the unread count', () async {
    final controller = NotificationsController(FakeNotificationsRepository());

    await controller.load();

    expect(controller.state.status, NotificationsStatus.data);
    expect(controller.unreadCount, 2);
  });

  test('markRead decreases the unread count', () async {
    final controller = NotificationsController(FakeNotificationsRepository());
    await controller.load();
    final target = controller.state.notifications.firstWhere((n) => !n.isRead);

    await controller.markRead(target.id);

    expect(controller.unreadCount, 1);
  });

  test('markAllRead clears the unread count', () async {
    final controller = NotificationsController(FakeNotificationsRepository());
    await controller.load();

    await controller.markAllRead();

    expect(controller.unreadCount, 0);
  });

  test(
    'handleIncomingPush maps a push payload and adds it as the newest item',
    () async {
      final controller = NotificationsController(FakeNotificationsRepository());
      await controller.load();
      final before = controller.unreadCount;

      await controller.handleIncomingPush(
        title: 'Цаг баталгаажлаа',
        body: 'Таны захиалсан цаг баталгаажлаа.',
        data: const {'type': 'appointment_confirmed', 'appointmentId': '123'},
      );

      expect(controller.unreadCount, before + 1);
      final newest = controller.state.notifications.first;
      expect(newest.title, 'Цаг баталгаажлаа');
      expect(newest.type, NotificationType.appointmentConfirmed);
      expect(newest.isRead, isFalse);
    },
  );

  test(
    'handleIncomingPush falls back to broadcast for an unknown or missing type',
    () async {
      final controller = NotificationsController(FakeNotificationsRepository());
      await controller.load();

      await controller.handleIncomingPush(
        title: null,
        body: null,
        data: const {},
      );

      final newest = controller.state.notifications.first;
      expect(newest.type, NotificationType.broadcast);
    },
  );

  test('reset returns to the initial state', () async {
    final controller = NotificationsController(FakeNotificationsRepository());
    await controller.load();
    expect(controller.state.status, NotificationsStatus.data);

    controller.reset();

    expect(controller.state.status, NotificationsStatus.initial);
    expect(controller.unreadCount, 0);
  });
}
