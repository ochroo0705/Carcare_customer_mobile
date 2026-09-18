import 'package:carcare_customer_mobile/app/router.dart';
import 'package:carcare_customer_mobile/app/theme/theme_controller.dart';
import 'package:carcare_customer_mobile/core/connectivity/connectivity_service.dart';
import 'package:carcare_customer_mobile/core/notifications/remote_push_service.dart';
import 'package:carcare_customer_mobile/data/cache/cache_store.dart';
import 'package:carcare_customer_mobile/features/auth/data/fake_auth_repository.dart';
import 'package:carcare_customer_mobile/features/booking/data/fake_appointment_repository.dart';
import 'package:carcare_customer_mobile/features/devices/data/device_id_store.dart';
import 'package:carcare_customer_mobile/features/devices/data/fake_device_repository.dart';
import 'package:carcare_customer_mobile/features/diagnostics/data/fake_diagnostics_repository.dart';
import 'package:carcare_customer_mobile/features/discovery/data/fake_organization_repository.dart';
import 'package:carcare_customer_mobile/features/history/data/fake_service_history_repository.dart';
import 'package:carcare_customer_mobile/features/notifications/data/fake_notifications_repository.dart';
import 'package:carcare_customer_mobile/features/vehicles/data/fake_vehicle_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// `CustomerRouterDelegate.build()` returns the whole page stack, so every
/// `notifyListeners` rebuilds the shell, all five tabs and every open overlay.
/// It must therefore only subscribe to controllers it actually *reads* in
/// `build()`. Subscribing to a data controller "for safety" is what made a
/// single appointment cancellation rebuild the entire app six times, and a
/// discovery keystroke rebuild it on every character.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  CustomerRouterDelegate buildDelegate() => CustomerRouterDelegate(
    FakeOrganizationRepository(),
    ThemeController(),
    FakeAuthRepository(),
    FakeAppointmentRepository(),
    FakeVehicleRepository(),
    FakeServiceHistoryRepository(),
    FakeDiagnosticsRepository(),
    FakeNotificationsRepository(),
    FakeDeviceRepository(),
    const NoopRemotePushService(),
    DeviceIdStore(),
    const NoopConnectivityService(),
    const NoopCacheStore(),
  );

  test('loading data-only controllers does not rebuild the page stack', () async {
    final delegate = buildDelegate();
    // The constructor kicks off discovery load + session restore; let those
    // settle before counting, so the test measures our own calls.
    await pumpEventQueue();

    var rebuilds = 0;
    void count() => rebuilds++;
    delegate.addListener(count);

    await delegate.discoveryController.load();
    await delegate.notificationsController.load();
    await delegate.appointmentsController.load();
    await delegate.vehiclesController.load();
    await delegate.historyController.load();
    await pumpEventQueue();

    expect(
      rebuilds,
      0,
      reason: 'Screens read these through Provider and rebuild themselves; '
          'the router must not rebuild every page for them.',
    );

    delegate.removeListener(count);
    delegate.dispose();
  });

  test('auth changes still rebuild — the page stack depends on them', () async {
    final delegate = buildDelegate();
    await pumpEventQueue();

    var rebuilds = 0;
    void count() => rebuilds++;
    delegate.addListener(count);

    await delegate.authController.signOut();
    await pumpEventQueue();

    expect(rebuilds, greaterThan(0));

    delegate.removeListener(count);
    delegate.dispose();
  });
}
