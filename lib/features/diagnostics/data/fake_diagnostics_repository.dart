import 'package:carcare_customer_mobile/core/errors/app_failure.dart';
import 'package:carcare_customer_mobile/features/diagnostics/domain/diagnostic_report_detail.dart';
import 'package:carcare_customer_mobile/features/diagnostics/domain/diagnostic_report_list_item.dart';
import 'package:carcare_customer_mobile/features/diagnostics/domain/diagnostics_repository.dart';
import 'package:carcare_customer_mobile/features/diagnostics/domain/report_severity.dart';
import 'package:carcare_customer_mobile/features/diagnostics/domain/template_schema.dart';

class FakeDiagnosticsRepository implements DiagnosticsRepository {
  FakeDiagnosticsRepository() : _now = DateTime.now();

  final DateTime _now;

  late final List<DiagnosticReportListItem> _reports = [
    DiagnosticReportListItem(
      id: 'seed-diagnostic-1',
      templateName: 'Ерөнхий үзлэг (хүлээж авах)',
      type: 'INTAKE',
      createdAt: _now.subtract(const Duration(days: 30)),
      mileageAtReport: 82000,
      severity: ReportSeverity.warn,
      vehiclePlate: '1234 УБА',
      vehicleMake: 'Toyota',
      vehicleModel: 'Prius',
      branchName: 'Үндсэн салбар',
    ),
    DiagnosticReportListItem(
      id: 'seed-diagnostic-2',
      templateName: 'Үйлчилгээний дараах шалгалт',
      type: 'POST_SERVICE',
      createdAt: _now.subtract(const Duration(days: 8)),
      mileageAtReport: 85200,
      severity: ReportSeverity.good,
      vehiclePlate: '1234 УБА',
      vehicleMake: 'Toyota',
      vehicleModel: 'Prius',
      branchName: 'Хан-Уул салбар',
    ),
  ];

  static const _schema = TemplateSchema(
    sections: [
      TemplateSection(
        id: 'sec_engine',
        title: 'Хөдөлгүүрийн тасалгаа',
        items: [
          TemplateItem(
            id: 'item_engine_oil',
            label: 'Хөдөлгүүрийн тос',
            type: 'check',
            options: ['Хэвийн', 'Анхаарах', 'Солих'],
          ),
          TemplateItem(
            id: 'item_brake_fluid',
            label: 'Тоормозны шингэн',
            type: 'check',
            options: ['Хэвийн', 'Анхаарах', 'Солих'],
          ),
        ],
      ),
      TemplateSection(
        id: 'sec_brakes',
        title: 'Тоормос',
        items: [
          TemplateItem(
            id: 'item_brake_pad',
            label: 'Наклад',
            type: 'check',
            options: ['Хэвийн', 'Анхаарах', 'Солих'],
            positionSet: 'LR',
          ),
          TemplateItem(id: 'item_notes', label: 'Нэмэлт тайлбар', type: 'text'),
        ],
      ),
    ],
  );

  late final Map<String, ReportData> _data = {
    'seed-diagnostic-1': const ReportData({
      'item_engine_oil': ReportEntry(value: 'Хэвийн'),
      'item_brake_fluid': ReportEntry(
        value: 'Анхаарах',
        note: 'Дараагийн 5000 км-т солих шаардлагатай.',
      ),
      'item_brake_pad@L': ReportEntry(value: 'Хэвийн'),
      'item_brake_pad@R': ReportEntry(value: 'Анхаарах'),
      'item_notes': ReportEntry(value: 'Ерөнхийдөө сайн байдалтай.'),
    }),
    'seed-diagnostic-2': const ReportData({
      'item_engine_oil': ReportEntry(value: 'Хэвийн'),
      'item_brake_fluid': ReportEntry(value: 'Хэвийн'),
      'item_brake_pad@L': ReportEntry(value: 'Хэвийн'),
      'item_brake_pad@R': ReportEntry(value: 'Хэвийн'),
    }),
  };

  @override
  Future<List<DiagnosticReportListItem>> getDiagnostics() async =>
      List.unmodifiable(_reports);

  @override
  Future<DiagnosticReportDetail> getDiagnosticDetail(String id) async {
    final item = _reports.where((r) => r.id == id).firstOrNull;
    if (item == null) throw const NotFoundFailure();
    return DiagnosticReportDetail(
      id: item.id,
      templateName: item.templateName,
      type: item.type,
      schema: _schema,
      data: _data[id] ?? const ReportData({}),
      severity: item.severity,
      mileageAtReport: item.mileageAtReport,
      createdAt: item.createdAt,
      vehiclePlate: item.vehiclePlate,
      vehicleMake: item.vehicleMake,
      vehicleModel: item.vehicleModel,
      branchName: item.branchName,
    );
  }
}
