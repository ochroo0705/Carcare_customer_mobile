import 'package:carcare_customer_mobile/features/history/domain/service_order.dart';

enum HistoryStatus { initial, loading, data, empty, error, unavailable }

class HistoryState {
  const HistoryState({
    this.status = HistoryStatus.initial,
    this.orders = const [],
    this.message,
    this.isFromCache = false,
  });

  final HistoryStatus status;
  final List<ServiceOrder> orders;
  final String? message;

  /// True when [orders] is the last successfully loaded list, shown because
  /// a fresh load just failed (e.g. no network) rather than because it is
  /// currently up to date.
  final bool isFromCache;

  bool get isLoading =>
      status == HistoryStatus.initial || status == HistoryStatus.loading;
}
