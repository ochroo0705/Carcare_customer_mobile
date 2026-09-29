import 'dart:async';

import 'package:carcare_customer_mobile/features/notifications/data/fake_notifications_repository.dart';
import 'package:carcare_customer_mobile/features/notifications/domain/app_notification.dart';
import 'package:carcare_customer_mobile/features/notifications/domain/notification_type.dart';
import 'package:carcare_customer_mobile/features/notifications/domain/notifications_page.dart';
import 'package:carcare_customer_mobile/features/notifications/domain/notifications_repository.dart';
import 'package:carcare_customer_mobile/features/notifications/presentation/controllers/notifications_controller.dart';
import 'package:carcare_customer_mobile/features/notifications/presentation/controllers/notifications_state.dart';
import 'package:flutter_test/flutter_test.dart';

/// Lets a test control exactly when each `getNotifications` call resolves,
/// to reproduce out-of-order responses (e.g. a pull-to-refresh's `load()`
/// resolving after a `markRead`-triggered `load()` that started later).
class _RaceNotificationsRepository implements NotificationsRepository {
  final List<Completer<NotificationsPage>> completers = [];

  @override
  Future<NotificationsPage> getNotifications() {
    final completer = Completer<NotificationsPage>();
    completers.add(completer);
    return completer.future;
  }

  @override
  Future<void> markRead(String id) async {}

  @override
  Future<void> markAllRead() async {}

  @override
  Future<void> addExternal(AppNotification notification) async {}
}

NotificationsPage _page(List<AppNotification> items) => NotificationsPage(
  items: items,
  unreadCount: items.where((n) => !n.isRead).length,
);

AppNotification _notification(String id, {bool isRead = false}) =>
    AppNotification(
      id: id,
      type: NotificationType.broadcast,
      title: id,
      message: '',
      createdAt: DateTime(2026, 1, 1),
      isRead: isRead,
    );

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
    'handleIncomingPush maps a staff phone-in booking push (appointment_booked_by_staff)',
    () async {
      final controller = NotificationsController(FakeNotificationsRepository());
      await controller.load();
      final before = controller.unreadCount;

      await controller.handleIncomingPush(
        title: 'Шинэ цаг захиалга',
        body: 'Инфосистемс таны нэр дээр 2026.09.28 08:00-д цаг бүртгэлээ.',
        data: const {
          'type': 'appointment_booked_by_staff',
          'appointmentId': '456',
        },
      );

      expect(controller.unreadCount, before + 1);
      final newest = controller.state.notifications.first;
      expect(newest.title, 'Шинэ цаг захиалга');
      expect(newest.type, NotificationType.appointmentBookedByStaff);
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

  test('ignores a stale load() response that arrives after a newer one '
      '(e.g. pull-to-refresh racing a mark-read reload)', () async {
    final repository = _RaceNotificationsRepository();
    final controller = NotificationsController(repository);

    // Two overlapping loads: the first mirrors a pull-to-refresh that
    // started first but is slow; the second mirrors the reload triggered
    // right after by a "mark read" tap.
    unawaited(controller.load());
    final second = controller.load();
    expect(repository.completers, hasLength(2));

    // The SECOND (newer) call's response arrives first...
    repository.completers[1].complete(_page([_notification('newer')]));
    await second;
    // ...then the stale first call's response arrives late.
    repository.completers[0].complete(_page([_notification('older')]));
    await Future<void>.delayed(Duration.zero);

    // The stale response must not clobber the newer result.
    expect(controller.state.notifications.single.id, 'newer');
  });
}
