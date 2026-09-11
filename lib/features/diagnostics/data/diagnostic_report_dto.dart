import 'package:carcare_customer_mobile/core/errors/app_failure.dart';
import 'package:carcare_customer_mobile/features/diagnostics/domain/diagnostic_report_detail.dart';
import 'package:carcare_customer_mobile/features/diagnostics/domain/diagnostic_report_list_item.dart';
import 'package:carcare_customer_mobile/features/diagnostics/domain/report_severity.dart';
import 'package:carcare_customer_mobile/features/diagnostics/domain/template_schema.dart';

/// `GET /api/v1/app/diagnostics` (list) болон `/diagnostics/[id]` (detail)-ийн
/// JSON-ийг domain руу задална (харах: `CUSTOMER_API_CONTRACT.md` "Оношилгоо").

int? _toIntOrNull(Object? value) {
  if (value == null) return null;
  if (value is num) return value.round();
  if (value is String) return num.tryParse(value)?.round();
  return null;
}

String _requiredString(Map value, String key) {
  final v = value[key];
  if (v is! String || v.isEmpty) {
    throw UnexpectedFailure('Оношилгооны өгөгдөл буруу байна: $key');
  }
  return v;
}

String _optionalString(Object? value, [String fallback = '']) =>
    value is String ? value : fallback;

DateTime _dateFrom(Object? value) {
  if (value is String) {
    final parsed = DateTime.tryParse(value);
    if (parsed != null) return parsed.toLocal();
  }
  throw const UnexpectedFailure('Оношилгооны огноо буруу байна.');
}

DiagnosticReportListItem diagnosticReportListItemFromJson(Map json) {
  final vehicle = json['vehicle'];
  final branch = json['branch'];
  return DiagnosticReportListItem(
    id: _requiredString(json, 'id'),
    templateName: _optionalString(json['templateName'], 'Тайлан'),
    type: _optionalString(json['type']),
    createdAt: _dateFrom(json['createdAt']),
    mileageAtReport: _toIntOrNull(json['mileageAtReport']),
    severity: reportSeverityFromApi(json['severity']),
    vehiclePlate: vehicle is Map ? _optionalString(vehicle['plate']) : '',
    vehicleMake: vehicle is Map ? _optionalString(vehicle['make']) : '',
    vehicleModel: vehicle is Map ? _optionalString(vehicle['model']) : '',
    branchName: branch is Map ? _optionalString(branch['name']) : '',
  );
}

List<DiagnosticReportListItem> parseDiagnosticReportListJson(Object? value) {
  if (value is! List) {
    throw const UnexpectedFailure('Оношилгооны жагсаалт буруу байна.');
  }
  return value
      .map((item) {
        if (item is! Map) {
          throw const UnexpectedFailure('Оношилгооны өгөгдөл буруу байна.');
        }
        return diagnosticReportListItemFromJson(item);
      })
      .toList(growable: false);
}

DiagnosticReportDetail diagnosticReportDetailFromJson(Map json) {
  final vehicle = json['vehicle'];
  final branch = json['branch'];
  return DiagnosticReportDetail(
    id: _requiredString(json, 'id'),
    templateName: _optionalString(json['templateName'], 'Тайлан'),
    type: _optionalString(json['type']),
    schema: TemplateSchema.fromJson(json['templateSchema']),
    data: ReportData.fromJson(json['data']),
    severity: reportSeverityFromApi(json['severity']),
    mileageAtReport: _toIntOrNull(json['mileageAtReport']),
    notes: json['notes'] is String ? json['notes'] as String : null,
    createdAt: _dateFrom(json['createdAt']),
    vehiclePlate: vehicle is Map ? _optionalString(vehicle['plate']) : '',
    vehicleMake: vehicle is Map ? _optionalString(vehicle['make']) : '',
    vehicleModel: vehicle is Map ? _optionalString(vehicle['model']) : '',
    branchName: branch is Map ? _optionalString(branch['name']) : '',
  );
}
