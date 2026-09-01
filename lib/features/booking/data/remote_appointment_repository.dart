import 'package:carcare_customer_mobile/core/errors/app_failure.dart';
import 'package:carcare_customer_mobile/core/network/api_client.dart';
import 'package:carcare_customer_mobile/features/booking/data/appointment_dto.dart';
import 'package:carcare_customer_mobile/features/booking/domain/appointment.dart';
import 'package:carcare_customer_mobile/features/booking/domain/appointment_repository.dart';

class RemoteAppointmentRepository implements AppointmentRepository {
  RemoteAppointmentRepository(this._client);

  final ApiClient _client;

  @override
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
    return CreatedAppointment(id: id, status: status, requestedAt: parsedAt);
  }

  @override
  Future<List<Appointment>> getAppointments() async {
    final json = await _client.getJson('/appointments');
    return parseAppointmentListJson(json['appointments'])
        .map((dto) => dto.toDomain())
        .toList(growable: false);
  }

  @override
  Future<void> cancelAppointment(String id) async {
    final json = await _client.postJson('/appointments/$id/cancel', const {});
    if (json['ok'] != true) {
      throw const UnexpectedFailure('Захиалга цуцлагдсангүй.');
    }
  }
}
