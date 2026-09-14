import 'package:carcare_customer_mobile/core/errors/app_failure.dart';
import 'package:carcare_customer_mobile/core/network/api_client.dart';
import 'package:carcare_customer_mobile/features/history/data/service_order_dto.dart';
import 'package:carcare_customer_mobile/features/history/domain/cancelled_appointment_summary.dart';
import 'package:carcare_customer_mobile/features/history/domain/service_order.dart';
import 'package:carcare_customer_mobile/features/history/domain/service_order_detail.dart';
import 'package:carcare_customer_mobile/features/history/domain/service_history_repository.dart';

/// `GET /api/v1/app/orders` + `/orders/[id]`-ийн эсрэг ажилладаг бодит
/// хэрэгжүүлэлт (web commit `79f0e9e`). Backend pagination and filters are
/// passed through as typed page requests; D-085 cancelled appointments are
/// returned in the same response with independent pagination metadata.
class RemoteServiceHistoryRepository implements ServiceHistoryRepository {
  RemoteServiceHistoryRepository(this._client);

  final ApiClient _client;

  static const _maxPageSize = 200;

  @override
  Future<ServiceHistoryPage> getServiceHistory({
    HistoryFilter filter = const HistoryFilter(),
  }) async {
    final query = <String, String>{
      'page': '${filter.page}',
      'pageSize': '${filter.pageSize}',
    };
    if (filter.query.trim().isNotEmpty) query['q'] = filter.query.trim();
    if (filter.year != null) query['year'] = '${filter.year}';
    final json = await _client.getJson('/orders?${Uri(queryParameters: query).query}');
    return serviceHistoryPageFromJson(json);
  }

  // D-085: `cancelledAppointments` is a field on the SAME `/orders` response
  // as `getServiceHistory` above, not a separate endpoint — this duplicates
  // that network call rather than adding shared response caching, since the
  // repository interface exposes them as two independent methods (matching
  // the fake/unavailable implementations). Acceptable for now; revisit if
  // this repository ever needs a real caching layer.
  @override
  Future<List<CancelledAppointmentSummary>> getCancelledAppointments() async {
    final json = await _client.getJson('/orders?pageSize=$_maxPageSize');
    return parseCancelledAppointmentListJson(json['cancelledAppointments']);
  }

  @override
  Future<ServiceOrderDetail> getServiceOrderDetail(String id) async {
    final json = await _client.getJson('/orders/$id');
    final order = json['order'];
    if (order is! Map) {
      throw const UnexpectedFailure('Захиалгын дэлгэрэнгүй буруу байна.');
    }
    return serviceOrderDetailFromJson(order);
  }
}
