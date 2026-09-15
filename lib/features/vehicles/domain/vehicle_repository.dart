import 'package:carcare_customer_mobile/features/vehicles/domain/vehicle.dart';
import 'package:carcare_customer_mobile/features/vehicles/domain/vehicle_lookup_result.dart';

abstract interface class VehicleRepository {
  Future<List<Vehicle>> getVehicles();

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
  });

  Future<void> deleteVehicle(String id);

  Future<VehicleLookupResult> lookupByPlate(String plate);

  /// Машины дэлгэрэнгүй дэлгэцээс гар аргаар HUR-аас дахин татаж, буцаасан
  /// шинэ (шинэчлэгдсэн) [Vehicle]-ийг буцаана. `id` = account-vehicle/link id
  /// (бусад бүх method-той адил).
  Future<Vehicle> refreshFromHur(String id);
}
