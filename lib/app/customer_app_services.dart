import 'dart:async';

import 'package:carcare_customer_mobile/app/push_coordinator.dart';
import 'package:carcare_customer_mobile/app/reload_coordinator.dart';
import 'package:carcare_customer_mobile/core/connectivity/connectivity_service.dart';
import 'package:carcare_customer_mobile/data/cache/cache_store.dart';
import 'package:carcare_customer_mobile/core/notifications/remote_push_service.dart';
import 'package:carcare_customer_mobile/features/auth/domain/auth_repository.dart';
import 'package:carcare_customer_mobile/features/auth/presentation/auth_controller.dart';
import 'package:carcare_customer_mobile/features/booking/domain/appointment_repository.dart';
import 'package:carcare_customer_mobile/features/devices/data/device_id_store.dart';
import 'package:carcare_customer_mobile/features/devices/domain/device_repository.dart';
import 'package:carcare_customer_mobile/features/diagnostics/domain/diagnostics_repository.dart';
import 'package:carcare_customer_mobile/features/booking/presentation/controllers/appointments_controller.dart';
import 'package:carcare_customer_mobile/features/discovery/domain/organization_repository.dart';
import 'package:carcare_customer_mobile/features/discovery/presentation/controllers/discovery_controller.dart';
import 'package:carcare_customer_mobile/features/discovery/presentation/controllers/organization_detail_controller.dart';
import 'package:carcare_customer_mobile/features/history/domain/service_history_repository.dart';
import 'package:carcare_customer_mobile/features/history/presentation/controllers/history_controller.dart';
import 'package:carcare_customer_mobile/features/notifications/domain/notifications_repository.dart';
import 'package:carcare_customer_mobile/features/notifications/presentation/controllers/notifications_controller.dart';
import 'package:carcare_customer_mobile/features/vehicles/domain/vehicle_repository.dart';
import 'package:carcare_customer_mobile/features/vehicles/presentation/controllers/vehicles_controller.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Owns the controllers and the push, connectivity, lifecycle and
/// device-registration side effects that used to live inside the old
/// `CustomerRouterDelegate`. Knows nothing about navigation: it never
/// touches a `Navigator`, a page stack, or `BuildContext` beyond the
/// `showMessage` callback the navigation layer wires in.
class CustomerAppServices with WidgetsBindingObserver {
  CustomerAppServices({
    required this.organizationRepository,
    required AuthRepository authRepository,
    required this.appointmentRepository,
    required this.vehicleRepository,
    required this.historyRepository,
    required this.diagnosticsRepository,
    required this.notificationsRepository,
    required this.deviceRepository,
    required this.remotePushService,
    required this.deviceIdStore,
    required this.connectivityService,
    required this.cacheStore,
  }) : discoveryController = DiscoveryController(
         organizationRepository,
         cache: cacheStore,
       )..load() {
    organizationDetailController = OrganizationDetailController(
      organizationRepository,
    );
    authController = AuthController(authRepository);
    final sessionRestored = authController.restore();
    // Nobody awaits this unless a cold-start push tap needs it; a failed
    // restore just means signed out, so it must not surface as unhandled.
    // (Later awaiters of [sessionRestored] still observe the error.)
    unawaited(sessionRestored.catchError((Object _) {}));
    appointmentsController = AppointmentsController(
      appointmentRepository,
      cache: cacheStore,
    );
    vehiclesController = VehiclesController(
      vehicleRepository,
      cache: cacheStore,
    );
    historyController = HistoryController(historyRepository, cache: cacheStore);
    // A customer cancelling their own appointment is a terminal transition, so
    // it has to reconcile both lists exactly as the staff-side terminal pushes
    // do in `_reloadListsForPushType` — History has its own cancelled-
    // appointments section. Wired here rather than inside the controller so
    // booking stays independent of history (cf. `beforeSignOut` above).
    appointmentsController.onAppointmentCancelled = historyController.load;
    notificationsController = NotificationsController(notificationsRepository);
    reload = ReloadCoordinator(
      discovery: discoveryController,
      organizationDetail: organizationDetailController,
      appointments: appointmentsController,
      vehicles: vehiclesController,
      history: historyController,
      notifications: notificationsController,
      isAuthenticated: () => authController.isAuthenticated,
    );
    authController.addListener(_onAuthChanged);

    WidgetsBinding.instance.addObserver(this);
    push = PushCoordinator(
      remotePushService: remotePushService,
      deviceRepository: deviceRepository,
      deviceIdStore: deviceIdStore,
      authController: authController,
      notificationsController: notificationsController,
      reloadListsForPushType: reload.onPush,
      sessionRestored: sessionRestored,
    );
    authController.beforeSignOut = push.removeDeviceForSignOut;
    _connectivitySubscription = connectivityService.onConnectivityChanged
        .listen(_onConnectivityChanged);
  }

  final DiscoveryController discoveryController;
  late final OrganizationDetailController organizationDetailController;
  late final AuthController authController;
  late final AppointmentsController appointmentsController;
  late final VehiclesController vehiclesController;
  late final HistoryController historyController;
  late final NotificationsController notificationsController;
  final OrganizationRepository organizationRepository;
  final AppointmentRepository appointmentRepository;
  final VehicleRepository vehicleRepository;
  final ServiceHistoryRepository historyRepository;
  final DiagnosticsRepository diagnosticsRepository;
  final NotificationsRepository notificationsRepository;
  final DeviceRepository deviceRepository;
  final RemotePushService remotePushService;
  final DeviceIdStore deviceIdStore;
  final ConnectivityService connectivityService;
  final CacheStore cacheStore;
  late final PushCoordinator push;
  late final StreamSubscription<bool> _connectivitySubscription;
  late final ReloadCoordinator reload;
  final ValueNotifier<bool> _isOnline = ValueNotifier(true);

  /// Whether the customer API is currently reachable (verified by the
  /// [ConnectivityService] probe). Starts `true` so nothing flashes offline
  /// before the first check. Drives the app-wide offline strip.
  ValueListenable<bool> get isOnline => _isOnline;

  /// Ticks each time the device regains connectivity. For screen-owned
  /// controllers this class can't reach (e.g. the diagnostics list inside
  /// `HistoryScreen`) so they can retry a failed load themselves.
  ValueListenable<int> get reconnects => reload.reconnects;
  bool _wasAuthenticated = false;

  /// The ONLY listenable navigation may rebuild on (31dcc14 invariant).
  Listenable get routerRefresh => authController.session;

  /// Set by the navigation layer; called for OS push taps (background +
  /// cold start). Services never navigates itself.
  set onNotificationTap(void Function(Map<String, dynamic> data)? handler) =>
      push.onNotificationTap = handler;
  void Function(Map<String, dynamic> data)? get onNotificationTap =>
      push.onNotificationTap;

  /// Shown after auth transitions (reactivated / closed / remote-closed).
  /// Set by the app to a ScaffoldMessenger-backed callback.
  void Function(String message)? showMessage;

  /// Routes a tapped push notification to the relevant screen, per the payload
  /// contract in `carcare.mn/docs/mobile-device-push.md` §4:
  /// `data.appointmentId` (appointment_confirmed/reminder) → that appointment's
  /// detail; anything else (broadcast) → the notifications list. Any transient
  /// overlays already on the stack are cleared first so the target lands
  /// cleanly on the shell.
  /// Public because the navigation layer calls it on a push tap.
  void reloadListsForPushType(String? type) => reload.onPush(type);

  void _onAuthChanged() {
    final isAuthenticated = authController.isAuthenticated;
    if (isAuthenticated && !_wasAuthenticated) {
      reload.onSignIn();
      push.registerDevice();
      if (authController.takeSessionEvent() == SessionEvent.reactivated) {
        showMessage?.call('Бүртгэл тань сэргээгдлээ');
      }
    } else if (!isAuthenticated && _wasAuthenticated) {
      // Signed out (incl. a closure from this or another device): the closure
      // page only makes sense for a signed-in account.
      reload.clearHistory();
      appointmentsController.reset();
      vehiclesController.reset();
      historyController.reset();
      notificationsController.reset();
      final event = authController.takeSessionEvent();
      if (event == SessionEvent.deleted || event == SessionEvent.deactivated) {
        // Account closure: the server already removed the devices, so skip
        // the removal call below and just confirm the action.
        showMessage?.call(
          event == SessionEvent.deleted
              ? 'Бүртгэл устгагдлаа'
              : 'Бүртгэл идэвхгүй боллоо',
        );
      } else if (event == SessionEvent.remoteDeleted ||
          event == SessionEvent.remoteDeactivated) {
        // Closed remotely (e.g. from the website) while this device was
        // still signed in — same skip-device-removal reasoning as above,
        // but distinct wording since this device didn't initiate it.
        showMessage?.call(
          event == SessionEvent.remoteDeleted
              ? 'Бүртгэл тань устгагдсан'
              : 'Бүртгэл тань идэвхгүй болсон',
        );
      } else if (event == SessionEvent.deviceRemovalHandled) {
        // beforeSignOut already removed the device; don't repeat the call.
      } else {
        // Best-effort safety net for the 401-triggered path: `authController`
        // wires `_removeDeviceForPush` to run before an explicit sign-out
        // clears the token (see `beforeSignOut` above), but a 401 means the
        // token was already invalid server-side, so this call is expected to
        // fail there too — left in only in case removal was never attempted.
        push.removeDeviceAfterUnhandledSignOut();
      }
    }
    _wasAuthenticated = isAuthenticated;
  }

  /// Reloads any screen currently showing stale (cached or errored) data the
  /// moment the device regains network connectivity — without this, a
  /// customer who reconnects has to know to manually tap retry on every tab
  /// individually, and tabs they haven't visited yet stay stuck showing the
  /// last failure even after the network is back.
  void _onConnectivityChanged(bool online) {
    _isOnline.value = online;
    reload.onConnectivity(online);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    // FCM/APNs delivery is best-effort — a push can be delayed or silently
    // dropped while backgrounded, and unlike the cache/error-driven reload
    // above, a missed push leaves state looking perfectly normal (no error,
    // no cache flag) so nothing else would ever catch it. Reconcile
    // unconditionally on every foreground return rather than waiting for
    // another unrelated push to happen to arrive.
    if (!authController.isAuthenticated) return;
    push.onResumed();
    reload.onResume();
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    push.dispose();
    _connectivitySubscription.cancel();
    reload.dispose();
    _isOnline.dispose();
    authController.removeListener(_onAuthChanged);
    discoveryController.dispose();
    organizationDetailController.dispose();
    authController.dispose();
    appointmentsController.dispose();
    vehiclesController.dispose();
    historyController.dispose();
    notificationsController.dispose();
  }
}
