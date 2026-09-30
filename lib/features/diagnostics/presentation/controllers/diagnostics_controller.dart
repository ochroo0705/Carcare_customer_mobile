import 'dart:async';

import 'package:carcare_customer_mobile/core/errors/app_failure.dart';
import 'package:carcare_customer_mobile/features/diagnostics/domain/diagnostic_report_list_item.dart';
import 'package:carcare_customer_mobile/features/diagnostics/domain/diagnostics_repository.dart';
import 'package:flutter/foundation.dart';

enum DiagnosticsStatus { initial, loading, data, empty, error }

/// Drives the "Оношилгооны жагсаалт" report list — query + year filter
/// (year-only, no "all years", defaults to the current year, same shape as
/// `HistoryController`), pagination, and load state. Extracted out of the
/// widget so a shared search/filter bar (e.g. one placed above a tab
/// switcher) can drive this list without owning its own `State`.
class DiagnosticsController extends ChangeNotifier {
  DiagnosticsController(this._repository);

  final DiagnosticsRepository _repository;

  DiagnosticsStatus _status = DiagnosticsStatus.initial;
  List<DiagnosticReportListItem> _reports = const [];
  DiagnosticPagination _pagination = const DiagnosticPagination(
    page: 1,
    pageSize: 20,
    total: 0,
    totalPages: 1,
    hasPrev: false,
    hasNext: false,
  );
  List<int> _serverAvailableYears = const [];
  String? _message;
  bool _isLoadingMore = false;
  bool _resultsStale = false;

  String _query = '';
  // "Бүх он" сонголт байхгүй — Түүхийн жилийн шүүлттэй адил, анхны утга нь
  // одоогийн жил.
  int _year = DateTime.now().year;
  Timer? _debounce;
  int _generation = 0;

  DiagnosticsStatus get status => _status;
  List<DiagnosticReportListItem> get reports => _reports;
  DiagnosticPagination get pagination => _pagination;
  String? get message => _message;
  bool get isLoadingMore => _isLoadingMore;
  bool get resultsStale => _resultsStale;
  bool get hasNextPage => _pagination.hasNext;

  String get query => _query;
  int get year => _year;

  /// Жилийн жагсаалт — серверээс ирсэн бодит жилүүд, одоогийн жил хэзээ ч
  /// дутахгүйн тулд түүнийг мөн эхэнд нэмнэ.
  List<int> get availableYears => ({_year, ..._serverAvailableYears}.toList()
    ..sort((a, b) => b.compareTo(a)));

  void setQuery(String value) {
    final trimmed = value.trim();
    if (_query == trimmed) return;
    _query = trimmed;
    _resultsStale = true;
    notifyListeners();
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

  Future<void> load({bool append = false}) async {
    if (append && (_isLoadingMore || !hasNextPage)) return;
    final generation = ++_generation;
    if (append) {
      _isLoadingMore = true;
    } else {
      _status = DiagnosticsStatus.loading;
    }
    notifyListeners();
    try {
      final result = await _repository.getDiagnostics(
        filter: DiagnosticFilter(
          query: _query,
          year: _year,
          page: append ? _pagination.page + 1 : 1,
        ),
      );
      if (generation != _generation) {
        _isLoadingMore = false;
        return;
      }
      _message = null;
      _resultsStale = false;
      _reports = append ? [..._reports, ...result.reports] : result.reports;
      _pagination = result.pagination;
      _serverAvailableYears = result.availableYears;
      _status = _reports.isEmpty
          ? DiagnosticsStatus.empty
          : DiagnosticsStatus.data;
      _isLoadingMore = false;
    } on AppFailure catch (failure) {
      _isLoadingMore = false;
      if (generation != _generation) return;
      if (append) {
        _message = failure.message;
      } else {
        _message = failure.message;
        _status = DiagnosticsStatus.error;
      }
    } catch (_) {
      _isLoadingMore = false;
      if (generation != _generation) return;
      if (append) {
        _message = 'Тодорхойгүй алдаа гарлаа.';
      } else {
        _message = 'Тодорхойгүй алдаа гарлаа.';
        _status = DiagnosticsStatus.error;
      }
    }
    notifyListeners();
  }

  Future<void> loadMore() => load(append: true);

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}
