import 'package:carcare_customer_mobile/data/cache/in_memory_cache_store.dart';
import 'package:carcare_customer_mobile/features/discovery/data/fake_organization_repository.dart';
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
