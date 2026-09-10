import 'package:carcare_customer_mobile/features/diagnostics/domain/report_severity.dart';

/// "Оношилгооны түүх" жагсаалтын нэг мөр — товч мэдээлэл. Бүрэн бөглөлтийг
/// [DiagnosticReportDetail] дуудлагаас авна (харах: history feature-ийн
/// sparse-list/rich-detail зарчим).
class DiagnosticReportListItem {
  const DiagnosticReportListItem({
    required this.id,
    required this.templateName,
    required this.type,
    required this.createdAt,
    required this.vehiclePlate,
    required this.vehicleMake,
    required this.vehicleModel,
    required this.branchName,
    this.mileageAtReport,
    this.severity,
  });

  final String id;
  final String templateName;
  final String type;
  final DateTime createdAt;
  final int? mileageAtReport;
  final ReportSeverity? severity;
  final String vehiclePlate;
  final String vehicleMake;
  final String vehicleModel;
  final String branchName;
}
