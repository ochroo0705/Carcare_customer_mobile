import 'package:carcare_customer_mobile/features/vehicles/domain/vehicle.dart';

enum VehiclesStatus { initial, loading, data, empty, error }

class VehiclesState {
  const VehiclesState({
    this.status = VehiclesStatus.initial,
    this.vehicles = const [],
    this.message,
    this.isFromCache = false,
  });

  final VehiclesStatus status;
  final List<Vehicle> vehicles;
  final String? message;

  /// True when [vehicles] is the last successfully loaded list, shown
  /// because a fresh load just failed (e.g. no network) rather than because
  /// it is currently up to date.
  final bool isFromCache;

  bool get isLoading =>
      status == VehiclesStatus.initial || status == VehiclesStatus.loading;
}
