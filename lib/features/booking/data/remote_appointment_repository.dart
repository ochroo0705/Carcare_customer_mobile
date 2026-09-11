import 'package:carcare_customer_mobile/core/errors/app_failure.dart';
import 'package:carcare_customer_mobile/core/network/api_client.dart';
import 'package:carcare_customer_mobile/features/booking/data/appointment_dto.dart';
import 'package:carcare_customer_mobile/features/booking/domain/appointment.dart';
import 'package:carcare_customer_mobile/features/booking/domain/appointment_payment.dart';
import 'package:carcare_customer_mobile/features/booking/domain/appointment_repository.dart';
import 'package:carcare_customer_mobile/features/booking/domain/availability.dart';
import 'package:carcare_customer_mobile/features/booking/domain/walk_in_order.dart';

/// Customer appointment API adapter.
///
/// Бүх endpoint Account bearer token шаарддаг. Create/cancel-ийн contract
/// алдааг [ApiClient] AppFailure болгон хөрвүүлдэг тул энэ давхарга зөвхөн
/// payload shape болон domain conversion-ийг хариуцна.
class RemoteAppointmentRepository implements AppointmentRepository {
  RemoteAppointmentRepository(this._client);

  final ApiClient _client;

  @override
  /// UTC ISO-8601 цаг илгээнэ. Server local timezone-оор тайлбарлахгүй байх
  /// нь өөр timezone-той device дээр захиалгын цаг зөрөхөөс сэргийлнэ.
  Future<DayAvailability> getAvailability({
    required String branchId,
    required DateTime date,
    List<String> categoryIds = const [],
  }) async {
    final dateStr =
        '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
    final query = <String, String>{'date': dateStr};
    if (categoryIds.isNotEmpty) query['categoryIds'] = categoryIds.join(',');
    final path =
        '/branches/${Uri.encodeComponent(branchId)}/availability'
        '?${Uri(queryParameters: query).query}';
    final json = await _client.getJson(path);
    final duration = json['durationMinutes'];
    final rawSlots = json['slots'];
    final slots = <AvailabilitySlot>[];
    if (rawSlots is List) {
      for (final item in rawSlots) {
        if (item is! Map) continue;
        final time = item['time'];
        if (time is! String) continue;
        final parts = time.split(':');
        if (parts.length != 2) continue;
        final hour = int.tryParse(parts[0]);
        final minute = int.tryParse(parts[1]);
        if (hour == null || minute == null) continue;
        final remaining = item['remaining'];
        slots.add(
          AvailabilitySlot(
            hour: hour,
            minute: minute,
            available: item['available'] == true,
            remaining: remaining is num ? remaining.toInt() : 0,
          ),
        );
      }
    }
    return DayAvailability(
      open: json['open'] == true,
      durationMinutes: duration is num ? duration.toInt() : 0,
      reason: json['reason'] is String ? json['reason'] as String : null,
      slots: slots,
    );
  }

  @override
  Future<CreatedAppointment> createAppointment({
    required String branchId,
    required DateTime requestedAt,
    String? note,
    String? accountVehicleId,
    List<String> categoryIds = const [],
  }) async {
    final json = await _client.postJson('/appointments', {
      'branchId': branchId,
      'requestedAt': requestedAt.toUtc().toIso8601String(),
      if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
      if (accountVehicleId != null && accountVehicleId.isNotEmpty)
        'accountVehicleId': accountVehicleId,
      if (categoryIds.isNotEmpty) 'categoryIds': categoryIds,
    });
    final value = json['appointment'];
    if (value is! Map) {
      throw const UnexpectedFailure('Захиалгын хариу буруу байна.');
    }
    final appointment = Map<String, dynamic>.from(value);
    final id = appointment['id'];
    final status = appointment['status'];
    final parsedAt = DateTime.tryParse('${appointment['requestedAt']}')?.toLocal();
    if (id is! String || status is! String || parsedAt == null) {
      throw const UnexpectedFailure('Захиалгын мэдээлэл буруу байна.');
    }
    return CreatedAppointment(
      id: id,
      status: status,
      requestedAt: parsedAt,
      payment: appointmentPaymentFromJson(appointment['payment']),
    );
  }

  @override
  /// Нэг Account-ийн бүх appointment-ийг server-ээс уншина. Энэ list нь
  /// rich payload боловч тусдаа appointment detail GET endpoint шаарддаггүй.
  Future<List<Appointment>> getAppointments() async {
    final json = await _client.getJson('/appointments');
    return parseAppointmentListJson(json['appointments'])
        .map((dto) => dto.toDomain())
        .toList(growable: false);
  }

  @override
  /// `getAppointments()`-ийн ЯГ адил endpoint дуудна, зөвхөн `walkInOrders`
  /// талбарыг унших — payload хөнгөн тул хоёр дахин дуудахад бага өртөгтэй,
  /// харин `Appointment`-ийн одоогийн `List<Appointment>` гэрээг хэвээр
  /// хадгална (бусад бүх дуудагч/тест кодыг өөрчлөхгүй).
  Future<List<WalkInOrder>> getWalkInOrders() async {
    final json = await _client.getJson('/appointments');
    return parseWalkInOrderListJson(json['walkInOrders'])
        .map((dto) => dto.toDomain())
        .toList(growable: false);
  }

  @override
  /// Зөвхөн PENDING/CONFIRMED төлөвийг server цуцлуулахыг зөвшөөрнө.
  /// Client талын canCancel нь UX-д зориулсан урьдчилсан шалгалт; эрхийн
  /// эцсийн шийдвэр server дээр үлдэнэ.
  Future<void> cancelAppointment(String id) async {
    final json = await _client.postJson('/appointments/$id/cancel', const {});
    if (json['ok'] != true) {
      throw const UnexpectedFailure('Захиалга цуцлагдсангүй.');
    }
  }

  @override
  Future<void> rescheduleAppointment(String id, DateTime requestedAt) async {
    final json = await _client.postJson('/appointments/$id/reschedule', {
      'requestedAt': requestedAt.toUtc().toIso8601String(),
    });
    if (json['ok'] != true) {
      throw const UnexpectedFailure('Цаг шилжүүлэгдсэнгүй.');
    }
  }

  @override
  Future<AppointmentPayment?> getPayment(String appointmentId) async {
    final json = await _client.getJson('/appointments/$appointmentId/payment');
    return appointmentPaymentFromJson(json['payment']);
  }

  @override
  Future<AppointmentPaymentCheckResult> checkPayment(
    String appointmentId,
  ) async {
    final json = await _client.postJson(
      '/appointments/$appointmentId/payment/check',
      const {},
    );
    final underpaid = json['underpaidAmount'];
    final message = json['message'];
    return AppointmentPaymentCheckResult(
      paid: json['paid'] == true,
      underpaidAmount: underpaid is num ? underpaid : null,
      message: message is String ? message : null,
    );
  }

  @override
  Future<AppointmentPayment?> retryPayment(String appointmentId) async {
    final json = await _client.postJson(
      '/appointments/$appointmentId/payment/retry',
      const {},
    );
    return appointmentPaymentFromJson(json['payment']);
  }
}
