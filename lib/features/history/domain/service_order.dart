import 'package:carcare_customer_mobile/features/history/domain/service_order_status.dart';

/// Sparse, list-shaped view of a completed service order. Mirrors the web
/// backend's known list/detail split: `GET /account/history` returns fewer
/// fields than the per-order detail endpoint would.
class ServiceOrder {
  const ServiceOrder({
    required this.id,
    required this.tenantName,
    required this.tenantSlug,
    required this.branchName,
    required this.completedAt,
    required this.status,
    required this.totalAmount,
    required this.paidAmount,
    this.vehiclePlate,
    this.isCancelled = false,
  });

  final String id;
  final String tenantName;
  final String tenantSlug;
  final String branchName;
  final DateTime completedAt;
  final ServiceOrderStatus status;
  final int totalAmount;
  final int paidAmount;
  final String? vehiclePlate;
  // History now also includes CANCELLED orders (D-085), not just COMPLETED
  // ones — [status] above is the PAYMENT status and stays meaningless/unpaid
  // for a cancelled order, so this is checked separately by the UI.
  final bool isCancelled;
}
