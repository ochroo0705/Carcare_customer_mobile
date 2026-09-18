import 'package:carcare_customer_mobile/features/booking/data/fake_appointment_repository.dart';
import 'package:carcare_customer_mobile/features/booking/domain/appointment_status.dart';
import 'package:carcare_customer_mobile/features/booking/presentation/controllers/appointments_controller.dart';
import 'package:carcare_customer_mobile/features/booking/presentation/controllers/appointments_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'loads the seeded appointments sorted active-first, then most recent',
    () async {
      final controller = AppointmentsController(FakeAppointmentRepository());

      await controller.load();

      expect(controller.state.status, AppointmentsStatus.data);
      final sorted = controller.sortedAppointments;
      expect(sorted.every((a) => a.status.isActive), isFalse);
      expect(sorted.first.status.isActive, isTrue);
      expect(sorted.last.status.isActive, isFalse);
    },
  );

  test(
    'cancels a pending appointment and reloads with cancelled status',
    () async {
      final controller = AppointmentsController(FakeAppointmentRepository());
      await controller.load();
      final target = controller.sortedAppointments.firstWhere(
        (a) => a.status.canCancel,
      );

      final error = await controller.cancel(target.id);

      expect(error, isNull);
      final updated = controller.sortedAppointments.firstWhere(
        (a) => a.id == target.id,
      );
      expect(updated.status.canCancel, isFalse);
    },
  );

  test(
    'a successful cancel fires onAppointmentCancelled so History reconciles',
    () async {
      // Cancelling is a terminal transition and History renders its own
      // cancelled-appointments section, so reloading only this controller
      // leaves the appointment absent from both lists. The router wires this
      // callback to `historyController.load()`.
      final controller = AppointmentsController(FakeAppointmentRepository());
      var fired = 0;
      controller.onAppointmentCancelled = () => fired++;
      await controller.load();
      final target = controller.sortedAppointments.firstWhere(
        (a) => a.status.canCancel,
      );

      final error = await controller.cancel(target.id);

      expect(error, isNull);
      expect(fired, 1);
    },
  );

  test('a failed cancel does not fire onAppointmentCancelled', () async {
    // Nothing changed server-side, so History is not stale and must not be
    // refetched — otherwise every mistyped/stale id costs a needless reload.
    final controller = AppointmentsController(FakeAppointmentRepository());
    var fired = 0;
    controller.onAppointmentCancelled = () => fired++;
    await controller.load();

    final error = await controller.cancel('does-not-exist');

    expect(error, isNotNull);
    expect(fired, 0);
  });

  test(
    'returns an error message instead of throwing for an unknown id',
    () async {
      final controller = AppointmentsController(FakeAppointmentRepository());
      await controller.load();

      final error = await controller.cancel('does-not-exist');

      expect(error, isNotNull);
    },
  );

  test('reset returns to the initial state', () async {
    final controller = AppointmentsController(FakeAppointmentRepository());
    await controller.load();
    expect(controller.state.status, AppointmentsStatus.data);

    controller.reset();

    expect(controller.state.status, AppointmentsStatus.initial);
    expect(controller.state.appointments, isEmpty);
  });
}
