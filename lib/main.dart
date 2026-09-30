import 'dart:async';

import 'package:carcare_customer_mobile/app/app.dart';
import 'package:carcare_customer_mobile/app/app_dependencies.dart';
import 'package:carcare_customer_mobile/core/analytics/analytics_service.dart';
import 'package:carcare_customer_mobile/core/notifications/local_push_service.dart';
import 'package:carcare_customer_mobile/core/notifications/remote_push_service.dart';
import 'package:carcare_customer_mobile/data/cache/cache_database.dart';
import 'package:carcare_customer_mobile/data/cache/drift_cache_store.dart';
import 'package:carcare_customer_mobile/features/onboarding/data/onboarding_store.dart';
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
  // One composition root: USE_FAKE_API picks fake or remote for every feature
  // at once, and all authenticated repositories share one ApiClient.
  final dependencies = AppDependencies.build(
    cacheStore: DriftCacheStore(CacheDatabase()),
    remotePushService: FirebaseRemotePushService(),
    analytics: FirebaseAnalyticsService(),
  );
  runApp(CarCareCustomerApp.fromDependencies(dependencies));

  // Deferred until after the first frame so launch is never gated on them.
  // `requestPermission()` in particular blocks on the OS permission dialog
  // on first run; the local-notification channel setup is a plugin round-trip.
  // Neither needs to complete before the UI is visible — a foreground push in
  // the brief window before this finishes is the only edge, and it's rare.
  unawaited(_initPushNotifications());
}

Future<void> _initPushNotifications() async {
  // On first run, onboarding's permission page owns the notification prompt, so
  // don't ask here (it would fire before onboarding is even shown). On later
  // runs, request as before — harmless if already granted/denied.
  // Local banners are initialised first so a foreground push that arrives
  // while the OS permission dialog is up is not dropped.
  await LocalPushService.instance.initialize();
  if (await const OnboardingStore().hasCompleted()) {
    await FirebaseMessaging.instance.requestPermission();
  }
}
