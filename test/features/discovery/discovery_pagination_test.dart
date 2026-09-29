import 'dart:async';

import 'package:carcare_customer_mobile/core/errors/app_failure.dart';
import 'package:carcare_customer_mobile/features/discovery/domain/branch.dart';
import 'package:carcare_customer_mobile/features/discovery/domain/organization.dart';
import 'package:carcare_customer_mobile/features/discovery/domain/organization_repository.dart';
import 'package:carcare_customer_mobile/features/discovery/presentation/controllers/discovery_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

Organization _organization(String slug) => Organization(
  slug: slug,
  name: slug,
  branches: [
    const Branch(
      id: 'branch',
      name: 'Branch',
      city: 'Улаанбаатар',
      district: 'Баянзүрх',
    ),
  ],
);

OrganizationPage _page({
  required int page,
  required List<Organization> items,
  bool hasNext = false,
}) => OrganizationPage(
      organizations: items,
      pagination: OrganizationPagination(
        page: page,
        pageSize: 20,
        total: hasNext ? 2 : items.length,
        totalPages: hasNext ? 2 : 1,
        hasPrev: page > 1,
        hasNext: hasNext,
      ),
      facets: const OrganizationFacets(
        cities: ['Улаанбаатар'],
        districts: ['Баянзүрх'],
      ),
    );

class _ScriptedRepository extends Fake implements OrganizationRepository {
  final requests = <OrganizationFilter>[];
  final mapRequests = <MapViewport>[];
  Future<OrganizationPage> Function(OrganizationFilter) handler =
      (_) async => _page(page: 1, items: const []);
  Future<OrganizationMapPage> Function(MapViewport) mapHandler =
      (_) async => const OrganizationMapPage(
        markers: [],
        count: 0,
        truncated: false,
        max: 500,
      );

  @override
  Future<OrganizationPage> getOrganizations({OrganizationFilter? filter}) {
    final request = filter ?? const OrganizationFilter();
    requests.add(request);
    return handler(request);
  }

  @override
  Future<OrganizationMapPage> getMapMarkers({
    required MapViewport viewport,
    OrganizationFilter? filter,
  }) {
    mapRequests.add(viewport);
    return mapHandler(viewport);
  }

  @override
  Future<OrganizationDetail> getOrganization(String slug) =>
      throw UnimplementedError();

  @override
  Future<List<ServiceKey>> getServiceKeys() async => const [];
}

void main() {
  test('sends text and location filters to the repository', () async {
    final repository = _ScriptedRepository()
      ..handler = (_) async => _page(page: 1, items: [_organization('one')]);
    final controller = DiscoveryController(repository);
    addTearDown(controller.dispose);

    controller.setCity('Улаанбаатар');
    await Future<void>.delayed(Duration.zero);
    controller.setDistrict('Баянзүрх');
    await Future<void>.delayed(Duration.zero);
    controller.setQuery('toyota');
    await Future<void>.delayed(const Duration(milliseconds: 400));

    final request = repository.requests.last;
    expect(request.query, 'toyota');
    expect(request.city, 'Улаанбаатар');
    expect(request.district, 'Баянзүрх');
    expect(request.page, 1);
  });

  test('ignores a slower response from the previous query', () async {
    final first = Completer<OrganizationPage>();
    final second = Completer<OrganizationPage>();
    final repository = _ScriptedRepository();
    var calls = 0;
    repository.handler = (_) => ++calls == 1 ? first.future : second.future;
    final controller = DiscoveryController(repository);
    addTearDown(controller.dispose);

    final initialLoad = controller.load();
    controller.setQuery('new');
    first.complete(_page(page: 1, items: [_organization('old')]));
    await initialLoad;
    expect(controller.state.organizations, isEmpty);

    await Future<void>.delayed(const Duration(milliseconds: 400));
    second.complete(_page(page: 1, items: [_organization('new')]));
    await Future<void>.delayed(Duration.zero);
    expect(controller.state.organizations.single.slug, 'new');
  });

  test(
    'appends one page, prevents duplicate loads, and exposes retry failure',
    () async {
      final repository = _ScriptedRepository();
      repository.handler = (filter) async {
        return filter.page == 1
            ? _page(page: 1, items: [_organization('one')], hasNext: true)
            : _page(page: 2, items: [_organization('two')]);
      };
      final controller = DiscoveryController(repository);
      addTearDown(controller.dispose);

      await controller.load();
      final before = repository.requests.length;
      await Future.wait([controller.loadMore(), controller.loadMore()]);
      expect(repository.requests.length, before + 1);
      expect(
        controller.state.organizations.map((item) => item.slug),
        ['one', 'two'],
      );

      final failingRepository = _ScriptedRepository();
      failingRepository.handler = (filter) async {
        if (filter.page == 2) throw const NetworkFailure();
        return _page(page: 1, items: [_organization('one')], hasNext: true);
      };
      final failingController = DiscoveryController(failingRepository);
      addTearDown(failingController.dispose);
      await failingController.load();
      await failingController.loadMore();
      expect(failingController.state.loadMoreMessage, isNotNull);
    },
  );

  test('uses buffered coverage and refetches after a filter change',
      () async {
    final repository = _ScriptedRepository();
    final controller = DiscoveryController(repository);
    addTearDown(controller.dispose);
    const viewport = MapViewport(
      north: 48,
      south: 47,
      east: 107,
      west: 106,
    );

    controller.requestMapMarkers(viewport);
    await Future<void>.delayed(const Duration(milliseconds: 600));
    expect(repository.mapRequests.single.north, closeTo(48.3, 0.0001));
    expect(repository.mapRequests.single.south, closeTo(46.7, 0.0001));
    expect(repository.mapRequests.single.east, closeTo(107.15, 0.0001));
    expect(repository.mapRequests.single.west, closeTo(105.85, 0.0001));
    controller.requestMapMarkers(const MapViewport(
      north: 48.1,
      south: 47.1,
      east: 107.1,
      west: 106.1,
    ));
    await Future<void>.delayed(const Duration(milliseconds: 600));
    expect(repository.mapRequests, hasLength(1));

    controller.requestMapMarkers(const MapViewport(
      north: 48.5,
      south: 47.5,
      east: 107.5,
      west: 106.5,
    ));
    await Future<void>.delayed(const Duration(milliseconds: 600));
    expect(repository.mapRequests, hasLength(2));

    controller.setCity('Улаанбаатар');
    await Future<void>.delayed(Duration.zero);
    controller.requestMapMarkers(viewport);
    await Future<void>.delayed(const Duration(milliseconds: 600));
    expect(repository.mapRequests, hasLength(3));
  });

  test('map retry bypasses the failed viewport dedupe key', () async {
    final repository = _ScriptedRepository()
      ..mapHandler = (_) async => throw const NetworkFailure();
    final controller = DiscoveryController(repository);
    addTearDown(controller.dispose);
    const viewport = MapViewport(
      north: 48,
      south: 47,
      east: 107,
      west: 106,
    );

    controller.requestMapMarkers(viewport);
    await Future<void>.delayed(const Duration(milliseconds: 600));
    controller.requestMapMarkers(viewport);
    await Future<void>.delayed(const Duration(milliseconds: 600));
    expect(repository.mapRequests, hasLength(1));
    expect(controller.mapError, isNotNull);

    controller.requestMapMarkers(viewport, force: true);
    await Future<void>.delayed(const Duration(milliseconds: 600));
    expect(repository.mapRequests, hasLength(2));
  });

  test('buffers antimeridian coverage without losing the crossing bounds',
      () async {
    final repository = _ScriptedRepository();
    final controller = DiscoveryController(repository);
    addTearDown(controller.dispose);
    const viewport = MapViewport(
      north: 10,
      south: 0,
      east: -179,
      west: 179,
    );

    controller.requestMapMarkers(viewport);
    await Future<void>.delayed(const Duration(milliseconds: 600));
    expect(repository.mapRequests.single.east, closeTo(-178.7, 0.0001));
    expect(repository.mapRequests.single.west, closeTo(178.7, 0.0001));

    controller.requestMapMarkers(const MapViewport(
      north: 9.5,
      south: 0.5,
      east: -179.5,
      west: 179.5,
    ));
    await Future<void>.delayed(const Duration(milliseconds: 600));
    expect(repository.mapRequests, hasLength(1));
  });

  test('clears a stale refresh error when cached coverage serves movement',
      () async {
    const marker = OrganizationMapMarker(
      id: 'branch',
      orgSlug: 'org',
      orgName: 'Org',
      branchName: 'Branch',
      latitude: 47.5,
      longitude: 106.5,
    );
    final repository = _ScriptedRepository()
      ..mapHandler = (_) async => const OrganizationMapPage(
        markers: [marker],
        count: 1,
        truncated: false,
        max: 500,
      );
    final controller = DiscoveryController(repository);
    addTearDown(controller.dispose);
    const viewport = MapViewport(
      north: 48,
      south: 47,
      east: 107,
      west: 106,
    );

    controller.requestMapMarkers(viewport);
    await Future<void>.delayed(const Duration(milliseconds: 600));
    repository.mapHandler = (_) async => throw const NetworkFailure();
    controller.requestMapMarkers(const MapViewport(
      north: 48.5,
      south: 47.5,
      east: 107.5,
      west: 106.5,
    ));
    await Future<void>.delayed(const Duration(milliseconds: 600));
    expect(repository.mapRequests, hasLength(2));
    expect(controller.mapError, isNotNull);
    expect(controller.mapMarkers, hasLength(1));

    controller.requestMapMarkers(const MapViewport(
      north: 48.1,
      south: 47.1,
      east: 107.1,
      west: 106.1,
    ));
    expect(repository.mapRequests, hasLength(2));
    expect(controller.mapError, isNull);
    expect(controller.mapMarkers, hasLength(1));
  });
}
