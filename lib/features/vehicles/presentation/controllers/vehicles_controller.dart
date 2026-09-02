import 'dart:convert';

import 'package:carcare_customer_mobile/core/errors/app_failure.dart';
import 'package:carcare_customer_mobile/features/vehicles/domain/vehicle.dart';
import 'package:carcare_customer_mobile/features/vehicles/domain/vehicle_repository.dart';
import 'package:carcare_customer_mobile/features/vehicles/presentation/controllers/vehicles_state.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class VehiclesController extends ChangeNotifier {
  VehiclesController(this._repository);

  static const _cacheKey = 'vehicles_cache_v1';

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
      await _saveCache(vehicles);
    } on AppFailure catch (failure) {
      _state = await _fallbackToCache(failure.message);
    } catch (_) {
      _state = await _fallbackToCache('Тодорхойгүй алдаа гарлаа.');
    }
    notifyListeners();
  }

  /// Resets to the initial state and clears the on-disk cache, e.g. after
  /// the customer signs out — the next account must never see this one's
  /// cached vehicles.
  Future<void> reset() async {
    _state = const VehiclesState();
    _deletingIds.clear();
    notifyListeners();
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.remove(_cacheKey);
    } catch (_) {
      // Best-effort — a stale cache is overwritten by the next load() anyway.
    }
  }

  Future<VehiclesState> _fallbackToCache(String failureMessage) async {
    final cached = await _readCache();
    if (cached == null || cached.isEmpty) {
      return VehiclesState(
        status: VehiclesStatus.error,
        message: failureMessage,
      );
    }
    return VehiclesState(
      status: VehiclesStatus.data,
      vehicles: cached,
      isFromCache: true,
      message: failureMessage,
    );
  }

  Future<void> _saveCache(List<Vehicle> vehicles) async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final json = jsonEncode(vehicles.map(_vehicleToJson).toList());
      await preferences.setString(_cacheKey, json);
    } catch (_) {
      // Persisting the cache is a best-effort convenience; a write failure
      // here must never surface as a load failure.
    }
  }

  Future<List<Vehicle>?> _readCache() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final raw = preferences.getString(_cacheKey);
      if (raw == null) return null;
      final decoded = jsonDecode(raw);
      if (decoded is! List) return null;
      final vehicles = decoded
          .map(_vehicleFromJson)
          .whereType<Vehicle>()
          .toList();
      return vehicles.isEmpty ? null : vehicles;
    } catch (_) {
      return null;
    }
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

Map<String, dynamic> _vehicleToJson(Vehicle vehicle) => {
  'id': vehicle.id,
  'plate': vehicle.plate,
  'make': vehicle.make,
  'model': vehicle.model,
  'year': vehicle.year,
  'vin': vehicle.vin,
};

Vehicle? _vehicleFromJson(Object? value) {
  if (value is! Map) return null;
  final id = value['id'];
  final plate = value['plate'];
  final make = value['make'];
  final model = value['model'];
  if (id is! String || plate is! String || make is! String || model is! String) {
    return null;
  }
  return Vehicle(
    id: id,
    plate: plate,
    make: make,
    model: model,
    year: value['year'] is num ? (value['year'] as num).toInt() : null,
    vin: value['vin'] is String ? value['vin'] as String : null,
  );
}
