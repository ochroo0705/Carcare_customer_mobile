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

  Future<void> initialize() async {
    if (_initialized) return;
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings();
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      ),
    );
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
    await _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true, badge: true, sound: true);
    _initialized = true;
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
    );
  }
}
