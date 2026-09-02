import 'package:connectivity_plus/connectivity_plus.dart';

/// Reports whether the device currently has network connectivity, injectable
/// so `CustomerRouterDelegate` (and the widget tests that construct
/// `CarCareCustomerApp` directly, bypassing `main()`) never touch the real
/// `connectivity_plus` platform channel unless explicitly given a
/// [PlatformConnectivityService] — mirrors [RemotePushService]'s pattern.
abstract interface class ConnectivityService {
  /// Emits `true` whenever the device transitions to having at least one
  /// active network interface, and `false` when it loses all of them.
  Stream<bool> get onConnectivityChanged;
}

class PlatformConnectivityService implements ConnectivityService {
  const PlatformConnectivityService();

  @override
  Stream<bool> get onConnectivityChanged =>
      Connectivity().onConnectivityChanged.map(
        (results) => results.any((result) => result != ConnectivityResult.none),
      );
}

/// Default for anywhere that doesn't explicitly wire the real platform
/// service — every existing widget test that constructs `CarCareCustomerApp`
/// gets this.
class NoopConnectivityService implements ConnectivityService {
  const NoopConnectivityService();

  @override
  Stream<bool> get onConnectivityChanged => const Stream.empty();
}
