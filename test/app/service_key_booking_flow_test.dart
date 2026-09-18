import 'package:carcare_customer_mobile/app/bootstrap_flags.dart';
import 'package:carcare_customer_mobile/app/app.dart';
import 'package:carcare_customer_mobile/features/auth/domain/account.dart';
import 'package:carcare_customer_mobile/features/auth/domain/auth_repository.dart';
import 'package:carcare_customer_mobile/features/booking/presentation/screens/booking_request_screen.dart';
import 'package:carcare_customer_mobile/features/discovery/data/fake_organization_repository.dart';
import 'package:carcare_customer_mobile/features/discovery/presentation/screens/organization_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _AuthedRepo implements AuthRepository {
  @override
  Stream<void> get onSessionInvalidated => const Stream.empty();

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

  testWidgets(
    'multi-selecting service keys in the sheet narrows cross-org branches '
    'inline, and booking locks the matching categories',
    (tester) async {
      await tester.pumpWidget(
        CarCareCustomerApp(
          organizationRepository: FakeOrganizationRepository(
            delay: Duration.zero,
          ),
          authRepository: _AuthedRepo(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Захиалах'));
      await tester.pumpAndSettle();

      // No selection yet — the branch list stays blank with a prompt, not a
      // full unfiltered catalog.
      expect(find.text('Ажлын төрлөө сонгоно уу'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('service-key-add')));
      await tester.pumpAndSettle();

      // Fake catalog: auto-doctor-bzd offers both oil-change + car-wash,
      // auto-doctor-sbd only car-wash, khurd-khud only tire-service.
      final oilChange = find.byKey(const ValueKey('service-key-oil-change'));
      await tester.tap(oilChange);
      await tester.pump();
      final carWash = find.byKey(const ValueKey('service-key-car-wash'));
      await tester.ensureVisible(carWash);
      await tester.pumpAndSettle();
      await tester.tap(carWash);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('service-key-apply')));
      await tester.pumpAndSettle();

      // Sheet closed, tags now show both picks, and only the branch covering
      // BOTH selected keys shows up — all on the same screen, no navigation.
      expect(find.text('Моторын тос солих'), findsOneWidget);
      expect(find.text('Угаалга'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('service-key-result-auto-doctor-bzd')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('service-key-result-auto-doctor-sbd')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('service-key-result-khurd-khud')),
        findsNothing,
      );

      await tester.tap(
        find.byKey(const ValueKey('service-key-result-auto-doctor-bzd')),
      );
      await tester.pumpAndSettle();

      // Booking screen opens directly with both categories preselected and
      // locked (no re-selectable chips, no branch dropdown to switch away).
      expect(find.text('Тос солих'), findsOneWidget);
      expect(find.text('Угаалга'), findsOneWidget);
      expect(find.text('Үйлчилгээ сонгох'), findsNothing);
      expect(find.text('Салбар сонгох'), findsNothing);
    },
  );

  testWidgets(
    'removing a tag directly (without reopening the sheet) refreshes the '
    'branch list',
    (tester) async {
      await tester.pumpWidget(
        CarCareCustomerApp(
          organizationRepository: FakeOrganizationRepository(
            delay: Duration.zero,
          ),
          authRepository: _AuthedRepo(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Захиалах'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('service-key-add')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('service-key-tire-service')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('service-key-apply')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('service-key-result-khurd-khud')),
        findsOneWidget,
      );

      // Delete icon on the Chip triggers onDeleted directly — no sheet.
      await tester.tap(find.byIcon(Icons.close).first);
      await tester.pumpAndSettle();

      expect(find.text('Ажлын төрлөө сонгоно уу'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('service-key-result-khurd-khud')),
        findsNothing,
      );
    },
  );

  testWidgets(
    'backing out of booking returns to the picker, not the organization '
    'detail screen the flow skipped',
    (tester) async {
      await tester.pumpWidget(
        CarCareCustomerApp(
          organizationRepository: FakeOrganizationRepository(
            delay: Duration.zero,
          ),
          authRepository: _AuthedRepo(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Захиалах'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('service-key-add')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('service-key-tire-service')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('service-key-apply')));
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey('service-key-result-khurd-khud')),
      );
      await tester.pumpAndSettle();

      expect(find.byType(BookingRequestScreen), findsOneWidget);
      // The skipped detail screen must never enter the stack, otherwise the
      // pop below surfaces it.
      expect(find.byType(OrganizationDetailScreen), findsNothing);

      // System back (Android gesture / hardware button) goes through
      // PopNavigatorRouterDelegateMixin.popRoute.
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(find.byType(BookingRequestScreen), findsNothing);
      expect(find.byType(OrganizationDetailScreen), findsNothing);
      // Back on the picker with the selection still applied.
      expect(
        find.byKey(const ValueKey('service-key-result-khurd-khud')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'search filters the service-key list inside the picker sheet',
    (tester) async {
      await tester.pumpWidget(
        CarCareCustomerApp(
          organizationRepository: FakeOrganizationRepository(
            delay: Duration.zero,
          ),
          authRepository: _AuthedRepo(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Захиалах'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('service-key-add')));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey('service-key-search')),
        'тос',
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('service-key-oil-change')), findsOneWidget);
      expect(find.byKey(const ValueKey('service-key-car-wash')), findsNothing);
      expect(find.byKey(const ValueKey('service-key-tire-service')), findsNothing);

      await tester.tap(find.byKey(const ValueKey('service-key-oil-change')));
      await tester.pumpAndSettle();
      expect(find.text('Хэрэглэх (1)'), findsOneWidget);
    },
  );
}
