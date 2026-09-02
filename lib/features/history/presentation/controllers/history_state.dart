import 'package:carcare_customer_mobile/features/history/domain/service_order.dart';

enum HistoryStatus { initial, loading, data, empty, error }

class HistoryState {
  const HistoryState({
    this.status = HistoryStatus.initial,
    this.orders = const [],
    this.message,
  });

  final HistoryStatus status;
  final List<ServiceOrder> orders;
  final String? message;

  bool get isLoading =>
      status == HistoryStatus.initial || status == HistoryStatus.loading;
}
