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
}

const _organizations = <Organization>[
  Organization(
    slug: 'auto-doctor',
    name: 'Auto Doctor Service',
    phone: '7700 1122',
    branches: [
      Branch(
        id: 'auto-doctor-bzd',
        name: 'Баянзүрх салбар',
        address: '26-р хороо, Нарны зам 18',
        city: 'Улаанбаатар',
        district: 'Баянзүрх',
        isOpen: true,
        hours: '09:00–19:00',
        latitude: 47.9187,
        longitude: 106.9684,
      ),
      Branch(
        id: 'auto-doctor-sbd',
        name: 'Сүхбаатар салбар',
        address: '1-р хороо, Олимпын гудамж 9',
        city: 'Улаанбаатар',
        district: 'Сүхбаатар',
        isOpen: false,
        hours: '09:00–18:00',
      ),
    ],
  ),
  Organization(
    slug: 'khurd-motors',
    name: 'Хурд Моторс',
    phone: '7505 2020',
    branches: [
      Branch(
        id: 'khurd-khud',
        name: 'Яармаг салбар',
        address: '8-р хороо, Наадамчдын зам 42',
        city: 'Улаанбаатар',
        district: 'Хан-Уул',
        isOpen: true,
        hours: '08:30–20:00',
        latitude: 47.8581,
        longitude: 106.7869,
      ),
    ],
  ),
  Organization(
    slug: 'erdenet-car-care',
    name: 'Эрдэнэт Car Care',
    phone: '7035 4455',
    branches: [
      Branch(
        id: 'erdenet-center',
        name: 'Төв салбар',
        address: 'Баян-Өндөр сум, Уурхайчин баг',
        city: 'Орхон',
        district: 'Баян-Өндөр',
        isOpen: true,
        hours: '09:00–18:00',
        latitude: 49.0278,
        longitude: 104.0444,
      ),
    ],
  ),
];
