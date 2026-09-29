import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';

/// Product analytics, injectable so widget tests (and anything constructing
/// `CarCareCustomerApp` without `main()`/`Firebase.initializeApp()`) never touch
/// the real plugin unless explicitly given a [FirebaseAnalyticsService].
///
/// Events carry no personal data — only flow/step names and outcomes.
abstract interface class AnalyticsService {
  Future<void> logEvent(String name, [Map<String, Object>? parameters]);
}

class FirebaseAnalyticsService implements AnalyticsService {
  FirebaseAnalyticsService({FirebaseAnalytics? analytics})
    : _analytics = analytics ?? FirebaseAnalytics.instance;

  final FirebaseAnalytics _analytics;

  @override
  Future<void> logEvent(String name, [Map<String, Object>? parameters]) async {
    try {
      await _analytics.logEvent(name: name, parameters: parameters);
    } catch (e) {
      // Analytics must never break a user flow.
      debugPrint('analytics: $name failed: $e');
    }
  }
}

class NoopAnalyticsService implements AnalyticsService {
  const NoopAnalyticsService();

  @override
  Future<void> logEvent(String name, [Map<String, Object>? parameters]) async {}
}
