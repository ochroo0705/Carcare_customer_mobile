import 'package:carcare_customer_mobile/core/errors/app_failure.dart';
import 'package:carcare_customer_mobile/data/cache/cache_store.dart';
import 'package:carcare_customer_mobile/features/history/domain/service_history_repository.dart';
import 'package:carcare_customer_mobile/features/history/presentation/controllers/history_state.dart';
import 'package:flutter/foundation.dart';

class HistoryController extends ChangeNotifier {
  HistoryController(this._repository, {CacheStore? cache})
    : _cache = cache ?? const NoopCacheStore();

  final ServiceHistoryRepository _repository;
  final CacheStore _cache;
  HistoryState _state = const HistoryState();

  HistoryState get state => _state;

  Future<void> load() async {
    _state = HistoryState(status: HistoryStatus.loading, orders: _state.orders);
    notifyListeners();
    try {
      final orders = (await _repository.getServiceHistory()).toList()
        ..sort((a, b) => b.completedAt.compareTo(a.completedAt));
      _state = HistoryState(
        status: orders.isEmpty ? HistoryStatus.empty : HistoryStatus.data,
        orders: orders,
      );
      await _cache.writeServiceOrders(orders);
    } on AppFailure catch (failure) {
      _state = await _fallbackToCache(failure.message);
    } catch (_) {
      _state = await _fallbackToCache('Тодорхойгүй алдаа гарлаа.');
    }
    notifyListeners();
  }

  /// Resets to the initial state and clears the on-disk cache, e.g. after
  /// the customer signs out — the next account must never see this one's
  /// cached service history.
  Future<void> reset() async {
    _state = const HistoryState();
    notifyListeners();
    await _cache.clearServiceOrders();
  }

  Future<HistoryState> _fallbackToCache(String failureMessage) async {
    final cached = await _cache.readServiceOrders();
    if (cached == null || cached.isEmpty) {
      return HistoryState(status: HistoryStatus.error, message: failureMessage);
    }
    return HistoryState(
      status: HistoryStatus.data,
      orders: cached,
      isFromCache: true,
      message: failureMessage,
    );
  }
}
