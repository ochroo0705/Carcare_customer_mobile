import 'package:carcare_customer_mobile/features/diagnostics/domain/diagnostic_report_detail.dart';
import 'package:carcare_customer_mobile/features/diagnostics/domain/diagnostic_report_list_item.dart';
import 'package:carcare_customer_mobile/features/diagnostics/domain/report_severity.dart';

abstract interface class DiagnosticsRepository {
  Future<DiagnosticPage> getDiagnostics({
    DiagnosticFilter filter = const DiagnosticFilter(),
  });

  Future<DiagnosticReportDetail> getDiagnosticDetail(String id);
}

class DiagnosticFilter {
  const DiagnosticFilter({
    this.query = '',
    this.severity,
    this.year,
    this.page = 1,
    this.pageSize = 20,
  });
  final String query;
  final ReportSeverity? severity;
  final int? year;
  final int page;
  final int pageSize;
}

class DiagnosticPagination {
  const DiagnosticPagination({
    required this.page,
    required this.pageSize,
    required this.total,
    required this.totalPages,
    required this.hasPrev,
    required this.hasNext,
  });
  final int page;
  final int pageSize;
  final int total;
  final int totalPages;
  final bool hasPrev;
  final bool hasNext;
}

class DiagnosticPage {
  const DiagnosticPage({
    required this.reports,
    required this.pagination,
    this.availableYears = const [],
  });
  final List<DiagnosticReportListItem> reports;
  final DiagnosticPagination pagination;
  final List<int> availableYears;
}
