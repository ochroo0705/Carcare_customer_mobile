import 'package:carcare_customer_mobile/features/notifications/data/fake_notifications_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('lists the seeded notifications with mixed read state', () async {
    final repository = FakeNotificationsRepository();

    final page = await repository.getNotifications();

    expect(page.items, hasLength(3));
    expect(page.items.where((n) => !n.isRead), hasLength(2));
    expect(page.unreadCount, 2);
  });

  test('markRead flips a single notification to read', () async {
    final repository = FakeNotificationsRepository();
    final target = (await repository.getNotifications()).items.firstWhere(
      (n) => !n.isRead,
    );

    await repository.markRead(target.id);

    final updated = (await repository.getNotifications()).items.firstWhere(
      (n) => n.id == target.id,
    );
    expect(updated.isRead, isTrue);
  });

  test('markAllRead flips every notification to read', () async {
    final repository = FakeNotificationsRepository();

    await repository.markAllRead();

    final page = await repository.getNotifications();
    expect(page.items.every((n) => n.isRead), isTrue);
    expect(page.unreadCount, 0);
  });
}
