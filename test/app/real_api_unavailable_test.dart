import 'package:carcare_customer_mobile/core/errors/app_failure.dart';
import 'package:carcare_customer_mobile/features/history/data/unavailable_service_history_repository.dart';
import 'package:carcare_customer_mobile/features/history/presentation/controllers/history_controller.dart';
import 'package:carcare_customer_mobile/features/history/presentation/controllers/history_state.dart';
import 'package:carcare_customer_mobile/features/notifications/data/unavailable_notifications_repository.dart';
import 'package:carcare_customer_mobile/features/notifications/presentation/controllers/notifications_controller.dart';
import 'package:carcare_customer_mobile/features/notifications/presentation/controllers/notifications_state.dart';
import 'package:flutter_test/flutter_test.dart';

/// The "real API build" behaviour (D-014): History and Notifications have no
/// endpoint, so their unavailable repositories surface an honest coming-soon
/// state instead of fake seed data.
void main() {
  group('service history', () {
    test('unavailable repo throws FeatureUnavailableFailure', () {
      expect(
        const UnavailableServiceHistoryRepository().getServiceHistory,
        throwsA(isA<FeatureUnavailableFailure>()),
      );
    });

    test('controller resolves to the unavailable (coming-soon) state', () async {
      final controller = HistoryController(
        const UnavailableServiceHistoryRepository(),
      );

      await controller.load();

      expect(controller.state.status, HistoryStatus.unavailable);
      expect(controller.state.orders, isEmpty); // never any fake seeds
    });
  });

  group('notifications', () {
    test('unavailable repo throws FeatureUnavailableFailure', () {
      expect(
        const UnavailableNotificationsRepository().getNotifications,
        throwsA(isA<FeatureUnavailableFailure>()),
      );
    });

    test('controller resolves to the unavailable (coming-soon) state', () async {
      final controller = NotificationsController(
        const UnavailableNotificationsRepository(),
      );

      await controller.load();

      expect(controller.state.status, NotificationsStatus.unavailable);
      expect(controller.unreadCount, 0);
    });

    test(
      'an incoming push does not break the unavailable list (banner is '
      'separate)',
      () async {
        final controller = NotificationsController(
          const UnavailableNotificationsRepository(),
        );

        // Must not throw even though addExternal/getNotifications are no-op /
        // unavailable — the local banner fires independently.
        await controller.handleIncomingPush(
          title: 'Цаг баталгаажлаа',
          body: 'Таны цаг баталгаажлаа.',
          data: const {'type': 'appointment_confirmed', 'appointmentId': 'a1'},
        );

        expect(controller.state.status, NotificationsStatus.unavailable);
      },
    );
  });
}
