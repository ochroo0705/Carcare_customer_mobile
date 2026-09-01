import 'package:carcare_customer_mobile/core/errors/app_failure.dart';
import 'package:carcare_customer_mobile/features/vehicles/domain/vehicle.dart';
import 'package:carcare_customer_mobile/features/vehicles/domain/vehicle_lookup_result.dart';
import 'package:carcare_customer_mobile/features/vehicles/domain/vehicle_repository.dart';

class FakeVehicleRepository implements VehicleRepository {
  final List<Vehicle> _vehicles = [
    const Vehicle(
      id: 'seed-vehicle-1',
      plate: '9911УБЕ',
      make: 'Hyundai',
      model: 'Sonata',
      year: 2019,
    ),
  ];
  var _sequence = 0;

  @override
  Future<List<Vehicle>> getVehicles() async => List.unmodifiable(_vehicles);

  @override
  Future<Vehicle> addVehicle({
    required String plate,
    required String make,
    required String model,
    int? year,
    String? vin,
    String? fuelType,
    String? wheelPosition,
  }) async {
    final normalizedPlate = plate.trim().toUpperCase();
    if (_vehicles.any(
      (vehicle) => vehicle.plate.toUpperCase() == normalizedPlate,
    )) {
      throw const ConflictFailure(
        'Энэ дугаартай тээврийн хэрэгсэл бүртгэлтэй байна.',
      );
    }
    _sequence += 1;
    final vehicle = Vehicle(
      id: 'fake-vehicle-$_sequence',
      plate: plate.trim(),
      make: make.trim(),
      model: model.trim(),
      year: year,
      vin: vin,
    );
    _vehicles.add(vehicle);
    return vehicle;
  }

  @override
  Future<void> deleteVehicle(String id) async {
    final index = _vehicles.indexWhere((vehicle) => vehicle.id == id);
    if (index == -1) throw const NotFoundFailure();
    _vehicles.removeAt(index);
  }

  @override
  Future<VehicleLookupResult> lookupByPlate(String plate) async {
    final normalizedPlate = plate.trim().toUpperCase();
    if (normalizedPlate == '1234УБА') {
      return const VehicleLookupResult(
        plate: '1234УБА',
        make: 'Toyota',
        model: 'Prius',
        source: VehicleLookupSource.global,
        year: 2018,
        fuelType: 'Бензин',
        wheelPosition: 'Зүүн',
        colorName: 'Цагаан',
        capacity: 1496,
        purpose: 'Суудал',
      );
    }
    return VehicleLookupResult(
      plate: plate.trim(),
      make: 'Тодорхойгүй',
      model: 'Тодорхойгүй',
      source: VehicleLookupSource.hur,
      fuelType: 'Бензин',
      purpose: 'Суудал',
    );
  }
}
