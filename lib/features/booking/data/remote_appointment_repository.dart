import 'package:carcare_customer_mobile/core/errors/app_failure.dart';
import 'package:carcare_customer_mobile/core/network/api_client.dart';
import 'package:carcare_customer_mobile/features/booking/data/appointment_dto.dart';
import 'package:carcare_customer_mobile/features/booking/domain/appointment.dart';
import 'package:carcare_customer_mobile/features/booking/domain/appointment_payment.dart';
import 'package:carcare_customer_mobile/features/booking/domain/appointment_repository.dart';

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
  Future<CreatedAppointment> createAppointment({
    required String branchId,
    required DateTime requestedAt,
    String? note,
    String? accountVehicleId,
  }) async {
    final json = await _client.postJson('/appointments', {
      'branchId': branchId,
      'requestedAt': requestedAt.toUtc().toIso8601String(),
      if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
      if (accountVehicleId != null && accountVehicleId.isNotEmpty)
        'accountVehicleId': accountVehicleId,
    });
    final value = json['appointment'];
    if (value is! Map) {
      throw const UnexpectedFailure('Захиалгын хариу буруу байна.');
    }
    final appointment = Map<String, dynamic>.from(value);
    final id = appointment['id'];
    final status = appointment['status'];
    final parsedAt = DateTime.tryParse('${appointment['requestedAt']}');
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
