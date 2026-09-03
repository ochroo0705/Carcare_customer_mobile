import 'dart:async';

import 'package:carcare_customer_mobile/app/app.dart';
import 'package:carcare_customer_mobile/core/config/app_environment.dart';
import 'package:carcare_customer_mobile/core/connectivity/connectivity_service.dart';
import 'package:carcare_customer_mobile/core/network/api_client.dart';
import 'package:carcare_customer_mobile/core/notifications/local_push_service.dart';
import 'package:carcare_customer_mobile/core/notifications/remote_push_service.dart';
import 'package:carcare_customer_mobile/data/cache/cache_database.dart';
import 'package:carcare_customer_mobile/data/cache/drift_cache_store.dart';
import 'package:carcare_customer_mobile/features/auth/data/fake_auth_repository.dart';
import 'package:carcare_customer_mobile/features/auth/data/remote_auth_repository.dart';
import 'package:carcare_customer_mobile/features/auth/data/secure_session_store.dart';
import 'package:carcare_customer_mobile/features/booking/data/fake_appointment_repository.dart';
import 'package:carcare_customer_mobile/features/booking/data/remote_appointment_repository.dart';
import 'package:carcare_customer_mobile/features/devices/data/fake_device_repository.dart';
import 'package:carcare_customer_mobile/features/devices/data/remote_device_repository.dart';
import 'package:carcare_customer_mobile/features/discovery/data/caching_organization_repository.dart';
import 'package:carcare_customer_mobile/features/discovery/data/fake_organization_repository.dart';
import 'package:carcare_customer_mobile/features/discovery/data/remote_organization_repository.dart';
import 'package:carcare_customer_mobile/features/vehicles/data/fake_vehicle_repository.dart';
import 'package:carcare_customer_mobile/features/vehicles/data/remote_vehicle_repository.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
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

  // Route uncaught errors to Crashlytics. Collection is disabled in debug so
  // local runs don't pollute production crash data; release/profile builds
  // report. `recordFlutterFatalError` handles framework build/layout errors;
  // the platformDispatcher hook catches uncaught async errors outside Flutter.
  await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(
    !kDebugMode,
  );
  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
  WidgetsBinding.instance.platformDispatcher.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  final remotePushService = FirebaseRemotePushService();
  final cacheStore = DriftCacheStore(CacheDatabase());
  // Cache-first-with-TTL for org detail (hours/address/phone) — served from the
  // local DB when recently seen, so the appointment detail's location card and
  // the discovery detail page skip a round-trip and work offline.
  final organizationRepository = CachingOrganizationRepository(
    AppEnvironment.useFakeApi
        ? FakeOrganizationRepository()
        : RemoteOrganizationRepository(
            ApiClient(baseUrl: AppEnvironment.apiBaseUrl),
          ),
    cacheStore,
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
      cacheStore: cacheStore,
    ),
  );

  // Deferred until after the first frame so launch is never gated on them.
  // `requestPermission()` in particular blocks on the OS permission dialog
  // on first run; the local-notification channel setup is a plugin round-trip.
  // Neither needs to complete before the UI is visible — a foreground push in
  // the brief window before this finishes is the only edge, and it's rare.
  unawaited(_initPushNotifications());
}

Future<void> _initPushNotifications() async {
  await FirebaseMessaging.instance.requestPermission();
  await LocalPushService.instance.initialize();
}
