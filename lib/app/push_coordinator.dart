import 'dart:async';

import 'package:carcare_customer_mobile/core/notifications/remote_push_service.dart';
import 'package:carcare_customer_mobile/features/auth/presentation/auth_controller.dart';
import 'package:carcare_customer_mobile/features/devices/data/device_id_store.dart';
import 'package:carcare_customer_mobile/features/devices/domain/device_repository.dart';
import 'package:carcare_customer_mobile/features/notifications/presentation/controllers/notifications_controller.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

/// Owns everything push: device registration/deregistration, the FCM token
/// refresh subscription, foreground messages, background and cold-start taps.
/// Never navigates: taps are handed to [onNotificationTap], which the
/// navigation layer sets.
///
/// Device-removal semantics (once for a user sign-out and a 401, never for a
/// remote closure) are driven by the owner via [removeDeviceForSignOut] (the
/// `beforeSignOut` hook) and [removeDeviceAfterUnhandledSignOut].
class PushCoordinator {
  PushCoordinator({
    required this.remotePushService,
    required this.deviceRepository,
    required this.deviceIdStore,
    required this.authController,
    required this.notificationsController,
    required this.reloadListsForPushType,
    required this.sessionRestored,
  }) {
    _tokenRefreshSubscription = remotePushService.onTokenRefresh.listen(
      _onTokenRefreshed,
    );
    _foregroundMessageSubscription = remotePushService.onMessage.listen(
      _onForegroundMessage,
    );
    // Deep-link a background notification tap into the relevant screen.
    _notificationTapSubscription = remotePushService.onMessageOpenedApp.listen(
      (message) => handleTap(message.data),
    );
    // A tap that cold-started the app: handle after the first frame so the
    // shell exists and its tab can be selected.
    SchedulerBinding.instance.addPostFrameCallback((_) => _handleInitial());
  }

  final RemotePushService remotePushService;
  final DeviceRepository deviceRepository;
  final DeviceIdStore deviceIdStore;
  final AuthController authController;
  final NotificationsController notificationsController;
  final void Function(String? type) reloadListsForPushType;

  /// Completes when the launch session restore has finished. A cold-start tap
  /// must not be routed before it does, or a signed-in user looks signed out.
  final Future<void> sessionRestored;

  /// Set by the navigation layer; called for OS push taps (background, cold
  /// start) and local-banner taps.
  void Function(Map<String, dynamic> data)? onNotificationTap;

  late final StreamSubscription<String> _tokenRefreshSubscription;
  late final StreamSubscription<RemoteMessage> _foregroundMessageSubscription;
  late final StreamSubscription<RemoteMessage> _notificationTapSubscription;
  bool _disposed = false;
  bool _tokenMissing = false;

  /// Delivers a tap (OS notification or local banner) to the navigation layer,
  /// dropping a malformed non-string `type` rather than letting it throw.
  void handleTap(Map<String, dynamic> data) {
    if (_disposed) return;
    final safe = data['type'] is String || !data.containsKey('type')
        ? data
        : (Map<String, dynamic>.of(data)..remove('type'));
    onNotificationTap?.call(safe);
  }

  Future<void> _handleInitial() async {
    if (_disposed) return;
    try {
      final initial = await remotePushService.getInitialMessage();
      if (initial == null) return;
      try {
        await sessionRestored;
      } catch (_) {
        // A failed restore just means signed out; route as such.
      }
      handleTap(initial.data);
    } catch (_) {}
  }

  void _onForegroundMessage(RemoteMessage message) {
    final data = message.data;
    final rawType = data['type'];
    final type = rawType is String ? rawType : null;
    // Silent, data-only account-closure push: never a visible/local
    // notification, never appended to the in-app list, never routed —
    // just force a local sign-out.
    if (type == 'account_closed') {
      authController.handleRemoteAccountClosed(
        deleted: data['reason'] == 'deleted',
      );
      return;
    }
    notificationsController.handleIncomingPush(
      title: message.notification?.title,
      body: message.notification?.body,
      data: data,
    );
    reloadListsForPushType(type);
  }

  /// Registers the current FCM token against `POST /api/v1/app/devices`.
  /// Best-effort: a missing token or a failed request must never block login;
  /// it is retried on the next app resume ([onResumed]).
  Future<void> registerDevice() async {
    final account = authController.account;
    if (account == null || _disposed) return;
    try {
      final token = await remotePushService.getToken();
      if (token == null) {
        _tokenMissing = true;
        return;
      }
      if (_disposed || !identical(authController.account, account)) return;
      await _post(account, token);
      _tokenMissing = false;
    } catch (_) {
      _tokenMissing = true;
      if (kDebugMode) {
        debugPrint('Push device registration could not complete.');
      }
    }
  }

  Future<void> _post(Object account, String token) async {
    final deviceId = await deviceIdStore.getOrCreate();
    if (_disposed || !identical(authController.account, account)) return;
    await deviceRepository.registerDevice(
      deviceId: deviceId,
      platform: _platformName,
      firebaseToken: token,
    );
  }

  /// The API contract requires re-registering whenever the FCM token
  /// refreshes, but only while signed in.
  Future<void> _onTokenRefreshed(String token) async {
    final account = authController.account;
    if (account == null || _disposed) return;
    try {
      await _post(account, token);
      _tokenMissing = false;
    } catch (_) {
      _tokenMissing = true;
    }
  }

  /// Call on every app resume: retries a registration that had no token.
  void onResumed() {
    if (_tokenMissing && authController.isAuthenticated) registerDevice();
  }

  /// `beforeSignOut` hook: runs while the session is still valid.
  Future<void> removeDeviceForSignOut() async {
    _tokenMissing = false;
    try {
      final deviceId = await deviceIdStore.getOrCreate();
      // Bounded: sign-out awaits this before clearing the token, and must
      // not hang on a slow network.
      await deviceRepository
          .removeDevice(deviceId)
          .timeout(const Duration(seconds: 4));
    } catch (_) {
      // Best-effort — matches the API doc's "call during logout when possible".
    }
    // Whether or not the DELETE landed, drop this install's FCM token so the
    // signed-out account's pushes can't keep arriving here.
    try {
      await remotePushService.deleteToken().timeout(const Duration(seconds: 4));
    } catch (_) {}
  }

  /// Best-effort safety net for the 401-triggered path (token already invalid
  /// server-side, so this is expected to fail there too).
  void removeDeviceAfterUnhandledSignOut() {
    removeDeviceForSignOut();
  }

  String get _platformName =>
      defaultTargetPlatform == TargetPlatform.iOS ? 'IOS' : 'ANDROID';

  void dispose() {
    _disposed = true;
    _tokenRefreshSubscription.cancel();
    _foregroundMessageSubscription.cancel();
    _notificationTapSubscription.cancel();
  }
}
