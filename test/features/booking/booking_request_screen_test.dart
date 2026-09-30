import 'dart:async';

import 'package:carcare_customer_mobile/app/theme/app_theme.dart';
import 'package:carcare_customer_mobile/core/errors/app_failure.dart';
import 'package:carcare_customer_mobile/features/booking/data/fake_appointment_repository.dart';
import 'package:carcare_customer_mobile/features/booking/domain/appointment.dart';
import 'package:carcare_customer_mobile/features/booking/domain/appointment_payment.dart';
import 'package:carcare_customer_mobile/features/booking/domain/appointment_repository.dart';
import 'package:carcare_customer_mobile/features/booking/domain/availability.dart';
import 'package:carcare_customer_mobile/features/booking/domain/walk_in_order.dart';
import 'package:carcare_customer_mobile/features/booking/presentation/screens/booking_request_screen.dart';
import 'package:carcare_customer_mobile/features/discovery/domain/branch.dart';
import 'package:carcare_customer_mobile/features/discovery/domain/organization.dart';
import 'package:carcare_customer_mobile/features/vehicles/data/fake_vehicle_repository.dart';
import 'package:carcare_customer_mobile/features/vehicles/presentation/controllers/vehicles_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

DayAvailability _fakeAvailability() => DayAvailability(
  open: true,
  durationMinutes: 30,
  slots: [
    for (var m = 9 * 60; m < 12 * 60; m += 30)
      AvailabilitySlot(
        hour: m ~/ 60,
        minute: m % 60,
        available: true,
        remaining: 1,
        // `_acceptDefaultDateTime` always picks a day in next month, so any
        // far-future anchor date keeps this a valid (non-past) instant.
        utc: DateTime.utc(
          DateTime.now().year + 1,
          1,
          1,
          m ~/ 60,
          m % 60,
        ).subtract(const Duration(hours: 8)),
      ),
  ],
);

class _CapturingAppointmentRepository extends Fake
    implements AppointmentRepository {
  bool called = false;
  int createCalls = 0;
  Completer<void>? createGate;
  String? capturedVehicleId;

  @override
  Future<DayAvailability> getAvailability({
    required String branchId,
    required DateTime date,
    List<String> categoryIds = const [],
  }) async => _fakeAvailability();

  @override
  Future<CreatedAppointment> createAppointment({
    required String branchId,
    required DateTime requestedAt,
    String? note,
    String? accountVehicleId,
    List<String> categoryIds = const [],
  }) async {
    called = true;
    createCalls += 1;
    capturedVehicleId = accountVehicleId;
    await createGate?.future;
    return CreatedAppointment(
      id: 'apt-1',
      status: 'PENDING',
      requestedAt: requestedAt,
    );
  }

  @override
  Future<List<Appointment>> getAppointments() async => const [];

  @override
  Future<List<WalkInOrder>> getWalkInOrders() async => const [];

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

/// Rejects the booking with a 409-style conflict (slot already taken).
class _ConflictAppointmentRepository extends Fake
    implements AppointmentRepository {
  @override
  Future<DayAvailability> getAvailability({
    required String branchId,
    required DateTime date,
    List<String> categoryIds = const [],
  }) async => _fakeAvailability();

  @override
  Future<CreatedAppointment> createAppointment({
    required String branchId,
    required DateTime requestedAt,
    String? note,
    String? accountVehicleId,
    List<String> categoryIds = const [],
  }) async => throw const ConflictFailure('Энэ цаг дүүрсэн байна.');

  @override
  Future<List<Appointment>> getAppointments() async => const [];
  @override
  Future<List<WalkInOrder>> getWalkInOrders() async => const [];
  @override
  Future<void> cancelAppointment(String id) async {}
  @override
  Future<AppointmentPayment?> getPayment(String id) async => null;
  @override
  Future<AppointmentPaymentCheckResult> checkPayment(String id) async =>
      const AppointmentPaymentCheckResult(paid: false);
  @override
  Future<AppointmentPayment?> retryPayment(String id) async => null;
}

/// Lets a test control exactly when each `getAvailability` call resolves, to
/// reproduce out-of-order network responses (a later-fired request's response
/// arriving before an earlier one's).
class _RaceAvailabilityRepository extends Fake
    implements AppointmentRepository {
  final List<Completer<DayAvailability>> completers = [];
  final List<DateTime> requestedDates = [];

  @override
  Future<DayAvailability> getAvailability({
    required String branchId,
    required DateTime date,
    List<String> categoryIds = const [],
  }) {
    final completer = Completer<DayAvailability>();
    completers.add(completer);
    requestedDates.add(date);
    return completer.future;
  }
}

DayAvailability _availabilityWithSlot(int hour, int minute) => DayAvailability(
  open: true,
  durationMinutes: 30,
  slots: [
    AvailabilitySlot(
      hour: hour,
      minute: minute,
      available: true,
      remaining: 1,
      utc: DateTime.utc(DateTime.now().year + 1, 1, 1, hour, minute),
    ),
  ],
);

/// Returns 09:00 on the first `getAvailability` call and 11:00 on every call
/// after — simulates the slot the customer picked getting taken (or the
/// schedule changing) while the app was backgrounded.
class _CountingAvailabilityRepository extends Fake
    implements AppointmentRepository {
  int calls = 0;

  @override
  Future<DayAvailability> getAvailability({
    required String branchId,
    required DateTime date,
    List<String> categoryIds = const [],
  }) async {
    calls += 1;
    return _availabilityWithSlot(calls == 1 ? 9 : 11, 0);
  }
}

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

const _categoryA = BranchServiceCategory(
  id: 'cat-a',
  name: 'Тос солих',
  durationMinutes: 30,
  systemServiceKeyId: 'key-a',
);
const _categoryB = BranchServiceCategory(
  id: 'cat-b',
  name: 'Дугуй солих',
  durationMinutes: 20,
  systemServiceKeyId: 'key-b',
);

const _branchWithCategories = BranchDetail(
  id: 'branch-with-categories',
  name: 'Ангилалтай салбар',
  city: 'Улаанбаатар',
  district: 'Баянзүрх',
  khoroo: '1-р хороо',
  address: 'Энхтайваны өргөн чөлөө',
  openTime: '09:00',
  closeTime: '18:00',
  categories: [_categoryA, _categoryB],
);

const _organizationWithCategories = OrganizationDetail(
  slug: 'infosystems',
  name: 'Инфосистемс',
  branches: [_branchWithCategories],
);

// Ганц салбартай тул BookingRequestScreen үүнийг шууд автоматаар сонгоно
// (category-first урсгал: олон салбартай бол салбар сонгох алхам шаардлагатай,
// ганцтай бол шаардлагагүй).
const _organization = OrganizationDetail(
  slug: 'infosystems',
  name: 'Инфосистемс',
  branches: [_branch],
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

  testWidgets('two rapid taps on submit create only one appointment', (
    tester,
  ) async {
    await _useTallSurface(tester);
    final repository = _CapturingAppointmentRepository()
      ..createGate = Completer<void>();
    final vehiclesController = VehiclesController(FakeVehicleRepository());
    await vehiclesController.load();

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: vehiclesController,
        child: MaterialApp(
          theme: AppTheme.light,
          home: BookingRequestScreen(
            organization: _organization,
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
    await _acceptDefaultDateTime(tester);

    // Two taps with no frame between them: the button is still enabled for
    // the second one, so only the submit guard can stop a duplicate.
    await tester.tap(find.byKey(const ValueKey('submit-booking')));
    await tester.tap(find.byKey(const ValueKey('submit-booking')));
    repository.createGate!.complete();
    await tester.pumpAndSettle();

    expect(repository.createCalls, 1);
  });

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

  testWidgets('surfaces the conflict message when the slot is already taken', (
    tester,
  ) async {
    await _useTallSurface(tester);
    final vehiclesController = VehiclesController(FakeVehicleRepository());
    await vehiclesController.load();
    var completed = false;

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: vehiclesController,
        child: MaterialApp(
          theme: AppTheme.light,
          home: BookingRequestScreen(
            organization: _organization,
            repository: _ConflictAppointmentRepository(),
            onAddVehicle: () {},
            onBack: () {},
            onCompleted: (_) => completed = true,
            onUnauthenticated: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await _acceptDefaultDateTime(tester);
    await tester.tap(find.byKey(const ValueKey('submit-booking')));
    await tester.pumpAndSettle();

    // The 409 message is shown in-place and the booking is NOT completed.
    expect(find.text('Энэ цаг дүүрсэн байна.'), findsOneWidget);
    expect(completed, isFalse);
  });

  testWidgets(
    'ignores a stale availability response that arrives after a newer one',
    (tester) async {
      await _useTallSurface(tester);
      final repository = _RaceAvailabilityRepository();
      final vehiclesController = VehiclesController(FakeVehicleRepository());
      await vehiclesController.load();

      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: vehiclesController,
          child: MaterialApp(
            theme: AppTheme.light,
            home: BookingRequestScreen(
              organization: _organization,
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

      await tester.tap(find.byKey(const ValueKey('booking-calendar-next')));
      await tester.pumpAndSettle();
      final now = DateTime.now();
      final nextMonth = DateTime(now.year, now.month + 1);

      // Tap day 1, then quickly switch to day 2, before either request has
      // resolved — mirrors a customer double-tapping between dates on a slow
      // connection.
      await tester.tap(
        find.byKey(
          ValueKey('booking-date-${nextMonth.year}-${nextMonth.month}-1'),
        ),
      );
      await tester.pump();
      await tester.tap(
        find.byKey(
          ValueKey('booking-date-${nextMonth.year}-${nextMonth.month}-2'),
        ),
      );
      await tester.pump();

      expect(repository.completers, hasLength(2));

      // Resolve the SECOND (newer, day-2) request first, then the stale
      // first (day-1) request — the out-of-order arrival this test targets.
      repository.completers[1].complete(_availabilityWithSlot(10, 0));
      await tester.pump();
      repository.completers[0].complete(_availabilityWithSlot(9, 0));
      await tester.pump();

      // The stale day-1 response (09:00) must not clobber the day-2 result
      // (10:00) that arrived first.
      expect(find.byKey(const ValueKey('booking-slot-10-0')), findsOneWidget);
      expect(find.byKey(const ValueKey('booking-slot-9-0')), findsNothing);
    },
  );

  testWidgets(
    're-validates the selected slot when the app resumes from background',
    (tester) async {
      await _useTallSurface(tester);
      final repository = _CountingAvailabilityRepository();
      final vehiclesController = VehiclesController(FakeVehicleRepository());
      await vehiclesController.load();

      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: vehiclesController,
          child: MaterialApp(
            theme: AppTheme.light,
            home: BookingRequestScreen(
              organization: _organization,
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

      await _acceptDefaultDateTime(tester);
      expect(repository.calls, 1);
      expect(find.byKey(const ValueKey('booking-slot-9-0')), findsOneWidget);

      // Simulate backgrounding the app (e.g. to unlock the phone) and coming
      // back — the customer's selected 09:00 slot may have been taken, or the
      // schedule may have changed, while the screen sat idle. The lifecycle
      // state machine only allows linear steps (resumed <-> inactive <->
      // hidden <-> paused), so the full chain must be walked both ways.
      for (final state in [
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
        AppLifecycleState.paused,
        AppLifecycleState.hidden,
        AppLifecycleState.inactive,
        AppLifecycleState.resumed,
      ]) {
        tester.binding.handleAppLifecycleStateChanged(state);
        await tester.pump();
      }
      await tester.pumpAndSettle();

      // Availability was re-fetched (not just left stale)...
      expect(repository.calls, 2);
      // ...and the now-different slot list is shown, with the earlier
      // selection cleared rather than silently carried over.
      expect(find.byKey(const ValueKey('booking-slot-11-0')), findsOneWidget);
      expect(find.byKey(const ValueKey('booking-slot-9-0')), findsNothing);
      expect(find.byKey(const ValueKey('submit-booking')), findsOneWidget);
    },
  );

  group('lockCategories revalidation', () {
    testWidgets(
      'blocks the flow and offers to go back when the locked branch id no '
      'longer exists',
      (tester) async {
        await _useTallSurface(tester);
        final vehiclesController = VehiclesController(FakeVehicleRepository());
        await vehiclesController.load();
        var backTapped = false;

        await tester.pumpWidget(
          ChangeNotifierProvider.value(
            value: vehiclesController,
            child: MaterialApp(
              theme: AppTheme.light,
              home: BookingRequestScreen(
                organization: _organizationWithCategories,
                initialBranchId: 'branch-that-no-longer-exists',
                initialCategoryIds: const ['cat-a'],
                lockCategories: true,
                repository: FakeAppointmentRepository(),
                onAddVehicle: () {},
                onBack: () => backTapped = true,
                onCompleted: (_) {},
                onUnauthenticated: () {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.text('Сонгосон салбар олдсонгүй. Дахин сонгоно уу.'),
          findsOneWidget,
        );
        expect(find.byKey(const ValueKey('submit-booking')), findsNothing);

        await tester.tap(find.text('Буцах'));
        expect(backTapped, isTrue);
      },
    );

    testWidgets(
      'drops a locked category the branch no longer offers, but keeps '
      'booking with the rest',
      (tester) async {
        await _useTallSurface(tester);
        final vehiclesController = VehiclesController(FakeVehicleRepository());
        await vehiclesController.load();

        await tester.pumpWidget(
          ChangeNotifierProvider.value(
            value: vehiclesController,
            child: MaterialApp(
              theme: AppTheme.light,
              home: BookingRequestScreen(
                organization: _organizationWithCategories,
                initialBranchId: 'branch-with-categories',
                initialCategoryIds: const ['cat-a', 'cat-removed'],
                lockCategories: true,
                repository: FakeAppointmentRepository(),
                onAddVehicle: () {},
                onBack: () {},
                onCompleted: (_) {},
                onUnauthenticated: () {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Still bookable: the form renders, keeps the still-offered category.
        expect(find.byKey(const ValueKey('submit-booking')), findsOneWidget);
        expect(find.text('Тос солих'), findsOneWidget);
        // Warns about the one that's gone (falls back to the raw id since no
        // branch in the org names it).
        expect(find.textContaining('cat-removed'), findsOneWidget);
      },
    );

    testWidgets(
      'blocks the flow when every locked category is no longer offered',
      (tester) async {
        await _useTallSurface(tester);
        final vehiclesController = VehiclesController(FakeVehicleRepository());
        await vehiclesController.load();

        await tester.pumpWidget(
          ChangeNotifierProvider.value(
            value: vehiclesController,
            child: MaterialApp(
              theme: AppTheme.light,
              home: BookingRequestScreen(
                organization: _organizationWithCategories,
                initialBranchId: 'branch-with-categories',
                initialCategoryIds: const ['cat-removed-1', 'cat-removed-2'],
                lockCategories: true,
                repository: FakeAppointmentRepository(),
                onAddVehicle: () {},
                onBack: () {},
                onCompleted: (_) {},
                onUnauthenticated: () {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.text(
            'Сонгосон бүх үйлчилгээг энэ салбар цаашид санал болгохгүй '
            'боллоо. Дахин сонгоно уу.',
          ),
          findsOneWidget,
        );
        expect(find.byKey(const ValueKey('submit-booking')), findsNothing);
      },
    );
  });
}
