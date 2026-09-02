import 'package:carcare_customer_mobile/app/app.dart';
import 'package:carcare_customer_mobile/core/config/app_environment.dart';
import 'package:carcare_customer_mobile/core/connectivity/connectivity_service.dart';
import 'package:carcare_customer_mobile/core/network/api_client.dart';
import 'package:carcare_customer_mobile/core/notifications/local_push_service.dart';
import 'package:carcare_customer_mobile/core/notifications/remote_push_service.dart';
import 'package:carcare_customer_mobile/features/auth/data/fake_auth_repository.dart';
import 'package:carcare_customer_mobile/features/auth/data/remote_auth_repository.dart';
import 'package:carcare_customer_mobile/features/auth/data/secure_session_store.dart';
import 'package:carcare_customer_mobile/features/booking/data/fake_appointment_repository.dart';
import 'package:carcare_customer_mobile/features/booking/data/remote_appointment_repository.dart';
import 'package:carcare_customer_mobile/features/devices/data/fake_device_repository.dart';
import 'package:carcare_customer_mobile/features/devices/data/remote_device_repository.dart';
import 'package:carcare_customer_mobile/features/discovery/data/fake_organization_repository.dart';
import 'package:carcare_customer_mobile/features/discovery/data/remote_organization_repository.dart';
import 'package:carcare_customer_mobile/features/vehicles/data/fake_vehicle_repository.dart';
import 'package:carcare_customer_mobile/features/vehicles/data/remote_vehicle_repository.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

/// Must be top-level (not a method/closure) — the plugin may run this in a
/// background isolate that never ran `main()`, so Firebase needs its own
/// initialization here too. Background/terminated `notification`-block
/// messages are otherwise displayed by the OS automatically; this handler
/// only needs to exist so the plugin doesn't warn about a missing one and so
/// data-only messages don't get silently dropped in the background.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  final remotePushService = FirebaseRemotePushService();
  await FirebaseMessaging.instance.requestPermission();
  await LocalPushService.instance.initialize();
  final organizationRepository = AppEnvironment.useFakeApi
      ? FakeOrganizationRepository()
      : RemoteOrganizationRepository(
          ApiClient(baseUrl: AppEnvironment.apiBaseUrl),
        );
  final sessionStore = SecureSessionStore();
  final authRepository = AppEnvironment.useFakeApi
      ? FakeAuthRepository()
      : RemoteAuthRepository(
          ApiClient(baseUrl: AppEnvironment.apiBaseUrl),
          sessionStore,
        );
  final deviceRepository = AppEnvironment.useFakeApi
      ? FakeDeviceRepository()
      : RemoteDeviceRepository(
          ApiClient(
            baseUrl: AppEnvironment.apiBaseUrl,
            accessTokenProvider: sessionStore.readToken,
            onUnauthorized: sessionStore.clear,
          ),
        );
  final appointmentRepository = AppEnvironment.useFakeApi
      ? FakeAppointmentRepository()
      : RemoteAppointmentRepository(
          ApiClient(
            baseUrl: AppEnvironment.apiBaseUrl,
            accessTokenProvider: sessionStore.readToken,
            onUnauthorized: sessionStore.clear,
          ),
        );
  final vehicleRepository = AppEnvironment.useFakeApi
      ? FakeVehicleRepository()
      : RemoteVehicleRepository(
          ApiClient(
            baseUrl: AppEnvironment.apiBaseUrl,
            accessTokenProvider: sessionStore.readToken,
            onUnauthorized: sessionStore.clear,
          ),
        );
  runApp(
    CarCareCustomerApp(
      organizationRepository: organizationRepository,
      authRepository: authRepository,
      appointmentRepository: appointmentRepository,
      vehicleRepository: vehicleRepository,
      deviceRepository: deviceRepository,
      remotePushService: remotePushService,
      connectivityService: const PlatformConnectivityService(),
    ),
  );
}
