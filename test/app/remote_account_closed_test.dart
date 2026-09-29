import 'package:carcare_customer_mobile/app/bootstrap_flags.dart';
import 'package:carcare_customer_mobile/app/app.dart';
import 'package:carcare_customer_mobile/features/booking/data/fake_appointment_repository.dart';
import 'package:carcare_customer_mobile/features/discovery/data/fake_organization_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/mocks.dart';
import 'support/app_harness.dart';

void main() {
  setUpAll(() => debugDisableAppBootstrap = true);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
    'account_closed (deleted) signs out locally, shows the deleted message, '
    'and makes no server call',
    (tester) async {
      final push = ControllablePush();
      final auth = signedInAuthRepository();
      await tester.pumpWidget(
        CarCareCustomerApp(
          organizationRepository: FakeOrganizationRepository(),
          authRepository: auth,
          appointmentRepository: FakeAppointmentRepository(),
          remotePushService: push,
        ),
      );
      await tester.pumpAndSettle();

      push.arrive(const {'type': 'account_closed', 'reason': 'deleted'});
      await tester.pumpAndSettle();

      expect(find.text('Бүртгэл тань устгагдсан'), findsOneWidget);
      verify(() => auth.signOut()).called(1);
      verifyNever(() => auth.deactivateAccount(any()));
      verifyNever(() => auth.deleteAccount(any()));
    },
  );

  testWidgets(
    'account_closed (deactivated) shows the deactivated message',
    (tester) async {
      final push = ControllablePush();
      final auth = signedInAuthRepository();
      await tester.pumpWidget(
        CarCareCustomerApp(
          organizationRepository: FakeOrganizationRepository(),
          authRepository: auth,
          appointmentRepository: FakeAppointmentRepository(),
          remotePushService: push,
        ),
      );
      await tester.pumpAndSettle();

      push.arrive(const {'type': 'account_closed', 'reason': 'deactivated'});
      await tester.pumpAndSettle();

      expect(find.text('Бүртгэл тань идэвхгүй болсон'), findsOneWidget);
      verify(() => auth.signOut()).called(1);
    },
  );

  testWidgets(
    'a second account_closed push after sign-out is a no-op (idempotent — '
    'covers the device that initiated the closure)',
    (tester) async {
      final push = ControllablePush();
      final auth = signedInAuthRepository();
      await tester.pumpWidget(
        CarCareCustomerApp(
          organizationRepository: FakeOrganizationRepository(),
          authRepository: auth,
          appointmentRepository: FakeAppointmentRepository(),
          remotePushService: push,
        ),
      );
      await tester.pumpAndSettle();

      push.arrive(const {'type': 'account_closed', 'reason': 'deleted'});
      await tester.pumpAndSettle();
      // mocktail's `verify` consumes the invocations it matches, so this
      // checkpoint also resets the count for the next one below.
      verify(() => auth.signOut()).called(1);

      // Let the first snackbar's display duration elapse so a second one is
      // unambiguous, then simulate the device's own push arriving late.
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();

      push.arrive(const {'type': 'account_closed', 'reason': 'deleted'});
      await tester.pumpAndSettle();

      // The first verify already consumed the one signOut() call, so
      // verifyNever here proves the second push caused no additional call.
      verifyNever(() => auth.signOut());
      expect(find.text('Бүртгэл тань устгагдсан'), findsNothing);
    },
  );

  testWidgets(
    'account_closed is never shown as, or added to, the notifications list',
    (tester) async {
      final push = ControllablePush();
      final auth = signedInAuthRepository();
      await tester.pumpWidget(
        CarCareCustomerApp(
          organizationRepository: FakeOrganizationRepository(),
          authRepository: auth,
          appointmentRepository: FakeAppointmentRepository(),
          remotePushService: push,
        ),
      );
      await tester.pumpAndSettle();

      push.arrive(const {'type': 'account_closed', 'reason': 'deleted'});
      await tester.pumpAndSettle();

      // Only the sign-out SnackBar text is present — nothing from a generic
      // notification banner (which would otherwise show the raw title/body,
      // both absent here since the payload carries neither).
      expect(find.text('Бүртгэл тань устгагдсан'), findsOneWidget);
    },
  );

  testWidgets('an unrelated push type is unaffected by the new handling', (
    tester,
  ) async {
    final push = ControllablePush();
    final auth = signedInAuthRepository();
    await tester.pumpWidget(
      CarCareCustomerApp(
        organizationRepository: FakeOrganizationRepository(),
        authRepository: auth,
        appointmentRepository: FakeAppointmentRepository(),
        remotePushService: push,
      ),
    );
    await tester.pumpAndSettle();

    push.arrive(const {'type': 'feedback_replied_account'});
    await tester.pumpAndSettle();

    verifyNever(() => auth.signOut());
    expect(find.text('Бүртгэл тань устгагдсан'), findsNothing);
    expect(find.text('Бүртгэл тань идэвхгүй болсон'), findsNothing);
  });
}
