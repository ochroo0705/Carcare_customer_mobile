import 'package:carcare_customer_mobile/core/errors/app_failure.dart';
import 'package:carcare_customer_mobile/features/vehicles/data/vehicle_dto.dart';
import 'package:carcare_customer_mobile/features/vehicles/domain/vehicle_lookup_result.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses a vehicle list entry matching the published contract', () {
    final vehicle = VehicleDto.fromJson({
      'id': 'veh-1',
      'plate': '1234УБА',
      'make': 'Toyota',
      'model': 'Prius',
      'year': 2018,
      'vin': 'VIN123',
    }).toDomain();

    expect(vehicle.id, 'veh-1');
    expect(vehicle.plate, '1234УБА');
    expect(vehicle.make, 'Toyota');
    expect(vehicle.model, 'Prius');
    expect(vehicle.year, 2018);
    expect(vehicle.vin, 'VIN123');
  });

  test('treats a missing year/vin as absent', () {
    final vehicle = VehicleDto.fromJson({
      'id': 'veh-2',
      'plate': '5678УБВ',
      'make': 'Hyundai',
      'model': 'Sonata',
    }).toDomain();

    expect(vehicle.year, isNull);
    expect(vehicle.vin, isNull);
  });

  test('throws on a malformed vehicle list', () {
    expect(
      () => parseVehicleListJson('not-a-list'),
      throwsA(isA<UnexpectedFailure>()),
    );
  });

  test('parses a HUR lookup response and maps source', () {
    final result = parseVehicleLookupJson({
      'vehicle': {
        'plate': '1234УБА',
        'make': 'Toyota',
        'model': 'Prius',
        'year': 2018,
        'vin': 'VIN123',
        'fuelType': 'Бензин',
        'wheelPosition': 'Зүүн',
        'colorName': 'Цагаан',
        'capacity': 1496,
        'purpose': 'Суудал',
      },
      'source': 'hur',
    });

    expect(result.source, VehicleLookupSource.hur);
    expect(result.colorName, 'Цагаан');
    expect(result.capacity, 1496);
  });

  test('defaults an unrecognized source to global', () {
    final result = parseVehicleLookupJson({
      'vehicle': {'plate': '1234УБА', 'make': 'Toyota', 'model': 'Prius'},
      'source': 'something-else',
    });

    expect(result.source, VehicleLookupSource.global);
  });

  test('throws when the lookup response has no vehicle object', () {
    expect(
      () => parseVehicleLookupJson({'source': 'global'}),
      throwsA(isA<UnexpectedFailure>()),
    );
  });
}
