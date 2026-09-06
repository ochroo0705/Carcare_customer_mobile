import 'dart:async';

import 'package:carcare_customer_mobile/core/notifications/remote_push_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('non-Apple registration does not query APNs or delay FCM', () async {
    final service = FirebaseRemotePushService(
      requiresApns: false,
      readApnsToken: () async => throw StateError('Unexpected APNs call'),
      readFcmToken: () async => 'fcm-token',
      wait: (_) async => throw StateError('Unexpected wait'),
    );

    expect(await service.getToken(), 'fcm-token');
  });

  test('Apple registration waits for APNs before requesting FCM', () async {
    var apnsCalls = 0;
    var fcmCalls = 0;
    final waits = <Duration>[];
    final service = FirebaseRemotePushService(
      requiresApns: true,
      readApnsToken: () async => ++apnsCalls < 3 ? null : 'apns-token',
      readFcmToken: () async {
        expect(apnsCalls, 3);
        fcmCalls++;
        return 'fcm-token';
      },
      wait: (duration) async => waits.add(duration),
    );

    expect(await service.getToken(), 'fcm-token');
    expect(fcmCalls, 1);
    expect(waits, const [
      Duration(milliseconds: 500),
      Duration(milliseconds: 500),
    ]);
  });

  test('missing APNs token stops retrying without calling FCM', () async {
    var waits = 0;
    var ready = false;
    final service = FirebaseRemotePushService(
      requiresApns: true,
      readApnsToken: () async => ready ? 'apns-token' : '',
      readFcmToken: () async {
        expect(ready, isTrue);
        return 'fcm-token';
      },
      wait: (_) async => waits++,
    );

    expect(await service.getToken(), isNull);
    expect(waits, 20);
    // A later request must be able to recover after the bounded wait.
    ready = true;
    expect(await service.getToken(), 'fcm-token');
  });

  test('APNs propagation error from FCM is retried', () async {
    var fcmCalls = 0;
    final service = FirebaseRemotePushService(
      requiresApns: true,
      readApnsToken: () async => 'apns-token',
      readFcmToken: () async {
        if (++fcmCalls == 1) {
          throw FirebaseException(
            plugin: 'firebase_messaging',
            code: 'apns-token-not-set',
          );
        }
        return 'fcm-token';
      },
      wait: (_) async {},
    );

    expect(await service.getToken(), 'fcm-token');
    expect(fcmCalls, 2);
  });

  test('unrelated Firebase failure is propagated without retry', () async {
    final error = FirebaseException(
      plugin: 'firebase_messaging',
      code: 'permission-denied',
    );
    final service = FirebaseRemotePushService(
      requiresApns: true,
      readApnsToken: () async => 'apns-token',
      readFcmToken: () async => throw error,
      wait: (_) async => throw StateError('Unexpected retry'),
    );

    await expectLater(service.getToken(), throwsA(same(error)));
  });

  test('concurrent requests share one token acquisition', () async {
    final token = Completer<String?>();
    var fcmCalls = 0;
    final service = FirebaseRemotePushService(
      requiresApns: true,
      readApnsToken: () async => 'apns-token',
      readFcmToken: () {
        fcmCalls++;
        return token.future;
      },
    );

    final first = service.getToken();
    final second = service.getToken();
    token.complete('fcm-token');

    expect(await Future.wait([first, second]), ['fcm-token', 'fcm-token']);
    expect(fcmCalls, 1);
  });
}
