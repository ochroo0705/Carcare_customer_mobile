import 'package:carcare_customer_mobile/features/history/domain/cancelled_appointment_summary.dart';
import 'package:carcare_customer_mobile/features/history/domain/service_order.dart';
import 'package:carcare_customer_mobile/features/history/domain/service_order_detail.dart';

abstract interface class ServiceHistoryRepository {
  Future<ServiceHistoryPage> getServiceHistory({HistoryFilter filter = const HistoryFilter()});

  Future<ServiceOrderDetail> getServiceOrderDetail(String id);

  /// D-085: appointments that were cancelled/no-showed/rejected before ever
  /// getting a `ServiceOrder` — cannot appear in [getServiceHistory]'s list,
  /// so history surfaces them separately instead of letting them disappear.
  Future<List<CancelledAppointmentSummary>> getCancelledAppointments();
}

class HistoryFilter {
  const HistoryFilter({
    this.query = '',
    this.year,
    this.month,
    this.page = 1,
    this.pageSize = 20,
  });
  final String query;
  final int? year;
  // Зөвхөн [year]-тэй хамт утгатай (1-12) — оноос тусад нь ялгамжтай биш.
  final int? month;
  final int page;
  final int pageSize;
}

class HistoryPagination {
  const HistoryPagination({
    required this.page,
    required this.pageSize,
    required this.total,
    required this.totalPages,
    required this.hasPrev,
    required this.hasNext,
  });
  final int page;
  final int pageSize;
  final int total;
  final int totalPages;
  final bool hasPrev;
  final bool hasNext;
}

class ServiceHistoryPage {
  const ServiceHistoryPage({
    required this.orders,
    required this.cancelledAppointments,
    required this.pagination,
    required this.cancelledPagination,
    this.availableYears = const [],
  });
  final List<ServiceOrder> orders;
  final List<CancelledAppointmentSummary> cancelledAppointments;
  final HistoryPagination pagination;
  final HistoryPagination cancelledPagination;
  final List<int> availableYears;
}
