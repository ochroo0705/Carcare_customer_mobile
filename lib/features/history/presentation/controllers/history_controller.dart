import 'dart:async';

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
  String _query = '';
  // "Бүх он" сонголт байхгүй — үргэлж тодорхой жил сонгогдсон байна, анхны
  // утга нь одоогийн жил.
  int _year = DateTime.now().year;
  Timer? _debounce;
  int _generation = 0;

  String get query => _query;
  int get year => _year;

  /// Жилийн сонголтод харуулах жагсаалт — серверээс ирсэн бодит өгөгдөлтэй
  /// жилүүд, одоогийн жил хэзээ ч дутахгүйн тулд түүнийг мөн эхэнд нэмнэ
  /// (тухайн жилд захиалга байхгүй байсан ч сонгогдсон хэвээр байх ёстой).
  List<int> get availableYears {
    final years = {_year, ..._state.availableYears}.toList()
      ..sort((a, b) => b.compareTo(a));
    return years;
  }

  bool get hasNextPage =>
      _state.pagination.hasNext || _state.cancelledPagination.hasNext;

  // Хайлт бичих зуур `_state`-ийг шууд цэвэрлэхгүй (өмнө нь ингэж байсан нь
  // status-ыг `initial`-руу шидэж, харагдаж буй жагсаалт/хайлтын мөрийг бүр
  // mount-оос нь хассан — гар товчлуур (keyboard) үсэг бүр дээр хаагдах
  // алдааны шалтгаан байсан). `load()` өөрөө debounce дууссаны дараа
  // status-оо `loading` болгоно; хайлтын мөр unmount болохгүй байхын тулд
  // `_AppointmentHistoryTab` (`history_screen.dart`) хайлтын мөрийг
  // switch-ийн гадна байрлуулсан.
  void setQuery(String value) {
    final trimmed = value.trim();
    if (_query == trimmed) return;
    _query = trimmed;
    _generation++;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), load);
  }

  void setYear(int value) {
    if (_year == value) return;
    _year = value;
    _generation++;
    load();
  }

  HistoryState get state => _state;

  Future<void> load({bool append = false}) async {
    if (append && (_state.isLoadingMore || !hasNextPage)) return;
    final generation = ++_generation;
    final requestedPage = append ? _state.page + 1 : 1;
    final filter = HistoryFilter(
      query: _query,
      year: _year,
      page: requestedPage,
    );
    if (append) {
      final existing = _state;
      _state = HistoryState(
        status: HistoryStatus.data,
        orders: existing.orders,
        cancelledAppointments: existing.cancelledAppointments,
        pagination: existing.pagination,
        cancelledPagination: existing.cancelledPagination,
        availableYears: existing.availableYears,
        isFromCache: existing.isFromCache,
        isLoadingMore: true,
        page: existing.page,
      );
    } else {
      _state = HistoryState(
        status: HistoryStatus.loading,
        orders: _state.orders,
        cancelledAppointments: _state.cancelledAppointments,
        availableYears: _state.availableYears,
      );
    }
    notifyListeners();
    try {
      final result = await _repository.getServiceHistory(filter: filter);
      if (generation != _generation) return;
      final orders = append
          ? [..._state.orders, ...result.orders]
          : result.orders;
      final cancelledAppointments = append
          ? [..._state.cancelledAppointments, ...result.cancelledAppointments]
          : result.cancelledAppointments;
      _state = HistoryState(
        status: orders.isEmpty && cancelledAppointments.isEmpty
            ? HistoryStatus.empty
            : HistoryStatus.data,
        orders: orders,
        cancelledAppointments: cancelledAppointments,
        pagination: result.pagination,
        cancelledPagination: result.cancelledPagination,
        availableYears: result.availableYears,
        page: requestedPage,
      );
      // "Шүүлтгүй" төлөв гэдгийг индикатор болгож кэшлэнэ — жил үргэлж
      // сонгогдсон байдаг тул одоогийн жилийг л анхны (default) төлөв гэж
      // үзнэ.
      if (!append && _query.isEmpty && _year == DateTime.now().year) {
        await _cache.writeServiceOrders(orders);
      }
    } on FeatureUnavailableFailure {
      if (generation != _generation) return;
      if (append) {
        _state = HistoryState(
          status: HistoryStatus.data,
          orders: _state.orders,
          cancelledAppointments: _state.cancelledAppointments,
          pagination: _state.pagination,
          cancelledPagination: _state.cancelledPagination,
          availableYears: _state.availableYears,
          page: _state.page,
        );
      } else {
        // Real API build: no History endpoint yet (D-014). Show an honest
        // "coming soon" state, not fake data or an error.
        _state = const HistoryState(status: HistoryStatus.unavailable);
      }
    } on AppFailure catch (failure) {
      if (generation != _generation) return;
      if (append) {
        _state = HistoryState(
          status: HistoryStatus.data,
          orders: _state.orders,
          cancelledAppointments: _state.cancelledAppointments,
          pagination: _state.pagination,
          cancelledPagination: _state.cancelledPagination,
          availableYears: _state.availableYears,
          loadMoreMessage: failure.message,
          page: _state.page,
        );
      } else {
        _state = await _fallbackToCache(failure.message);
      }
    } catch (_) {
      if (generation != _generation) return;
      if (append) {
        _state = HistoryState(
          status: HistoryStatus.data,
          orders: _state.orders,
          cancelledAppointments: _state.cancelledAppointments,
          pagination: _state.pagination,
          cancelledPagination: _state.cancelledPagination,
          availableYears: _state.availableYears,
          loadMoreMessage: 'Тодорхойгүй алдаа гарлаа.',
          page: _state.page,
        );
      } else {
        _state = await _fallbackToCache('Тодорхойгүй алдаа гарлаа.');
      }
    }
    notifyListeners();
  }

  Future<void> loadMore() => load(append: true);

  /// Resets to the initial state and clears the on-disk cache, e.g. after
  /// the customer signs out — the next account must never see this one's
  /// cached service history.
  Future<void> reset() async {
    _state = const HistoryState();
    _query = '';
    _year = DateTime.now().year;
    notifyListeners();
    await _cache.clearServiceOrders();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
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
