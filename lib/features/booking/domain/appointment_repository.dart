import 'package:carcare_customer_mobile/features/booking/domain/appointment.dart';

class CreatedAppointment {
  const CreatedAppointment({
    required this.id,
    required this.status,
    required this.requestedAt,
  });

  final String id;
  final String status;
  final DateTime requestedAt;
}

abstract interface class AppointmentRepository {
  Future<CreatedAppointment> createAppointment({
    required String branchId,
    required DateTime requestedAt,
    String? note,
    String? accountVehicleId,
  });

  Future<List<Appointment>> getAppointments();

  Future<void> cancelAppointment(String id);
}
