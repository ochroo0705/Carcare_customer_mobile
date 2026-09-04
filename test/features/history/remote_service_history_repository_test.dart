import 'dart:convert';
import 'dart:typed_data';

import 'package:carcare_customer_mobile/core/network/api_client.dart';
import 'package:carcare_customer_mobile/features/history/data/remote_service_history_repository.dart';
import 'package:carcare_customer_mobile/features/history/domain/service_order_status.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// Minimal Dio adapter that returns canned JSON per requested path and records
/// the paths it was asked for.
class _StubAdapter implements HttpClientAdapter {
  _StubAdapter(this.responses);
  final Map<String, Object> responses;
  final List<String> requestedPaths = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final path = options.path;
    requestedPaths.add(path);
    final key = responses.keys.firstWhere(
      (k) => path == k || path.startsWith(k),
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

RemoteServiceHistoryRepository _repo(Map<String, Object> responses) {
  final dio = Dio(BaseOptions(baseUrl: 'https://example.test/api/v1/app'))
    ..httpClientAdapter = _StubAdapter(responses);
  return RemoteServiceHistoryRepository(
    ApiClient(baseUrl: 'https://example.test/api/v1/app', dio: dio),
  );
}

void main() {
  test('getServiceHistory requests /orders and parses the list', () async {
    final repo = _repo({
      '/orders': {
        'orders': [
          {
            'id': 'ord-1',
            'paymentStatus': 'PAID',
            'completedAt': '2026-09-01T10:00:00.000Z',
            'createdAt': '2026-08-30T10:00:00.000Z',
            'totalAmount': '150000',
            'paidAmount': '150000',
            'tenant': {'name': 'Инфосистемс', 'slug': 'infosystems'},
            'branch': {'name': 'Үндсэн салбар'},
            'vehicle': {'plate': '1234УБА'},
          },
        ],
        'pagination': {'page': 1, 'total': 1},
      },
    });

    final orders = await repo.getServiceHistory();
    expect(orders, hasLength(1));
    expect(orders.single.id, 'ord-1');
    expect(orders.single.status, ServiceOrderStatus.paid);
    expect(orders.single.totalAmount, 150000);
  });

  test('getServiceOrderDetail requests /orders/[id] and parses detail',
      () async {
    final repo = _repo({
      '/orders/ord-9': {
        'order': {
          'id': 'ord-9',
          'paymentStatus': 'PARTIAL',
          'completedAt': '2026-09-01T10:00:00.000Z',
          'createdAt': '2026-08-30T10:00:00.000Z',
          'notes': 'Санамж',
          'totalAmount': 200000,
          'paidAmount': 120000,
          'tenant': {'name': 'X', 'slug': 'x'},
          'branch': {'name': 'B'},
          'items': [
            {
              'id': 'it-1',
              'kind': 'PART',
              'description': 'Шүүлтүүр',
              'quantity': 1,
              'unitPrice': 40000,
            },
          ],
          'reports': [
            {
              'id': 'rep-1',
              'type': 'INSPECTION',
              'templateName': 'Үзлэг',
              'createdAt': '2026-09-01T09:00:00.000Z',
            },
          ],
        },
      },
    });

    final detail = await repo.getServiceOrderDetail('ord-9');
    expect(detail.order.id, 'ord-9');
    expect(detail.order.status, ServiceOrderStatus.partiallyPaid);
    expect(detail.note, 'Санамж');
    expect(detail.items, hasLength(1));
    expect(detail.reports, hasLength(1));
  });
}
