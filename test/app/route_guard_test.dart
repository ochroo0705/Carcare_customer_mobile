import 'package:carcare_customer_mobile/app/bootstrap_flags.dart';
import 'package:carcare_customer_mobile/features/auth/data/fake_auth_repository.dart';
import 'package:carcare_customer_mobile/features/auth/presentation/auth_controller.dart';
import 'package:carcare_customer_mobile/features/auth/presentation/login_screen.dart';
import 'package:carcare_customer_mobile/features/booking/presentation/screens/appointment_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/app_harness.dart';

void main() {
  setUpAll(() => debugDisableAppBootstrap = true);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Uri currentUri(WidgetTester tester, Type screen) =>
      GoRouterState.of(tester.element(find.byType(screen).last)).uri;

  testWidgets('a pushed protected page leaves the screen on sign-out', (
    tester,
  ) async {
    final push = ControllablePush();
    await pumpApp(tester, push: push);
    push.tap(const {
      'type': 'appointment_confirmed',
      'appointmentId': 'seed-1',
    });
    await tester.pumpAndSettle();
    expect(find.byType(AppointmentDetailScreen), findsOneWidget);

    await tester
        .element(find.byType(AppointmentDetailScreen))
        .read<AuthController>()
        .signOut();
    await tester.pumpAndSettle();

    expect(
      find.byType(AppointmentDetailScreen, skipOffstage: false),
      findsNothing,
    );
  });

  testWidgets('two requestLogin taps push a single login page', (tester) async {
    await pumpApp(tester, auth: FakeAuthRepository());
    await tester.tap(find.text('Захиалгууд'));
    await tester.pumpAndSettle();
    final button = find.byKey(const ValueKey('appointments-login'));
    await tester.tap(button);
    await tester.tap(button, warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen, skipOffstage: false), findsOneWidget);
  });

  testWidgets('a signed-out push tap lands on login, then the target', (
    tester,
  ) async {
    final push = ControllablePush();
    await pumpApp(tester, auth: FakeAuthRepository(), push: push);
    push.tap(const {
      'type': 'appointment_confirmed',
      'appointmentId': 'seed-1',
    });
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(
      currentUri(tester, LoginScreen).queryParameters['from'],
      '/appointments/seed-1',
    );

    await tester.enterText(
      find.byKey(const ValueKey('login-phone')),
      '99112233',
    );
    await tester.tap(find.text('Код авах →'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('login-otp')), '123456');
    await tester.tap(find.text('Нэвтрэх →'));
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsNothing);
    expect(find.byType(AppointmentDetailScreen), findsOneWidget);
  });

  testWidgets('a signed-out broadcast push tap keeps /notifications in from', (
    tester,
  ) async {
    final push = ControllablePush();
    await pumpApp(tester, auth: FakeAuthRepository(), push: push);
    push.tap(const {'type': 'broadcast'});
    await tester.pumpAndSettle();

    expect(
      currentUri(tester, LoginScreen).queryParameters['from'],
      '/notifications',
    );
  });

  Future<void> signInWithOtp(WidgetTester tester) async {
    await tester.enterText(
      find.byKey(const ValueKey('login-phone')),
      '99112233',
    );
    await tester.tap(find.text('Код авах →'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('login-otp')), '123456');
    await tester.tap(find.text('Нэвтрэх →'));
    await tester.pumpAndSettle();
  }

  const appointmentPush = {
    'type': 'appointment_confirmed',
    'appointmentId': 'seed-1',
  };

  testWidgets('requestLogin still works after a push-tap login and sign-out', (
    tester,
  ) async {
    final push = ControllablePush();
    await pumpApp(tester, auth: FakeAuthRepository(), push: push);
    push.tap(appointmentPush);
    await tester.pumpAndSettle();
    await signInWithOtp(tester);
    expect(find.byType(AppointmentDetailScreen), findsOneWidget);

    await tester
        .element(find.byType(AppointmentDetailScreen))
        .read<AuthController>()
        .signOut();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Захиалгууд'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('appointments-login')));
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);
  });

  testWidgets('two signed-out push taps in a row each land on login', (
    tester,
  ) async {
    final push = ControllablePush();
    await pumpApp(tester, auth: FakeAuthRepository(), push: push);
    push.tap(appointmentPush);
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);
    await signInWithOtp(tester);
    await tester
        .element(find.byType(AppointmentDetailScreen))
        .read<AuthController>()
        .signOut();
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsNothing);

    push.tap(appointmentPush);
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);
  });
}
