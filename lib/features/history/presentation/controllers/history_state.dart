import 'package:carcare_customer_mobile/features/history/domain/cancelled_appointment_summary.dart';
import 'package:carcare_customer_mobile/features/history/domain/service_order.dart';
import 'package:carcare_customer_mobile/features/history/domain/service_history_repository.dart';

enum HistoryStatus { initial, loading, data, empty, error, unavailable }

class HistoryState {
  const HistoryState({
    this.status = HistoryStatus.initial,
    this.orders = const [],
    this.cancelledAppointments = const [],
    this.message,
    this.isFromCache = false,
    this.pagination = const HistoryPagination(
      page: 1,
      pageSize: 20,
      total: 0,
      totalPages: 1,
      hasPrev: false,
      hasNext: false,
    ),
    this.cancelledPagination = const HistoryPagination(
      page: 1,
      pageSize: 20,
      total: 0,
      totalPages: 1,
      hasPrev: false,
      hasNext: false,
    ),
    this.availableYears = const [],
    this.isLoadingMore = false,
    this.loadMoreMessage,
    this.page = 1,
  });

  final HistoryStatus status;
  final List<ServiceOrder> orders;
  // D-085: not cached alongside [orders] — if a fresh load fails and we fall
  // back to cache, this simply stays empty rather than showing a stale copy.
  final List<CancelledAppointmentSummary> cancelledAppointments;
  final String? message;

  /// True when [orders] is the last successfully loaded list, shown because
  /// a fresh load just failed (e.g. no network) rather than because it is
  /// currently up to date.
  final bool isFromCache;
  final HistoryPagination pagination;
  final HistoryPagination cancelledPagination;
  final List<int> availableYears;
  final bool isLoadingMore;
  final String? loadMoreMessage;
  /// Last page requested from the combined orders/cancelled response. This is
  /// independent of either list's clamped pagination metadata.
  final int page;

  bool get isLoading =>
      status == HistoryStatus.initial || status == HistoryStatus.loading;
}
