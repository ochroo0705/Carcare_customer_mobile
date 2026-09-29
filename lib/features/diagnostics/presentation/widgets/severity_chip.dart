import 'package:carcare_customer_mobile/app/theme/app_theme.dart';
import 'package:carcare_customer_mobile/features/diagnostics/domain/report_severity.dart';
import 'package:flutter/material.dart';
import 'package:carcare_customer_mobile/core/widgets/status_chip.dart';

/// Web-ийн `SEVERITY_BADGE`/`CHECK_TONE_ACTIVE`-тай ижил өнгөний зарчим:
/// good → ногоон, warn → шар, bad → улаан.
Color colorForTone(CheckTone tone) => switch (tone) {
  CheckTone.good => AppColors.green,
  CheckTone.warn => AppColors.warning,
  CheckTone.bad => AppColors.red,
};

Color colorForSeverity(ReportSeverity severity) => switch (severity) {
  ReportSeverity.good => AppColors.green,
  ReportSeverity.warn => AppColors.warning,
  ReportSeverity.bad => AppColors.red,
};

class SeverityChip extends StatelessWidget {
  const SeverityChip({required this.severity, super.key});

  final ReportSeverity severity;

  @override
  Widget build(BuildContext context) => StatusChip(
    bordered: true,
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
  Widget build(BuildContext context) => StatusChip(
    label: value,
    color: colorForTone(checkOptionTone(value)),
    bordered: true,
  );
}
