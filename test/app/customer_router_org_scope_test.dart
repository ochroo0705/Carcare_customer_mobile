// Fix round 1: covers the stale-slug guard in `_OrganizationScope`
// (`lib/app/customer_router.dart`) — a scope must never render the OTHER
// org's data just because the shared `OrganizationDetailController` happens
// to be holding it when this scope rebuilds. `organizationDetailController`
// is shared across every `_OrganizationScope` on the navigation stack (the
// reviewer's scenario: an org-detail page underneath a booking page, or a
// second org visited without popping the first), so this simulates the
// shared controller being swapped to a different org while THIS scope's
// page is still the one on screen — the same hazard, without depending on
// go_router's page-transition timing (which would otherwise make the
// intermediate frame this test checks for flaky to observe).
import 'dart:async';

import 'package:carcare_customer_mobile/app/customer_app_services.dart';
import 'package:carcare_customer_mobile/app/customer_navigation.dart';
import 'package:carcare_customer_mobile/app/customer_router.dart';
import 'package:carcare_customer_mobile/app/theme/app_theme.dart';
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
import 'package:carcare_customer_mobile/features/discovery/presentation/controllers/organization_detail_controller.dart';
import 'package:carcare_customer_mobile/features/history/data/fake_service_history_repository.dart';
import 'package:carcare_customer_mobile/features/notifications/data/fake_notifications_repository.dart';
import 'package:carcare_customer_mobile/features/vehicles/data/fake_vehicle_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

CustomerAppServices _buildServices({bool signedIn = false}) =>
    CustomerAppServices(
      organizationRepository: FakeOrganizationRepository(delay: Duration.zero),
      authRepository: FakeAuthRepository(signedIn: signedIn),
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

/// A bounded stand-in for `pumpAndSettle`: the org-detail page's loading
/// skeleton (and other always-mounted shell tabs, e.g. the discovery map)
/// run animations that never fully settle in a widget test, so
/// `pumpAndSettle` would time out even once the state we care about has
/// long since resolved. A handful of frames is more than enough for a
/// `Duration.zero` fake load and its `notifyListeners` to propagate.
Future<void> _pumpAWhile(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  testWidgets(
    'renders the loading state, not the other org\'s stale data, when the '
    'shared controller is swapped to a different org while this page is '
    'still on screen — then self-heals back to its own slug',
    (tester) async {
      final services = _buildServices();
      addTearDown(services.dispose);
      final navigation = CustomerNavigation(services);
      final router = buildCustomerRouter(services, navigation);
      navigation.router = router;
      addTearDown(router.dispose);
      final themeController = ThemeController();
      addTearDown(themeController.dispose);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: themeController),
            ChangeNotifierProvider.value(value: services.discoveryController),
            ChangeNotifierProvider.value(
              value: services.organizationDetailController,
            ),
            ChangeNotifierProvider.value(value: services.authController),
            ChangeNotifierProvider.value(
              value: services.appointmentsController,
            ),
            ChangeNotifierProvider.value(value: services.vehiclesController),
            ChangeNotifierProvider.value(value: services.historyController),
            ChangeNotifierProvider.value(
              value: services.notificationsController,
            ),
          ],
          child: MaterialApp.router(
            theme: AppTheme.light,
            routerConfig: router,
          ),
        ),
      );
      await _pumpAWhile(tester);

      // Open auto-doctor's detail page and let its load settle (and cache).
      router.push('/organizations/auto-doctor');
      await _pumpAWhile(tester);
      expect(find.text('Auto Doctor Service'), findsOneWidget);

      // Something else swaps the SHARED controller to a different org while
      // the auto-doctor page is still the one on screen — exactly the
      // reviewer's "two `_OrganizationScope`s share one controller" hazard,
      // triggered directly rather than through a second push/pop (which
      // would make the frame this test checks for racy against go_router's
      // page-transition animation instead of against the guard itself).
      unawaited(services.organizationDetailController.load('khurd-motors'));

      // `load()` sets `organization = null` and `status = loading`
      // synchronously before its first `await`, so a single frame already
      // sees the mismatch. The auto-doctor page must show neither org's
      // name at this point.
      await tester.pump();
      expect(find.text('Auto Doctor Service'), findsNothing);
      expect(find.text('Хурд Моторс'), findsNothing);

      // Once khurd-motors' load finishes, this scope's own guard-triggered
      // reload (a cache hit for auto-doctor, since it was already loaded
      // above) fires and corrects the shared controller back.
      await _pumpAWhile(tester);
      expect(find.text('Auto Doctor Service'), findsOneWidget);
      expect(find.text('Хурд Моторс'), findsNothing);
    },
  );

  testWidgets(
    'a failed org load on the booking route shows the error with a retry '
    'instead of reloading forever behind a loading skeleton',
    (tester) async {
      final services = _buildServices(signedIn: true);
      addTearDown(services.dispose);
      final navigation = CustomerNavigation(services);
      final router = buildCustomerRouter(services, navigation);
      navigation.router = router;
      addTearDown(router.dispose);
      final themeController = ThemeController();
      addTearDown(themeController.dispose);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: themeController),
            ChangeNotifierProvider.value(value: services.discoveryController),
            ChangeNotifierProvider.value(
              value: services.organizationDetailController,
            ),
            ChangeNotifierProvider.value(value: services.authController),
            ChangeNotifierProvider.value(
              value: services.appointmentsController,
            ),
            ChangeNotifierProvider.value(value: services.vehiclesController),
            ChangeNotifierProvider.value(value: services.historyController),
            ChangeNotifierProvider.value(
              value: services.notificationsController,
            ),
          ],
          child: MaterialApp.router(
            theme: AppTheme.light,
            routerConfig: router,
          ),
        ),
      );
      await _pumpAWhile(tester);

      // The fake repository throws NotFoundFailure for an unknown slug.
      router.push('/organizations/no-such-org/book');
      await _pumpAWhile(tester);
      expect(find.text('Байгууллага олдсонгүй.'), findsOneWidget);
      expect(find.text('Дахин оролдох'), findsOneWidget);

      // Still settled on the error a while later — no silent reload loop.
      await _pumpAWhile(tester);
      expect(
        services.organizationDetailController.status,
        OrganizationDetailStatus.error,
      );
      expect(find.text('Дахин оролдох'), findsOneWidget);
    },
  );
}
