import 'package:carcare_customer_mobile/app/bootstrap_flags.dart';
import 'package:carcare_customer_mobile/app/customer_app_services.dart';
import 'package:carcare_customer_mobile/app/customer_shell.dart';
import 'package:carcare_customer_mobile/core/connectivity/connectivity_service.dart';
import 'package:carcare_customer_mobile/core/notifications/remote_push_service.dart';
import 'package:carcare_customer_mobile/data/cache/cache_store.dart';
import 'package:carcare_customer_mobile/features/auth/data/fake_auth_repository.dart';
import 'package:carcare_customer_mobile/features/booking/data/fake_appointment_repository.dart';
import 'package:carcare_customer_mobile/features/devices/data/device_id_store.dart';
import 'package:carcare_customer_mobile/features/devices/data/fake_device_repository.dart';
import 'package:carcare_customer_mobile/features/diagnostics/data/fake_diagnostics_repository.dart';
import 'package:carcare_customer_mobile/features/discovery/data/fake_organization_repository.dart';
import 'package:carcare_customer_mobile/features/discovery/presentation/controllers/discovery_controller.dart';
import 'package:carcare_customer_mobile/features/history/data/fake_service_history_repository.dart';
import 'package:carcare_customer_mobile/features/notifications/data/fake_notifications_repository.dart';
import 'package:carcare_customer_mobile/features/vehicles/data/fake_vehicle_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/app_harness.dart';

/// The old router delegate's `build()` returned the whole page stack, so every
/// `notifyListeners` rebuilt the shell, all five tabs and every open overlay,
/// and `buildCustomerRouter`'s `refreshListenable` inherits the same
/// requirement. Navigation must therefore only rebuild on `routerRefresh` (the
/// auth controller). Subscribing to a data controller "for safety" is what made a
/// single appointment cancellation rebuild the entire app six times, and a
/// discovery keystroke rebuild it on every character.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() => debugDisableAppBootstrap = true);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  CustomerAppServices buildServices() => CustomerAppServices(
    // `Duration.zero` — the default 450ms delay left the constructor's own
    // fire-and-forget initial `discoveryController.load()` still in flight
    // when a test's `pumpEventQueue()` (which drains microtasks, not real
    // timers) returned and the test called `dispose()`. That background
    // load then resolved after disposal and called `notifyListeners()` on
    // a disposed `DiscoveryController`, an async leak that surfaced as a
    // failure misattributed to whatever test happened to be running when
    // the timer fired 450ms later. Match `pumpApp`'s harness, which already
    // avoids this by passing `delay: Duration.zero`.
    organizationRepository: FakeOrganizationRepository(delay: Duration.zero),
    authRepository: FakeAuthRepository(),
    appointmentRepository: FakeAppointmentRepository(),
    vehicleRepository: FakeVehicleRepository(),
    historyRepository: FakeServiceHistoryRepository(),
    diagnosticsRepository: FakeDiagnosticsRepository(),
    notificationsRepository: FakeNotificationsRepository(),
    deviceRepository: FakeDeviceRepository(),
    remotePushService: const NoopRemotePushService(),
    deviceIdStore: DeviceIdStore(),
    connectivityService: const NoopConnectivityService(),
    cacheStore: const NoopCacheStore(),
  );

  test('loading data-only controllers does not rebuild the page stack', () async {
    final services = buildServices();
    // The constructor kicks off discovery load + session restore; let those
    // settle before counting, so the test measures our own calls.
    await pumpEventQueue();

    var rebuilds = 0;
    void count() => rebuilds++;
    services.routerRefresh.addListener(count);

    await services.discoveryController.load();
    await services.notificationsController.load();
    await services.appointmentsController.load();
    await services.vehiclesController.load();
    await services.historyController.load();
    await pumpEventQueue();

    expect(
      rebuilds,
      0,
      reason: 'Screens read these through Provider and rebuild themselves; '
          'the router must not rebuild every page for them.',
    );

    services.routerRefresh.removeListener(count);
    services.dispose();
  });

  test('auth changes still rebuild — the page stack depends on them', () async {
    final services = buildServices();
    await pumpEventQueue();

    var rebuilds = 0;
    void count() => rebuilds++;
    services.routerRefresh.addListener(count);

    await services.authController.signOut();
    await pumpEventQueue();

    expect(rebuilds, greaterThan(0));

    services.routerRefresh.removeListener(count);
    services.dispose();
  });

  testWidgets('a discovery load does not rebuild the router pages',
      (tester) async {
    await pumpApp(tester);
    final router = GoRouter.of(tester.element(find.byType(CustomerShell)));
    var notifications = 0;
    void count() => notifications++;
    router.routerDelegate.addListener(count);

    final discovery =
        tester.element(find.byType(CustomerShell)).read<DiscoveryController>();
    await discovery.load();
    await tester.pumpAndSettle();

    expect(notifications, 0);
    router.routerDelegate.removeListener(count);
  });
}
