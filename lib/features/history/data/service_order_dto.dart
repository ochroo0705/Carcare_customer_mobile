import 'package:carcare_customer_mobile/core/errors/app_failure.dart';
import 'package:carcare_customer_mobile/features/history/domain/diagnostic_report_summary.dart';
import 'package:carcare_customer_mobile/features/history/domain/service_order.dart';
import 'package:carcare_customer_mobile/features/history/domain/service_order_detail.dart';
import 'package:carcare_customer_mobile/features/history/domain/service_order_item.dart';
import 'package:carcare_customer_mobile/features/history/domain/service_order_status.dart';

/// `GET /api/v1/app/orders` (list) болон `/orders/[id]` (detail)-ийн JSON-ийг
/// domain руу задална. Мөнгөн дүнгүүд backend дээр Prisma `Decimal` тул JSON-д
/// STRING ("150000") эсвэл тоо байж болзошгүй — [_toInt] хоёуланг зохицуулна.
/// `completedAt` null байж болно (дуусаагүй захиалга); домэйн талд заавал тул
/// `completedAt ?? scheduledAt ?? createdAt`-аар нөхнө.

int _toInt(Object? value) {
  if (value is num) return value.round();
  if (value is String) {
    final parsed = num.tryParse(value);
    if (parsed != null) return parsed.round();
  }
  return 0;
}

int? _toIntOrNull(Object? value) {
  if (value == null) return null;
  if (value is num) return value.round();
  if (value is String) return num.tryParse(value)?.round();
  return null;
}

String _requiredString(Map value, String key) {
  final v = value[key];
  if (v is! String || v.isEmpty) {
    throw UnexpectedFailure('Захиалгын өгөгдөл буруу байна: $key');
  }
  return v;
}

String? _optionalString(Object? value) => value is String ? value : null;

DateTime _dateFrom(Object? value) {
  if (value is String) {
    final parsed = DateTime.tryParse(value);
    if (parsed != null) return parsed;
  }
  throw const UnexpectedFailure('Захиалгын огноо буруу байна.');
}

DateTime? _dateFromOrNull(Object? value) =>
    value is String ? DateTime.tryParse(value) : null;

/// Захиалгын "огноо" — дууссан бол дуусах, эс бол товлосон, эс бол үүсгэсэн.
DateTime _effectiveDate(Map order) =>
    _dateFromOrNull(order['completedAt']) ??
    _dateFromOrNull(order['scheduledAt']) ??
    _dateFrom(order['createdAt']);

ServiceOrder serviceOrderFromJson(Map order) {
  final vehicle = order['vehicle'];
  final tenant = order['tenant'];
  final branch = order['branch'];
  return ServiceOrder(
    id: _requiredString(order, 'id'),
    tenantName: tenant is Map ? _optionalString(tenant['name']) ?? '' : '',
    tenantSlug: tenant is Map ? _optionalString(tenant['slug']) ?? '' : '',
    branchName: branch is Map ? _optionalString(branch['name']) ?? '' : '',
    completedAt: _effectiveDate(order),
    status: serviceOrderStatusFromApi(
      _optionalString(order['paymentStatus']) ?? '',
    ),
    totalAmount: _toInt(order['totalAmount']),
    paidAmount: _toInt(order['paidAmount']),
    vehiclePlate: vehicle is Map ? _optionalString(vehicle['plate']) : null,
  );
}

List<ServiceOrder> parseServiceOrderListJson(Object? value) {
  if (value is! List) {
    throw const UnexpectedFailure('Түүхийн жагсаалт буруу байна.');
  }
  return value
      .map((item) {
        if (item is! Map) {
          throw const UnexpectedFailure('Захиалгын өгөгдөл буруу байна.');
        }
        return serviceOrderFromJson(item);
      })
      .toList(growable: false);
}

ServiceOrderItem _itemFromJson(Map item) => ServiceOrderItem(
  kind: serviceOrderItemKindFromApi(_optionalString(item['kind']) ?? ''),
  name: _optionalString(item['description']) ?? '',
  quantity: _toInt(item['quantity']),
  unitPrice: _toInt(item['unitPrice']),
);

DiagnosticReportSummary _reportFromJson(Map report) => DiagnosticReportSummary(
  id: _requiredString(report, 'id'),
  templateName: _optionalString(report['templateName']) ?? 'Тайлан',
  type: _optionalString(report['type']) ?? '',
  createdAt: _dateFrom(report['createdAt']),
  mileageAtReport: _toIntOrNull(report['mileageAtReport']),
);

ServiceOrderDetail serviceOrderDetailFromJson(Map order) {
  final itemsRaw = order['items'];
  final reportsRaw = order['reports'];
  return ServiceOrderDetail(
    order: serviceOrderFromJson(order),
    items: itemsRaw is List
        ? itemsRaw
              .whereType<Map>()
              .map(_itemFromJson)
              .toList(growable: false)
        : const [],
    note: _optionalString(order['notes']),
    reports: reportsRaw is List
        ? reportsRaw
              .whereType<Map>()
              .map(_reportFromJson)
              .toList(growable: false)
        : const [],
  );
}
