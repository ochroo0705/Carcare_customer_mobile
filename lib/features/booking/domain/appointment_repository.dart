import 'package:carcare_customer_mobile/features/booking/domain/appointment.dart';
import 'package:carcare_customer_mobile/features/booking/domain/appointment_payment.dart';

class CreatedAppointment {
  const CreatedAppointment({
    required this.id,
    required this.status,
    required this.requestedAt,
    this.payment,
  });

  final String id;
  final String status;
  final DateTime requestedAt;
  final AppointmentPayment? payment;
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

  /// Current fee/payment status for one appointment — call whenever a
  /// payment screen opens (`CUSTOMER_API_CONTRACT.md`'s
  /// `GET /appointments/[id]/payment`).
  Future<AppointmentPayment?> getPayment(String appointmentId);

  /// Polls QPay to see if the customer has paid yet, after they've scanned
  /// the QR — idempotent, safe to call repeatedly.
  Future<AppointmentPaymentCheckResult> checkPayment(String appointmentId);

  /// Retries QPay checkout creation after it failed
  /// (`AppointmentFeeStatus.failed`), returning the new pending payment.
  Future<AppointmentPayment?> retryPayment(String appointmentId);
}
