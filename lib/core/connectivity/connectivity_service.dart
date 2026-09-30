import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';

/// Reports whether the device currently has network connectivity, injectable
/// so `CustomerAppServices` (and the widget tests that construct
/// `CarCareCustomerApp` directly, bypassing `main()`) never touch the real
/// `connectivity_plus` platform channel unless explicitly given a
/// [PlatformConnectivityService] — mirrors [RemotePushService]'s pattern.
abstract interface class ConnectivityService {
  /// Emits `true` once the customer API is verified reachable, and `false`
  /// when the device loses every network interface or the API stops
  /// answering. Consecutive duplicates are never emitted.
  Stream<bool> get onConnectivityChanged;
}

/// Returns `true` when the customer API actually answered.
typedef ReachabilityProbe = Future<bool> Function();

/// `connectivity_plus` only reports that an interface exists — Wi-Fi with no
/// internet or a captive portal still reads as "online". This service treats
/// an interface as a hint and confirms it with [probe] before emitting
/// `true`:
///
/// - OS events are debounced ([debounce]) so a Wi-Fi → mobile handover or a
///   flapping link causes one check, not several.
/// - Losing every interface emits `false` immediately (no probe needed).
/// - A failed probe is retried after each of [retryDelays]; if all fail it
///   emits `false` and keeps re-probing every [recheckInterval] while an
///   interface is up — e.g. until the customer signs in to a captive portal,
///   which raises no OS event.
class PlatformConnectivityService implements ConnectivityService {
  PlatformConnectivityService({
    required this.probe,
    this.changes,
    this.checkNow,
    this.debounce = const Duration(seconds: 1),
    this.retryDelays = const [Duration(seconds: 2), Duration(seconds: 5)],
    this.recheckInterval = const Duration(seconds: 30),
  });

  final ReachabilityProbe probe;

  /// OS interface events; defaults to `connectivity_plus` (tests inject).
  final Stream<List<ConnectivityResult>>? changes;
  final Future<List<ConnectivityResult>> Function()? checkNow;
  final Duration debounce;
  final List<Duration> retryDelays;
  final Duration recheckInterval;

  @override
  Stream<bool> get onConnectivityChanged {
    late final StreamController<bool> controller;
    StreamSubscription<bool>? osSubscription;
    Timer? timer;
    var generation = 0;
    bool? last;

    void emit(bool online) {
      if (online == last || controller.isClosed) return;
      last = online;
      controller.add(online);
    }

    Future<void> verify(int gen) async {
      final attempts = [Duration.zero, ...retryDelays];
      for (final delay in attempts) {
        if (delay > Duration.zero) await Future<void>.delayed(delay);
        if (gen != generation) return;
        bool ok;
        try {
          ok = await probe();
        } catch (_) {
          ok = false;
        }
        if (gen != generation) return;
        if (ok) {
          emit(true);
          return;
        }
      }
      emit(false);
      timer = Timer(recheckInterval, () => verify(gen));
    }

    void onInterfaces(bool hasInterface) {
      final gen = ++generation;
      timer?.cancel();
      if (!hasInterface) {
        emit(false);
        return;
      }
      timer = Timer(debounce, () => verify(gen));
    }

    bool anyInterface(List<ConnectivityResult> results) =>
        results.any((result) => result != ConnectivityResult.none);

    controller = StreamController<bool>(
      onListen: () {
        osSubscription = (changes ?? Connectivity().onConnectivityChanged)
            .map(anyInterface)
            .listen(onInterfaces);
        // The OS stream isn't guaranteed to emit the current state on
        // subscribe, so seed it once.
        (checkNow ?? Connectivity().checkConnectivity)().then((results) {
          if (generation == 0) onInterfaces(anyInterface(results));
        }, onError: (Object _) {});
      },
      onCancel: () async {
        generation++;
        timer?.cancel();
        await osSubscription?.cancel();
      },
    );
    return controller.stream;
  }
}

/// Probes the customer API's `GET /health` (public, no DB, no rate limit —
/// see `CUSTOMER_API_CONTRACT.md`). Any JSON response below 500 proves our
/// server answered; a captive portal's HTML page or a timeout does not.
class ApiReachabilityProbe {
  ApiReachabilityProbe(String baseUrl, {Dio? dio, this.path = '/health'})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: baseUrl.endsWith('/')
                  ? baseUrl.substring(0, baseUrl.length - 1)
                  : baseUrl,
              connectTimeout: const Duration(seconds: 3),
              receiveTimeout: const Duration(seconds: 3),
              validateStatus: (_) => true,
              followRedirects: false,
              responseType: ResponseType.plain,
            ),
          );

  final Dio _dio;
  final String path;

  Future<bool> call() async {
    try {
      final response = await _dio.get<String>(path);
      final status = response.statusCode ?? 0;
      final contentType = response.headers.value(Headers.contentTypeHeader);
      return status < 500 &&
          (contentType?.contains('application/json') ?? false);
    } on DioException {
      return false;
    }
  }
}

/// Default for anywhere that doesn't explicitly wire the real platform
/// service — every existing widget test that constructs `CarCareCustomerApp`
/// gets this.
class NoopConnectivityService implements ConnectivityService {
  const NoopConnectivityService();

  @override
  Stream<bool> get onConnectivityChanged => const Stream.empty();
}
