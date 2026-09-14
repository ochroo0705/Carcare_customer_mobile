import 'dart:async';

import 'package:carcare_customer_mobile/core/errors/app_failure.dart';
import 'package:carcare_customer_mobile/features/discovery/domain/branch.dart';
import 'package:carcare_customer_mobile/features/discovery/domain/organization.dart';
import 'package:carcare_customer_mobile/features/discovery/domain/organization_repository.dart';
import 'package:carcare_customer_mobile/features/discovery/presentation/controllers/discovery_controller.dart';
import 'package:flutter_test/flutter_test.dart';

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

class _ScriptedRepository implements OrganizationRepository {
  final requests = <OrganizationFilter>[];
  Future<OrganizationPage> Function(OrganizationFilter) handler =
      (_) async => _page(page: 1, items: const []);

  @override
  Future<OrganizationPage> getOrganizations({OrganizationFilter? filter}) {
    final request = filter ?? const OrganizationFilter();
    requests.add(request);
    return handler(request);
  }

  @override
  Future<OrganizationDetail> getOrganization(String slug) =>
      throw UnimplementedError();
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
}
