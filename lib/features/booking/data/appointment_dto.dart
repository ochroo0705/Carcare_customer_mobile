import 'package:carcare_customer_mobile/core/errors/app_failure.dart';
import 'package:carcare_customer_mobile/features/booking/domain/appointment.dart';
import 'package:carcare_customer_mobile/features/booking/domain/appointment_payment.dart';
import 'package:carcare_customer_mobile/features/booking/domain/appointment_status.dart';

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
  });

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
  );
}

/// Parses the shared `payment` shape returned by every
/// `/appointments*`/`/appointments/[id]/payment*` endpoint
/// (`CUSTOMER_API_CONTRACT.md` §"4.1 Цаг захиалгын хураамж"). `null` input
/// means no fee is required.
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
    underpaidAmount: value['underpaidAmount'] is num
        ? value['underpaidAmount'] as num
        : null,
  );
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
