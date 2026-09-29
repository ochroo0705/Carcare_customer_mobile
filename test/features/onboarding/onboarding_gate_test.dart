import 'package:carcare_customer_mobile/core/permissions/notification_permission_service.dart';
import 'package:carcare_customer_mobile/features/onboarding/data/onboarding_store.dart';
import 'package:carcare_customer_mobile/features/onboarding/presentation/onboarding_gate.dart';
import 'package:carcare_customer_mobile/features/onboarding/presentation/screens/onboarding_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeNotif extends Fake implements NotificationPermissionService {
  _FakeNotif(this.state);
  PermissionState state;
  int settingsOpened = 0;
  int requested = 0;

  @override
  Future<PermissionState> check() async => state;
  @override
  Future<PermissionState> request() async {
    requested++;
    return state;
  }

  @override
  Future<bool> openSettings() async {
    settingsOpened++;
    return true;
  }
}

Future<void> _pumpGate(
  WidgetTester tester, {
  required VoidCallback onLogin,
  NotificationPermissionService? notif,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: OnboardingGate(
        onRequestLogin: onLogin,
        notificationService: notif ?? _FakeNotif(PermissionState.denied),
        child: const Scaffold(body: Text('APP-BEHIND')),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _skipToLast(WidgetTester tester) async {
  await tester.tap(find.text('Алгасах'));
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

  testWidgets('Skip lands on the last page (notification ask), not the app', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await _pumpGate(tester, onLogin: () {});

    await _skipToLast(tester);
    expect(find.byKey(const ValueKey('notif-grant')), findsOneWidget);
    expect(find.text('APP-BEHIND'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('onboarding-start')));
    await tester.pumpAndSettle();
    expect(find.text('APP-BEHIND'), findsOneWidget);
    expect(await const OnboardingStore().hasCompleted(), isTrue);
  });

  testWidgets('the flow is three pages; sign-in reveals the app and requests '
      'login', (tester) async {
    SharedPreferences.setMockInitialValues({});
    var loginRequested = false;
    await _pumpGate(tester, onLogin: () => loginRequested = true);

    for (var i = 0; i < 2; i++) {
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

  testWidgets('returning users can sign in from the first page', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    var loginRequested = false;
    await _pumpGate(tester, onLogin: () => loginRequested = true);

    await tester.tap(find.byKey(const ValueKey('onboarding-welcome-login')));
    await tester.pumpAndSettle();

    expect(find.text('APP-BEHIND'), findsOneWidget);
    expect(loginRequested, isTrue);
    expect(await const OnboardingStore().hasCompleted(), isTrue);
  });

  testWidgets('granting notifications asks the OS and shows a check', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final notif = _FakeNotif(PermissionState.denied);
    await _pumpGate(tester, onLogin: () {}, notif: notif);
    await _skipToLast(tester);

    notif.state = PermissionState.granted;
    await tester.tap(find.byKey(const ValueKey('notif-grant')));
    await tester.pumpAndSettle();

    expect(notif.requested, 1);
    expect(find.byKey(const ValueKey('notif-grant')), findsNothing);
    expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
  });

  testWidgets('system back steps to the previous page', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await _pumpGate(tester, onLogin: () {});

    await _skipToLast(tester);
    expect(find.byKey(const ValueKey('onboarding-start')), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('onboarding-start')), findsNothing);
    expect(find.byType(OnboardingScreen), findsOneWidget);
  });

  testWidgets('permanently denied: Settings button, and the state is re-read '
      'on return', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final notif = _FakeNotif(PermissionState.permanentlyDenied);
    await _pumpGate(tester, onLogin: () {}, notif: notif);
    await _skipToLast(tester);

    final settingsBtn = find.byKey(const ValueKey('notif-open-settings'));
    expect(settingsBtn, findsOneWidget);
    expect(find.byKey(const ValueKey('notif-grant')), findsNothing);
    await tester.tap(settingsBtn);
    await tester.pumpAndSettle();
    expect(notif.settingsOpened, 1);

    // User enables notifications in Settings, then the app resumes.
    notif.state = PermissionState.granted;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(settingsBtn, findsNothing);
    expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
  });

  Future<void> pumpScreen(WidgetTester tester, {bool reduceMotion = false}) =>
      tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(disableAnimations: reduceMotion),
            child: OnboardingScreen(
              onFinish: ({required login}) {},
              notificationService: _FakeNotif(PermissionState.denied),
            ),
          ),
        ),
      );

  testWidgets('how-it-works booking preview flips pending → confirmed', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await pumpScreen(tester);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Цааш'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400)); // page slide done

    expect(
      find.byKey(const ValueKey('booking-preview-pending')),
      findsOneWidget,
    );
    await tester.pumpAndSettle(); // one-shot animations finish; nothing loops
    expect(
      find.byKey(const ValueKey('booking-preview-confirmed')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('booking-preview-pending')), findsNothing);
  });

  testWidgets('reduce motion shows the finished state immediately', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await pumpScreen(tester, reduceMotion: true);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Цааш'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400)); // page slide done

    expect(
      find.byKey(const ValueKey('booking-preview-confirmed')),
      findsOneWidget,
    );
  });

  testWidgets('no animation keeps ticking after leaving the flow', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await _pumpGate(tester, onLogin: () {});
    await _skipToLast(tester);
    await tester.tap(find.byKey(const ValueKey('onboarding-start')));
    await tester.pumpAndSettle();
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  for (final brightness in Brightness.values) {
    testWidgets('pages scroll instead of overflowing on a small screen with '
        'large text ($brightness)', (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(320, 480);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      tester.platformDispatcher.textScaleFactorTestValue = 1.6;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(brightness: brightness),
          home: OnboardingScreen(
            onFinish: ({required login}) {},
            notificationService: _FakeNotif(PermissionState.denied),
          ),
        ),
      );
      await tester.pumpAndSettle();
      for (var i = 0; i < 2; i++) {
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('Цааш'));
        await tester.pumpAndSettle();
      }
      expect(tester.takeException(), isNull);
    });
  }
}
