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
    return _Chip(label: status.localizedLabel, color: color);
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
  Widget build(BuildContext context) => _Chip(label: label, color: AppColors.red);
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      label,
      style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12),
    ),
  );
}
