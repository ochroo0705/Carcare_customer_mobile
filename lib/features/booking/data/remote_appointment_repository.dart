import 'package:carcare_customer_mobile/core/errors/app_failure.dart';
import 'package:carcare_customer_mobile/core/network/api_client.dart';
import 'package:carcare_customer_mobile/features/booking/domain/appointment_repository.dart';

class RemoteAppointmentRepository implements AppointmentRepository {
  RemoteAppointmentRepository(this._client);

  final ApiClient _client;

  @override
  Future<CreatedAppointment> createAppointment({
    required String branchId,
    required DateTime requestedAt,
    String? note,
  }) async {
    final json = await _client.postJson('/appointments', {
      'branchId': branchId,
      'requestedAt': requestedAt.toUtc().toIso8601String(),
      if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
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
}
