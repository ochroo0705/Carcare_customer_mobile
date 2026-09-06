import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

/// Thin wrapper around `FirebaseMessaging.instance`, injectable so
/// `CustomerRouterDelegate` (and the widget tests that construct
/// `CarCareCustomerApp` directly, bypassing `main()`/`Firebase.initializeApp()`)
/// never touch the real plugin unless explicitly given a
/// [FirebaseRemotePushService].
abstract interface class RemotePushService {
  Future<String?> getToken();

  Stream<String> get onTokenRefresh;

  /// Foreground messages (the OS does not display these; the app shows a local
  /// banner and appends to the in-app list).
  Stream<RemoteMessage> get onMessage;

  /// Fires when the user taps a notification while the app is in the
  /// background (not terminated). Used to deep-link into the relevant screen.
  Stream<RemoteMessage> get onMessageOpenedApp;

  /// The notification that cold-started the app (tapped while terminated), or
  /// `null` if the app was launched normally. Deliver-once semantics — the
  /// plugin returns it only on the first call after launch.
  Future<RemoteMessage?> getInitialMessage();
}

class FirebaseRemotePushService implements RemotePushService {
  FirebaseRemotePushService({
    Future<String?> Function()? readApnsToken,
    Future<String?> Function()? readFcmToken,
    Future<void> Function(Duration)? wait,
    bool? requiresApns,
  }) : _readApnsToken =
           readApnsToken ?? (() => FirebaseMessaging.instance.getAPNSToken()),
       _readFcmToken =
           readFcmToken ?? (() => FirebaseMessaging.instance.getToken()),
       _wait = wait ?? ((duration) => Future<void>.delayed(duration)),
       _requiresApns =
           requiresApns ??
           (!kIsWeb &&
               (defaultTargetPlatform == TargetPlatform.iOS ||
                   defaultTargetPlatform == TargetPlatform.macOS));

  // Injectable token readers/delay keep startup-race tests independent of
  // Firebase initialization, native plugins, and wall-clock waits.
  final Future<String?> Function() _readApnsToken;
  final Future<String?> Function() _readFcmToken;
  final Future<void> Function(Duration) _wait;
  final bool _requiresApns;
  Future<String?>? _pendingToken;

  /// Apple must finish APNs registration before FCM can issue its token.
  /// Permission prompts remain owned by onboarding/startup, not this retry.
  /// Retry every 500 ms for up to 20 waits; later token-refresh events and
  /// subsequent sign-ins can still register if APNs takes longer to arrive.
  @override
  Future<String?> getToken() async {
    final pending = _pendingToken;
    if (pending != null) return pending;
    final request = _loadToken();
    _pendingToken = request;
    try {
      return await request;
    } finally {
      _pendingToken = null;
    }
  }

  Future<String?> _loadToken() async {
    if (!_requiresApns) return _readFcmToken();

    const retries = 20;
    const interval = Duration(milliseconds: 500);
    for (var attempt = 0; attempt <= retries; attempt++) {
      try {
        final apnsToken = await _readApnsToken();
        if (apnsToken != null && apnsToken.isNotEmpty) {
          return await _readFcmToken();
        }
      } on FirebaseException catch (error) {
        // The native token can still be propagating when FCM is queried.
        // Do not retry permission/configuration/network errors as APNs races.
        if (error.code != 'apns-token-not-set') rethrow;
      }
      if (attempt < retries) await _wait(interval);
    }
    if (kDebugMode) {
      debugPrint('Push registration deferred: APNs token is not ready.');
    }
    return null;
  }

  @override
  Stream<String> get onTokenRefresh =>
      FirebaseMessaging.instance.onTokenRefresh;

  @override
  Stream<RemoteMessage> get onMessage => FirebaseMessaging.onMessage;

  @override
  Stream<RemoteMessage> get onMessageOpenedApp =>
      FirebaseMessaging.onMessageOpenedApp;

  @override
  Future<RemoteMessage?> getInitialMessage() =>
      FirebaseMessaging.instance.getInitialMessage();
}

/// Default for anywhere that doesn't explicitly wire real FCM — every
/// existing widget test that constructs `CarCareCustomerApp` gets this.
class NoopRemotePushService implements RemotePushService {
  const NoopRemotePushService();

  @override
  Future<String?> getToken() async => null;

  @override
  Stream<String> get onTokenRefresh => const Stream.empty();

  @override
  Stream<RemoteMessage> get onMessage => const Stream.empty();

  @override
  Stream<RemoteMessage> get onMessageOpenedApp => const Stream.empty();

  @override
  Future<RemoteMessage?> getInitialMessage() async => null;
}
