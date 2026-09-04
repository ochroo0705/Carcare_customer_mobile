import 'package:carcare_customer_mobile/core/permissions/notification_permission_service.dart';
import 'package:carcare_customer_mobile/features/discovery/services/location_permission_service.dart';
import 'package:carcare_customer_mobile/features/onboarding/data/onboarding_store.dart';
import 'package:carcare_customer_mobile/features/onboarding/presentation/onboarding_gate.dart';
import 'package:carcare_customer_mobile/features/onboarding/presentation/screens/onboarding_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeLocation implements LocationPermissionService {
  _FakeLocation(this.state);
  LocationAccessState state;
  int settingsOpened = 0;

  @override
  Future<LocationAccessState> check() async => state;
  @override
  Future<LocationAccessState> request() async => state;

  @override
  Future<bool> openSettings() async {
    settingsOpened++;
    return true;
  }
}

class _FakeNotif implements NotificationPermissionService {
  _FakeNotif(this.state);
  PermissionState state;
  int settingsOpened = 0;

  @override
  Future<PermissionState> check() async => state;
  @override
  Future<PermissionState> request() async => state;
  @override
  Future<bool> openSettings() async {
    settingsOpened++;
    return true;
  }
}

Future<void> _pumpGate(
  WidgetTester tester, {
  required VoidCallback onLogin,
  LocationPermissionService? location,
  NotificationPermissionService? notif,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: OnboardingGate(
        onRequestLogin: onLogin,
        locationService: location ?? _FakeLocation(LocationAccessState.denied),
        notificationService: notif ?? _FakeNotif(PermissionState.denied),
        child: const Scaffold(body: Text('APP-BEHIND')),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows onboarding on first run', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await _pumpGate(tester, onLogin: () {});

    expect(find.byType(OnboardingScreen), findsOneWidget);
    expect(find.text('APP-BEHIND'), findsNothing);
  });

  testWidgets('skips onboarding once completed', (tester) async {
    SharedPreferences.setMockInitialValues({'onboarding_completed_v1': true});
    await _pumpGate(tester, onLogin: () {});

    expect(find.byType(OnboardingScreen), findsNothing);
    expect(find.text('APP-BEHIND'), findsOneWidget);
  });

  testWidgets('Skip finishes onboarding and reveals the app (no login)',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    var loginRequested = false;
    await _pumpGate(tester, onLogin: () => loginRequested = true);

    await tester.tap(find.text('Алгасах'));
    await tester.pumpAndSettle();

    expect(find.text('APP-BEHIND'), findsOneWidget);
    expect(loginRequested, isFalse);
    expect(await const OnboardingStore().hasCompleted(), isTrue);
  });

  testWidgets('paging to the end and choosing sign-in reveals the app and '
      'requests login', (tester) async {
    SharedPreferences.setMockInitialValues({});
    var loginRequested = false;
    await _pumpGate(tester, onLogin: () => loginRequested = true);

    for (var i = 0; i < 4; i++) {
      await tester.tap(find.text('Цааш'));
      await tester.pumpAndSettle();
    }

    expect(find.byKey(const ValueKey('onboarding-start')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('onboarding-login')));
    await tester.pumpAndSettle();

    expect(find.text('APP-BEHIND'), findsOneWidget);
    expect(loginRequested, isTrue);
    expect(await const OnboardingStore().hasCompleted(), isTrue);
  });

  testWidgets('permanently-denied permission shows a Settings button that '
      'opens app settings', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final location = _FakeLocation(LocationAccessState.permanentlyDenied);
    final notif = _FakeNotif(PermissionState.granted);
    await _pumpGate(tester, onLogin: () {}, location: location, notif: notif);

    // Page to the permissions page (index 3).
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.text('Цааш'));
      await tester.pumpAndSettle();
    }

    // Location is permanently denied → a "Settings" affordance, not "grant".
    final settingsBtn = find.byKey(const ValueKey('loc-open-settings'));
    expect(settingsBtn, findsOneWidget);
    expect(find.byKey(const ValueKey('loc-grant')), findsNothing);
    // Notifications were granted → a check, no button.
    expect(find.byKey(const ValueKey('notif-grant')), findsNothing);

    await tester.tap(settingsBtn);
    await tester.pumpAndSettle();
    expect(location.settingsOpened, 1);
  });
}
