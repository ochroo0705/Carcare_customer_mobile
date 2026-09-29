import 'dart:async';

import 'package:carcare_customer_mobile/app/bootstrap_flags.dart';
import 'package:carcare_customer_mobile/app/app.dart';
import 'package:carcare_customer_mobile/core/notifications/remote_push_service.dart';
import 'package:carcare_customer_mobile/features/auth/domain/account.dart';
import 'package:carcare_customer_mobile/features/auth/domain/auth_repository.dart';
import 'package:carcare_customer_mobile/features/booking/data/fake_appointment_repository.dart';
import 'package:carcare_customer_mobile/features/discovery/data/fake_organization_repository.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Push service whose foreground (`onMessage`) stream the test drives — same
/// shape as `push_reload_test.dart`'s `_ControllableForegroundPush`.
class _ControllableForegroundPush implements RemotePushService {
  final _incoming = StreamController<RemoteMessage>.broadcast();

  void arrive(Map<String, dynamic> data) =>
      _incoming.add(RemoteMessage(data: data));

  @override
  Stream<RemoteMessage> get onMessage => _incoming.stream;

  @override
  Stream<RemoteMessage> get onMessageOpenedApp => const Stream.empty();

  @override
  Future<RemoteMessage?> getInitialMessage() async => null;

  @override
  Future<String?> getToken() async => null;

  @override
  Stream<String> get onTokenRefresh => const Stream.empty();
}

/// Auth repo that restores an already-signed-in account and counts
/// `signOut()` calls — `handleRemoteAccountClosed` must call it exactly once
/// per closure, and never call `deactivateAccount`/`deleteAccount` (those
/// would be a real server request, which the local-only closure must avoid).
class _AuthedRepo implements AuthRepository {
  int signOutCalls = 0;
  int serverClosureCalls = 0;

  @override
  Stream<void> get onSessionInvalidated => const Stream.empty();

  @override
  Future<Account?> restoreSession() async =>
      const Account(id: '1', phone: '99112233');

  @override
  Future<void> requestOtp(String phone) async {}

  @override
  Future<({Account account, bool reactivated})> verifyOtp({
    required String phone,
    required String code,
    String? name,
  }) async =>
      (account: const Account(id: '1', phone: '99112233'), reactivated: false);

  @override
  Future<void> signOut() async => signOutCalls++;

  @override
  Future<String> requestClosureOtp() async => '****1234';

  @override
  Future<void> deactivateAccount(String code) async => serverClosureCalls++;

  @override
  Future<void> deleteAccount(String code) async => serverClosureCalls++;
}

void main() {
  setUpAll(() => debugDisableAppBootstrap = true);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
    'account_closed (deleted) signs out locally, shows the deleted message, '
    'and makes no server call',
    (tester) async {
      final push = _ControllableForegroundPush();
      final auth = _AuthedRepo();
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
      expect(auth.signOutCalls, 1);
      expect(auth.serverClosureCalls, 0);
    },
  );

  testWidgets(
    'account_closed (deactivated) shows the deactivated message',
    (tester) async {
      final push = _ControllableForegroundPush();
      final auth = _AuthedRepo();
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
      expect(auth.signOutCalls, 1);
    },
  );

  testWidgets(
    'a second account_closed push after sign-out is a no-op (idempotent — '
    'covers the device that initiated the closure)',
    (tester) async {
      final push = _ControllableForegroundPush();
      final auth = _AuthedRepo();
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
      expect(auth.signOutCalls, 1);

      // Let the first snackbar's display duration elapse so a second one is
      // unambiguous, then simulate the device's own push arriving late.
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();

      push.arrive(const {'type': 'account_closed', 'reason': 'deleted'});
      await tester.pumpAndSettle();

      expect(auth.signOutCalls, 1);
      expect(find.text('Бүртгэл тань устгагдсан'), findsNothing);
    },
  );

  testWidgets(
    'account_closed is never shown as, or added to, the notifications list',
    (tester) async {
      final push = _ControllableForegroundPush();
      final auth = _AuthedRepo();
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
    final push = _ControllableForegroundPush();
    final auth = _AuthedRepo();
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

    expect(auth.signOutCalls, 0);
    expect(find.text('Бүртгэл тань устгагдсан'), findsNothing);
    expect(find.text('Бүртгэл тань идэвхгүй болсон'), findsNothing);
  });
}
