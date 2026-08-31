import 'package:carcare_customer_mobile/core/errors/app_failure.dart';
import 'package:carcare_customer_mobile/features/booking/domain/bookable_service.dart';
import 'package:carcare_customer_mobile/features/booking/domain/service_catalog.dart';
import 'package:carcare_customer_mobile/features/booking/domain/service_category.dart';
import 'package:carcare_customer_mobile/features/booking/domain/service_repository.dart';

enum FakeServiceScenario { data, empty, error }

class FakeServiceRepository implements ServiceRepository {
  FakeServiceRepository({
    this.scenario = FakeServiceScenario.data,
    this.delay = const Duration(milliseconds: 350),
  });

  final FakeServiceScenario scenario;
  final Duration delay;

  @override
  Future<ServiceCatalog> getServicesForBranch(String branchId) async {
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    return switch (scenario) {
      FakeServiceScenario.data => _catalogFor(branchId),
      FakeServiceScenario.empty => const ServiceCatalog(
        categories: [],
        services: [],
      ),
      FakeServiceScenario.error => throw const ServerFailure(
        'Үйлчилгээний мэдээллийг ачаалж чадсангүй.',
      ),
    };
  }
}

const _categories = <ServiceCategory>[
  ServiceCategory(
    id: 'maintenance',
    name: 'Тогтмол үйлчилгээ',
    description: 'Машины хэвийн ажиллагааг хадгалах үндсэн үйлчилгээнүүд',
  ),
  ServiceCategory(
    id: 'diagnostics',
    name: 'Оношилгоо',
    description: 'Гэмтэл, анхааруулах дохионы шалтгааныг тодорхойлох',
  ),
  ServiceCategory(
    id: 'tires',
    name: 'Дугуй',
    description: 'Дугуйн угсралт, баланс болон улирлын үйлчилгээ',
  ),
];

const _services = <BookableService>[
  BookableService(
    id: 'oil-change',
    categoryId: 'maintenance',
    name: 'Тос, тосны шүүлтүүр солих',
    description: 'Хөдөлгүүрийн тос болон тосны шүүлтүүрийн иж бүрэн солилт',
    durationMinutes: 45,
    price: 85000,
  ),
  BookableService(
    id: 'full-inspection',
    categoryId: 'maintenance',
    name: 'Ерөнхий үзлэг',
    description: 'Шингэн, гэрэл, явах эд анги болон аюулгүй байдлын шалгалт',
    durationMinutes: 60,
    price: 65000,
  ),
  BookableService(
    id: 'computer-diagnostics',
    categoryId: 'diagnostics',
    name: 'Компьютер оношилгоо',
    description: 'Алдааны код уншиж, үндсэн системүүдийг шалгана',
    durationMinutes: 40,
    price: 50000,
  ),
  BookableService(
    id: 'brake-diagnostics',
    categoryId: 'diagnostics',
    name: 'Тоормосны оношилгоо',
    description: 'Наклад, диск, шингэн болон тоормосны ажиллагааны шалгалт',
    durationMinutes: 35,
    price: 40000,
  ),
  BookableService(
    id: 'tire-change',
    categoryId: 'tires',
    name: '4 дугуй солих',
    description: 'Дугуй буулгах, угсрах болон даралт тохируулах',
    durationMinutes: 60,
    price: 80000,
  ),
  BookableService(
    id: 'wheel-balance',
    categoryId: 'tires',
    name: 'Дугуй баланс',
    description: 'Дөрвөн дугуйн баланс тохируулна',
    durationMinutes: 45,
    price: 60000,
  ),
];

ServiceCatalog _catalogFor(String branchId) {
  // Dummy branch scoping mirrors the web rule: some categories are available
  // everywhere, while others can be limited to selected branches.
  final excludedCategories = switch (branchId) {
    'auto-doctor-sbd' => const {'tires'},
    'erdenet-center' => const {'diagnostics'},
    _ => const <String>{},
  };
  final categories = _categories
      .where((category) => !excludedCategories.contains(category.id))
      .toList(growable: false);
  final categoryIds = categories.map((category) => category.id).toSet();
  return ServiceCatalog(
    categories: categories,
    services: _services
        .where((service) => categoryIds.contains(service.categoryId))
        .toList(growable: false),
  );
}
