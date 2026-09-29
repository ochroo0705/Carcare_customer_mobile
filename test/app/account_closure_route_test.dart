import 'package:carcare_customer_mobile/app/app.dart';
import 'package:carcare_customer_mobile/app/bootstrap_flags.dart';
import 'package:carcare_customer_mobile/features/auth/data/fake_auth_repository.dart';
import 'package:carcare_customer_mobile/features/discovery/data/fake_organization_repository.dart';
import 'package:carcare_customer_mobile/features/profile/presentation/screens/account_closure_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The account-closure page lives on the router delegate's page stack (no
/// `Navigator.push(MaterialPageRoute)` side door): Profile opens it, system
/// back removes it, and a successful closure drops it along with the session.
void main() {
  setUpAll(() => debugDisableAppBootstrap = true);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<FakeAuthRepository> openProfile(WidgetTester tester) async {
    final auth = FakeAuthRepository(signedIn: true);
    await tester.pumpWidget(
      CarCareCustomerApp(
        organizationRepository: FakeOrganizationRepository(
          delay: Duration.zero,
        ),
        authRepository: auth,
      ),
    );
    await tester.pumpAndSettle();
    // Discover opens on the map, which hides the shell AppBar/avatar.
    await tester.tap(find.byKey(const ValueKey('discovery-map-list-toggle')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('shell-avatar')));
    await tester.pumpAndSettle();
    return auth;
  }

  Future<void> openClosure(WidgetTester tester) async {
    final tile = find.byKey(const ValueKey('profile-account-closure-tile'));
    await tester.scrollUntilVisible(
      tile,
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(tile);
    await tester.pumpAndSettle();
    expect(find.byType(AccountClosureScreen), findsOneWidget);
  }

  testWidgets('Profile opens the closure page and back removes it', (
    tester,
  ) async {
    await openProfile(tester);
    await openClosure(tester);

    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.byType(AccountClosureScreen), findsNothing);
    expect(
      find.byKey(const ValueKey('profile-account-closure-tile')),
      findsOneWidget,
    );
  });

  testWidgets(
    'a successful deactivation drops the closure page and signs out',
    (tester) async {
      final auth = await openProfile(tester);
      await openClosure(tester);

      await tester.tap(find.text('Идэвхгүй болгох'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Код авах'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, '654321');
      await tester.tap(find.text('Идэвхгүй болгох').last);
      await tester.pumpAndSettle();

      expect(auth.lastClosure, ('deactivate', '654321'));
      expect(find.byType(AccountClosureScreen), findsNothing);
      expect(
        find.byKey(const ValueKey('profile-account-closure-tile')),
        findsNothing,
      );
    },
  );
}
