import 'package:carcare_customer_mobile/features/booking/domain/appointment_status.dart';

class Appointment {
  const Appointment({
    required this.id,
    required this.status,
    required this.requestedAt,
    required this.tenantName,
    required this.tenantSlug,
    required this.branchName,
    this.note,
    this.categoryName,
    this.vehiclePlate,
  });

  final String id;
  final AppointmentStatus status;
  final DateTime requestedAt;
  final String tenantName;
  final String tenantSlug;
  final String branchName;
  final String? note;
  final String? categoryName;
  final String? vehiclePlate;

  Appointment copyWith({AppointmentStatus? status}) => Appointment(
    id: id,
    status: status ?? this.status,
    requestedAt: requestedAt,
    tenantName: tenantName,
    tenantSlug: tenantSlug,
    branchName: branchName,
    note: note,
    categoryName: categoryName,
    vehiclePlate: vehiclePlate,
  );
}
