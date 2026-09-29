import 'package:carcare_customer_mobile/app/bootstrap_flags.dart';
import 'package:carcare_customer_mobile/app/app.dart';
import 'package:carcare_customer_mobile/features/auth/data/fake_auth_repository.dart';
import 'package:carcare_customer_mobile/features/discovery/data/fake_organization_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Covers `CustomerAppServices._onAuthChanged` (`lib/app/customer_app_services.dart`) — the one-time
/// "Бүртгэл тань сэргээгдлээ" SnackBar shown right after a sign-in whose
/// `verifyOtp` reported the server's `reactivated` flag, and the flag being
/// reset so it can never fire twice for the same sign-in.
void main() {
  setUpAll(() => debugDisableAppBootstrap = true);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> signIn(WidgetTester tester) async {
    // Discover opens on the map, which hides the shell's own AppBar (and
    // with it the login button) to give the map the whole screen — switch
    // to the list to reach it, same as `customer_shell_account_test.dart`.
    await tester.tap(find.byKey(const ValueKey('discovery-map-list-toggle')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('shell-login')));
    await tester.pumpAndSettle();
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

  testWidgets(
    'a reactivating sign-in shows the welcome-back snackbar once, and '
    'resets the flag',
    (tester) async {
      final auth = FakeAuthRepository()..nextVerifyReactivated = true;
      await tester.pumpWidget(
        CarCareCustomerApp(
          organizationRepository: FakeOrganizationRepository(
            delay: Duration.zero,
          ),
          authRepository: auth,
        ),
      );
      await tester.pumpAndSettle();

      await signIn(tester);

      expect(find.text('Бүртгэл тань сэргээгдлээ'), findsOneWidget);

      // The SnackBar is one-shot: it must not still be showing (or reappear)
      // once its display duration elapses — that would mean the flag was
      // never reset.
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      expect(find.text('Бүртгэл тань сэргээгдлээ'), findsNothing);
    },
  );

  testWidgets(
    'an ordinary (non-reactivating) sign-in never shows the snackbar',
    (tester) async {
      final auth = FakeAuthRepository()..nextVerifyReactivated = false;
      await tester.pumpWidget(
        CarCareCustomerApp(
          organizationRepository: FakeOrganizationRepository(
            delay: Duration.zero,
          ),
          authRepository: auth,
        ),
      );
      await tester.pumpAndSettle();

      await signIn(tester);

      expect(find.text('Бүртгэл тань сэргээгдлээ'), findsNothing);
    },
  );
}
