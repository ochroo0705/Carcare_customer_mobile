import 'package:carcare_customer_mobile/features/booking/domain/appointment.dart';
import 'package:carcare_customer_mobile/features/booking/domain/appointment_status.dart';
import 'package:carcare_customer_mobile/features/booking/domain/service_progress.dart';
import 'package:flutter_test/flutter_test.dart';

/// Once staff confirm a booking and create the ServiceOrder, the appointment
/// stays `CONFIRMED` — so a status-only check keeps offering "cancel". That is
/// worse than useless: neither cancel path on the server touches the linked
/// order, so the customer believes they cancelled while the work proceeds, and
/// staff receive a misleading "customer cancelled" notification.
///
/// `Appointment.canCancel` therefore also requires `serviceProgress == null`.
Appointment _appointment({
  AppointmentStatus status = AppointmentStatus.confirmed,
  AppointmentServiceProgress? serviceProgress,
}) => Appointment(
  id: 'a1',
  status: status,
  requestedAt: DateTime(2026, 9, 18, 10),
  tenantName: 'Тест сервис',
  tenantSlug: 'test-service',
  branchName: 'Төв салбар',
  serviceProgress: serviceProgress,
);

AppointmentServiceProgress _progress() => const AppointmentServiceProgress(
  id: 'o1',
  number: 'ORD-001',
  status: ServiceProgressStatus.inProgress,
  items: [],
);

void main() {
  test('an active appointment with no order can be cancelled', () {
    expect(_appointment().canCancel, isTrue);
    expect(_appointment(status: AppointmentStatus.pending).canCancel, isTrue);
  });

  test('an appointment that has become an order cannot be cancelled', () {
    final withOrder = _appointment(serviceProgress: _progress());

    // The status alone still says yes — that is exactly the trap.
    expect(withOrder.status.canCancel, isTrue);
    expect(withOrder.canCancel, isFalse);
  });

  test('a terminal appointment cannot be cancelled regardless of order', () {
    for (final status in [
      AppointmentStatus.cancelled,
      AppointmentStatus.rejected,
      AppointmentStatus.noShow,
    ]) {
      expect(_appointment(status: status).canCancel, isFalse, reason: '$status');
    }
  });
}
