import 'package:carcare_customer_mobile/app/app.dart';
import 'package:carcare_customer_mobile/features/discovery/data/fake_organization_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
    'top bar swaps the sign-in button for the avatar after login, and back after sign-out',
    (tester) async {
      await tester.pumpWidget(
        CarCareCustomerApp(
          organizationRepository: FakeOrganizationRepository(
            delay: Duration.zero,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('shell-login')), findsOneWidget);
      expect(find.byKey(const ValueKey('shell-avatar')), findsNothing);

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

      expect(find.byKey(const ValueKey('shell-login')), findsNothing);
      expect(find.byKey(const ValueKey('shell-avatar')), findsOneWidget);

      // Sign-out now lives on the Профайл screen, reached by tapping the
      // avatar rather than a dropdown menu.
      await tester.tap(find.byKey(const ValueKey('shell-avatar')));
      await tester.pumpAndSettle();
      expect(find.text('99112233'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('profile-sign-out')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('shell-login')), findsOneWidget);
      expect(find.byKey(const ValueKey('shell-avatar')), findsNothing);
    },
  );
}
