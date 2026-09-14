import 'package:carcare_customer_mobile/core/errors/app_failure.dart';
import 'package:carcare_customer_mobile/core/network/api_client.dart';
import 'package:carcare_customer_mobile/features/diagnostics/data/diagnostic_report_dto.dart';
import 'package:carcare_customer_mobile/features/diagnostics/domain/diagnostic_report_detail.dart';
import 'package:carcare_customer_mobile/features/diagnostics/domain/diagnostics_repository.dart';

/// `GET /api/v1/app/diagnostics` + `/diagnostics/[id]`-ийн эсрэг ажилладаг
/// бодит хэрэгжүүлэлт (харах: `CUSTOMER_API_CONTRACT.md` "Оношилгоо").
class RemoteDiagnosticsRepository implements DiagnosticsRepository {
  RemoteDiagnosticsRepository(this._client);

  final ApiClient _client;

  @override
  Future<DiagnosticPage> getDiagnostics({DiagnosticFilter filter = const DiagnosticFilter()}) async {
    final query = <String, String>{
      'page': '${filter.page}', 'pageSize': '${filter.pageSize}',
    };
    if (filter.query.trim().isNotEmpty) query['q'] = filter.query.trim();
    if (filter.severity != null) query['severity'] = filter.severity!.name.toUpperCase();
    if (filter.year != null) query['year'] = '${filter.year}';
    final json = await _client.getJson('/diagnostics?${Uri(queryParameters: query).query}');
    return diagnosticPageFromJson(json);
  }

  @override
  Future<DiagnosticReportDetail> getDiagnosticDetail(String id) async {
    final json = await _client.getJson('/diagnostics/$id');
    final report = json['report'];
    if (report is! Map) {
      throw const UnexpectedFailure('Оношилгооны тайлан буруу байна.');
    }
    return diagnosticReportDetailFromJson(report);
  }
}
