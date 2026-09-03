import 'package:carcare_customer_mobile/core/errors/app_failure.dart';
import 'package:carcare_customer_mobile/features/vehicles/domain/vehicle.dart';
import 'package:carcare_customer_mobile/features/vehicles/domain/vehicle_lookup_result.dart';

class VehicleDto {
  VehicleDto({
    required this.id,
    required this.plate,
    required this.make,
    required this.model,
    this.year,
    this.vin,
  });

  factory VehicleDto.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final plate = _requiredString(json, 'plate');
    final make = _requiredString(json, 'make');
    final model = _requiredString(json, 'model');
    if (id is! String) {
      throw const UnexpectedFailure(
        'Тээврийн хэрэгслийн мэдээлэл буруу байна.',
      );
    }
    return VehicleDto(
      id: id,
      plate: plate,
      make: make,
      model: model,
      year: _optionalInt(json['year']),
      vin: _optionalString(json['vin']),
    );
  }

  final String id;
  final String plate;
  final String make;
  final String model;
  final int? year;
  final String? vin;

  Vehicle toDomain() => Vehicle(
    id: id,
    plate: plate,
    make: make,
    model: model,
    year: year,
    vin: vin,
  );
}

List<VehicleDto> parseVehicleListJson(Object? value) {
  if (value is! List) {
    throw const UnexpectedFailure('Тээврийн хэрэгслийн жагсаалт буруу байна.');
  }
  return value
      .map((item) {
        if (item is! Map) {
          throw const UnexpectedFailure(
            'Тээврийн хэрэгслийн өгөгдөл буруу байна.',
          );
        }
        return VehicleDto.fromJson(Map<String, dynamic>.from(item));
      })
      .toList(growable: false);
}

VehicleLookupResult parseVehicleLookupJson(Map<String, dynamic> json) {
  final vehicle = json['vehicle'];
  if (vehicle is! Map) {
    throw const UnexpectedFailure('Хайлтын хариу буруу байна.');
  }
  final map = Map<String, dynamic>.from(vehicle);
  final source = json['source'] == 'hur'
      ? VehicleLookupSource.hur
      : VehicleLookupSource.global;
  // HUR fields are all nullable server-side (`HurVehicle.plate/make/model:
  // string | null`) — a plate can be registered with make/model missing.
  // Default the blanks to '' so the lookup autofills what it can and the
  // customer completes the rest, rather than failing the whole lookup.
  return VehicleLookupResult(
    plate: _optionalString(map['plate']) ?? '',
    make: _optionalString(map['make']) ?? '',
    model: _optionalString(map['model']) ?? '',
    source: source,
    year: _optionalInt(map['year']),
    vin: _optionalString(map['vin']),
    fuelType: _optionalString(map['fuelType']),
    wheelPosition: _optionalString(map['wheelPosition']),
    colorName: _optionalString(map['colorName']),
    capacity: _optionalInt(map['capacity']),
    purpose: _optionalString(map['purpose']),
  );
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = _optionalString(json[key]);
  if (value == null) throw UnexpectedFailure('API талбар буруу байна: $key');
  return value;
}

String? _optionalString(Object? value) {
  if (value is! String || value.trim().isEmpty) return null;
  return value.trim();
}

int? _optionalInt(Object? value) => value is num ? value.toInt() : null;
