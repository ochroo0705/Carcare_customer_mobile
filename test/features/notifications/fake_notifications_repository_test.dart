import 'package:carcare_customer_mobile/features/notifications/data/fake_notifications_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('lists the seeded notifications with mixed read state', () async {
    final repository = FakeNotificationsRepository();

    final notifications = await repository.getNotifications();

    expect(notifications, hasLength(3));
    expect(notifications.where((n) => !n.isRead), hasLength(2));
  });

  test('markRead flips a single notification to read', () async {
    final repository = FakeNotificationsRepository();
    final target = (await repository.getNotifications()).firstWhere(
      (n) => !n.isRead,
    );

    await repository.markRead(target.id);

    final updated = (await repository.getNotifications()).firstWhere(
      (n) => n.id == target.id,
    );
    expect(updated.isRead, isTrue);
  });

  test('markAllRead flips every notification to read', () async {
    final repository = FakeNotificationsRepository();

    await repository.markAllRead();

    final notifications = await repository.getNotifications();
    expect(notifications.every((n) => n.isRead), isTrue);
  });
}
