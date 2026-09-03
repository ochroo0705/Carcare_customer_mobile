import 'package:carcare_customer_mobile/app/theme/app_theme.dart';
import 'package:carcare_customer_mobile/features/booking/data/fake_appointment_repository.dart';
import 'package:carcare_customer_mobile/features/booking/domain/appointment.dart';
import 'package:carcare_customer_mobile/features/booking/domain/appointment_payment.dart';
import 'package:carcare_customer_mobile/features/booking/domain/appointment_repository.dart';
import 'package:carcare_customer_mobile/features/booking/presentation/screens/booking_request_screen.dart';
import 'package:carcare_customer_mobile/features/discovery/domain/branch.dart';
import 'package:carcare_customer_mobile/features/discovery/domain/organization.dart';
import 'package:carcare_customer_mobile/features/vehicles/data/fake_vehicle_repository.dart';
import 'package:carcare_customer_mobile/features/vehicles/presentation/controllers/vehicles_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class _CapturingAppointmentRepository implements AppointmentRepository {
  bool called = false;
  String? capturedVehicleId;

  @override
  Future<CreatedAppointment> createAppointment({
    required String branchId,
    required DateTime requestedAt,
    String? note,
    String? accountVehicleId,
  }) async {
    called = true;
    capturedVehicleId = accountVehicleId;
    return CreatedAppointment(
      id: 'apt-1',
      status: 'PENDING',
      requestedAt: requestedAt,
    );
  }

  @override
  Future<List<Appointment>> getAppointments() async => const [];

  @override
  Future<void> cancelAppointment(String id) async {}

  @override
  Future<AppointmentPayment?> getPayment(String appointmentId) async => null;

  @override
  Future<AppointmentPaymentCheckResult> checkPayment(
    String appointmentId,
  ) async => const AppointmentPaymentCheckResult(paid: true);

  @override
  Future<AppointmentPayment?> retryPayment(String appointmentId) async => null;
}

const _organization = OrganizationDetail(
  slug: 'infosystems',
  name: 'Инфосистемс',
  branches: [],
);

const _branch = BranchDetail(
  id: 'branch-1',
  name: 'Үндсэн салбар',
  city: 'Улаанбаатар',
  district: 'Баянзүрх',
  khoroo: '1-р хороо',
  address: 'Энхтайваны өргөн чөлөө',
  openTime: '09:00',
  closeTime: '18:00',
);

/// Navigates the calendar to next month and picks its first day — always in
/// the future regardless of today's date, avoiding month-boundary flakiness
/// from just picking "tomorrow" — then the branch's first working-hours slot.
Future<void> _acceptDefaultDateTime(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('booking-calendar-next')));
  await tester.pumpAndSettle();
  final now = DateTime.now();
  final nextMonth = DateTime(now.year, now.month + 1);
  await tester.tap(
    find.byKey(ValueKey('booking-date-${nextMonth.year}-${nextMonth.month}-1')),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('booking-slot-9-0')));
  await tester.pumpAndSettle();
}

/// The booking form is a tall ListView (header → calendar → vehicle picker →
/// note → submit). In the default 800×600 test viewport the calendar — whose
/// height varies by month (5 vs 6 week-rows) — pushes the vehicle picker and
/// submit button below the fold, where the lazy ListView never builds them,
/// making these tests fail intermittently by real-world date. A tall surface
/// renders the whole form so every control is built and hit-testable.
Future<void> _useTallSurface(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(1000, 2400));
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

void main() {
  testWidgets(
    'auto-selects and submits the only vehicle without touching the picker',
    (tester) async {
      await _useTallSurface(tester);
      final repository = _CapturingAppointmentRepository();
      final vehiclesController = VehiclesController(FakeVehicleRepository());
      await vehiclesController.load();

      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: vehiclesController,
          child: MaterialApp(
            theme: AppTheme.light,
            home: BookingRequestScreen(
              organization: _organization,
              branch: _branch,
              repository: repository,
              onAddVehicle: () {},
              onBack: () {},
              onCompleted: (_) {},
              onUnauthenticated: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // A one-vehicle customer gets it pre-selected (mirrors web 27a9875),
      // so the closed picker shows the vehicle rather than "Сонгохгүй".
      expect(find.text('9911УБЕ · Hyundai Sonata'), findsOneWidget);

      await _acceptDefaultDateTime(tester);
      await tester.tap(find.byKey(const ValueKey('submit-booking')));
      await tester.pumpAndSettle();

      expect(repository.called, isTrue);
      expect(repository.capturedVehicleId, 'seed-vehicle-1');
    },
  );

  testWidgets(
    'submits with no vehicle after the customer clears the selection',
    (tester) async {
      await _useTallSurface(tester);
      final repository = _CapturingAppointmentRepository();
      final vehiclesController = VehiclesController(FakeVehicleRepository());
      await vehiclesController.load();

      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: vehiclesController,
          child: MaterialApp(
            theme: AppTheme.light,
            home: BookingRequestScreen(
              organization: _organization,
              branch: _branch,
              repository: repository,
              onAddVehicle: () {},
              onBack: () {},
              onCompleted: (_) {},
              onUnauthenticated: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // The only vehicle starts auto-selected; explicitly clear it to "Сонгохгүй".
      await tester.tap(find.byKey(const ValueKey('booking-vehicle')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Сонгохгүй').last);
      await tester.pumpAndSettle();

      await _acceptDefaultDateTime(tester);
      await tester.tap(find.byKey(const ValueKey('submit-booking')));
      await tester.pumpAndSettle();

      expect(repository.called, isTrue);
      expect(repository.capturedVehicleId, isNull);
    },
  );

  testWidgets('offers an add-vehicle link when the customer has none yet', (
    tester,
  ) async {
    await _useTallSurface(tester);
    final vehiclesController = VehiclesController(FakeVehicleRepository());
    // Delete the seeded vehicle so the picker falls back to the empty state.
    await vehiclesController.load();
    await vehiclesController.delete(
      vehiclesController.state.vehicles.single.id,
    );
    var addVehicleTapped = false;

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: vehiclesController,
        child: MaterialApp(
          theme: AppTheme.light,
          home: BookingRequestScreen(
            organization: _organization,
            branch: _branch,
            repository: FakeAppointmentRepository(),
            onAddVehicle: () => addVehicleTapped = true,
            onBack: () {},
            onCompleted: (_) {},
            onUnauthenticated: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('booking-vehicle')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('booking-add-vehicle')));
    expect(addVehicleTapped, isTrue);
  });
}
