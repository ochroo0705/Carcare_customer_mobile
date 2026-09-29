import 'package:carcare_customer_mobile/app/theme/app_theme.dart';
import 'package:carcare_customer_mobile/features/history/domain/diagnostic_report_summary.dart';
import 'package:flutter/material.dart';

/// Нэг оношилгооны тайлангийн мөр (нэр + огноо/гүйлт) — захиалгын
/// дэлгэрэнгүй (`ServiceOrderDetailScreen`) болон явц (`ServiceProgressSection`)
/// хоёуланд ижил харагдацтай, тайлан бэлэн болсон даруйд аль алинд нь
/// (ажил дуусаагүй ч) харуулна.
class DiagnosticReportRow extends StatelessWidget {
  const DiagnosticReportRow({required this.report, this.onTap, super.key});

  final DiagnosticReportSummary report;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final date =
        '${report.createdAt.year}.${report.createdAt.month.toString().padLeft(2, '0')}.${report.createdAt.day.toString().padLeft(2, '0')}';
    final subtitle = report.mileageAtReport != null
        ? '$date · ${report.mileageAtReport} км'
        : date;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.medium),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Icon(Icons.assignment_outlined, size: 18, color: scheme.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    report.templateName,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            if (onTap != null)
              Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}
