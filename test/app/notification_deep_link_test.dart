import 'package:carcare_customer_mobile/app/bootstrap_flags.dart';
import 'dart:async';

import 'package:carcare_customer_mobile/app/app.dart';
import 'package:carcare_customer_mobile/core/notifications/remote_push_service.dart';
import 'package:carcare_customer_mobile/features/auth/domain/account.dart';
import 'package:carcare_customer_mobile/features/auth/domain/auth_repository.dart';
import 'package:carcare_customer_mobile/features/booking/data/fake_appointment_repository.dart';
import 'package:carcare_customer_mobile/features/discovery/data/fake_organization_repository.dart';
import 'package:carcare_customer_mobile/features/notifications/presentation/screens/notifications_screen.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Push service whose notification-tap stream the test drives.
class _ControllablePush implements RemotePushService {
  final _opened = StreamController<RemoteMessage>.broadcast();

  void tap(Map<String, dynamic> data) => _opened.add(RemoteMessage(data: data));

  @override
  Stream<RemoteMessage> get onMessageOpenedApp => _opened.stream;

  @override
  Future<RemoteMessage?> getInitialMessage() async => null;

  @override
  Future<String?> getToken() async => null;

  @override
  Stream<String> get onTokenRefresh => const Stream.empty();

  @override
  Stream<RemoteMessage> get onMessage => const Stream.empty();
}

/// Auth repo that restores an already-signed-in account.
class _AuthedRepo implements AuthRepository {
  @override
  Future<Account?> restoreSession() async =>
      const Account(id: '1', phone: '99112233');

  @override
  Future<void> requestOtp(String phone) async {}

  @override
  Future<Account> verifyOtp({
    required String phone,
    required String code,
    String? name,
  }) async => const Account(id: '1', phone: '99112233');

  @override
  Future<void> signOut() async {}
}

void main() {
  setUpAll(() => debugDisableAppBootstrap = true);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('tapping an appointment push opens that appointment detail', (
    tester,
  ) async {
    final push = _ControllablePush();
    await tester.pumpWidget(
      CarCareCustomerApp(
        organizationRepository: FakeOrganizationRepository(),
        authRepository: _AuthedRepo(),
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

  testWidgets('tapping a broadcast push opens the notifications list', (
    tester,
  ) async {
    final push = _ControllablePush();
    await tester.pumpWidget(
      CarCareCustomerApp(
        organizationRepository: FakeOrganizationRepository(),
        authRepository: _AuthedRepo(),
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
    final push = _ControllablePush();
    await tester.pumpWidget(
      CarCareCustomerApp(
        organizationRepository: FakeOrganizationRepository(),
        authRepository: _AuthedRepo(),
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
    final push = _ControllablePush();
    await tester.pumpWidget(
      CarCareCustomerApp(
        organizationRepository: FakeOrganizationRepository(),
        authRepository: _AuthedRepo(),
        remotePushService: push,
      ),
    );
    await tester.pumpAndSettle();

    push.tap(const {'type': 'feedback_replied_account', 'feedbackId': 'f1'});
    await tester.pumpAndSettle();

    expect(find.byType(NotificationsScreen), findsOneWidget);
  });
}
