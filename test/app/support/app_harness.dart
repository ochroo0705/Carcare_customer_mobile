import 'dart:async';

import 'package:carcare_customer_mobile/app/app.dart';
import 'package:carcare_customer_mobile/core/notifications/remote_push_service.dart';
import 'package:carcare_customer_mobile/features/auth/domain/account.dart';
import 'package:carcare_customer_mobile/features/auth/domain/auth_repository.dart';
import 'package:carcare_customer_mobile/features/booking/data/fake_appointment_repository.dart';
import 'package:carcare_customer_mobile/features/booking/domain/appointment_repository.dart';
import 'package:carcare_customer_mobile/features/discovery/data/fake_organization_repository.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class AuthedAuthRepository implements AuthRepository {
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
  Future<void> signOut() async {}
  @override
  Future<String> requestClosureOtp() async => '****1234';
  @override
  Future<void> deactivateAccount(String code) async {}
  @override
  Future<void> deleteAccount(String code) async {}
}

/// Push service whose notification-tap stream the test drives. Copied from
/// `test/app/notification_deep_link_test.dart`'s private `_ControllablePush`
/// so both files can share the same shape without one importing the other's
/// test file.
class ControllablePush implements RemotePushService {
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

Future<void> pumpApp(
  WidgetTester tester, {
  AuthRepository? auth,
  RemotePushService? push,
  AppointmentRepository? appointments,
}) async {
  await tester.pumpWidget(
    CarCareCustomerApp(
      organizationRepository: FakeOrganizationRepository(delay: Duration.zero),
      authRepository: auth ?? AuthedAuthRepository(),
      appointmentRepository: appointments ?? FakeAppointmentRepository(),
      remotePushService: push,
    ),
  );
  await tester.pumpAndSettle();
}

/// Discover opens on the map, which hides the shell AppBar/avatar.
Future<void> openListView(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('discovery-map-list-toggle')));
  await tester.pumpAndSettle();
}
