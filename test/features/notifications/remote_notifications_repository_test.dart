import 'dart:convert';
import 'dart:typed_data';

import 'package:carcare_customer_mobile/core/errors/app_failure.dart';
import 'package:carcare_customer_mobile/core/network/api_client.dart';
import 'package:carcare_customer_mobile/features/notifications/data/remote_notifications_repository.dart';
import 'package:carcare_customer_mobile/features/notifications/domain/app_notification.dart';
import 'package:carcare_customer_mobile/features/notifications/domain/notification_type.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// Minimal Dio adapter that returns canned JSON per requested path and records
/// the method + path of every request.
class _StubAdapter implements HttpClientAdapter {
  _StubAdapter(this.responses);
  final Map<String, Object> responses;
  final List<String> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final path = options.path;
    requests.add('${options.method} $path');
    final key = responses.keys.firstWhere(
      (k) => path == k,
      orElse: () => throw StateError('No stub for $path'),
    );
    return ResponseBody.fromString(
      jsonEncode(responses[key]),
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

({RemoteNotificationsRepository repo, _StubAdapter adapter}) _repo(
  Map<String, Object> responses,
) {
  final adapter = _StubAdapter(responses);
  final dio = Dio(BaseOptions(baseUrl: 'https://example.test/api/v1/app'))
    ..httpClientAdapter = adapter;
  return (
    repo: RemoteNotificationsRepository(
      ApiClient(baseUrl: 'https://example.test/api/v1/app', dio: dio),
    ),
    adapter: adapter,
  );
}

Map<String, Object?> _row({
  String id = 'notif-1',
  String type = 'order_completed',
  bool read = false,
  Object? data = const {'type': 'order_completed', 'appointmentId': 'appt-1'},
}) => {
  'id': id,
  'type': type,
  'title': 'Захиалга дууслаа',
  'body': 'Таны засварын хуудас дууслаа.',
  'data': data,
  'read': read,
  'createdAt': '2026-09-17T10:00:00.000Z',
};

void main() {
  test('getNotifications parses the list and the server unread count', () async {
    final (:repo, :adapter) = _repo({
      '/notifications': {
        'notifications': [_row(), _row(id: 'notif-2', read: true)],
        'pagination': {'page': 1, 'total': 2},
        'unreadCount': 7,
      },
    });

    final page = await repo.getNotifications();

    expect(adapter.requests, ['GET /notifications']);
    expect(page.items, hasLength(2));
    expect(page.items.first.type, NotificationType.orderCompleted);
    expect(page.items.first.isRead, isFalse);
    // Deliberately larger than the unread rows on this page — the badge must
    // follow the server, not the page.
    expect(page.unreadCount, 7);
  });

  test('getNotifications keeps the routable ids from `data`', () async {
    final (:repo, adapter: _) = _repo({
      '/notifications': {
        'notifications': [_row()],
        'unreadCount': 1,
      },
    });

    final page = await repo.getNotifications();

    expect(page.items.single.data['appointmentId'], 'appt-1');
  });

  test('getNotifications drops non-string `data` values', () async {
    final (:repo, adapter: _) = _repo({
      '/notifications': {
        'notifications': [
          _row(data: {'appointmentId': 42, 'orderId': 'ord-1'}),
        ],
        'unreadCount': 1,
      },
    });

    final page = await repo.getNotifications();

    expect(page.items.single.data, {'orderId': 'ord-1'});
  });

  test('getNotifications renders an unknown type instead of failing', () async {
    final (:repo, adapter: _) = _repo({
      '/notifications': {
        'notifications': [_row(type: 'something_new_server_side', data: null)],
        'unreadCount': 1,
      },
    });

    final page = await repo.getNotifications();

    expect(page.items.single.type, NotificationType.broadcast);
    expect(page.items.single.data, isEmpty);
  });

  test('getNotifications falls back to the page when unreadCount is absent', () async {
    final (:repo, adapter: _) = _repo({
      '/notifications': {
        'notifications': [_row(), _row(id: 'notif-2', read: true)],
      },
    });

    final page = await repo.getNotifications();

    expect(page.unreadCount, 1);
  });

  test('markRead PATCHes the notification', () async {
    final (:repo, :adapter) = _repo({
      '/notifications/notif-1/read': {'ok': true},
    });

    await repo.markRead('notif-1');

    expect(adapter.requests, ['PATCH /notifications/notif-1/read']);
  });

  test('markRead fails loudly when the server does not confirm', () async {
    final (:repo, adapter: _) = _repo({
      '/notifications/notif-1/read': {'ok': false},
    });

    expect(() => repo.markRead('notif-1'), throwsA(isA<UnexpectedFailure>()));
  });

  test('addExternal makes no request — the server stored the row first', () async {
    final (:repo, :adapter) = _repo({});

    await repo.addExternal(
      AppNotification(
        id: 'push-1',
        type: NotificationType.orderCompleted,
        title: 'Захиалга дууслаа',
        message: '',
        createdAt: DateTime(2026, 9, 17),
        isRead: false,
      ),
    );

    expect(adapter.requests, isEmpty);
  });

  test('markAllRead POSTs to read-all', () async {
    final (:repo, :adapter) = _repo({
      '/notifications/read-all': {'ok': true, 'count': 3},
    });

    await repo.markAllRead();

    expect(adapter.requests, ['POST /notifications/read-all']);
  });
}
