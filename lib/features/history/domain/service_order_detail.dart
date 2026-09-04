import 'package:carcare_customer_mobile/features/history/domain/diagnostic_report_summary.dart';
import 'package:carcare_customer_mobile/features/history/domain/service_order.dart';
import 'package:carcare_customer_mobile/features/history/domain/service_order_item.dart';

/// Full detail view of a single order, including line items. Fetched
/// separately from the list per the sparse-list/rich-detail split.
class ServiceOrderDetail {
  const ServiceOrderDetail({
    required this.order,
    required this.items,
    this.note,
    this.reports = const [],
  });

  final ServiceOrder order;
  final List<ServiceOrderItem> items;
  final String? note;

  /// Хавсаргасан оношилгооны тайлангууд (байхгүй байж болно).
  final List<DiagnosticReportSummary> reports;
}
