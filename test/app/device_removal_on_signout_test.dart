import 'dart:async';

import 'package:carcare_customer_mobile/app/bootstrap_flags.dart';
import 'package:carcare_customer_mobile/app/customer_app_services.dart';
import 'package:carcare_customer_mobile/core/connectivity/connectivity_service.dart';
import 'package:carcare_customer_mobile/data/cache/cache_store.dart';
import 'package:carcare_customer_mobile/features/booking/data/fake_appointment_repository.dart';
import 'package:carcare_customer_mobile/features/devices/data/device_id_store.dart';
import 'package:carcare_customer_mobile/features/devices/data/fake_device_repository.dart';
import 'package:carcare_customer_mobile/features/diagnostics/data/fake_diagnostics_repository.dart';
import 'package:carcare_customer_mobile/features/discovery/data/fake_organization_repository.dart';
import 'package:carcare_customer_mobile/features/history/data/fake_service_history_repository.dart';
import 'package:carcare_customer_mobile/features/notifications/data/fake_notifications_repository.dart';
import 'package:carcare_customer_mobile/features/vehicles/data/fake_vehicle_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/mocks.dart';
import 'support/app_harness.dart';

class _CountingDevices extends FakeDeviceRepository {
  int removals = 0;

  @override
  Future<void> removeDevice(String deviceId) async => removals++;
}

/// Listener-level guarantee that a sign-out deregisters the device exactly
/// once: `signOut` runs `beforeSignOut`, and `_onAuthChanged` must not repeat
/// it for that same sign-out.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => debugDisableAppBootstrap = true);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  late _CountingDevices devices;
  late MockAuthRepository auth;
  late StreamController<void> invalidated;
  late ControllablePush push;
  late CustomerAppServices services;

  Future<void> boot() async {
    devices = _CountingDevices();
    push = ControllablePush();
    invalidated = StreamController<void>.broadcast();
    auth = signedInAuthRepository();
    when(() => auth.onSessionInvalidated).thenAnswer((_) => invalidated.stream);
    services = CustomerAppServices(
      organizationRepository: FakeOrganizationRepository(delay: Duration.zero),
      authRepository: auth,
      appointmentRepository: FakeAppointmentRepository(),
      vehicleRepository: FakeVehicleRepository(),
      historyRepository: FakeServiceHistoryRepository(),
      diagnosticsRepository: FakeDiagnosticsRepository(),
      notificationsRepository: FakeNotificationsRepository(),
      deviceRepository: devices,
      remotePushService: push,
      deviceIdStore: DeviceIdStore(),
      connectivityService: const NoopConnectivityService(),
      cacheStore: const NoopCacheStore(),
    );
    await pumpEventQueue();
    expect(services.authController.isAuthenticated, isTrue);
  }

  tearDown(() async {
    services.dispose();
    await invalidated.close();
  });

  test(
    'a user-initiated signOut deregisters the device exactly once',
    () async {
      await boot();
      await services.authController.signOut();
      await pumpEventQueue();
      expect(devices.removals, 1);
    },
  );

  test('a 401 (session invalidated) sign-out still deregisters', () async {
    await boot();
    invalidated.add(null);
    await pumpEventQueue();
    expect(services.authController.isAuthenticated, isFalse);
    expect(devices.removals, 1);
  });

  test('clearConfirmedUnauthorized deregisters exactly once', () async {
    await boot();
    await services.authController.clearConfirmedUnauthorized();
    await pumpEventQueue();
    expect(devices.removals, 1);
  });

  test(
    'a remote-closure sign-out makes no removal call (server dropped it)',
    () async {
      await boot();
      await services.authController.handleRemoteAccountClosed(deleted: true);
      await pumpEventQueue();
      expect(services.authController.isAuthenticated, isFalse);
      expect(devices.removals, 0);
    },
  );
}
