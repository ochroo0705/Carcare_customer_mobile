import 'dart:async';

import 'package:carcare_customer_mobile/core/errors/app_failure.dart';
import 'package:carcare_customer_mobile/data/cache/in_memory_cache_store.dart';
import 'package:carcare_customer_mobile/features/booking/data/fake_appointment_repository.dart';
import 'package:carcare_customer_mobile/features/booking/domain/appointment.dart';
import 'package:carcare_customer_mobile/features/booking/domain/appointment_payment.dart';
import 'package:carcare_customer_mobile/features/booking/domain/service_progress.dart';
import 'package:carcare_customer_mobile/features/booking/domain/walk_in_order.dart';
import 'package:carcare_customer_mobile/features/booking/domain/appointment_status.dart';
import 'package:carcare_customer_mobile/features/booking/presentation/controllers/appointments_controller.dart';
import 'package:carcare_customer_mobile/features/booking/presentation/controllers/appointments_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/mocks.dart';

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

  const walkIn = WalkInOrder(
    tenantName: 'Walk',
    tenantSlug: 'walk',
    branchName: 'Main',
    progress: AppointmentServiceProgress(
      id: 'w1',
      number: '1',
      status: ServiceProgressStatus.pending,
      items: [],
    ),
  );

  test('a failed refresh keeps live appointments and walk-ins on screen '
      'instead of falling back to the cache', () async {
    final seeded = await FakeAppointmentRepository().getAppointments();
    final repository = MockAppointmentRepository();
    when(() => repository.getAppointments()).thenAnswer((_) async => seeded);
    when(() => repository.getWalkInOrders()).thenAnswer((_) async => [walkIn]);
    final cache = InMemoryCacheStore();
    final controller = AppointmentsController(repository, cache: cache);
    await controller.load();
    // A different (older) cache must not replace what is on screen.
    await cache.writeAppointments([seeded.first]);
    when(() => repository.getAppointments())
        .thenThrow(const NetworkFailure('offline'));

    await controller.load();

    expect(controller.state.status, AppointmentsStatus.data);
    expect(controller.state.isFromCache, isFalse);
    expect(controller.state.message, isNotNull);
    expect(controller.state.appointments, seeded);
    expect(controller.state.walkInOrders, [walkIn]);
  });

  test('walk-in orders stay on screen when a refresh fails offline '
      '(the cache holds appointments only)', () async {
    final repository = MockAppointmentRepository();
    when(() => repository.getAppointments()).thenAnswer((_) async => []);
    when(() => repository.getWalkInOrders()).thenAnswer((_) async => [walkIn]);
    final controller = AppointmentsController(
      repository,
      cache: InMemoryCacheStore(),
    );
    await controller.load();
    expect(controller.state.status, AppointmentsStatus.data);
    when(() => repository.getWalkInOrders())
        .thenThrow(const NetworkFailure('offline'));

    await controller.load();

    expect(controller.state.status, AppointmentsStatus.data);
    expect(controller.state.walkInOrders, [walkIn]);
  });

  group('refreshSilently', () {
    late MockAppointmentRepository repository;
    late AppointmentsController controller;
    late List<Appointment> seeded;

    setUp(() async {
      seeded = await FakeAppointmentRepository().getAppointments();
      repository = MockAppointmentRepository();
      when(() => repository.getAppointments()).thenAnswer((_) async => seeded);
      when(() => repository.getWalkInOrders()).thenAnswer((_) async => []);
      controller = AppointmentsController(
        repository,
        cache: InMemoryCacheStore(),
      );
      await controller.load();
      clearInteractions(repository);
    });

    test('never enters the loading state and does not notify when the '
        'data is unchanged', () async {
      // Fresh instances with identical content, as a real refetch returns.
      when(() => repository.getAppointments())
          .thenAnswer((_) async => [...seeded]);
      final statuses = <AppointmentsStatus>[];
      var notifications = 0;
      controller.addListener(() {
        notifications++;
        statuses.add(controller.state.status);
      });

      await controller.refreshSilently();

      expect(notifications, 0);
      expect(statuses, isNot(contains(AppointmentsStatus.loading)));
      verify(() => repository.getAppointments()).called(1);
    });

    test('notifies once, without loading, when the data changed', () async {
      final changed = [
        seeded.first.copyWith(status: AppointmentStatus.cancelled),
        ...seeded.skip(1),
      ];
      when(() => repository.getAppointments()).thenAnswer((_) async => changed);
      final statuses = <AppointmentsStatus>[];
      controller.addListener(() => statuses.add(controller.state.status));

      await controller.refreshSilently();

      expect(statuses, [AppointmentsStatus.data]);
      expect(
        controller.state.appointments.first.status,
        AppointmentStatus.cancelled,
      );
    });

    test('overlapping calls issue a single request', () async {
      final gate = Completer<List<Appointment>>();
      when(() => repository.getAppointments()).thenAnswer((_) => gate.future);

      final first = controller.refreshSilently();
      final second = controller.refreshSilently();
      gate.complete(seeded);
      await Future.wait([first, second]);

      verify(() => repository.getAppointments()).called(1);
    });

    test('notifies when only the payment QR or bank links change', () async {
      AppointmentPayment pay(String qr, String link) => AppointmentPayment(
        status: AppointmentFeeStatus.pending,
        amount: 5000,
        currency: 'MNT',
        qrImageBase64: qr,
        urls: [QpayBankUrl(name: 'b', nameMn: 'b', logo: 'l', link: link)],
      );
      final base = [seeded.first.copyWith(payment: pay('qr1', 'a://1'))];
      when(() => repository.getAppointments()).thenAnswer((_) async => base);
      await controller.refreshSilently();
      var notifications = 0;
      controller.addListener(() => notifications++);

      when(() => repository.getAppointments()).thenAnswer(
        (_) async => [seeded.first.copyWith(payment: pay('qr2', 'a://1'))],
      );
      await controller.refreshSilently();
      when(() => repository.getAppointments()).thenAnswer(
        (_) async => [seeded.first.copyWith(payment: pay('qr2', 'a://2'))],
      );
      await controller.refreshSilently();

      expect(notifications, 2);
    });

    test('a reset during the cache write leaves nothing cached and does '
        'not notify', () async {
      final cache = _SlowCache();
      final c = AppointmentsController(repository, cache: cache);
      var notifications = 0;
      c.addListener(() => notifications++);

      final refresh = c.refreshSilently();
      await Future<void>.delayed(Duration.zero);
      await c.reset();
      final afterReset = notifications;
      cache.release.complete();
      await refresh;

      expect(await cache.readAppointments(), isNull);
      expect(notifications, afterReset);
    });

    test('the newer load cache survives a slow stale write', () async {
      final stale = [seeded.first];
      final fresh = seeded;
      final cache = _FirstWriteSlowCache();
      final c = AppointmentsController(repository, cache: cache);
      when(() => repository.getAppointments()).thenAnswer((_) async => stale);
      final first = c.load();
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      when(() => repository.getAppointments()).thenAnswer((_) async => fresh);
      await c.load();
      cache.release.complete();
      await first;

      expect(await cache.readAppointments(), fresh);
    });

    test('a failed silent refresh keeps live data on screen', () async {
      when(() => repository.getAppointments())
          .thenThrow(const NetworkFailure('offline'));

      await controller.refreshSilently();

      expect(controller.state.status, AppointmentsStatus.data);
      expect(controller.state.isFromCache, isFalse);
      expect(controller.state.appointments, seeded);
    });
  });
}

class _SlowCache extends InMemoryCacheStore {
  final release = Completer<void>();
  @override
  Future<void> writeAppointments(List<Appointment> appointments) async {
    await release.future;
    await super.writeAppointments(appointments);
  }
}

class _FirstWriteSlowCache extends InMemoryCacheStore {
  final release = Completer<void>();
  bool _first = true;
  @override
  Future<void> writeAppointments(List<Appointment> appointments) async {
    await super.writeAppointments(appointments);
    // Only the first (stale) write is slow to report completion; its data is
    // already stored when the newer load writes and finishes.
    if (_first) {
      _first = false;
      await release.future;
    }
  }
}
