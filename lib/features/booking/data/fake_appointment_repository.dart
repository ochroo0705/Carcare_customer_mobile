import 'package:carcare_customer_mobile/core/errors/app_failure.dart';
import 'package:carcare_customer_mobile/features/booking/domain/appointment.dart';
import 'package:carcare_customer_mobile/features/booking/domain/appointment_repository.dart';
import 'package:carcare_customer_mobile/features/booking/domain/appointment_status.dart';

class FakeAppointmentRepository implements AppointmentRepository {
  FakeAppointmentRepository() : _now = DateTime.now();

  final DateTime _now;
  late final List<Appointment> _appointments = [
    Appointment(
      id: 'seed-1',
      status: AppointmentStatus.confirmed,
      requestedAt: _now.add(const Duration(days: 2, hours: 3)),
      tenantName: 'Инфосистемс',
      tenantSlug: 'infosystems',
      branchName: 'Үндсэн салбар',
      categoryName: 'Тоормос',
    ),
    Appointment(
      id: 'seed-2',
      status: AppointmentStatus.pending,
      requestedAt: _now.add(const Duration(days: 5)),
      tenantName: 'Тэсо Моторс',
      tenantSlug: 'teso-motors',
      branchName: 'Хан-Уул салбар',
    ),
    Appointment(
      id: 'seed-3',
      status: AppointmentStatus.cancelled,
      requestedAt: _now.subtract(const Duration(days: 10)),
      tenantName: 'Инфосистемс',
      tenantSlug: 'infosystems',
      branchName: 'Үндсэн салбар',
    ),
  ];
  var _sequence = 0;

  @override
  Future<CreatedAppointment> createAppointment({
    required String branchId,
    required DateTime requestedAt,
    String? note,
    String? accountVehicleId,
  }) async {
    _sequence += 1;
    final id = 'fake-appointment-$_sequence';
    _appointments.insert(
      0,
      Appointment(
        id: id,
        status: AppointmentStatus.pending,
        requestedAt: requestedAt,
        tenantName: 'Таны сонгосон байгууллага',
        tenantSlug: branchId,
        branchName: 'Сонгосон салбар',
        note: note,
      ),
    );
    return CreatedAppointment(
      id: id,
      status: 'PENDING',
      requestedAt: requestedAt,
    );
  }

  @override
  Future<List<Appointment>> getAppointments() async =>
      List.unmodifiable(_appointments);

  @override
  Future<void> cancelAppointment(String id) async {
    final index = _appointments.indexWhere(
      (appointment) => appointment.id == id,
    );
    if (index == -1) throw const NotFoundFailure();
    final appointment = _appointments[index];
    if (!appointment.status.canCancel) throw const ConflictFailure();
    _appointments[index] = appointment.copyWith(
      status: AppointmentStatus.cancelled,
    );
  }
}
