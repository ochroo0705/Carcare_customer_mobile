import 'dart:typed_data';

import 'package:carcare_customer_mobile/app/app_dependencies.dart';
import 'package:carcare_customer_mobile/core/analytics/analytics_service.dart';
import 'package:carcare_customer_mobile/core/connectivity/connectivity_service.dart';
import 'package:carcare_customer_mobile/core/network/api_client.dart';
import 'package:carcare_customer_mobile/core/notifications/remote_push_service.dart';
import 'package:carcare_customer_mobile/data/cache/cache_store.dart';
import 'package:carcare_customer_mobile/features/auth/data/fake_auth_repository.dart';
import 'package:carcare_customer_mobile/features/auth/data/secure_session_store.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

class _TagAdapter implements HttpClientAdapter {
  _TagAdapter(this.tag, this.hits);
  final String tag;
  final List<String> hits;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    hits.add(tag);
    throw DioException(
      requestOptions: options,
      type: DioExceptionType.connectionError,
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  test('each repository is wired to the right client', () async {
    final hits = <String>[];
    final created = <bool>[];
    final deps = AppDependencies.remote(
      cacheStore: const NoopCacheStore(),
      remotePushService: const NoopRemotePushService(),
      analytics: const NoopAnalyticsService(),
      connectivityService: const NoopConnectivityService(),
      sessionStore: SecureSessionStore(),
      baseUrl: 'https://example.test/api/v1/app',
      clientFactory: ({required authenticated}) {
        created.add(authenticated);
        final tag = authenticated ? 'authed' : 'public';
        final dio = Dio(BaseOptions(baseUrl: 'https://example.test/api'))
          ..httpClientAdapter = _TagAdapter(tag, hits);
        return ApiClient(baseUrl: 'https://example.test/api', dio: dio);
      },
    );
    expect(created, [true, false]);

    Future<String> tagOf(Future<Object?> Function() call) async {
      hits.clear();
      try {
        await call();
      } on Object {
        // The stub always fails; only which client saw the request matters.
      }
      expect(hits, hasLength(1));
      return hits.single;
    }

    final authed = <String, Future<Object?> Function()>{
      'auth': () => deps.authRepository.requestOtp('99112233'),
      'appointments': () => deps.appointmentRepository.getAppointments(),
      'vehicles': () => deps.vehicleRepository.getVehicles(),
      'history': () => deps.historyRepository.getServiceHistory(),
      'diagnostics': () => deps.diagnosticsRepository.getDiagnostics(),
      'notifications': () => deps.notificationsRepository.getNotifications(),
      'devices': () => deps.deviceRepository.removeDevice('d1'),
    };
    for (final entry in authed.entries) {
      expect(await tagOf(entry.value), 'authed', reason: entry.key);
    }
    expect(
      await tagOf(() => deps.organizationRepository.getOrganizations()),
      'public',
    );
  });

  test('build() with useFakeApi wires fakes and creates no clients', () {
    var built = 0;
    final deps = AppDependencies.build(
      cacheStore: const NoopCacheStore(),
      remotePushService: const NoopRemotePushService(),
      analytics: const NoopAnalyticsService(),
      connectivityService: const NoopConnectivityService(),
      useFakeApi: true,
      clientFactory: ({required authenticated}) {
        built++;
        return ApiClient(baseUrl: 'https://example.test/api');
      },
    );
    expect(deps.authRepository, isA<FakeAuthRepository>());
    expect(built, 0);
  });
}
