import 'package:carcare_customer_mobile/core/errors/app_failure.dart';
import 'package:carcare_customer_mobile/features/booking/domain/appointment.dart';
import 'package:carcare_customer_mobile/features/booking/domain/appointment_payment.dart';
import 'package:carcare_customer_mobile/features/booking/domain/appointment_status.dart';
import 'package:carcare_customer_mobile/features/booking/domain/service_progress.dart';
import 'package:carcare_customer_mobile/features/history/domain/service_order_item.dart'
    show ServiceOrderItemKind, serviceOrderItemKindFromApi;

/// `GET /appointments`-ийн rich list payload-ийг domain model-оос тусгаарлана.
/// Backend-ийн nested `tenant`, `branch`, `category`, `accountVehicle`-г энд
/// flatten хийж, optional хэсгүүдийг байхгүй үед null хэвээр нь үлдээнэ.
class AppointmentDto {
  AppointmentDto({
    required this.id,
    required this.status,
    required this.requestedAt,
    required this.tenantName,
    required this.tenantSlug,
    required this.branchName,
    this.note,
    this.categoryName,
    this.vehiclePlate,
    this.payment,
    this.serviceProgress,
  });

  /// Published API shape-ийг defensive байдлаар шалгана.
  /// Required талбар дутуу үед partial Appointment үүсгэхгүй, учир нь UI
  /// дээрх organization/branch нэр нь list card-ийн үндсэн мэдээлэл юм.
  factory AppointmentDto.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final status = json['status'];
    final requestedAt = DateTime.tryParse('${json['requestedAt']}');
    if (id is! String || status is! String || requestedAt == null) {
      throw const UnexpectedFailure('Захиалгын мэдээлэл буруу байна.');
    }
    final tenant = _requiredMap(json, 'tenant');
    final branch = _requiredMap(json, 'branch');
    final category = _optionalMap(json['category']);
    final accountVehicle = _optionalMap(json['accountVehicle']);
    final serviceOrder = _optionalMap(json['serviceOrder']);
    return AppointmentDto(
      id: id,
      status: status,
      requestedAt: requestedAt,
      tenantName: _requiredString(tenant, 'name'),
      tenantSlug: _requiredString(tenant, 'slug'),
      branchName: _requiredString(branch, 'name'),
      note: _optionalString(json['note']),
      categoryName: category == null ? null : _optionalString(category['name']),
      vehiclePlate: accountVehicle == null
          ? null
          : _optionalString(accountVehicle['plate']),
      payment: appointmentPaymentFromJson(json['payment']),
      serviceProgress: serviceProgressFromJson(serviceOrder),
    );
  }

  final String id;
  final String status;
  final DateTime requestedAt;
  final String tenantName;
  final String tenantSlug;
  final String branchName;
  final String? note;
  final String? categoryName;
  final String? vehiclePlate;
  final AppointmentPayment? payment;
  final AppointmentServiceProgress? serviceProgress;

  Appointment toDomain() => Appointment(
    id: id,
    status: appointmentStatusFromApi(status),
    requestedAt: requestedAt,
    tenantName: tenantName,
    tenantSlug: tenantSlug,
    branchName: branchName,
    note: note,
    categoryName: categoryName,
    vehiclePlate: vehiclePlate,
    payment: payment,
    serviceProgress: serviceProgress,
  );
}

/// Parses the optional linked ServiceOrder included in appointment list
/// responses. A booking can exist for some time before staff creates its order,
/// so malformed/absent progress must not invalidate the appointment itself.
AppointmentServiceProgress? serviceProgressFromJson(Object? value) {
  final json = _optionalMap(value);
  if (json == null) return null;
  final id = _optionalString(json['id']);
  final status = _optionalString(json['status']);
  if (id == null || status == null) return null;

  final items = <AppointmentServiceItemProgress>[];
  final rawItems = json['items'];
  if (rawItems is List) {
    for (final rawItem in rawItems) {
      final item = _optionalMap(rawItem);
      final itemId = item == null ? null : _optionalString(item['id']);
      final name = item == null ? null : _optionalString(item['description']);
      final itemStatus = item == null
          ? null
          : _optionalString(item['status']);
      if (itemId == null || name == null || itemStatus == null) continue;
      final kindRaw = item == null ? null : _optionalString(item['kind']);
      items.add(
        AppointmentServiceItemProgress(
          id: itemId,
          name: name,
          status: serviceProgressStatusFromApi(itemStatus),
          kind: kindRaw == null
              ? ServiceOrderItemKind.labor
              : serviceOrderItemKindFromApi(kindRaw),
          quantity: _optionalNum(item?['quantity']),
          unitPrice: _optionalNum(item?['unitPrice']),
          total: _optionalNum(item?['total']),
        ),
      );
    }
  }

  final vehicle = _optionalMap(json['vehicle']);

  return AppointmentServiceProgress(
    id: id,
    number: _optionalString(json['number']) ?? '',
    status: serviceProgressStatusFromApi(status),
    paymentStatus: orderPaymentStatusFromApi(
      _optionalString(json['paymentStatus']),
    ),
    scheduledAt: _optionalDateTime(json['scheduledAt']),
    startedAt: _optionalDateTime(json['startedAt']),
    completedAt: _optionalDateTime(json['completedAt']),
    estimatedDurationMinutes: json['estimatedDurationMinutes'] is int
        ? json['estimatedDurationMinutes'] as int
        : null,
    expectedFinishAt: _optionalDateTime(json['expectedFinishAt']),
    totalAmount: _optionalNum(json['totalAmount']),
    paidAmount: _optionalNum(json['paidAmount']),
    vehiclePlate: vehicle == null ? null : _optionalString(vehicle['plate']),
    vehicleMake: vehicle == null ? null : _optionalString(vehicle['make']),
    vehicleModel: vehicle == null ? null : _optionalString(vehicle['model']),
    vehicleYear: vehicle?['year'] is int ? vehicle!['year'] as int : null,
    items: List.unmodifiable(items),
  );
}

num? _optionalNum(Object? value) => value is num ? value : null;

/// `/appointments*` болон `/appointments/[id]/payment*` endpoint-үүдийн
/// ижил `payment` shape-ийг задлана (`CUSTOMER_API_CONTRACT.md` §"4.1 Цаг
/// захиалгын хураамж`). `null` input бол хураамж шаардахгүй гэсэн үг.
AppointmentPayment? appointmentPaymentFromJson(Object? value) {
  if (value is! Map) return null;
  final statusRaw = value['status'];
  final amount = value['amount'];
  if (statusRaw is! String || amount is! num) return null;
  return AppointmentPayment(
    status: appointmentFeeStatusFromApi(statusRaw),
    amount: amount,
    currency: value['currency'] is String ? value['currency'] as String : 'MNT',
    qrImageBase64: value['qrImage'] is String
        ? value['qrImage'] as String
        : null,
    qrText: value['qrText'] is String ? value['qrText'] as String : null,
    urls: _bankUrlsFromJson(value['urls']),
    underpaidAmount: value['underpaidAmount'] is num
        ? value['underpaidAmount'] as num
        : null,
  );
}

/// QPay банкны deep link жагсаалтыг задлана. Талбар байхгүй/null/буруу бол
/// хоосон жагсаалт (фичер нэвтрэхээс өмнөх invoice, эсвэл хураамжгүй). `link`
/// заавал шаардлагатай — линкгүй мөрийг алгасна (нээх юмгүй товч гаргахгүй).
List<QpayBankUrl> _bankUrlsFromJson(Object? value) {
  if (value is! List) return const [];
  final result = <QpayBankUrl>[];
  for (final item in value) {
    if (item is! Map) continue;
    final link = item['link'];
    if (link is! String || link.isEmpty) continue;
    result.add(
      QpayBankUrl(
        name: item['name'] is String ? item['name'] as String : '',
        nameMn: item['name_mn'] is String ? item['name_mn'] as String : '',
        logo: item['logo'] is String ? item['logo'] as String : '',
        link: link,
        description: item['description'] is String
            ? item['description'] as String
            : null,
      ),
    );
  }
  return List.unmodifiable(result);
}

List<AppointmentDto> parseAppointmentListJson(Object? value) {
  if (value is! List) {
    throw const UnexpectedFailure('Захиалгын жагсаалт буруу байна.');
  }
  return value
      .map((item) {
        if (item is! Map) {
          throw const UnexpectedFailure('Захиалгын өгөгдөл буруу байна.');
        }
        return AppointmentDto.fromJson(Map<String, dynamic>.from(item));
      })
      .toList(growable: false);
}

Map<String, dynamic> _requiredMap(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! Map) {
    throw UnexpectedFailure('API талбар буруу байна: $key');
  }
  return Map<String, dynamic>.from(value);
}

Map<String, dynamic>? _optionalMap(Object? value) =>
    value is Map ? Map<String, dynamic>.from(value) : null;

String _requiredString(Map<String, dynamic> json, String key) {
  final value = _optionalString(json[key]);
  if (value == null) throw UnexpectedFailure('API талбар буруу байна: $key');
  return value;
}

String? _optionalString(Object? value) {
  if (value is! String || value.trim().isEmpty) return null;
  return value.trim();
}

DateTime? _optionalDateTime(Object? value) =>
    value is String ? DateTime.tryParse(value) : null;
