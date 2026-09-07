import 'package:carcare_customer_mobile/app/theme/app_theme.dart';
import 'package:carcare_customer_mobile/features/history/domain/service_order_status.dart';
import 'package:flutter/material.dart';

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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status.localizedLabel,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}
