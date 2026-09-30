import 'dart:async';

import 'package:carcare_customer_mobile/core/errors/app_failure.dart';
import 'package:carcare_customer_mobile/features/booking/domain/appointment_repository.dart';
import 'package:carcare_customer_mobile/features/booking/domain/availability.dart';
import 'package:carcare_customer_mobile/features/booking/presentation/controllers/booking_form_controller.dart';
import 'package:carcare_customer_mobile/features/discovery/domain/branch.dart';
import 'package:carcare_customer_mobile/features/discovery/domain/organization.dart';
import 'package:carcare_customer_mobile/features/vehicles/data/fake_vehicle_repository.dart';
import 'package:carcare_customer_mobile/features/vehicles/presentation/controllers/vehicles_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../support/mocks.dart';

const _catA = BranchServiceCategory(
  id: 'cat-a',
  name: 'A',
  durationMinutes: 30,
  systemServiceKeyId: 'key-a',
);
const _catB = BranchServiceCategory(
  id: 'cat-b',
  name: 'B',
  durationMinutes: 20,
  systemServiceKeyId: 'key-b',
);

BranchDetail _branch(String id, List<BranchServiceCategory> categories) =>
    BranchDetail(
      id: id,
      name: 'Branch $id',
      city: 'UB',
      district: 'D',
      khoroo: '1',
      address: 'addr',
      openTime: '09:00',
      closeTime: '18:00',
      categories: categories,
    );

final _slotUtc = DateTime.now().toUtc().add(const Duration(days: 30));

DayAvailability _availability() => DayAvailability(
  open: true,
  durationMinutes: 30,
  slots: [
    AvailabilitySlot(
      hour: 9,
      minute: 0,
      available: true,
      remaining: 1,
      utc: _slotUtc,
    ),
  ],
);

void main() {
  late MockAppointmentRepository repository;
  late VehiclesController vehicles;

  setUpAll(() => registerFallbackValue(DateTime(2030)));

  setUp(() async {
    repository = MockAppointmentRepository();
    vehicles = VehiclesController(FakeVehicleRepository());
    await vehicles.load();
    when(
      () => repository.getAvailability(
        branchId: any(named: 'branchId'),
        date: any(named: 'date'),
        categoryIds: any(named: 'categoryIds'),
      ),
    ).thenAnswer((_) async => _availability());
  });

  BookingFormController build({
    List<BranchDetail>? branches,
    bool lockCategories = false,
    bool lockBranch = false,
    String? initialBranchId,
    List<String>? initialCategoryIds,
  }) => BookingFormController(
    organization: OrganizationDetail(
      slug: 'org',
      name: 'Org',
      branches:
          branches ??
          [
            _branch('b1', const [_catA]),
          ],
    ),
    repository: repository,
    vehiclesController: vehicles,
    lockCategories: lockCategories,
    lockBranch: lockBranch,
    initialBranchId: initialBranchId,
    initialCategoryIds: initialCategoryIds,
  );

  Future<BookingFormController> readyToSubmit() async {
    final form = build();
    form.selectDate(DateTime.now().add(const Duration(days: 30)));
    await pumpEventQueue();
    form.selectSlot((hour: 9, minute: 0));
    return form;
  }

  test('double submit calls the repository once', () async {
    final gate = Completer<CreatedAppointment>();
    when(
      () => repository.createAppointment(
        branchId: any(named: 'branchId'),
        requestedAt: any(named: 'requestedAt'),
        note: any(named: 'note'),
        accountVehicleId: any(named: 'accountVehicleId'),
        categoryIds: any(named: 'categoryIds'),
      ),
    ).thenAnswer((_) => gate.future);
    final form = await readyToSubmit();

    final first = form.submit('');
    final second = await form.submit('');
    expect(second.status, BookingSubmitStatus.ignored);
    gate.complete(
      CreatedAppointment(id: 'a', status: 'PENDING', requestedAt: _slotUtc),
    );
    expect((await first).status, BookingSubmitStatus.completed);

    verify(
      () => repository.createAppointment(
        branchId: any(named: 'branchId'),
        requestedAt: any(named: 'requestedAt'),
        note: any(named: 'note'),
        accountVehicleId: any(named: 'accountVehicleId'),
        categoryIds: any(named: 'categoryIds'),
      ),
    ).called(1);
    form.dispose();
  });

  test(
    'a failed submit re-enables and surfaces the conflict message',
    () async {
      when(
        () => repository.createAppointment(
          branchId: any(named: 'branchId'),
          requestedAt: any(named: 'requestedAt'),
          note: any(named: 'note'),
          accountVehicleId: any(named: 'accountVehicleId'),
          categoryIds: any(named: 'categoryIds'),
        ),
      ).thenThrow(const ConflictFailure('Энэ цаг дүүрсэн байна.'));
      final form = await readyToSubmit();

      final outcome = await form.submit('');
      expect(outcome.status, BookingSubmitStatus.failed);
      expect(form.submitting, isFalse);
      expect(form.error, 'Энэ цаг дүүрсэн байна.');
      form.dispose();
    },
  );

  test('submit without a slot is ignored with a validation error', () async {
    final form = build();
    final outcome = await form.submit('');
    expect(outcome.status, BookingSubmitStatus.ignored);
    expect(form.error, 'Ирээдүйн өдөр, цаг сонгоно уу.');
    form.dispose();
  });

  test(
    'selecting a date loads slots and picking one sets requestedAt',
    () async {
      final form = build();
      form.selectDate(DateTime.now().add(const Duration(days: 30)));
      expect(form.loadingSlots, isTrue);
      await pumpEventQueue();
      expect(form.loadingSlots, isFalse);
      expect(form.selectedSlot, isNull);
      form.selectSlot((hour: 9, minute: 0));
      expect(form.requestedAt, _slotUtc);
      form.dispose();
    },
  );

  test(
    'toggling a category clears the slot and drops an incompatible branch',
    () {
      final form = build(
        branches: [
          _branch('b1', const [_catA]),
          _branch('b2', const [_catA, _catB]),
        ],
      );
      form.toggleCategory('cat-a', true);
      expect(form.selectedBranch, isNull);
      form.toggleCategory('cat-b', true);
      expect(form.compatibleBranches.map((b) => b.id), ['b2']);
      expect(form.selectedBranch?.id, 'b2');
      expect(form.selectedDurationMinutes, 50);
      form.dispose();
    },
  );

  test('a single vehicle is auto-selected until the customer touches it', () {
    final form = build();
    expect(form.selectedVehicleId, 'seed-vehicle-1');
    form.selectVehicle(null);
    expect(form.selectedVehicleId, isNull);
    form.dispose();
  });

  test('locked categories the branch no longer offers are reported', () {
    final form = build(
      lockCategories: true,
      initialBranchId: 'b1',
      initialCategoryIds: const ['cat-a', 'gone'],
    );
    expect(form.selectedCategoryIds, {'cat-a'});
    expect(form.lockedUnavailableCategoryNames, ['gone']);
    expect(form.lockedFlowBlocked, isFalse);
    form.dispose();
  });
}
