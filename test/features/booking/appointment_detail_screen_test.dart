import 'dart:async';

import 'package:carcare_customer_mobile/app/theme/app_theme.dart';
import 'package:carcare_customer_mobile/features/booking/data/fake_appointment_repository.dart';
import 'package:carcare_customer_mobile/features/booking/domain/appointment.dart';
import 'package:carcare_customer_mobile/features/booking/domain/appointment_payment.dart';
import 'package:carcare_customer_mobile/features/booking/domain/appointment_repository.dart';
import 'package:carcare_customer_mobile/features/booking/domain/appointment_status.dart';
import 'package:carcare_customer_mobile/features/booking/domain/service_progress.dart';
import 'package:carcare_customer_mobile/features/booking/domain/walk_in_order.dart';
import 'package:carcare_customer_mobile/features/booking/presentation/controllers/appointments_controller.dart';
import 'package:carcare_customer_mobile/features/booking/presentation/controllers/appointments_state.dart';
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
class _OneAppointmentRepo extends Fake implements AppointmentRepository {
  _OneAppointmentRepo(this._appointment);
  final Appointment _appointment;

  @override
  Future<List<Appointment>> getAppointments() async => [_appointment];

  @override
  Future<List<WalkInOrder>> getWalkInOrders() async => const [];
  @override
  Future<void> cancelAppointment(String id) async {}
  @override
  Future<AppointmentPayment?> getPayment(String id) async => null;
  @override
  Future<AppointmentPayment?> retryPayment(String id) async => null;
}

class _GatedRepo extends _OneAppointmentRepo {
  _GatedRepo(List<Appointment> seeded, this._next) : super(seeded.first);
  final Future<List<Appointment>> Function() _next;

  @override
  Future<List<Appointment>> getAppointments() => _next();
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
    // Захиалга үүсээгүй (seed-1-д serviceProgress байхгүй) тул ангиллууд
    // хэвээр харагдана — booking v2-ын бүх ангилал, ганцхан нэг биш.
    expect(find.text('Тоормос · Тос солих'), findsOneWidget);
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

  testWidgets('shows linked service progress and individual service statuses', (
    tester,
  ) async {
    final appointment = Appointment(
      id: 'apt-progress',
      status: AppointmentStatus.confirmed,
      requestedAt: DateTime(2026, 10, 1, 10),
      tenantName: 'Auto Doctor Service',
      tenantSlug: 'auto-doctor',
      branchName: 'Баянзүрх салбар',
      serviceProgress: const AppointmentServiceProgress(
        id: 'order-1',
        number: 'A-100',
        status: ServiceProgressStatus.inProgress,
        items: [
          AppointmentServiceItemProgress(
            id: 'item-1',
            name: 'Тос солих',
            status: ServiceProgressStatus.completed,
          ),
          AppointmentServiceItemProgress(
            id: 'item-2',
            name: 'Тоормос шалгах',
            status: ServiceProgressStatus.inProgress,
          ),
        ],
      ),
    );
    final controller = AppointmentsController(_OneAppointmentRepo(appointment));
    await controller.load();

    await _pump(tester, controller, 'apt-progress');

    expect(find.byKey(const ValueKey('appointment-progress')), findsOneWidget);
    expect(find.text('Үйлчилгээний явц'), findsOneWidget);
    expect(find.text('Засварын хуудас №A-100'), findsOneWidget);
    expect(find.text('Тос солих'), findsOneWidget);
    expect(find.text('Тоормос шалгах'), findsOneWidget);
    expect(find.text('1/2 үйлчилгээ дууссан'), findsOneWidget);
    controller.dispose();
  });

  testWidgets('hides the pay button when the appointment is cancelled even if '
      'the fee is unpaid', (tester) async {
    // Regression: a fee that is still PENDING must not be payable once the
    // appointment itself is cancelled — paying a dead booking is nonsensical.
    final appointment = Appointment(
      id: 'apt-cancelled',
      status: AppointmentStatus.cancelled,
      requestedAt: DateTime(2026, 10, 1, 10),
      tenantName: 'Auto Doctor Service',
      tenantSlug: 'auto-doctor',
      branchName: 'Баянзүрх салбар',
      payment: const AppointmentPayment(
        status: AppointmentFeeStatus.pending,
        amount: 5000,
        currency: 'MNT',
        qrText: 'qpay://example',
        qrImageBase64: '',
      ),
    );
    final controller = AppointmentsController(_OneAppointmentRepo(appointment));
    await controller.load();

    await _pump(tester, controller, 'apt-cancelled');

    expect(
      find.byKey(const ValueKey('detail-pay-apt-cancelled')),
      findsNothing,
    );
    expect(find.text('Төлөх'), findsNothing);
    controller.dispose();
  });

  testWidgets('shows a fee-paid badge (and no pay button) once the fee is '
      'paid, while the appointment stays pending', (tester) async {
    final appointment = Appointment(
      id: 'apt-paid',
      status: AppointmentStatus.pending, // staff not yet confirmed
      requestedAt: DateTime(2026, 10, 1, 10),
      tenantName: 'Auto Doctor Service',
      tenantSlug: 'auto-doctor',
      branchName: 'Баянзүрх салбар',
      payment: const AppointmentPayment(
        status: AppointmentFeeStatus.paid,
        amount: 5000,
        currency: 'MNT',
      ),
    );
    final controller = AppointmentsController(_OneAppointmentRepo(appointment));
    await controller.load();

    await _pump(tester, controller, 'apt-paid');

    expect(
      find.byKey(const ValueKey('detail-fee-paid-apt-paid')),
      findsOneWidget,
    );
    expect(find.text('Хураамж төлөгдсөн'), findsOneWidget);
    expect(find.byKey(const ValueKey('detail-pay-apt-paid')), findsNothing);
    // Appointment status itself is unchanged — payment ≠ staff confirmation.
    expect(find.text('Хүлээгдэж буй'), findsOneWidget);
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
    expect(
      find.text('26-р хороо, Нарны зам 18'),
      findsOneWidget,
    ); // fullAddress
    expect(find.byKey(const ValueKey('detail-show-on-maps')), findsOneWidget);
    expect(find.byKey(const ValueKey('detail-call')), findsOneWidget);
    expect(find.byKey(const ValueKey('detail-copy-phone')), findsOneWidget);
    controller.dispose();
  });

  testWidgets(
    'drops the category row once a service order exists, and shows the real '
    'start time instead of any estimate',
    (tester) async {
      final appointment = Appointment(
        id: 'apt-started',
        status: AppointmentStatus.confirmed,
        requestedAt: DateTime(2026, 10, 1, 10),
        tenantName: 'Auto Doctor Service',
        tenantSlug: 'auto-doctor',
        branchName: 'Баянзүрх салбар',
        categoryNames: const ['Тоормос', 'Тос солих'],
        serviceProgress: AppointmentServiceProgress(
          id: 'order-2',
          number: 'A-101',
          status: ServiceProgressStatus.inProgress,
          startedAt: DateTime(2026, 10, 1, 14, 20),
          scheduledAt: DateTime(2026, 10, 1, 10),
          estimatedDurationMinutes: 90,
          // Аль хэдийн хэтэрсэн таамаг — өмнө нь улаан "хожимдож байна"
          // анхааруулга гаргадаг байсан нөхцөл.
          expectedFinishAt: DateTime(2026, 10, 1, 12),
          items: const [
            AppointmentServiceItemProgress(
              id: 'item-1',
              name: 'Тос солих',
              status: ServiceProgressStatus.inProgress,
            ),
          ],
        ),
      );
      final controller = AppointmentsController(
        _OneAppointmentRepo(appointment),
      );
      await controller.load();

      await _pump(tester, controller, 'apt-started');

      // Захиалга үүссэн тул ангиллын мөр алга — доорх item жагсаалт орлоно.
      expect(find.text('Тоормос · Тос солих'), findsNothing);
      expect(find.text('Ангилал'), findsNothing);
      expect(find.text('Ангиллууд'), findsNothing);

      // Бодит эхэлсэн цаг харагдана, товлосон огноо түүнд байраа тавина.
      expect(find.text('Ажил эхэлсэн: 2026.10.01 14:20'), findsOneWidget);
      expect(find.textContaining('Товлосон огноо'), findsNothing);

      // Таамаг болон хожимдлын анхааруулга бүрмөсөн алга.
      expect(find.textContaining('Ойролцоо хугацаа'), findsNothing);
      expect(find.textContaining('Дуусах хугацаа'), findsNothing);
      expect(find.textContaining('Дуусах ёстой байсан'), findsNothing);
      expect(find.text('Төлөвлөснөөс хожимдож байна'), findsNothing);
      controller.dispose();
    },
  );

  testWidgets('keeps the scheduled date while the work has not started', (
    tester,
  ) async {
    final appointment = Appointment(
      id: 'apt-scheduled',
      status: AppointmentStatus.confirmed,
      requestedAt: DateTime(2026, 10, 1, 10),
      tenantName: 'Auto Doctor Service',
      tenantSlug: 'auto-doctor',
      branchName: 'Баянзүрх салбар',
      serviceProgress: AppointmentServiceProgress(
        id: 'order-3',
        number: 'A-102',
        status: ServiceProgressStatus.scheduled,
        scheduledAt: DateTime(2026, 10, 2, 9, 30),
        items: const [],
      ),
    );
    final controller = AppointmentsController(_OneAppointmentRepo(appointment));
    await controller.load();

    await _pump(tester, controller, 'apt-scheduled');

    expect(find.text('Товлосон огноо: 2026.10.02 09:30'), findsOneWidget);
    expect(find.textContaining('Ажил эхэлсэн'), findsNothing);
    controller.dispose();
  });

  testWidgets(
    'puts the service progress above the branch info card, and marks cancel '
    'as destructive',
    (tester) async {
      // Бүх хэсгийг нэг дор build хийлгэхийн тулд өндөр viewport — ListView
      // нь lazy тул анхдагч 800x600 дээр доод картууд build хийгдэхгүй.
      tester.view.physicalSize = const Size(1200, 3600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final appointment = Appointment(
        id: 'apt-order',
        status: AppointmentStatus.confirmed,
        requestedAt: DateTime(2026, 10, 1, 10),
        tenantName: 'Auto Doctor Service',
        tenantSlug: 'auto-doctor',
        branchName: 'Баянзүрх салбар',
        serviceProgress: AppointmentServiceProgress(
          id: 'order-4',
          number: 'A-103',
          status: ServiceProgressStatus.inProgress,
          startedAt: DateTime(2026, 10, 1, 14, 20),
          items: const [
            AppointmentServiceItemProgress(
              id: 'item-1',
              name: 'Тос солих',
              status: ServiceProgressStatus.inProgress,
            ),
          ],
        ),
      );
      final controller = AppointmentsController(
        _OneAppointmentRepo(appointment),
      );
      await controller.load();

      await _pump(tester, controller, 'apt-order');

      final progressY = tester
          .getTopLeft(find.byKey(const ValueKey('appointment-progress')))
          .dy;
      final branchY = tester
          .getTopLeft(find.text('Байршил ба цагийн хуваарь'))
          .dy;
      expect(
        progressY,
        lessThan(branchY),
        reason: 'Явц нь салбарын лавлах мэдээллээс дээр байх ёстой',
      );
      controller.dispose();
    },
  );

  testWidgets('styles the cancel button with the danger colour', (
    tester,
  ) async {
    final controller = await _loadedController();

    // seed-2 нь PENDING, захиалгагүй — цуцлах товч харагдана.
    await _pump(tester, controller, 'seed-2');

    final button = tester.widget<OutlinedButton>(
      find.byKey(const ValueKey('detail-cancel-seed-2')),
    );
    expect(
      button.style?.foregroundColor?.resolve(<WidgetState>{}),
      AppColors.readable(AppColors.red, Brightness.light),
      reason:
          'Эргэлт буцалтгүй үйлдэл нь салбарын картын энгийн OutlinedButton-'
          'оос өнгөөрөө ялгарах ёстой',
    );
    controller.dispose();
  });

  testWidgets('the 25s poll refreshes silently: no loading state, no '
      'overlapping request', (tester) async {
    final seeded = await FakeAppointmentRepository().getAppointments();
    final gate = Completer<List<Appointment>>();
    var calls = 0;
    final repo = _GatedRepo(seeded, () {
      calls++;
      return calls == 1 ? Future.value(seeded) : gate.future;
    });
    final controller = AppointmentsController(repo);
    await controller.load();
    final statuses = <AppointmentsStatus>[];
    controller.addListener(() => statuses.add(controller.state.status));
    await _pump(tester, controller, seeded.first.id);

    await tester.pump(const Duration(seconds: 26));
    await tester.pump(const Duration(seconds: 25));

    expect(calls, 2, reason: 'second tick skipped while first is in flight');
    expect(statuses, isNot(contains(AppointmentsStatus.loading)));
    gate.complete(seeded);
    await tester.pump();
    // Unmount so the periodic timer is cancelled.
    await tester.pumpWidget(const SizedBox());
  });
}
