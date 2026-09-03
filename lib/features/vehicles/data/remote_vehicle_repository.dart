import 'package:carcare_customer_mobile/core/errors/app_failure.dart';
import 'package:carcare_customer_mobile/core/network/api_client.dart';
import 'package:carcare_customer_mobile/features/vehicles/data/vehicle_dto.dart';
import 'package:carcare_customer_mobile/features/vehicles/domain/vehicle.dart';
import 'package:carcare_customer_mobile/features/vehicles/domain/vehicle_lookup_result.dart';
import 'package:carcare_customer_mobile/features/vehicles/domain/vehicle_repository.dart';

/// Account-ийн vehicle болон HUR lookup endpoint-үүдийн adapter.
///
/// `id` нь global vehicle биш AccountVehicle link-ийн id бөгөөд delete болон
/// appointment create-д яг энэ утгыг буцааж хэрэглэнэ.
class RemoteVehicleRepository implements VehicleRepository {
  RemoteVehicleRepository(this._client);

  final ApiClient _client;

  @override
  /// Нэвтэрсэн Account-ийн хадгалсан машинуудыг уншина.
  Future<List<Vehicle>> getVehicles() async {
    final json = await _client.getJson('/vehicles');
    return parseVehicleListJson(json['vehicles'])
        .map((dto) => dto.toDomain())
        .toList(growable: false);
  }

  @override
  /// API-ийн шаардлагатай plate/make/model-г явуулж, optional талбаруудыг
  /// хоосон үед payload-д оруулахгүй.
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
  /// HUR/global lookup нь owner-ийн хувийн мэдээлэл буцаадаггүй; зөвхөн
  /// vehicle autofill-д хэрэгтэй техникийн талбаруудыг ашиглана.
  Future<VehicleLookupResult> lookupByPlate(String plate) async {
    final json = await _client.getJson(
      '/hur/lookup?plate=${Uri.encodeQueryComponent(plate)}',
    );
    return parseVehicleLookupJson(json);
  }
}
