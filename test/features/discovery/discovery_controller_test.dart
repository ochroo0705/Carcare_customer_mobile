import 'package:carcare_customer_mobile/data/cache/in_memory_cache_store.dart';
import 'package:carcare_customer_mobile/features/discovery/data/fake_organization_repository.dart';
import 'package:carcare_customer_mobile/features/discovery/domain/organization_repository.dart';
import 'package:carcare_customer_mobile/features/discovery/presentation/controllers/discovery_controller.dart';
import 'package:carcare_customer_mobile/features/discovery/presentation/controllers/discovery_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late DiscoveryController controller;

  setUp(() async {
    controller = DiscoveryController(
      FakeOrganizationRepository(delay: Duration.zero),
    );
    await controller.load();
  });

  tearDown(() => controller.dispose());

  test('filters by organization and branch text on the server', () async {
    controller.setQuery('auto doctor');
    await Future<void>.delayed(const Duration(milliseconds: 400));
    expect(controller.visibleOrganizations, hasLength(1));
    expect(controller.visibleOrganizations.single.branches, hasLength(2));

    controller.setQuery('Яармаг');
    await Future<void>.delayed(const Duration(milliseconds: 400));
    expect(controller.visibleOrganizations, hasLength(1));
    expect(controller.visibleOrganizations.single.slug, 'khurd-motors');
  });

  test(
    "mapFallbackOrganizations holds the previous result through a filter "
    "change's blank window, instead of flashing empty",
    () async {
      // setUp()'s initial unfiltered load() already populated this.
      expect(controller.mapFallbackOrganizations, isNotEmpty);

      controller.setQuery('auto doctor');
      await Future<void>.delayed(const Duration(milliseconds: 600));
      expect(controller.mapFallbackOrganizations, hasLength(1));
      expect(controller.mapFallbackOrganizations.single.slug, 'auto-doctor');

      controller.setQuery('Яармаг');
      // visibleOrganizations blanks immediately so a stale response can't
      // render as a match for the new query — but the map's own fallback
      // must not follow it down to empty; it should still show the
      // *previous* query's result until the new one lands.
      expect(controller.visibleOrganizations, isEmpty);
      expect(controller.mapFallbackOrganizations, hasLength(1));
      expect(controller.mapFallbackOrganizations.single.slug, 'auto-doctor');

      await Future<void>.delayed(const Duration(milliseconds: 600));
      expect(controller.mapFallbackOrganizations, hasLength(1));
      expect(controller.mapFallbackOrganizations.single.slug, 'khurd-motors');
    },
  );

  test('filters branches by city and district on the server', () async {
    controller.setCity('Улаанбаатар');
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(controller.visibleOrganizations, hasLength(2));
    expect(controller.districts, contains('Баянзүрх'));

    controller.setDistrict('Баянзүрх');
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(controller.visibleOrganizations, hasLength(1));
    expect(
      controller.visibleOrganizations.single.branches.single.id,
      'auto-doctor-bzd',
    );
  });

  test(
    'a filter change drops mapLoaded immediately, and markers narrow once '
    'the viewport is re-requested (simulating the camera refit\'s '
    'onCameraIdle)',
    () async {
      const viewport = MapViewport(north: 55, south: 40, east: 120, west: 90);
      controller.requestMapMarkers(viewport);
      await Future<void>.delayed(const Duration(milliseconds: 600));
      expect(controller.mapLoaded, isTrue);
      final fullCount = controller.mapMarkers.length;
      expect(fullCount, greaterThan(1));

      controller.setQuery('Яармаг');
      // No automatic re-fetch at the (now possibly stale) old viewport —
      // that raced against the camera refit and could show an empty
      // result before the camera ever caught up (see
      // _invalidateMapForFilterChange). Falling back to unbounded list
      // data is immediate instead.
      expect(controller.mapLoaded, isFalse);

      // The map widget's own onCameraIdle re-requests the (now correct)
      // viewport once the camera settles — simulate that here.
      controller.requestMapMarkers(viewport);
      await Future<void>.delayed(const Duration(milliseconds: 600));
      expect(controller.mapMarkers, hasLength(1));

      controller.setQuery('');
      expect(controller.mapLoaded, isFalse);
      controller.requestMapMarkers(viewport);
      await Future<void>.delayed(const Duration(milliseconds: 600));
      expect(controller.mapMarkers, hasLength(fullCount));
    },
  );

  test(
    'bumps mapRefitSignal when the org list refreshes, not on a plain pan/zoom',
    () async {
      const viewportA = MapViewport(north: 55, south: 40, east: 120, west: 90);
      const viewportB = MapViewport(north: 50, south: 45, east: 110, west: 95);

      controller.requestMapMarkers(viewportA);
      await Future<void>.delayed(const Duration(milliseconds: 600));
      final afterInitialLoad = controller.mapRefitSignal;

      // Plain pan/zoom — the user moving the map — must not recenter it.
      controller.requestMapMarkers(viewportB);
      await Future<void>.delayed(const Duration(milliseconds: 600));
      expect(controller.mapRefitSignal, afterInitialLoad);

      // A search/filter change (i.e. a fresh load()) is what should
      // trigger a recenter.
      controller.setQuery('Яармаг');
      await Future<void>.delayed(const Duration(milliseconds: 600));
      expect(controller.mapRefitSignal, greaterThan(afterInitialLoad));
    },
  );

  test(
    'a match outside the current viewport falls back to the unbounded list '
    'instead of leaving the map showing nothing',
    () async {
      // Ulaanbaatar only — excludes Erdenet Car Care (49.0278, 104.0444).
      const ulaanbaatarViewport = MapViewport(
        north: 48.2,
        south: 47.5,
        east: 107.2,
        west: 106.5,
      );
      controller.requestMapMarkers(ulaanbaatarViewport);
      await Future<void>.delayed(const Duration(milliseconds: 600));
      expect(controller.mapLoaded, isTrue);
      expect(controller.mapMarkers, hasLength(2)); // auto-doctor + khurd

      final refitBefore = controller.mapRefitSignal;
      controller.setQuery('Эрдэнэт');
      // Immediately (before either debounce fires): the stale, now-mismatched
      // viewport-scoped markers must not still be treated as authoritative.
      expect(controller.mapLoaded, isFalse);

      // The list's own (unbounded) fetch lands — the match is visible via
      // visibleOrganizations, and the refit signal has moved so the map
      // widget's `didUpdateWidget` would recenter the camera on it. There
      // is deliberately no automatic map re-fetch at the old viewport
      // here (see _invalidateMapForFilterChange) — mapLoaded stays false,
      // showing the unbounded fallback, until a real viewport request
      // comes in.
      await Future<void>.delayed(const Duration(milliseconds: 400));
      expect(
        controller.visibleOrganizations.map((o) => o.slug),
        contains('erdenet-car-care'),
      );
      expect(controller.mapRefitSignal, greaterThan(refitBefore));
      expect(controller.mapLoaded, isFalse);

      // Simulates the camera actually having recentered on Erdenet (driven
      // by the refit above) and the map's onCameraIdle firing with a
      // viewport that now covers it — a real request, this time correctly
      // scoped, finds the match instead of coming back empty.
      const erdenetViewport = MapViewport(
        north: 49.5,
        south: 48.5,
        east: 104.5,
        west: 103.5,
      );
      controller.requestMapMarkers(erdenetViewport);
      await Future<void>.delayed(const Duration(milliseconds: 600));
      expect(controller.mapLoaded, isTrue);
      expect(controller.mapMarkers, hasLength(1));
      expect(controller.mapMarkers.single.orgSlug, 'erdenet-car-care');
    },
  );

  test('changing city resets district and clear restores all data', () async {
    controller
      ..setCity('Улаанбаатар')
      ..setDistrict('Баянзүрх')
      ..setCity('Орхон');
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(controller.district, isEmpty);
    expect(controller.visibleOrganizations.single.slug, 'erdenet-car-care');

    controller.clearFilters();
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(controller.hasActiveFilters, isFalse);
    expect(controller.visibleOrganizations, hasLength(3));
  });

  group('offline cache', () {
    late InMemoryCacheStore cache;

    setUp(() => cache = InMemoryCacheStore());

    test(
      'falls back to the last successful list when a later load fails',
      () async {
        final online = DiscoveryController(
          FakeOrganizationRepository(delay: Duration.zero),
          cache: cache,
        );
        await online.load();
        expect(online.state.status, DiscoveryStatus.data);
        expect(online.state.isFromCache, isFalse);
        online.dispose();

        // A fresh controller instance simulates a new app start; it only
        // shares state with the previous one through the persisted cache.
        final offline = DiscoveryController(
          FakeOrganizationRepository(
            delay: Duration.zero,
            scenario: FakeOrganizationScenario.error,
          ),
          cache: cache,
        );
        await offline.load();

        expect(offline.state.status, DiscoveryStatus.data);
        expect(offline.state.isFromCache, isTrue);
        expect(offline.state.organizations, isNotEmpty);
        offline.dispose();
      },
    );

    test(
      'reports a plain error when there is no cache to fall back to',
      () async {
        final controller = DiscoveryController(
          FakeOrganizationRepository(
            delay: Duration.zero,
            scenario: FakeOrganizationScenario.error,
          ),
          cache: cache,
        );

        await controller.load();

        expect(controller.state.status, DiscoveryStatus.error);
        expect(controller.state.isFromCache, isFalse);
        controller.dispose();
      },
    );
  });
}
