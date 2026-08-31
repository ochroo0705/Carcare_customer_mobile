import 'package:carcare_customer_mobile/features/discovery/data/fake_organization_repository.dart';
import 'package:carcare_customer_mobile/features/discovery/presentation/controllers/discovery_controller.dart';
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
}
