import 'package:carcare_customer_mobile/app/bootstrap_flags.dart';
import 'package:carcare_customer_mobile/app/app.dart';
import 'package:carcare_customer_mobile/data/cache/in_memory_cache_store.dart';
import 'package:carcare_customer_mobile/features/discovery/data/fake_organization_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The Discovery header's search field has its own internal `Scrollable`
/// (an `EditableText` implementation detail, scrolling horizontally), so the
/// default `find.byType(Scrollable)` target is ambiguous — pin to the
/// vertical one, which is the page's own `CustomScrollView`.
Future<void> _scrollUntilVisible(
  WidgetTester tester,
  Finder finder,
  double delta,
) => tester.scrollUntilVisible(
  finder,
  delta,
  scrollable: find.byWidgetPredicate(
    (widget) =>
        widget is Scrollable && widget.axisDirection == AxisDirection.down,
  ),
);

void main() {
  setUpAll(() => debugDisableAppBootstrap = true);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('offers the list when map initialization times out', (
    tester,
  ) async {
    // The native map-configuration channel is unimplemented in the test VM, so
    // `isConfigured()` would otherwise hang and the map would sit on the
    // loading overlay forever (its 12s timeout timer is only armed once
    // `isConfigured` resolves). Mock it to "configured" so the loading →
    // timeout → failed path this test exercises can actually run.
    const mapChannel = MethodChannel(
      'mn.carcare.carcare_customer_mobile/map_configuration',
    );
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      mapChannel,
      (call) async => call.method == 'isConfigured' ? true : null,
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        mapChannel,
        null,
      ),
    );

    await tester.pumpWidget(
      CarCareCustomerApp(
        organizationRepository: FakeOrganizationRepository(
          delay: Duration.zero,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('discovery-open-map')));
    // Let the page-push transition finish before asserting: unlike the old
    // inline setState-driven toggle, this is a real Navigator push, and
    // `isConfigured()` resolves a beat after the first frame.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Газрын зураг ачаалж байна…'), findsOneWidget);

    // The 12s init-timeout timer is armed only after `isConfigured()` resolves
    // (one async hop past frame 0), so it fires just past the 12s mark —
    // advance a hair beyond it rather than landing exactly on the boundary.
    await tester.pump(const Duration(seconds: 13));
    await tester.pump();
    expect(find.text('Газрын зураг ачаалсангүй'), findsOneWidget);

    final showListButton = find.byKey(const ValueKey('map-show-list'));
    await tester.ensureVisible(showListButton);
    await tester.pumpAndSettle();
    await tester.tap(showListButton);
    await tester.pumpAndSettle();
    // Back on Explore's list, the fullscreen map page popped off the stack.
    expect(
      find.byKey(const ValueKey('branch-auto-doctor-auto-doctor-bzd')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('discovery-open-map')), findsOneWidget);
  });

  testWidgets(
    'opens the fullscreen map from the FAB, only on the Хайх tab',
    (tester) async {
      // Map config is unmocked here (unlike the timeout test above), so
      // `isConfigured()` never resolves and the map would sit on its
      // spinning "loading" overlay forever — `pumpAndSettle` would time out
      // waiting for that animation. Reporting "unconfigured" keeps the map
      // page static so this test only needs to assert the FAB/nav wiring.
      const mapChannel = MethodChannel(
        'mn.carcare.carcare_customer_mobile/map_configuration',
      );
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        mapChannel,
        (call) async => call.method == 'isConfigured' ? false : null,
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          mapChannel,
          null,
        ),
      );

      await tester.pumpWidget(
        CarCareCustomerApp(
          organizationRepository: FakeOrganizationRepository(
            delay: Duration.zero,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('discovery-open-map')), findsOneWidget);

      // Switching to another tab hides the map FAB — it's Explore-only.
      await tester.tap(find.text('Захиалгууд'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('discovery-open-map')), findsNothing);

      await tester.tap(find.text('Хайх'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('discovery-open-map')));
      await tester.pumpAndSettle();
      expect(find.text('Газрын зураг'), findsOneWidget);

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('branch-auto-doctor-auto-doctor-bzd')),
        findsOneWidget,
      );
    },
  );

  testWidgets('opens a branch detail page from a tap', (tester) async {
    await tester.pumpWidget(
      CarCareCustomerApp(
        organizationRepository: FakeOrganizationRepository(
          delay: Duration.zero,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final branchCard = find.byKey(
      const ValueKey('branch-auto-doctor-auto-doctor-bzd'),
    );
    await _scrollUntilVisible(tester, branchCard, 200);
    await tester.tap(branchCard);
    await tester.pumpAndSettle();
    expect(find.text('Баянзүрх салбар'), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(branchCard, findsOneWidget);
  });

  testWidgets('shows branches and opens a branch detail page with booking', (
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
    expect(find.text('Нэр, хот эсвэл дүүргээр хайх'), findsOneWidget);

    // Auto Doctor Service has two branches, so the tenant name (the card's
    // subtext) appears once per branch card.
    expect(find.text('Auto Doctor Service'), findsNWidgets(2));

    final sbdBranch = find.byKey(
      const ValueKey('branch-auto-doctor-auto-doctor-sbd'),
    );
    await _scrollUntilVisible(tester, sbdBranch, 200);
    await tester.tap(sbdBranch);
    await tester.pumpAndSettle();

    // Only the tapped branch's own info renders (not its sibling branch),
    // and the booking CTA is present (global service-key block resolved).
    expect(find.text('Цаг захиалах'), findsOneWidget);
    expect(find.text('Сүхбаатар салбар'), findsOneWidget);
    expect(find.text('Баянзүрх салбар'), findsNothing);
    expect(find.text('1-р хороо, Олимпын гудамж 9'), findsOneWidget);
    expect(find.text('09:00–18:00'), findsOneWidget);
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

    await tester.enterText(find.byType(TextField), 'Эрдэнэт');
    await tester.pumpAndSettle();

    final erdenetCard = find.text('Эрдэнэт Car Care');
    await _scrollUntilVisible(tester, erdenetCard, 200);
    expect(erdenetCard, findsOneWidget);
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
      // A single cache shared across both "launches" stands in for the
      // on-disk Drift cache surviving an app restart.
      final cache = InMemoryCacheStore();

      // First launch: a normal, successful load persists the list to cache.
      await tester.pumpWidget(
        CarCareCustomerApp(
          organizationRepository: FakeOrganizationRepository(
            delay: Duration.zero,
          ),
          cacheStore: cache,
        ),
      );
      await tester.pumpAndSettle();
      await _scrollUntilVisible(
        tester,
        find.byKey(const ValueKey('branch-auto-doctor-auto-doctor-bzd')),
        200,
      );
      expect(find.text('Auto Doctor Service'), findsNWidgets(2));

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
          cacheStore: cache,
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Сүлжээгүй байна — сүүлд ачаалсан жагсаалтыг харуулж байна'),
        findsOneWidget,
      );
      // The offline banner adds height above the list, so the first card
      // needs a scroll to come into the test viewport.
      await _scrollUntilVisible(
        tester,
        find.byKey(const ValueKey('branch-auto-doctor-auto-doctor-bzd')),
        200,
      );
      expect(find.text('Auto Doctor Service'), findsNWidgets(2));

      // Retrying while still offline keeps showing the cached list rather
      // than dropping to a hard error, since the cache is still valid data.
      final retryButton = find.byKey(const ValueKey('discovery-offline-retry'));
      await _scrollUntilVisible(tester, retryButton, -200);
      await tester.tap(retryButton);
      await tester.pumpAndSettle();
      expect(
        find.text('Сүлжээгүй байна — сүүлд ачаалсан жагсаалтыг харуулж байна'),
        findsOneWidget,
      );
      await _scrollUntilVisible(
        tester,
        find.byKey(const ValueKey('branch-auto-doctor-auto-doctor-bzd')),
        200,
      );
      expect(find.text('Auto Doctor Service'), findsNWidgets(2));
    },
  );
}
