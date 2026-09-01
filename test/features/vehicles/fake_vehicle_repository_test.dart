import 'package:carcare_customer_mobile/core/errors/app_failure.dart';
import 'package:carcare_customer_mobile/features/vehicles/data/fake_vehicle_repository.dart';
import 'package:carcare_customer_mobile/features/vehicles/domain/vehicle_lookup_result.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('adds a vehicle and it appears in the list', () async {
    final repository = FakeVehicleRepository();

    final added = await repository.addVehicle(
      plate: '5678УБВ',
      make: 'Hyundai',
      model: 'Sonata',
      year: 2020,
    );

    final vehicles = await repository.getVehicles();
    expect(vehicles.map((v) => v.id), contains(added.id));
    expect(vehicles, hasLength(2));
  });

  test('rejects a duplicate plate with a conflict failure', () async {
    final repository = FakeVehicleRepository();

    expect(
      () => repository.addVehicle(
        plate: '9911УБЕ',
        make: 'Hyundai',
        model: 'Sonata',
      ),
      throwsA(isA<ConflictFailure>()),
    );
  });

  test('looks up a known plate as a global-source hit', () async {
    final repository = FakeVehicleRepository();

    final result = await repository.lookupByPlate('1234УБА');

    expect(result.source, VehicleLookupSource.global);
    expect(result.make, 'Toyota');
  });

  test('looks up an unknown plate as a HUR-source hit', () async {
    final repository = FakeVehicleRepository();

    final result = await repository.lookupByPlate('9999УБГ');

    expect(result.source, VehicleLookupSource.hur);
  });
}
