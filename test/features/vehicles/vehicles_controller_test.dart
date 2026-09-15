import 'dart:async';

import 'package:carcare_customer_mobile/features/vehicles/data/fake_vehicle_repository.dart';
import 'package:carcare_customer_mobile/features/vehicles/domain/vehicle.dart';
import 'package:carcare_customer_mobile/features/vehicles/domain/vehicle_lookup_result.dart';
import 'package:carcare_customer_mobile/features/vehicles/domain/vehicle_repository.dart';
import 'package:carcare_customer_mobile/features/vehicles/presentation/controllers/vehicles_controller.dart';
import 'package:carcare_customer_mobile/features/vehicles/presentation/controllers/vehicles_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Lets a test control exactly when each `getVehicles` call resolves, to
/// reproduce out-of-order responses (e.g. a manual refresh's `load()`
/// resolving after a `delete()`-triggered `load()` that started later).
class _RaceVehicleRepository implements VehicleRepository {
  final List<Completer<List<Vehicle>>> completers = [];

  @override
  Future<List<Vehicle>> getVehicles() {
    final completer = Completer<List<Vehicle>>();
    completers.add(completer);
    return completer.future;
  }

  @override
  Future<Vehicle> addVehicle({
    required String plate,
    required String make,
    required String model,
    int? year,
    String? vin,
    String? fuelType,
    String? wheelPosition,
    String? colorName,
    int? capacity,
    String? purpose,
  }) async => throw UnimplementedError();

  @override
  Future<void> deleteVehicle(String id) async {}

  @override
  Future<VehicleLookupResult> lookupByPlate(String plate) async =>
      throw UnimplementedError();

  @override
  Future<Vehicle> refreshFromHur(String id) async => throw UnimplementedError();
}

Vehicle _vehicle(String id) =>
    Vehicle(id: id, plate: id, make: 'Toyota', model: 'Prius');

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

  test('ignores a stale load() response that arrives after a newer one '
      '(e.g. a manual refresh racing a delete-triggered reload)', () async {
    final repository = _RaceVehicleRepository();
    final controller = VehiclesController(repository);

    // Two overlapping loads: the first mirrors a manual refresh that
    // started first but is slow; the second mirrors the reload triggered
    // right after by a delete.
    unawaited(controller.load());
    final second = controller.load();
    expect(repository.completers, hasLength(2));

    // The SECOND (newer) call's response arrives first...
    repository.completers[1].complete([_vehicle('newer')]);
    await second;
    // ...then the stale first call's response arrives late.
    repository.completers[0].complete([_vehicle('older')]);
    await Future<void>.delayed(Duration.zero);

    // The stale response must not clobber the newer result.
    expect(controller.state.vehicles.single.id, 'newer');
  });
}
