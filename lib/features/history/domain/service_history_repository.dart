import 'package:carcare_customer_mobile/features/history/domain/cancelled_appointment_summary.dart';
import 'package:carcare_customer_mobile/features/history/domain/service_order.dart';
import 'package:carcare_customer_mobile/features/history/domain/service_order_detail.dart';

abstract interface class ServiceHistoryRepository {
  Future<List<ServiceOrder>> getServiceHistory();

  Future<ServiceOrderDetail> getServiceOrderDetail(String id);

  /// D-085: appointments that were cancelled/no-showed/rejected before ever
  /// getting a `ServiceOrder` — cannot appear in [getServiceHistory]'s list,
  /// so history surfaces them separately instead of letting them disappear.
  Future<List<CancelledAppointmentSummary>> getCancelledAppointments();
}
