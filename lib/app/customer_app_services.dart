import 'dart:async';

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
import 'package:carcare_customer_mobile/features/booking/presentation/controllers/appointments_state.dart';
import 'package:carcare_customer_mobile/features/discovery/domain/organization_repository.dart';
import 'package:carcare_customer_mobile/features/discovery/presentation/controllers/discovery_controller.dart';
import 'package:carcare_customer_mobile/features/discovery/presentation/controllers/discovery_state.dart';
import 'package:carcare_customer_mobile/features/discovery/presentation/controllers/organization_detail_controller.dart';
import 'package:carcare_customer_mobile/features/history/domain/service_history_repository.dart';
import 'package:carcare_customer_mobile/features/history/presentation/controllers/history_controller.dart';
import 'package:carcare_customer_mobile/features/history/presentation/controllers/history_state.dart';
import 'package:carcare_customer_mobile/features/notifications/domain/notifications_repository.dart';
import 'package:carcare_customer_mobile/features/notifications/presentation/controllers/notifications_controller.dart';
import 'package:carcare_customer_mobile/features/vehicles/domain/vehicle_repository.dart';
import 'package:carcare_customer_mobile/features/vehicles/presentation/controllers/vehicles_controller.dart';
import 'package:carcare_customer_mobile/features/vehicles/presentation/controllers/vehicles_state.dart';
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
    authController = AuthController(authRepository)
      ..restore()
      ..beforeSignOut = _removeDeviceForPush;
    appointmentsController = AppointmentsController(
      appointmentRepository,
      cache: cacheStore,
    );
    vehiclesController = VehiclesController(vehicleRepository, cache: cacheStore);
    historyController = HistoryController(historyRepository, cache: cacheStore);
    // A customer cancelling their own appointment is a terminal transition, so
    // it has to reconcile both lists exactly as the staff-side terminal pushes
    // do in `_reloadListsForPushType` — History has its own cancelled-
    // appointments section. Wired here rather than inside the controller so
    // booking stays independent of history (cf. `beforeSignOut` above).
    appointmentsController.onAppointmentCancelled = historyController.load;
    notificationsController = NotificationsController(notificationsRepository);
    authController.addListener(_onAuthChanged);

    WidgetsBinding.instance.addObserver(this);
    _tokenRefreshSubscription = remotePushService.onTokenRefresh.listen(
      _onTokenRefreshed,
    );
    _foregroundMessageSubscription = remotePushService.onMessage.listen((
      message,
    ) {
      final type = message.data['type'] as String?;
      // Silent, data-only account-closure push: never a visible/local
      // notification, never appended to the in-app list, never routed —
      // just force a local sign-out. Handled before
      // `notificationsController.handleIncomingPush` so it can't leak in
      // as a notification.
      if (type == 'account_closed') {
        authController.handleRemoteAccountClosed(
          deleted: message.data['reason'] == 'deleted',
        );
        return;
      }
      notificationsController.handleIncomingPush(
        title: message.notification?.title,
        body: message.notification?.body,
        data: message.data,
      );
      reloadListsForPushType(type);
    });
    _connectivitySubscription = connectivityService.onConnectivityChanged
        .listen(_onConnectivityChanged);
    // Deep-link a background notification tap into the relevant screen.
    _notificationTapSubscription = remotePushService.onMessageOpenedApp.listen(
      (message) => onNotificationTap?.call(message.data),
    );
    // A tap that cold-started the app: handle after the first frame so the
    // shell exists and its tab can be selected.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final initial = await remotePushService.getInitialMessage();
      if (initial != null) onNotificationTap?.call(initial.data);
    });
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
  late final StreamSubscription<String> _tokenRefreshSubscription;
  late final StreamSubscription<dynamic> _foregroundMessageSubscription;
  late final StreamSubscription<bool> _connectivitySubscription;
  late final StreamSubscription<dynamic> _notificationTapSubscription;
  bool _wasAuthenticated = false;
  bool _disposed = false;

  /// The ONLY listenable navigation may rebuild on (31dcc14 invariant).
  Listenable get routerRefresh => authController;

  /// Set by the navigation layer; called for OS push taps (background +
  /// cold start). Services never navigates itself.
  void Function(Map<String, dynamic> data)? onNotificationTap;

  /// Shown after auth transitions (reactivated / closed / remote-closed).
  /// Set by the app to a ScaffoldMessenger-backed callback.
  void Function(String message)? showMessage;

  /// Routes a tapped push notification to the relevant screen, per the payload
  /// contract in `carcare.mn/docs/mobile-device-push.md` §4:
  /// `data.appointmentId` (appointment_confirmed/reminder) → that appointment's
  /// detail; anything else (broadcast) → the notifications list. Any transient
  /// overlays already on the stack are cleared first so the target lands
  /// cleanly on the shell.
  // Terminal-status push types move an appointment/order OUT of the active
  // Appointments list and INTO History (D-085: rejected/expired/no-show
  // appointments and completed/cancelled orders all surface there) — those
  // need both controllers reloaded. Everything else only ever changes a
  // field on an already-active appointment/order, so Appointments alone
  // covers it. `feedback_replied`/`broadcast`/unknown touch neither list.
  static const _terminalPushTypes = {
    'appointment_rejected',
    'appointment_expired',
    'appointment_no_show',
    'order_completed',
    'order_cancelled',
  };
  static const _activeOnlyPushTypes = {
    'appointment_confirmed',
    'appointment_booked_by_staff',
    'appointment_reminder',
    'appointment_rescheduled',
    'order_in_progress',
    'order_payment_received',
    'order_rescheduled',
    'expected_finish_revised',
  };

  /// Same body as today's `_reloadListsForPushType`. Public because the
  /// navigation layer calls it on a push tap.
  void reloadListsForPushType(String? type) {
    if (!authController.isAuthenticated) return;
    if (_terminalPushTypes.contains(type)) {
      appointmentsController.load();
      historyController.load();
      // `GET /api/v1/app/vehicles` embeds per-vehicle `_count`s of completed
      // service orders and diagnostic reports, and `VehicleDetailScreen` is a
      // StatelessWidget rendering whatever `VehiclesController` already holds
      // — it never refetches. There is also no vehicle push type at all (the
      // backend's NOTIFICATION_REGISTRY has none), so without this the counts
      // stay stale until sign-out/in, a cache/error-driven connectivity
      // reload, or a vehicle CRUD action. A terminal order push is exactly
      // the event that invalidates them.
      vehiclesController.load();
    } else if (_activeOnlyPushTypes.contains(type)) {
      appointmentsController.load();
    }
    // feedback_replied / broadcast_account / unknown: no list is affected.
  }

  void _onAuthChanged() {
    final isAuthenticated = authController.isAuthenticated;
    if (isAuthenticated && !_wasAuthenticated) {
      appointmentsController.load();
      vehiclesController.load();
      historyController.load();
      notificationsController.load();
      _registerDeviceForPush();
      if (authController.justReactivated) {
        authController.justReactivated = false;
        showMessage?.call('Бүртгэл тань сэргээгдлээ');
      }
    } else if (!isAuthenticated && _wasAuthenticated) {
      // Signed out (incl. a closure from this or another device): the closure
      // page only makes sense for a signed-in account.
      appointmentsController.reset();
      vehiclesController.reset();
      historyController.reset();
      notificationsController.reset();
      final closedDeleteForever = authController.justClosedAccount;
      final remoteClosedReason = authController.justRemoteClosedAccount;
      if (closedDeleteForever != null) {
        // Account closure: the server already removed the devices, so skip
        // the removal call below and just confirm the action.
        authController.justClosedAccount = null;
        showMessage?.call(
          closedDeleteForever ? 'Бүртгэл устгагдлаа' : 'Бүртгэл идэвхгүй боллоо',
        );
      } else if (remoteClosedReason != null) {
        // Closed remotely (e.g. from the website) while this device was
        // still signed in — same skip-device-removal reasoning as above,
        // but distinct wording since this device didn't initiate it.
        authController.justRemoteClosedAccount = null;
        showMessage?.call(
          remoteClosedReason == 'deleted'
              ? 'Бүртгэл тань устгагдсан'
              : 'Бүртгэл тань идэвхгүй болсон',
        );
      } else {
        // Best-effort safety net for the 401-triggered path: `authController`
        // wires `_removeDeviceForPush` to run before an explicit sign-out
        // clears the token (see `beforeSignOut` above), but a 401 means the
        // token was already invalid server-side, so this call is expected to
        // fail there too — left in only in case removal was never attempted.
        _removeDeviceForPush();
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
    if (!online) return;
    if (discoveryController.state.isFromCache ||
        discoveryController.state.status == DiscoveryStatus.error) {
      discoveryController.load();
    }
    if (!authController.isAuthenticated) return;
    if (appointmentsController.state.isFromCache ||
        appointmentsController.state.status == AppointmentsStatus.error) {
      appointmentsController.load();
    }
    if (vehiclesController.state.isFromCache ||
        vehiclesController.state.status == VehiclesStatus.error) {
      vehiclesController.load();
    }
    if (historyController.state.isFromCache ||
        historyController.state.status == HistoryStatus.error) {
      historyController.load();
    }
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
    appointmentsController.load();
    historyController.load();
  }

  /// Registers the current FCM token against `POST /api/v1/app/devices` (see
  /// `CUSTOMER_API_CONTRACT.md` "Push device registration"). Best-effort: a
  /// missing token (no Firebase configured, permission denied, or a platform
  /// this app doesn't ship push on) or a failed request must never block
  /// login.
  Future<void> _registerDeviceForPush() async {
    final account = authController.account;
    if (account == null || _disposed) return;
    try {
      final token = await remotePushService.getToken();
      if (token == null ||
          _disposed ||
          !identical(authController.account, account)) {
        return;
      }
      final deviceId = await deviceIdStore.getOrCreate();
      if (_disposed || !identical(authController.account, account)) return;
      await deviceRepository.registerDevice(
        deviceId: deviceId,
        platform: _platformName,
        firebaseToken: token,
      );
    } catch (_) {
      // Best-effort — push registration failing must never block sign-in.
      if (kDebugMode) debugPrint('Push device registration could not complete.');
    }
  }

  Future<void> _removeDeviceForPush() async {
    try {
      final deviceId = await deviceIdStore.getOrCreate();
      await deviceRepository.removeDevice(deviceId);
    } catch (_) {
      // Best-effort — matches the API doc's "call during logout when possible".
    }
  }

  /// The API contract requires re-registering whenever the FCM token
  /// refreshes, but only while signed in — there's no account to attach an
  /// unauthenticated refresh to.
  Future<void> _onTokenRefreshed(String token) async {
    final account = authController.account;
    if (account == null || _disposed) return;
    try {
      final deviceId = await deviceIdStore.getOrCreate();
      if (_disposed || !identical(authController.account, account)) return;
      await deviceRepository.registerDevice(
        deviceId: deviceId,
        platform: _platformName,
        firebaseToken: token,
      );
    } catch (_) {
      // Best-effort, same as _registerDeviceForPush.
    }
  }

  String get _platformName =>
      defaultTargetPlatform == TargetPlatform.iOS ? 'IOS' : 'ANDROID';

  void dispose() {
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _tokenRefreshSubscription.cancel();
    _foregroundMessageSubscription.cancel();
    _connectivitySubscription.cancel();
    _notificationTapSubscription.cancel();
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
