import 'package:carcare_customer_mobile/core/errors/app_failure.dart';
import 'package:carcare_customer_mobile/features/vehicles/domain/vehicle_repository.dart';
import 'package:carcare_customer_mobile/features/vehicles/presentation/controllers/vehicles_state.dart';
import 'package:flutter/foundation.dart';

class VehiclesController extends ChangeNotifier {
  VehiclesController(this._repository);

  final VehicleRepository _repository;
  VehiclesState _state = const VehiclesState();
  final Set<String> _deletingIds = {};

  VehiclesState get state => _state;

  bool isDeleting(String id) => _deletingIds.contains(id);

  Future<void> load() async {
    _state = VehiclesState(
      status: VehiclesStatus.loading,
      vehicles: _state.vehicles,
    );
    notifyListeners();
    try {
      final vehicles = await _repository.getVehicles();
      _state = VehiclesState(
        status: vehicles.isEmpty ? VehiclesStatus.empty : VehiclesStatus.data,
        vehicles: vehicles,
      );
    } on AppFailure catch (failure) {
      _state = VehiclesState(
        status: VehiclesStatus.error,
        message: failure.message,
      );
    } catch (_) {
      _state = const VehiclesState(
        status: VehiclesStatus.error,
        message: 'Тодорхойгүй алдаа гарлаа.',
      );
    }
    notifyListeners();
  }

  /// Resets to the initial state, e.g. after the customer signs out.
  void reset() {
    _state = const VehiclesState();
    _deletingIds.clear();
    notifyListeners();
  }

  /// Deletes a vehicle and reloads the list. Returns an error message on
  /// failure, or `null` on success.
  Future<String?> delete(String id) async {
    if (_deletingIds.contains(id)) return null;
    _deletingIds.add(id);
    notifyListeners();
    try {
      await _repository.deleteVehicle(id);
      await load();
      return null;
    } on AppFailure catch (failure) {
      return failure.message;
    } catch (_) {
      return 'Тодорхойгүй алдаа гарлаа.';
    } finally {
      _deletingIds.remove(id);
      notifyListeners();
    }
  }
}
