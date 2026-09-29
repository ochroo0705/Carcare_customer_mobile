import 'package:carcare_customer_mobile/app/bootstrap_flags.dart';

import 'package:carcare_customer_mobile/app/app.dart';
import 'package:carcare_customer_mobile/features/booking/data/fake_appointment_repository.dart';
import 'package:carcare_customer_mobile/features/discovery/data/fake_organization_repository.dart';
import 'package:carcare_customer_mobile/features/notifications/presentation/screens/notifications_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/mocks.dart';
import 'support/app_harness.dart';

void main() {
  setUpAll(() => debugDisableAppBootstrap = true);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('tapping an appointment push opens that appointment detail', (
    tester,
  ) async {
    final push = ControllablePush();
    await tester.pumpWidget(
      CarCareCustomerApp(
        organizationRepository: FakeOrganizationRepository(),
        authRepository: signedInAuthRepository(),
        appointmentRepository: FakeAppointmentRepository(),
        remotePushService: push,
      ),
    );
    await tester.pumpAndSettle();

    push.tap(const {
      'type': 'appointment_confirmed',
      'appointmentId': 'seed-1',
    });
    await tester.pumpAndSettle();

    expect(find.text('Цагийн дэлгэрэнгүй'), findsOneWidget);
    expect(find.text('Инфосистемс'), findsOneWidget);
  });

  testWidgets(
    'tapping a staff phone-in booking push (appointment_booked_by_staff) opens that appointment detail',
    (tester) async {
      final push = ControllablePush();
      await tester.pumpWidget(
        CarCareCustomerApp(
          organizationRepository: FakeOrganizationRepository(),
          authRepository: signedInAuthRepository(),
          appointmentRepository: FakeAppointmentRepository(),
          remotePushService: push,
        ),
      );
      await tester.pumpAndSettle();

      push.tap(const {
        'type': 'appointment_booked_by_staff',
        'appointmentId': 'seed-1',
      });
      await tester.pumpAndSettle();

      expect(find.text('Цагийн дэлгэрэнгүй'), findsOneWidget);
      expect(find.text('Инфосистемс'), findsOneWidget);
    },
  );

  testWidgets('tapping a broadcast push opens the notifications list', (
    tester,
  ) async {
    final push = ControllablePush();
    await tester.pumpWidget(
      CarCareCustomerApp(
        organizationRepository: FakeOrganizationRepository(),
        authRepository: signedInAuthRepository(),
        remotePushService: push,
      ),
    );
    await tester.pumpAndSettle();

    push.tap(const {'type': 'broadcast'});
    await tester.pumpAndSettle();

    expect(find.byType(NotificationsScreen), findsOneWidget);
  });

  testWidgets('a rejected-appointment push still deep-links to the detail', (
    tester,
  ) async {
    final push = ControllablePush();
    await tester.pumpWidget(
      CarCareCustomerApp(
        organizationRepository: FakeOrganizationRepository(),
        authRepository: signedInAuthRepository(),
        appointmentRepository: FakeAppointmentRepository(),
        remotePushService: push,
      ),
    );
    await tester.pumpAndSettle();

    // seed-3 is a cancelled/rejected-style appointment in the fake repo.
    push.tap(const {'type': 'appointment_rejected', 'appointmentId': 'seed-3'});
    await tester.pumpAndSettle();

    expect(find.text('Цагийн дэлгэрэнгүй'), findsOneWidget);
  });

  testWidgets('a feedback-reply push (no appointmentId) opens notifications', (
    tester,
  ) async {
    final push = ControllablePush();
    await tester.pumpWidget(
      CarCareCustomerApp(
        organizationRepository: FakeOrganizationRepository(),
        authRepository: signedInAuthRepository(),
        remotePushService: push,
      ),
    );
    await tester.pumpAndSettle();

    push.tap(const {'type': 'feedback_replied_account', 'feedbackId': 'f1'});
    await tester.pumpAndSettle();

    expect(find.byType(NotificationsScreen), findsOneWidget);
  });
}
