import 'package:carcare_customer_mobile/app/theme/app_theme.dart';
import 'package:carcare_customer_mobile/features/diagnostics/domain/report_severity.dart';
import 'package:flutter/material.dart';

/// Web-ийн `SEVERITY_BADGE`/`CHECK_TONE_ACTIVE`-тай ижил өнгөний зарчим:
/// good → ногоон, warn → шар, bad → улаан.
Color colorForTone(CheckTone tone) => switch (tone) {
  CheckTone.good => AppColors.green,
  CheckTone.warn => const Color(0xFFF59E0B),
  CheckTone.bad => AppColors.red,
};

Color colorForSeverity(ReportSeverity severity) => switch (severity) {
  ReportSeverity.good => AppColors.green,
  ReportSeverity.warn => const Color(0xFFF59E0B),
  ReportSeverity.bad => AppColors.red,
};

class SeverityChip extends StatelessWidget {
  const SeverityChip({required this.severity, super.key});

  final ReportSeverity severity;

  @override
  Widget build(BuildContext context) => _Chip(
    label: severity.localizedLabel,
    color: colorForSeverity(severity),
  );
}

/// Нэг check хариултын (ж: "Хэвийн"/"Анхаарах"/"Солих") чип — web-ийн
/// хариулт бүрийн өнгөт chip-тэй ижил.
class CheckValueChip extends StatelessWidget {
  const CheckValueChip({required this.value, super.key});

  final String value;

  @override
  Widget build(BuildContext context) =>
      _Chip(label: value, color: colorForTone(checkOptionTone(value)));
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
      border: Border.all(color: color.withValues(alpha: 0.35)),
    ),
    child: Text(
      label,
      style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12),
    ),
  );
}
