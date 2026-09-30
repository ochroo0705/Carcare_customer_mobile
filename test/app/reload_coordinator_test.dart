import 'dart:async';

import 'package:carcare_customer_mobile/app/bootstrap_flags.dart';
import 'package:carcare_customer_mobile/app/customer_app_services.dart';
import 'package:carcare_customer_mobile/app/reload_coordinator.dart';
import 'package:carcare_customer_mobile/core/connectivity/connectivity_service.dart';
import 'package:carcare_customer_mobile/core/errors/app_failure.dart';
import 'package:carcare_customer_mobile/data/cache/cache_store.dart';
import 'package:carcare_customer_mobile/features/booking/data/fake_appointment_repository.dart';
import 'package:carcare_customer_mobile/features/booking/domain/appointment.dart';
import 'package:carcare_customer_mobile/features/devices/data/device_id_store.dart';
import 'package:carcare_customer_mobile/features/devices/data/fake_device_repository.dart';
import 'package:carcare_customer_mobile/features/diagnostics/data/fake_diagnostics_repository.dart';
import 'package:carcare_customer_mobile/features/discovery/data/fake_organization_repository.dart';
import 'package:carcare_customer_mobile/features/history/data/fake_service_history_repository.dart';
import 'package:carcare_customer_mobile/features/history/domain/service_history_repository.dart';
import 'package:carcare_customer_mobile/features/notifications/data/fake_notifications_repository.dart';
import 'package:carcare_customer_mobile/features/vehicles/data/fake_vehicle_repository.dart';
import 'package:carcare_customer_mobile/features/vehicles/domain/vehicle.dart';
import 'package:flutter/widgets.dart' show AppLifecycleState;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/mocks.dart';
import 'support/app_harness.dart';

class _Appointments extends FakeAppointmentRepository {
  int calls = 0;
  bool fail = false;

  @override
  Future<List<Appointment>> getAppointments() {
    calls++;
    if (fail) throw const NetworkFailure('offline');
    return super.getAppointments();
  }
}

class _History extends FakeServiceHistoryRepository {
  int calls = 0;

  @override
  Future<ServiceHistoryPage> getServiceHistory({
    HistoryFilter filter = const HistoryFilter(),
  }) {
    calls++;
    return super.getServiceHistory(filter: filter);
  }
}

class _Vehicles extends FakeVehicleRepository {
  int calls = 0;

  @override
  Future<List<Vehicle>> getVehicles() {
    calls++;
    return super.getVehicles();
  }
}

class _Connectivity implements ConnectivityService {
  final controller = StreamController<bool>.broadcast(sync: true);

  @override
  Stream<bool> get onConnectivityChanged => controller.stream;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => debugDisableAppBootstrap = true);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  late _Appointments appointments;
  late _History history;
  late _Vehicles vehicles;
  late _Connectivity connectivity;
  late ControllablePush push;
  late CustomerAppServices services;
  var now = DateTime(2026, 1, 1, 12);

  Future<void> boot({bool failAppointments = false}) async {
    now = DateTime(2026, 1, 1, 12);
    reloadClock = () => now;
    appointments = _Appointments()..fail = failAppointments;
    history = _History();
    vehicles = _Vehicles();
    connectivity = _Connectivity();
    push = ControllablePush();
    services = CustomerAppServices(
      organizationRepository: FakeOrganizationRepository(delay: Duration.zero),
      authRepository: signedInAuthRepository(),
      appointmentRepository: appointments,
      vehicleRepository: vehicles,
      historyRepository: history,
      diagnosticsRepository: FakeDiagnosticsRepository(),
      notificationsRepository: FakeNotificationsRepository(),
      deviceRepository: FakeDeviceRepository(),
      remotePushService: push,
      deviceIdStore: DeviceIdStore(),
      connectivityService: connectivity,
      cacheStore: const NoopCacheStore(),
    );
    await pumpEventQueue();
  }

  tearDown(() {
    reloadClock = DateTime.now;
    services.dispose();
  });

  Future<void> resume() async {
    services.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await pumpEventQueue();
  }

  group('signIn', () {
    test('loads appointments, vehicles and history once', () async {
      await boot();
      expect(appointments.calls, 1);
      expect(vehicles.calls, 1);
      expect(history.calls, 1);
    });
  });

  group('push(type)', () {
    test('terminal reloads appointments, history and vehicles', () async {
      await boot();
      push.arrive({'type': 'order_completed'});
      await pumpEventQueue();
      expect([appointments.calls, history.calls, vehicles.calls], [2, 2, 2]);
    });

    test('active-only reloads appointments only', () async {
      await boot();
      push.arrive({'type': 'order_in_progress'});
      await pumpEventQueue();
      expect([appointments.calls, history.calls, vehicles.calls], [2, 1, 1]);
    });

    test('unknown reloads nothing', () async {
      await boot();
      push.arrive({'type': 'broadcast_account'});
      await pumpEventQueue();
      expect([appointments.calls, history.calls, vehicles.calls], [1, 1, 1]);
    });

    test('push is never throttled', () async {
      await boot();
      push.arrive({'type': 'order_in_progress'});
      push.arrive({'type': 'order_in_progress'});
      await pumpEventQueue();
      expect(appointments.calls, 3);
    });
  });

  group('resume', () {
    test('within 30s of a successful load is skipped', () async {
      await boot();
      now = now.add(const Duration(seconds: 29));
      await resume();
      expect([appointments.calls, history.calls], [1, 1]);
    });

    test('after 30s reloads appointments and history only', () async {
      await boot();
      now = now.add(const Duration(seconds: 31));
      await resume();
      expect([appointments.calls, history.calls, vehicles.calls], [2, 2, 1]);
    });

    test('a failed load does not start the throttle window', () async {
      await boot(failAppointments: true);
      await resume();
      expect(appointments.calls, 2);
      expect(history.calls, 1);
    });
  });

  group('resume after a kept-live failure', () {
    test('is not throttled: the retry reloads', () async {
      await boot();
      appointments.fail = true;
      now = now.add(const Duration(seconds: 31));
      await resume();
      expect(appointments.calls, 2);
      expect(services.appointmentsController.state.message, isNotNull);
      now = now.add(const Duration(seconds: 1));
      await resume();
      expect(appointments.calls, 3);
    });
  });

  group('reconnect', () {
    test('startup true does not tick reconnects or reload', () async {
      await boot(failAppointments: true);
      final before = appointments.calls;
      connectivity.controller.add(true);
      await pumpEventQueue();
      expect(services.reconnects.value, 0);
      expect(appointments.calls, before);
    });

    test('false then true ticks once and reloads errored lists', () async {
      await boot(failAppointments: true);
      final before = appointments.calls;
      connectivity.controller.add(false);
      connectivity.controller.add(true);
      await pumpEventQueue();
      expect(services.reconnects.value, 1);
      expect(appointments.calls, before + 1);
      // Healthy lists are left alone.
      expect(history.calls, 1);
      expect(vehicles.calls, 1);
    });
  });
}
