import 'package:carcare_customer_mobile/features/history/domain/cancelled_appointment_summary.dart';
import 'package:carcare_customer_mobile/features/history/domain/service_order.dart';

enum HistoryStatus { initial, loading, data, empty, error, unavailable }

class HistoryState {
  const HistoryState({
    this.status = HistoryStatus.initial,
    this.orders = const [],
    this.cancelledAppointments = const [],
    this.message,
    this.isFromCache = false,
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

  bool get isLoading =>
      status == HistoryStatus.initial || status == HistoryStatus.loading;
}
