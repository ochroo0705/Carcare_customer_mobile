import 'package:carcare_customer_mobile/features/vehicles/domain/vehicle.dart';

enum VehiclesStatus { initial, loading, data, empty, error }

class VehiclesState {
  const VehiclesState({
    this.status = VehiclesStatus.initial,
    this.vehicles = const [],
    this.message,
  });

  final VehiclesStatus status;
  final List<Vehicle> vehicles;
  final String? message;

  bool get isLoading =>
      status == VehiclesStatus.initial || status == VehiclesStatus.loading;
}
