import 'package:carcare_customer_mobile/features/diagnostics/domain/report_severity.dart';
import 'package:carcare_customer_mobile/features/diagnostics/domain/template_schema.dart';

/// Нэг оношилгооны тайлангийн БҮРЭН бөглөлт — жагсаалтаас (эсвэл захиалгын
/// дэлгэрэнгүй дэх товч мөрөөс) дарж орсны дараа татаж авна.
class DiagnosticReportDetail {
  const DiagnosticReportDetail({
    required this.id,
    required this.templateName,
    required this.type,
    required this.schema,
    required this.data,
    required this.createdAt,
    required this.vehiclePlate,
    required this.vehicleMake,
    required this.vehicleModel,
    required this.branchName,
    this.severity,
    this.mileageAtReport,
    this.notes,
  });

  final String id;
  final String templateName;
  final String type;
  final TemplateSchema schema;
  final ReportData data;
  final ReportSeverity? severity;
  final int? mileageAtReport;
  final String? notes;
  final DateTime createdAt;
  final String vehiclePlate;
  final String vehicleMake;
  final String vehicleModel;
  final String branchName;
}
