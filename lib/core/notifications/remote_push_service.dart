import 'package:firebase_messaging/firebase_messaging.dart';

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
  @override
  Future<String?> getToken() => FirebaseMessaging.instance.getToken();

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
