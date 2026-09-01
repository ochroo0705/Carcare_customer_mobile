import 'package:carcare_customer_mobile/app/app.dart';
import 'package:carcare_customer_mobile/features/discovery/data/fake_organization_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('saves an organization and shows it in Favorites', (
    tester,
  ) async {
    await tester.pumpWidget(
      CarCareCustomerApp(
        organizationRepository: FakeOrganizationRepository(
          delay: Duration.zero,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final favoriteButton = find.byKey(const ValueKey('favorite-auto-doctor'));
    await tester.ensureVisible(favoriteButton);
    await tester.tap(favoriteButton);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Хадгалсан'));
    await tester.pumpAndSettle();

    expect(find.text('Хадгалсан сервисүүд'), findsOneWidget);
    expect(find.text('Auto Doctor Service'), findsOneWidget);
  });

  testWidgets('offers the list when map initialization times out', (
    tester,
  ) async {
    await tester.pumpWidget(
      CarCareCustomerApp(
        organizationRepository: FakeOrganizationRepository(
          delay: Duration.zero,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.map_outlined));
    await tester.pump();
    expect(find.text('Газрын зураг ачаалж байна…'), findsOneWidget);

    await tester.pump(const Duration(seconds: 12));
    await tester.pump();
    expect(find.text('Газрын зураг ачаалсангүй'), findsOneWidget);

    final showListButton = find.byKey(const ValueKey('map-show-list'));
    await tester.ensureVisible(showListButton);
    await tester.pumpAndSettle();
    await tester.tap(showListButton);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('organization-auto-doctor')),
      findsOneWidget,
    );
  });

  testWidgets('preserves map mode while switching top-level destinations', (
    tester,
  ) async {
    await tester.pumpWidget(
      CarCareCustomerApp(
        organizationRepository: FakeOrganizationRepository(
          delay: Duration.zero,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.map_outlined));
    await tester.pump();
    await tester.tap(find.text('Хадгалсан'));
    await tester.pump();
    await tester.tap(find.text('Хайх'));
    await tester.pump();

    final switcherFinder = find.byWidgetPredicate(
      (widget) => widget.runtimeType.toString().startsWith('SegmentedButton<'),
    );
    final dynamic switcher = tester.widget(switcherFinder);
    expect(switcher.selected.single.toString(), contains('map'));
    expect(find.byKey(const ValueKey('discovery-map-0')), findsOneWidget);
  });

  testWidgets('saves an organization from its detail page', (tester) async {
    await tester.pumpWidget(
      CarCareCustomerApp(
        organizationRepository: FakeOrganizationRepository(
          delay: Duration.zero,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final organizationCard = find.byKey(
      const ValueKey('organization-auto-doctor'),
    );
    await tester.ensureVisible(organizationCard);
    await tester.tapAt(
      tester.getTopLeft(organizationCard) + const Offset(100, 24),
    );
    await tester.pumpAndSettle();
    expect(find.text('Хадгалах'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('detail-favorite-auto-doctor')));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.favorite_rounded), findsOneWidget);
    expect(find.text('Хадгалсан'), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Хадгалсан'));
    await tester.pumpAndSettle();

    expect(find.text('Auto Doctor Service'), findsOneWidget);
  });

  testWidgets('shows organizations and opens details', (tester) async {
    await tester.pumpWidget(
      CarCareCustomerApp(
        organizationRepository: FakeOrganizationRepository(
          delay: Duration.zero,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Авто сервисээ\nхялбархан олоорой'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.view_list_outlined));
    await tester.pumpAndSettle();
    expect(find.text('Auto Doctor Service'), findsOneWidget);

    final organizationCard = find.byKey(
      const ValueKey('organization-auto-doctor'),
    );
    await tester.ensureVisible(organizationCard);
    await tester.pumpAndSettle();
    await tester.tap(organizationCard);
    await tester.pumpAndSettle();
    expect(find.text('Баянзүрх салбар'), findsNWidgets(2));
    expect(find.text('Цаг захиалах'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('branch-choice-auto-doctor-sbd')),
    );
    await tester.pumpAndSettle();
    expect(find.text('1-р хороо, Олимпын гудамж 9'), findsOneWidget);
    expect(find.text('09:00–18:00'), findsOneWidget);

    await tester.ensureVisible(find.text('Цаг захиалах'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Цаг захиалах'));
    await tester.pumpAndSettle();
    expect(find.text('Нэвтрэх / Бүртгүүлэх'), findsOneWidget);
    expect(
      find.text('Утасны дугаараа оруулаад, ирэх 6 оронтой кодоор нэвтэрнэ.'),
      findsOneWidget,
    );
    expect(find.text('Үйлчилгээ сонгох'), findsNothing);

    await tester.enterText(
      find.byKey(const ValueKey('login-phone')),
      '99112233',
    );
    await tester.tap(find.text('Код авах →'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('login-otp')), '123456');
    await tester.tap(find.text('Нэвтрэх →'));
    await tester.pumpAndSettle();
    expect(find.text('Цаг хүсэх'), findsOneWidget);
    expect(find.text('Сүхбаатар салбар'), findsOneWidget);
  });

  testWidgets('shows an explicit empty state', (tester) async {
    await tester.pumpWidget(
      CarCareCustomerApp(
        organizationRepository: FakeOrganizationRepository(
          scenario: FakeOrganizationScenario.empty,
          delay: Duration.zero,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Авто сервис олдсонгүй'), findsOneWidget);
  });

  testWidgets('filters the organization list from search', (tester) async {
    await tester.pumpWidget(
      CarCareCustomerApp(
        organizationRepository: FakeOrganizationRepository(
          delay: Duration.zero,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.view_list_outlined));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Эрдэнэт');
    await tester.pumpAndSettle();

    expect(find.text('Эрдэнэт Car Care'), findsOneWidget);
    expect(find.text('Auto Doctor Service'), findsNothing);
  });

  testWidgets('shows an error with retry action', (tester) async {
    await tester.pumpWidget(
      CarCareCustomerApp(
        organizationRepository: FakeOrganizationRepository(
          scenario: FakeOrganizationScenario.error,
          delay: Duration.zero,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Мэдээлэл ачаалсангүй'), findsOneWidget);
    expect(find.text('Дахин оролдох'), findsOneWidget);
  });

  testWidgets(
    'shows the last loaded list with an offline banner when a later load fails',
    (tester) async {
      // First launch: a normal, successful load persists the list to cache.
      await tester.pumpWidget(
        CarCareCustomerApp(
          organizationRepository: FakeOrganizationRepository(
            delay: Duration.zero,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.view_list_outlined));
      await tester.pumpAndSettle();
      expect(find.text('Auto Doctor Service'), findsOneWidget);

      // Simulated restart with no network: unmount the whole tree first so
      // the next pumpWidget performs a genuine fresh initState (otherwise
      // Flutter reuses the existing State for the same widget type and never
      // re-runs DiscoveryController.load() with the new repository).
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(
        CarCareCustomerApp(
          organizationRepository: FakeOrganizationRepository(
            scenario: FakeOrganizationScenario.error,
            delay: Duration.zero,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.view_list_outlined));
      await tester.pumpAndSettle();

      expect(
        find.text('Сүлжээгүй байна — сүүлд ачаалсан жагсаалтыг харуулж байна'),
        findsOneWidget,
      );
      // The offline banner adds height above the list, so the first card
      // needs a scroll to come into the test viewport.
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -400));
      await tester.pumpAndSettle();
      expect(find.text('Auto Doctor Service'), findsOneWidget);

      // Retrying while still offline keeps showing the cached list rather
      // than dropping to a hard error, since the cache is still valid data.
      await tester.tap(find.byKey(const ValueKey('discovery-offline-retry')));
      await tester.pumpAndSettle();
      expect(
        find.text('Сүлжээгүй байна — сүүлд ачаалсан жагсаалтыг харуулж байна'),
        findsOneWidget,
      );
      expect(find.text('Auto Doctor Service'), findsOneWidget);
    },
  );
}
