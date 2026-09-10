import 'package:carcare_customer_mobile/features/diagnostics/domain/diagnostic_report_detail.dart';
import 'package:carcare_customer_mobile/features/diagnostics/domain/diagnostic_report_list_item.dart';

abstract interface class DiagnosticsRepository {
  Future<List<DiagnosticReportListItem>> getDiagnostics();

  Future<DiagnosticReportDetail> getDiagnosticDetail(String id);
}
