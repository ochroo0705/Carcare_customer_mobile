import 'dart:async';

import 'package:carcare_customer_mobile/app/app.dart';
import 'package:carcare_customer_mobile/core/notifications/remote_push_service.dart';
import 'package:carcare_customer_mobile/features/auth/domain/auth_repository.dart';
import 'package:carcare_customer_mobile/features/booking/data/fake_appointment_repository.dart';
import 'package:carcare_customer_mobile/features/booking/domain/appointment_repository.dart';
import 'package:carcare_customer_mobile/features/discovery/data/fake_organization_repository.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/mocks.dart';

/// Push service whose notification-tap (`onMessageOpenedApp`) and foreground
/// (`onMessage`) streams the test drives. Shared by every `test/app/*` file
/// that needs a controllable `RemotePushService` double, so each one imports
/// this instead of declaring its own copy.
class ControllablePush extends Fake implements RemotePushService {
  final _opened = StreamController<RemoteMessage>.broadcast();
  final _incoming = StreamController<RemoteMessage>.broadcast();

  void tap(Map<String, dynamic> data) => _opened.add(RemoteMessage(data: data));

  void arrive(Map<String, dynamic> data) =>
      _incoming.add(RemoteMessage(data: data));

  @override
  Stream<RemoteMessage> get onMessageOpenedApp => _opened.stream;

  @override
  Future<RemoteMessage?> getInitialMessage() async => null;

  @override
  Future<String?> getToken() async => null;

  @override
  Stream<String> get onTokenRefresh => const Stream.empty();

  @override
  Stream<RemoteMessage> get onMessage => _incoming.stream;
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
      authRepository: auth ?? signedInAuthRepository(),
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
