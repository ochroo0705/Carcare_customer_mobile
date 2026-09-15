import 'package:carcare_customer_mobile/core/errors/app_failure.dart';
import 'package:carcare_customer_mobile/features/discovery/domain/branch.dart';
import 'package:carcare_customer_mobile/features/discovery/domain/organization.dart';
import 'package:carcare_customer_mobile/features/discovery/domain/organization_repository.dart';

enum FakeOrganizationScenario { data, empty, error }

class FakeOrganizationRepository implements OrganizationRepository {
  FakeOrganizationRepository({
    this.scenario = FakeOrganizationScenario.data,
    this.delay = const Duration(milliseconds: 450),
  });
  final FakeOrganizationScenario scenario;
  final Duration delay;

  @override
  Future<OrganizationPage> getOrganizations({
    OrganizationFilter? filter,
  }) async {
    // Fake mode серверийн шүүлтийг дуурайлгахгүй — бүх жагсаалтыг буцаана.
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    if (scenario == FakeOrganizationScenario.empty) {
      return const OrganizationPage(
        organizations: [],
        pagination: OrganizationPagination(
          page: 1, pageSize: 20, total: 0, totalPages: 1,
          hasPrev: false, hasNext: false,
        ),
      );
    }
    if (scenario == FakeOrganizationScenario.error) {
      throw const ServerFailure('Авто сервисүүдийг ачаалж чадсангүй.');
    }
    final current = filter ?? const OrganizationFilter();
    final query = current.query.toLowerCase();
    final filtered = _organizations.map((organization) {
      final orgMatches = query.isNotEmpty && organization.name.toLowerCase().contains(query);
      final branches = organization.branches.where((branch) {
        if (current.city.isNotEmpty && branch.city != current.city) return false;
        if (current.district.isNotEmpty && branch.district != current.district) return false;
        if (current.serviceKey.isNotEmpty &&
            !branch.serviceKeyIds.contains(current.serviceKey)) {
          return false;
        }
        if (query.isEmpty || orgMatches) return true;
        return [branch.name, branch.city, branch.district]
            .any((value) => value.toLowerCase().contains(query));
      }).toList(growable: false);
      return Organization(
        slug: organization.slug,
        name: organization.name,
        logoUrl: organization.logoUrl,
        branches: branches,
      );
    }).where((organization) => organization.branches.isNotEmpty).toList(growable: false);
    final start = (current.page - 1) * current.pageSize;
    final items = start >= filtered.length
        ? const <Organization>[]
        : filtered.skip(start).take(current.pageSize).toList(growable: false);
    return OrganizationPage(
      organizations: items,
      pagination: OrganizationPagination(
        page: current.page,
        pageSize: current.pageSize,
        total: filtered.length,
        totalPages: filtered.isEmpty ? 1 : (filtered.length / current.pageSize).ceil(),
        hasPrev: current.page > 1,
        hasNext: start + items.length < filtered.length,
      ),
      facets: OrganizationFacets(
        cities: _organizations.expand((o) => o.branches).map((b) => b.city).toSet().toList(),
        districts: _organizations.expand((o) => o.branches).map((b) => b.district).toSet().toList(),
      ),
    );
  }

  @override
  Future<OrganizationMapPage> getMapMarkers({
    required MapViewport viewport,
    OrganizationFilter? filter,
  }) async {
    final current = filter ?? const OrganizationFilter();
    // The map endpoint is independent of list pagination; use one complete
    // in-memory catalog snapshot before applying the viewport.
    final page = await getOrganizations(
      filter: OrganizationFilter(
        query: current.query,
        city: current.city,
        district: current.district,
        page: 1,
        pageSize: 10000,
        lat: current.lat,
        lng: current.lng,
        radiusKm: current.radiusKm,
        openNow: current.openNow,
        weekend: current.weekend,
        serviceKey: current.serviceKey,
      ),
    );
    final markers = <OrganizationMapMarker>[];
    for (final organization in page.organizations) {
      for (final branch in organization.branches) {
        final lat = branch.latitude;
        final lng = branch.longitude;
        if (lat == null || lng == null || lat < viewport.south || lat > viewport.north) {
          continue;
        }
        final inLongitude = viewport.west <= viewport.east
            ? lng >= viewport.west && lng <= viewport.east
            : lng >= viewport.west || lng <= viewport.east;
        if (!inLongitude) continue;
        markers.add(OrganizationMapMarker(
          id: branch.id,
          orgSlug: organization.slug,
          orgName: organization.name,
          branchName: branch.name,
          logoUrl: organization.logoUrl,
          city: branch.city,
          district: branch.district,
          latitude: lat,
          longitude: lng,
          distanceKm: branch.distanceKm,
          serviceKeyIds: branch.serviceKeyIds,
        ));
      }
    }
    return OrganizationMapPage(
      markers: markers,
      count: markers.length,
      truncated: false,
      max: 500,
    );
  }

  @override
  Future<OrganizationDetail> getOrganization(String slug) async {
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    if (scenario == FakeOrganizationScenario.error) {
      throw const ServerFailure('Сервисийн мэдээллийг ачаалж чадсангүй.');
    }
    for (final organization in _organizationDetails) {
      if (organization.slug == slug) return organization;
    }
    throw const NotFoundFailure('Байгууллага олдсонгүй.');
  }

  @override
  Future<List<ServiceKey>> getServiceKeys() async {
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    if (scenario == FakeOrganizationScenario.error) {
      throw const ServerFailure('Ажлын төрлүүдийг ачаалж чадсангүй.');
    }
    return const [
      ServiceKey(id: 'oil-change', name: 'Моторын тос солих'),
      ServiceKey(id: 'tire-service', name: 'Дугуйны үйлчилгээ'),
      ServiceKey(id: 'car-wash', name: 'Угаалга'),
    ];
  }
}

const _organizations = <Organization>[
  Organization(
    slug: 'auto-doctor',
    name: 'Auto Doctor Service',
    branches: [
      Branch(
        id: 'auto-doctor-bzd',
        name: 'Баянзүрх салбар',
        city: 'Улаанбаатар',
        district: 'Баянзүрх',
        latitude: 47.9187,
        longitude: 106.9684,
        serviceKeyIds: ['oil-change', 'car-wash'],
      ),
      Branch(
        id: 'auto-doctor-sbd',
        name: 'Сүхбаатар салбар',
        city: 'Улаанбаатар',
        district: 'Сүхбаатар',
        serviceKeyIds: ['car-wash'],
      ),
    ],
  ),
  Organization(
    slug: 'khurd-motors',
    name: 'Хурд Моторс',
    branches: [
      Branch(
        id: 'khurd-khud',
        name: 'Яармаг салбар',
        city: 'Улаанбаатар',
        district: 'Хан-Уул',
        latitude: 47.8581,
        longitude: 106.7869,
        serviceKeyIds: ['tire-service'],
      ),
    ],
  ),
  Organization(
    slug: 'erdenet-car-care',
    name: 'Эрдэнэт Car Care',
    branches: [
      Branch(
        id: 'erdenet-center',
        name: 'Төв салбар',
        city: 'Орхон',
        district: 'Баян-Өндөр',
        latitude: 49.0278,
        longitude: 104.0444,
      ),
    ],
  ),
];

const _organizationDetails = <OrganizationDetail>[
  OrganizationDetail(
    slug: 'auto-doctor',
    name: 'Auto Doctor Service',
    phone: '7700 1122',
    branches: [
      BranchDetail(
        id: 'auto-doctor-bzd',
        name: 'Баянзүрх салбар',
        address: 'Нарны зам 18',
        khoroo: '26-р хороо',
        city: 'Улаанбаатар',
        district: 'Баянзүрх',
        openTime: '09:00',
        closeTime: '19:00',
        latitude: 47.9187,
        longitude: 106.9684,
        // Cross-org "юу хийлгэх гэж байна?" урсгалыг (Booking tab) туршихад
        // зориулж — жагсаалт түвшний `serviceKeyIds: ['oil-change',
        // 'car-wash']`-тэй нийцүүлсэн.
        categories: [
          BranchServiceCategory(
            id: 'auto-doctor-bzd-oil-change',
            name: 'Тос солих',
            durationMinutes: 45,
            systemServiceKeyId: 'oil-change',
          ),
          BranchServiceCategory(
            id: 'auto-doctor-bzd-car-wash',
            name: 'Угаалга',
            durationMinutes: 60,
            systemServiceKeyId: 'car-wash',
          ),
        ],
      ),
      BranchDetail(
        id: 'auto-doctor-sbd',
        name: 'Сүхбаатар салбар',
        address: 'Олимпын гудамж 9',
        khoroo: '1-р хороо',
        city: 'Улаанбаатар',
        district: 'Сүхбаатар',
        openTime: '09:00',
        closeTime: '18:00',
      ),
    ],
  ),
  OrganizationDetail(
    slug: 'khurd-motors',
    name: 'Хурд Моторс',
    phone: '7505 2020',
    branches: [
      BranchDetail(
        id: 'khurd-khud',
        name: 'Яармаг салбар',
        address: 'Наадамчдын зам 42',
        khoroo: '8-р хороо',
        city: 'Улаанбаатар',
        district: 'Хан-Уул',
        openTime: '08:30',
        closeTime: '20:00',
        latitude: 47.8581,
        longitude: 106.7869,
      ),
    ],
  ),
  OrganizationDetail(
    slug: 'erdenet-car-care',
    name: 'Эрдэнэт Car Care',
    phone: '7035 4455',
    branches: [
      BranchDetail(
        id: 'erdenet-center',
        name: 'Төв салбар',
        address: 'Уурхайчин баг',
        khoroo: '',
        city: 'Орхон',
        district: 'Баян-Өндөр',
        openTime: '09:00',
        closeTime: '18:00',
        latitude: 49.0278,
        longitude: 104.0444,
      ),
    ],
  ),
];
