import 'package:carcare_customer_mobile/features/booking/data/appointment_dto.dart';
import 'package:carcare_customer_mobile/features/booking/domain/appointment_status.dart';
import 'package:carcare_customer_mobile/core/errors/app_failure.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses a full appointment matching the published contract', () {
    final appointment = AppointmentDto.fromJson({
      'id': 'apt-1',
      'status': 'PENDING',
      'requestedAt': '2026-09-02T09:00:00.000Z',
      'note': 'Тэмдэглэл',
      'tenant': {'name': 'Инфосистемс', 'slug': 'infosystems'},
      'branch': {'name': 'Үндсэн салбар'},
      'category': {'name': 'Тоормос'},
      'accountVehicle': {'plate': '1234УБА'},
    }).toDomain();

    expect(appointment.id, 'apt-1');
    expect(appointment.status, AppointmentStatus.pending);
    expect(appointment.tenantName, 'Инфосистемс');
    expect(appointment.tenantSlug, 'infosystems');
    expect(appointment.branchName, 'Үндсэн салбар');
    expect(appointment.categoryName, 'Тоормос');
    expect(appointment.vehiclePlate, '1234УБА');
    expect(appointment.note, 'Тэмдэглэл');
  });

  test('treats null category and accountVehicle as absent', () {
    final appointment = AppointmentDto.fromJson({
      'id': 'apt-2',
      'status': 'CONFIRMED',
      'requestedAt': '2026-09-02T09:00:00.000Z',
      'tenant': {'name': 'Инфосистемс', 'slug': 'infosystems'},
      'branch': {'name': 'Үндсэн салбар'},
      'category': null,
      'accountVehicle': null,
    }).toDomain();

    expect(appointment.status, AppointmentStatus.confirmed);
    expect(appointment.categoryName, isNull);
    expect(appointment.vehiclePlate, isNull);
  });

  test('maps an unrecognized status to unknown rather than throwing', () {
    final appointment = AppointmentDto.fromJson({
      'id': 'apt-3',
      'status': 'SOMETHING_NEW',
      'requestedAt': '2026-09-02T09:00:00.000Z',
      'tenant': {'name': 'Инфосистемс', 'slug': 'infosystems'},
      'branch': {'name': 'Үндсэн салбар'},
    }).toDomain();

    expect(appointment.status, AppointmentStatus.unknown);
    expect(appointment.status.canCancel, isFalse);
  });

  test('throws on a malformed appointment list', () {
    expect(
      () => parseAppointmentListJson('not-a-list'),
      throwsA(isA<UnexpectedFailure>()),
    );
  });

  test('throws when a required nested field is missing', () {
    expect(
      () => AppointmentDto.fromJson({
        'id': 'apt-4',
        'status': 'PENDING',
        'requestedAt': '2026-09-02T09:00:00.000Z',
        'branch': {'name': 'Үндсэн салбар'},
      }),
      throwsA(isA<UnexpectedFailure>()),
    );
  });
}
