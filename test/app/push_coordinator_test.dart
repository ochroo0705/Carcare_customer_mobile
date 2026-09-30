import 'dart:async';

import 'package:carcare_customer_mobile/app/app.dart';
import 'package:carcare_customer_mobile/app/bootstrap_flags.dart';
import 'package:carcare_customer_mobile/app/customer_app_services.dart';
import 'package:carcare_customer_mobile/app/customer_navigation.dart';
import 'package:go_router/go_router.dart';
import 'package:carcare_customer_mobile/core/connectivity/connectivity_service.dart';
import 'package:carcare_customer_mobile/core/notifications/remote_push_service.dart';
import 'package:carcare_customer_mobile/data/cache/cache_store.dart';
import 'package:carcare_customer_mobile/features/auth/domain/account.dart';
import 'package:carcare_customer_mobile/features/booking/data/fake_appointment_repository.dart';
import 'package:carcare_customer_mobile/features/devices/data/device_id_store.dart';
import 'package:carcare_customer_mobile/features/devices/data/fake_device_repository.dart';
import 'package:carcare_customer_mobile/features/diagnostics/data/fake_diagnostics_repository.dart';
import 'package:carcare_customer_mobile/features/discovery/data/fake_organization_repository.dart';
import 'package:carcare_customer_mobile/features/history/data/fake_service_history_repository.dart';
import 'package:carcare_customer_mobile/features/notifications/data/fake_notifications_repository.dart';
import 'package:carcare_customer_mobile/features/vehicles/data/fake_vehicle_repository.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/mocks.dart';

class _Push extends Fake implements RemotePushService {
  final _incoming = StreamController<RemoteMessage>.broadcast();
  final _refresh = StreamController<String>.broadcast();
  String? token;
  RemoteMessage? initial;

  void arrive(Map<String, dynamic> data) =>
      _incoming.add(RemoteMessage(data: data));
  void refresh(String t) => _refresh.add(t);

  @override
  Stream<RemoteMessage> get onMessage => _incoming.stream;
  @override
  Stream<RemoteMessage> get onMessageOpenedApp => const Stream.empty();
  @override
  Stream<String> get onTokenRefresh => _refresh.stream;
  @override
  Future<String?> getToken() async => token;
  @override
  Future<RemoteMessage?> getInitialMessage() async => initial;
  @override
  Future<void> deleteToken() async {}
}

class _Devices extends FakeDeviceRepository {
  final registered = <String>[];

  @override
  Future<void> registerDevice({
    required String deviceId,
    required String platform,
    required String firebaseToken,
    String? name,
    String? model,
    String? os,
  }) async => registered.add(firebaseToken);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => debugDisableAppBootstrap = true);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('cold-start tap waits for a slow session restore', (
    tester,
  ) async {
    final restore = Completer<Account?>();
    final auth = signedInAuthRepository();
    when(() => auth.restoreSession()).thenAnswer((_) => restore.future);
    final push = _Push()
      ..initial = RemoteMessage(
        data: const {
          'type': 'appointment_confirmed',
          'appointmentId': 'seed-1',
        },
      );
    await tester.pumpWidget(
      CarCareCustomerApp(
        organizationRepository: FakeOrganizationRepository(),
        authRepository: auth,
        appointmentRepository: FakeAppointmentRepository(),
        remotePushService: push,
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));
    restore.complete(testAccount);
    await tester.pumpAndSettle();

    expect(find.text('Цагийн дэлгэрэнгүй'), findsOneWidget);
  });

  group('services', () {
    late _Push push;
    late _Devices devices;
    late CustomerAppServices services;

    Future<void> boot() async {
      push = _Push();
      devices = _Devices();
      services = CustomerAppServices(
        organizationRepository: FakeOrganizationRepository(
          delay: Duration.zero,
        ),
        authRepository: signedInAuthRepository(),
        appointmentRepository: FakeAppointmentRepository(),
        vehicleRepository: FakeVehicleRepository(),
        historyRepository: FakeServiceHistoryRepository(),
        diagnosticsRepository: FakeDiagnosticsRepository(),
        notificationsRepository: FakeNotificationsRepository(),
        deviceRepository: devices,
        remotePushService: push,
        deviceIdStore: DeviceIdStore(),
        connectivityService: const NoopConnectivityService(),
        cacheStore: const NoopCacheStore(),
      );
      await pumpEventQueue();
    }

    tearDown(() => services.dispose());

    test(
      'a foreground push with a non-string type is ignored, not thrown',
      () async {
        await boot();
        push.arrive({'type': 42, 'reason': 'deleted'});
        await pumpEventQueue();
        expect(services.authController.isAuthenticated, isTrue);
      },
    );

    test(
      'a tap with a non-string type is delivered without the type',
      () async {
        await boot();
        Map<String, dynamic>? got;
        services.onNotificationTap = (d) => got = d;
        services.push.handleTap({'type': 7, 'appointmentId': 'a1'});
        expect(got, {'appointmentId': 'a1'});
      },
    );

    test('openFromPush tolerates a non-string type (list-row tap)', () async {
      await boot();
      final nav = CustomerNavigation(services)
        ..router = GoRouter(
          routes: [GoRoute(path: '/', builder: (_, _) => const SizedBox())],
        );
      expect(
        () => nav.openFromPush({
          'type': 7,
          'appointmentId': 'a1',
        }, fromList: true),
        returnsNormally,
      );
      await pumpEventQueue();
    });

    test('a token-missing registration is retried once per resume', () async {
      await boot();
      expect(devices.registered, isEmpty);
      push.token = 'tok-1';
      services.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await pumpEventQueue();
      expect(devices.registered, ['tok-1']);
      services.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await pumpEventQueue();
      expect(devices.registered, ['tok-1']);
    });

    test('a token refresh registers the new token while signed in', () async {
      await boot();
      push.refresh('tok-2');
      await pumpEventQueue();
      expect(devices.registered, ['tok-2']);
    });
  });
}
