import 'package:carcare_customer_mobile/core/errors/app_failure.dart';
import 'package:carcare_customer_mobile/core/network/api_client.dart';
import 'package:carcare_customer_mobile/features/vehicles/data/vehicle_dto.dart';
import 'package:carcare_customer_mobile/features/vehicles/domain/vehicle.dart';
import 'package:carcare_customer_mobile/features/vehicles/domain/vehicle_lookup_result.dart';
import 'package:carcare_customer_mobile/features/vehicles/domain/vehicle_repository.dart';

class RemoteVehicleRepository implements VehicleRepository {
  RemoteVehicleRepository(this._client);

  final ApiClient _client;

  @override
  Future<List<Vehicle>> getVehicles() async {
    final json = await _client.getJson('/vehicles');
    return parseVehicleListJson(json['vehicles'])
        .map((dto) => dto.toDomain())
        .toList(growable: false);
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
  }) async {
    final json = await _client.postJson('/vehicles', {
      'plate': plate,
      'make': make,
      'model': model,
      'year': ?year,
      if (vin != null && vin.trim().isNotEmpty) 'vin': vin.trim(),
      if (fuelType != null && fuelType.trim().isNotEmpty)
        'fuelType': fuelType.trim(),
      if (wheelPosition != null && wheelPosition.trim().isNotEmpty)
        'wheelPosition': wheelPosition.trim(),
    });
    final value = json['vehicle'];
    if (value is! Map) {
      throw const UnexpectedFailure('Тээврийн хэрэгслийн хариу буруу байна.');
    }
    return VehicleDto.fromJson(Map<String, dynamic>.from(value)).toDomain();
  }

  @override
  Future<void> deleteVehicle(String id) async {
    final json = await _client.deleteJson('/vehicles/$id');
    if (json['ok'] != true) {
      throw const UnexpectedFailure('Тээврийн хэрэгсэл устгагдсангүй.');
    }
  }

  @override
  Future<VehicleLookupResult> lookupByPlate(String plate) async {
    final json = await _client.getJson(
      '/hur/lookup?plate=${Uri.encodeQueryComponent(plate)}',
    );
    return parseVehicleLookupJson(json);
  }
}
