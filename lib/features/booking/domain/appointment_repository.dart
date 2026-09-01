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
  });
}
