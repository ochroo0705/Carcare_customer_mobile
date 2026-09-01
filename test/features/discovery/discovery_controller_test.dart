import 'package:carcare_customer_mobile/features/discovery/data/fake_organization_repository.dart';
import 'package:carcare_customer_mobile/features/discovery/presentation/controllers/discovery_controller.dart';
import 'package:carcare_customer_mobile/features/discovery/presentation/controllers/discovery_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late DiscoveryController controller;

  setUp(() async {
    controller = DiscoveryController(
      FakeOrganizationRepository(delay: Duration.zero),
    );
    await controller.load();
  });

  tearDown(() => controller.dispose());

  test('filters by organization and branch text', () {
    controller.setQuery('auto doctor');
    expect(controller.visibleOrganizations, hasLength(1));
    expect(controller.visibleOrganizations.single.branches, hasLength(2));

    controller.setQuery('Яармаг');
    expect(controller.visibleOrganizations, hasLength(1));
    expect(controller.visibleOrganizations.single.slug, 'khurd-motors');
  });

  test('filters branches by city and district', () {
    controller.setCity('Улаанбаатар');
    expect(controller.visibleOrganizations, hasLength(2));
    expect(controller.districts, contains('Баянзүрх'));

    controller.setDistrict('Баянзүрх');
    expect(controller.visibleOrganizations, hasLength(1));
    expect(
      controller.visibleOrganizations.single.branches.single.id,
      'auto-doctor-bzd',
    );
  });

  test('changing city resets district and clear restores all data', () {
    controller
      ..setCity('Улаанбаатар')
      ..setDistrict('Баянзүрх')
      ..setCity('Орхон');

    expect(controller.district, isEmpty);
    expect(controller.visibleOrganizations.single.slug, 'erdenet-car-care');

    controller.clearFilters();
    expect(controller.hasActiveFilters, isFalse);
    expect(controller.visibleOrganizations, hasLength(3));
  });

  group('offline cache', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test(
      'falls back to the last successful list when a later load fails',
      () async {
        final online = DiscoveryController(
          FakeOrganizationRepository(delay: Duration.zero),
        );
        await online.load();
        expect(online.state.status, DiscoveryStatus.data);
        expect(online.state.isFromCache, isFalse);
        online.dispose();

        // A fresh controller instance simulates a new app start; it only
        // shares state with the previous one through persisted storage.
        final offline = DiscoveryController(
          FakeOrganizationRepository(
            delay: Duration.zero,
            scenario: FakeOrganizationScenario.error,
          ),
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
        );

        await controller.load();

        expect(controller.state.status, DiscoveryStatus.error);
        expect(controller.state.isFromCache, isFalse);
        controller.dispose();
      },
    );
  });
}
