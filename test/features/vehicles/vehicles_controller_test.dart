import 'package:carcare_customer_mobile/features/vehicles/data/fake_vehicle_repository.dart';
import 'package:carcare_customer_mobile/features/vehicles/presentation/controllers/vehicles_controller.dart';
import 'package:carcare_customer_mobile/features/vehicles/presentation/controllers/vehicles_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('loads the seeded vehicle', () async {
    final controller = VehiclesController(FakeVehicleRepository());

    await controller.load();

    expect(controller.state.status, VehiclesStatus.data);
    expect(controller.state.vehicles.single.plate, '9911УБЕ');
  });

  test('deletes a vehicle and reloads', () async {
    final controller = VehiclesController(FakeVehicleRepository());
    await controller.load();
    final target = controller.state.vehicles.single;

    final error = await controller.delete(target.id);

    expect(error, isNull);
    expect(controller.state.status, VehiclesStatus.empty);
  });

  test(
    'returns an error message instead of throwing for an unknown id',
    () async {
      final controller = VehiclesController(FakeVehicleRepository());
      await controller.load();

      final error = await controller.delete('does-not-exist');

      expect(error, isNotNull);
    },
  );

  test('reset returns to the initial state', () async {
    final controller = VehiclesController(FakeVehicleRepository());
    await controller.load();
    expect(controller.state.status, VehiclesStatus.data);

    controller.reset();

    expect(controller.state.status, VehiclesStatus.initial);
    expect(controller.state.vehicles, isEmpty);
  });
}
