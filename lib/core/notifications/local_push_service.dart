import 'dart:convert';

import 'package:carcare_customer_mobile/features/notifications/domain/app_notification.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Demo-only local device notifications, standing in for real push until a
/// Firebase project and backend push infrastructure exist. See
/// CUSTOMER_FLUTTER_PROGRESS.md for the scope decision.
class LocalPushService {
  LocalPushService._();

  static final LocalPushService instance = LocalPushService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  var _initialized = false;

  /// Called with the routable push data when the user taps a local banner.
  /// Set by the app once navigation exists; a tap before then is dropped.
  void Function(Map<String, dynamic> data)? onTap;

  Future<void> initialize() async {
    if (_initialized) return;
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    // Never prompt from here: this runs on every launch, including the first,
    // before onboarding is shown. Onboarding's permissions page and the
    // post-onboarding FirebaseMessaging request in main.dart own the prompt.
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      ),
      onDidReceiveNotificationResponse: _onResponse,
    );
    _initialized = true;
  }

  void _onResponse(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null || payload.isEmpty) return;
    try {
      final decoded = jsonDecode(payload);
      if (decoded is Map<String, dynamic>) onTap?.call(decoded);
    } catch (_) {
      // A malformed payload is ignored rather than crashing the tap.
    }
  }

  Future<void> show(AppNotification notification) async {
    if (!_initialized) return;
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'carcare_customer_default',
        'Carservice мэдэгдэл',
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(),
    );
    await _plugin.show(
      id: notification.id.hashCode,
      title: notification.title,
      body: notification.message,
      notificationDetails: details,
      payload: jsonEncode(notification.data),
    );
  }
}
