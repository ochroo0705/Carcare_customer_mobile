import 'package:firebase_messaging/firebase_messaging.dart';

/// Thin wrapper around `FirebaseMessaging.instance`, injectable so
/// `CustomerRouterDelegate` (and the widget tests that construct
/// `CarCareCustomerApp` directly, bypassing `main()`/`Firebase.initializeApp()`)
/// never touch the real plugin unless explicitly given a
/// [FirebaseRemotePushService].
abstract interface class RemotePushService {
  Future<String?> getToken();

  Stream<String> get onTokenRefresh;

  Stream<RemoteMessage> get onMessage;
}

class FirebaseRemotePushService implements RemotePushService {
  @override
  Future<String?> getToken() => FirebaseMessaging.instance.getToken();

  @override
  Stream<String> get onTokenRefresh =>
      FirebaseMessaging.instance.onTokenRefresh;

  @override
  Stream<RemoteMessage> get onMessage => FirebaseMessaging.onMessage;
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
}
