import 'package:carcare_customer_mobile/app/theme/app_theme.dart';
import 'package:carcare_customer_mobile/features/history/domain/service_order_status.dart';
import 'package:flutter/material.dart';
import 'package:carcare_customer_mobile/core/widgets/status_chip.dart';

/// Захиалгын төлбөрийн төлөв (unpaid/partial/paid) — түүхийн жагсаалт болон
/// дэлгэрэнгүй дэлгэц хоёуланд ижилхэн харагдана.
class ServiceOrderStatusChip extends StatelessWidget {
  const ServiceOrderStatusChip({required this.status, super.key});

  final ServiceOrderStatus status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      ServiceOrderStatus.paid => AppColors.green,
      ServiceOrderStatus.partiallyPaid => AppColors.blue,
      ServiceOrderStatus.unpaid => AppColors.red,
    };
    return StatusChip(label: status.localizedLabel, color: color);
  }
}

/// D-085: history now includes CANCELLED orders too, which the payment-only
/// [ServiceOrderStatusChip] above cannot represent (they're always
/// "unpaid" but that's not the point — they were cancelled, not underpaid).
/// Also reused for the cancelled/no-show/rejected appointments section,
/// whose label varies by [label] (defaults to the order case).
class CancelledOrderChip extends StatelessWidget {
  const CancelledOrderChip({this.label = 'Цуцлагдсан', super.key});

  final String label;

  @override
  Widget build(BuildContext context) =>
      StatusChip(label: label, color: AppColors.red);
}
