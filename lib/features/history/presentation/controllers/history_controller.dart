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

  // True while the lists on screen came from a successful network load (not
  // the disk cache). A failed refresh must then keep them rather than swap
  // them for an older cached copy or an error screen.
  bool _hasLiveData = false;

  // Year + query the live orders were loaded for. Live data is only kept on a
  // failed refresh when it belongs to the CURRENT filter; otherwise the
  // previous filter's rows would show under the new year/query.
  String? _liveFilterKey;

  String get _filterKey => '$_year|$_query';

  // True from the moment the query changes until the debounced reload lands,
  // so the screen can tell that the visible list is for the previous query.
  bool _resultsStale = false;

  String get query => _query;
  int get year => _year;
  bool get resultsStale => _resultsStale;

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
    _resultsStale = true;
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
      // Both lists share one `page` parameter, but each has its own
      // pagination. A list that already ended is clamped by the server to its
      // last page, so appending it again would duplicate rows: only extend a
      // list whose previous page said it had a next one.
      final extendOrders = append && _state.pagination.hasNext;
      final extendCancelled = append && _state.cancelledPagination.hasNext;
      final orders = extendOrders
          ? [..._state.orders, ...result.orders]
          : append
          ? _state.orders
          : result.orders;
      final cancelledAppointments = extendCancelled
          ? [..._state.cancelledAppointments, ...result.cancelledAppointments]
          : append
          ? _state.cancelledAppointments
          : result.cancelledAppointments;
      final pagination = append && !extendOrders
          ? _state.pagination
          : result.pagination;
      final cancelledPagination = append && !extendCancelled
          ? _state.cancelledPagination
          : result.cancelledPagination;
      _state = HistoryState(
        status: orders.isEmpty && cancelledAppointments.isEmpty
            ? HistoryStatus.empty
            : HistoryStatus.data,
        orders: orders,
        cancelledAppointments: cancelledAppointments,
        pagination: pagination,
        cancelledPagination: cancelledPagination,
        availableYears: result.availableYears,
        page: requestedPage,
      );
      _hasLiveData = _state.status == HistoryStatus.data;
      _liveFilterKey = _filterKey;
      _resultsStale = false;
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
        _hasLiveData = false;
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
        if (_keepLiveData(failure.message)) {
          notifyListeners();
          return;
        }
        final fallback = await _fallbackToCache(failure.message);
        if (generation != _generation) return;
        _state = fallback;
        _hasLiveData = false;
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
        if (_keepLiveData('Тодорхойгүй алдаа гарлаа.')) {
          notifyListeners();
          return;
        }
        final fallback = await _fallbackToCache('Тодорхойгүй алдаа гарлаа.');
        if (generation != _generation) return;
        _state = fallback;
        _hasLiveData = false;
      }
    }
    _resultsStale = false;
    notifyListeners();
  }

  Future<void> loadMore() => load(append: true);

  /// Resets to the initial state and clears the on-disk cache, e.g. after
  /// the customer signs out — the next account must never see this one's
  /// cached service history.
  Future<void> reset() async {
    // Invalidates a load still in flight, so it can't restore this
    // account's orders (state or disk cache) after sign-out.
    _generation++;
    _hasLiveData = false;
    _liveFilterKey = null;
    _resultsStale = false;
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

  /// Keeps the live lists on screen after a failed refresh; returns false
  /// when nothing live is showing and the cache/error fallback should apply.
  bool _keepLiveData(String failureMessage) {
    if (!_hasLiveData || _liveFilterKey != _filterKey) return false;
    _resultsStale = false;
    _state = HistoryState(
      status: HistoryStatus.data,
      orders: _state.orders,
      cancelledAppointments: _state.cancelledAppointments,
      pagination: _state.pagination,
      cancelledPagination: _state.cancelledPagination,
      availableYears: _state.availableYears,
      message: failureMessage,
      page: _state.page,
    );
    return true;
  }

  Future<HistoryState> _fallbackToCache(String failureMessage) async {
    // The cache only ever holds the default filter (current year, no query);
    // under any other filter it would show unrelated orders as if they matched.
    final isDefaultFilter = _query.isEmpty && _year == DateTime.now().year;
    if (!isDefaultFilter) {
      return HistoryState(status: HistoryStatus.error, message: failureMessage);
    }
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
