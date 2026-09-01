import 'package:carcare_customer_mobile/features/booking/domain/appointment_repository.dart';

class FakeAppointmentRepository implements AppointmentRepository {
  @override
  Future<CreatedAppointment> createAppointment({
    required String branchId,
    required DateTime requestedAt,
    String? note,
  }) async => CreatedAppointment(
    id: 'fake-appointment',
    status: 'PENDING',
    requestedAt: requestedAt,
  );
}
