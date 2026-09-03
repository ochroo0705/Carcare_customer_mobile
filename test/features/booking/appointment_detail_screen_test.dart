import 'package:carcare_customer_mobile/app/theme/app_theme.dart';
import 'package:carcare_customer_mobile/features/booking/data/fake_appointment_repository.dart';
import 'package:carcare_customer_mobile/features/booking/domain/appointment.dart';
import 'package:carcare_customer_mobile/features/booking/domain/appointment_payment.dart';
import 'package:carcare_customer_mobile/features/booking/domain/appointment_repository.dart';
import 'package:carcare_customer_mobile/features/booking/domain/appointment_status.dart';
import 'package:carcare_customer_mobile/features/booking/presentation/controllers/appointments_controller.dart';
import 'package:carcare_customer_mobile/features/booking/presentation/screens/appointment_detail_screen.dart';
import 'package:carcare_customer_mobile/features/discovery/data/fake_organization_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

Future<AppointmentsController> _loadedController() async {
  final controller = AppointmentsController(FakeAppointmentRepository());
  await controller.load();
  return controller;
}

/// A repository that exposes exactly one appointment, so a test can pin its
/// tenant slug / branch name to a known `FakeOrganizationRepository` branch.
class _OneAppointmentRepo implements AppointmentRepository {
  _OneAppointmentRepo(this._appointment);
  final Appointment _appointment;

  @override
  Future<List<Appointment>> getAppointments() async => [_appointment];

  @override
  Future<void> cancelAppointment(String id) async {}
  @override
  Future<AppointmentPayment?> getPayment(String id) async => null;
  @override
  Future<AppointmentPayment?> retryPayment(String id) async => null;
  @override
  Future<CreatedAppointment> createAppointment({
    required String branchId,
    required DateTime requestedAt,
    String? note,
    String? accountVehicleId,
  }) => throw UnimplementedError();
  @override
  Future<AppointmentPaymentCheckResult> checkPayment(String id) =>
      throw UnimplementedError();
}

Future<void> _pump(
  WidgetTester tester,
  AppointmentsController controller,
  String appointmentId, {
  ValueChanged<Appointment>? onPay,
}) async {
  await tester.pumpWidget(
    ChangeNotifierProvider.value(
      value: controller,
      child: MaterialApp(
        theme: AppTheme.light,
        home: AppointmentDetailScreen(
          appointmentId: appointmentId,
          organizationRepository: FakeOrganizationRepository(),
          onBack: () {},
          onPay: onPay ?? (_) {},
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows the selected appointment resolved by id', (tester) async {
    final controller = await _loadedController();

    await _pump(tester, controller, 'seed-1');

    expect(find.text('Инфосистемс'), findsOneWidget);
    expect(find.text('Үндсэн салбар'), findsOneWidget);
    expect(find.text('Тоормос'), findsOneWidget); // category
    controller.dispose();
  });

  testWidgets('offers a pay button for an appointment with an unpaid fee', (
    tester,
  ) async {
    final controller = await _loadedController();

    await _pump(tester, controller, 'seed-2');

    expect(find.byKey(const ValueKey('detail-pay-seed-2')), findsOneWidget);
    controller.dispose();
  });

  testWidgets('invokes onPay with the appointment when Төлөх is tapped', (
    tester,
  ) async {
    final controller = await _loadedController();
    Appointment? paid;

    await _pump(tester, controller, 'seed-2', onPay: (a) => paid = a);
    await tester.tap(find.byKey(const ValueKey('detail-pay-seed-2')));

    expect(paid?.id, 'seed-2');
    controller.dispose();
  });

  testWidgets('shows a not-found state for an unknown id once loaded', (
    tester,
  ) async {
    final controller = await _loadedController();

    await _pump(tester, controller, 'does-not-exist');

    expect(find.text('Захиалга олдсонгүй'), findsOneWidget);
    controller.dispose();
  });

  testWidgets('shows branch location, hours and contact when the branch '
      'matches the org detail', (tester) async {
    final appointment = Appointment(
      id: 'apt-x',
      status: AppointmentStatus.confirmed,
      requestedAt: DateTime(2026, 10, 1, 10),
      tenantName: 'Auto Doctor Service',
      tenantSlug: 'auto-doctor',
      branchName: 'Баянзүрх салбар', // matches FakeOrganizationRepository
    );
    final controller = AppointmentsController(_OneAppointmentRepo(appointment));
    await controller.load();

    await _pump(tester, controller, 'apt-x');

    expect(find.text('Байршил ба цагийн хуваарь'), findsOneWidget);
    expect(find.text('26-р хороо, Нарны зам 18'), findsOneWidget); // fullAddress
    expect(find.byKey(const ValueKey('detail-show-on-maps')), findsOneWidget);
    expect(find.byKey(const ValueKey('detail-call')), findsOneWidget);
    expect(find.byKey(const ValueKey('detail-copy-phone')), findsOneWidget);
    controller.dispose();
  });
}
