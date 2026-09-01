import 'package:carcare_customer_mobile/features/booking/domain/appointment.dart';

enum AppointmentsStatus { initial, loading, data, empty, error }

class AppointmentsState {
  const AppointmentsState({
    this.status = AppointmentsStatus.initial,
    this.appointments = const [],
    this.message,
  });

  final AppointmentsStatus status;
  final List<Appointment> appointments;
  final String? message;

  bool get isLoading =>
      status == AppointmentsStatus.initial ||
      status == AppointmentsStatus.loading;
}
