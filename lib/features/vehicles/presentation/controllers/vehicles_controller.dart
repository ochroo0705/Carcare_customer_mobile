import 'package:carcare_customer_mobile/core/errors/app_failure.dart';
import 'package:carcare_customer_mobile/data/cache/cache_store.dart';
import 'package:carcare_customer_mobile/features/vehicles/domain/vehicle_repository.dart';
import 'package:carcare_customer_mobile/features/vehicles/presentation/controllers/vehicles_state.dart';
import 'package:flutter/foundation.dart';

class VehiclesController extends ChangeNotifier {
  VehiclesController(this._repository, {CacheStore? cache})
    : _cache = cache ?? const NoopCacheStore();

  final VehicleRepository _repository;
  final CacheStore _cache;
  VehiclesState _state = const VehiclesState();
  final Set<String> _deletingIds = {};
  final Set<String> _refreshingIds = {};

  /// `delete()` triggers its own `load()` on top of a possible manual
  /// refresh, so calls can overlap — without this, a slower call finishing
  /// after a faster one can silently overwrite state it already moved past
  /// (e.g. a delete's reload landing before, then getting clobbered by, a
  /// stale concurrent refresh that started earlier and doesn't reflect the
  /// deletion). Incremented at the start of every `load()`; only the call
  /// that is still the latest may apply.
  int _loadRequestId = 0;

  // True while the list on screen came from a successful network load (not
  // the disk cache); a failed refresh then keeps it instead of falling back.
  bool _hasLiveData = false;

  VehiclesState get state => _state;

  bool isDeleting(String id) => _deletingIds.contains(id);

  bool isRefreshing(String id) => _refreshingIds.contains(id);

  Future<void> load() async {
    final requestId = ++_loadRequestId;
    _state = VehiclesState(
      status: VehiclesStatus.loading,
      vehicles: _state.vehicles,
    );
    notifyListeners();
    VehiclesState result;
    try {
      final vehicles = await _repository.getVehicles();
      // A superseded or post-sign-out load must not write the cache either.
      if (requestId != _loadRequestId) return;
      result = VehiclesState(
        status: vehicles.isEmpty ? VehiclesStatus.empty : VehiclesStatus.data,
        vehicles: vehicles,
      );
      await _cache.writeVehicles(vehicles);
    } on AppFailure catch (failure) {
      result = await _resultAfterFailure(failure.message);
    } catch (_) {
      result = await _resultAfterFailure('Тодорхойгүй алдаа гарлаа.');
    }
    if (requestId != _loadRequestId) return;
    _hasLiveData = result.status == VehiclesStatus.data && !result.isFromCache;
    _state = result;
    notifyListeners();
  }

  /// Resets to the initial state and clears the on-disk cache, e.g. after
  /// the customer signs out — the next account must never see this one's
  /// cached vehicles.
  Future<void> reset() async {
    _loadRequestId++;
    _hasLiveData = false;
    _state = const VehiclesState();
    _deletingIds.clear();
    _refreshingIds.clear();
    notifyListeners();
    await _cache.clearVehicles();
  }

  Future<VehiclesState> _resultAfterFailure(String failureMessage) async {
    if (_hasLiveData) {
      return VehiclesState(
        status: VehiclesStatus.data,
        vehicles: _state.vehicles,
        message: failureMessage,
      );
    }
    return _fallbackToCache(failureMessage);
  }

  Future<VehiclesState> _fallbackToCache(String failureMessage) async {
    final cached = await _cache.readVehicles();
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

  /// Машины дэлгэрэнгүй дэлгэцээс гар аргаар HUR-аас дахин татна — амжилттай
  /// бол `_state.vehicles` доторх тухайн машиныг шинэ утгаар СОЛИНО (жагсаалт
  /// дахин ачаалахгүй), алдаатай бол мессежийг буцаана.
  Future<String?> refresh(String id) async {
    if (_refreshingIds.contains(id)) return null;
    _refreshingIds.add(id);
    notifyListeners();
    final requestId = _loadRequestId;
    try {
      final updated = await _repository.refreshFromHur(id);
      // A load or reset that ran meanwhile owns the state (and the cache).
      if (requestId != _loadRequestId) return null;
      _state = VehiclesState(
        status: _state.status,
        vehicles: [
          for (final v in _state.vehicles)
            if (v.id == id) updated else v,
        ],
        message: _state.message,
        isFromCache: _state.isFromCache,
      );
      await _cache.writeVehicles(_state.vehicles);
      return null;
    } on AppFailure catch (failure) {
      return failure.message;
    } catch (_) {
      return 'Тодорхойгүй алдаа гарлаа.';
    } finally {
      _refreshingIds.remove(id);
      notifyListeners();
    }
  }
}
