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
  Future<List<Organization>> getOrganizations() async {
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    return switch (scenario) {
      FakeOrganizationScenario.data => _organizations,
      FakeOrganizationScenario.empty => const [],
      FakeOrganizationScenario.error => throw const ServerFailure(
        'Авто сервисүүдийг ачаалж чадсангүй.',
      ),
    };
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
      ),
      Branch(
        id: 'auto-doctor-sbd',
        name: 'Сүхбаатар салбар',
        city: 'Улаанбаатар',
        district: 'Сүхбаатар',
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
