import 'package:carcare_customer_mobile/features/booking/data/fake_service_repository.dart';
import 'package:carcare_customer_mobile/features/booking/presentation/controllers/service_selection_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('loads branch-scoped services and calculates selection totals', () async {
    final controller = ServiceSelectionController(
      FakeServiceRepository(delay: Duration.zero),
      'auto-doctor-sbd',
    );

    await controller.load();

    expect(controller.categories.map((item) => item.id), isNot(contains('tires')));
    expect(controller.services.map((item) => item.id), isNot(contains('tire-change')));

    controller.toggleService('oil-change');
    controller.toggleService('computer-diagnostics');

    expect(controller.selectedServices, hasLength(2));
    expect(controller.totalPrice, 135000);
    expect(controller.totalDurationMinutes, 85);
  });

  test('filters services by category without clearing the selection', () async {
    final controller = ServiceSelectionController(
      FakeServiceRepository(delay: Duration.zero),
      'auto-doctor-bzd',
    );

    await controller.load();
    controller.toggleService('oil-change');
    controller.selectCategory('diagnostics');

    expect(
      controller.visibleServices.every(
        (service) => service.categoryId == 'diagnostics',
      ),
      isTrue,
    );
    expect(controller.isSelected('oil-change'), isTrue);
  });

  test('exposes repository failures for retry UI', () async {
    final controller = ServiceSelectionController(
      FakeServiceRepository(
        scenario: FakeServiceScenario.error,
        delay: Duration.zero,
      ),
      'auto-doctor-bzd',
    );

    await controller.load();

    expect(controller.isLoading, isFalse);
    expect(controller.errorMessage, isNotNull);
  });
}
