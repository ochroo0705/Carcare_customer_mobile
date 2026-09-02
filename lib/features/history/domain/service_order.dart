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
}
