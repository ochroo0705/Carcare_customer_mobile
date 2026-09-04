import 'package:carcare_customer_mobile/core/errors/app_failure.dart';
import 'package:carcare_customer_mobile/features/history/data/service_order_dto.dart';
import 'package:carcare_customer_mobile/features/history/domain/service_order_item.dart';
import 'package:carcare_customer_mobile/features/history/domain/service_order_status.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parseServiceOrderListJson', () {
    test('parses the list shape from GET /orders', () {
      final orders = parseServiceOrderListJson([
        {
          'id': 'ord-1',
          'number': 'A-100',
          'status': 'COMPLETED',
          'paymentStatus': 'PAID',
          'completedAt': '2026-09-01T10:00:00.000Z',
          'createdAt': '2026-08-30T10:00:00.000Z',
          'totalAmount': '150000', // Prisma Decimal → string
          'paidAmount': 150000, // or a raw number
          'tenant': {'name': 'Инфосистемс', 'slug': 'infosystems'},
          'branch': {'name': 'Үндсэн салбар'},
          'vehicle': {'plate': '1234УБА', 'make': 'Toyota'},
          'itemCount': 3,
        },
      ]);

      expect(orders, hasLength(1));
      final o = orders.first;
      expect(o.id, 'ord-1');
      expect(o.tenantName, 'Инфосистемс');
      expect(o.branchName, 'Үндсэн салбар');
      expect(o.status, ServiceOrderStatus.paid);
      expect(o.totalAmount, 150000); // string parsed to int
      expect(o.paidAmount, 150000);
      expect(o.vehiclePlate, '1234УБА');
      expect(o.completedAt, DateTime.utc(2026, 9, 1, 10));
    });

    test('maps PARTIAL/UNPAID payment status', () {
      final orders = parseServiceOrderListJson([
        _order(paymentStatus: 'PARTIAL'),
        _order(id: 'ord-2', paymentStatus: 'UNPAID'),
        _order(id: 'ord-3', paymentStatus: 'SOMETHING_ELSE'),
      ]);
      expect(orders[0].status, ServiceOrderStatus.partiallyPaid);
      expect(orders[1].status, ServiceOrderStatus.unpaid);
      expect(orders[2].status, ServiceOrderStatus.unpaid); // safe default
    });

    test('falls back to createdAt when completedAt is null (open order)', () {
      final orders = parseServiceOrderListJson([
        {
          'id': 'ord-open',
          'paymentStatus': 'UNPAID',
          'completedAt': null,
          'scheduledAt': null,
          'createdAt': '2026-08-30T08:00:00.000Z',
          'totalAmount': 0,
          'paidAmount': 0,
          'tenant': {'name': 'X', 'slug': 'x'},
          'branch': {'name': 'B'},
        },
      ]);
      expect(orders.single.completedAt, DateTime.utc(2026, 8, 30, 8));
    });

    test('tolerates a null vehicle', () {
      final orders = parseServiceOrderListJson([
        _order()..remove('vehicle'),
      ]);
      expect(orders.single.vehiclePlate, isNull);
    });

    test('throws on a non-list payload', () {
      expect(
        () => parseServiceOrderListJson({'not': 'a list'}),
        throwsA(isA<UnexpectedFailure>()),
      );
    });
  });

  group('serviceOrderDetailFromJson', () {
    test('parses items, note and diagnostic reports from GET /orders/[id]', () {
      final detail = serviceOrderDetailFromJson({
        'id': 'ord-1',
        'paymentStatus': 'PARTIAL',
        'completedAt': '2026-09-01T10:00:00.000Z',
        'createdAt': '2026-08-30T10:00:00.000Z',
        'notes': 'Тэмдэглэл',
        'totalAmount': '200000',
        'paidAmount': '120000',
        'tenant': {'name': 'Инфосистемс', 'slug': 'infosystems'},
        'branch': {'name': 'Үндсэн салбар', 'phone': '7000'},
        'vehicle': {'plate': '1234УБА'},
        'items': [
          {
            'id': 'it-1',
            'kind': 'LABOR',
            'description': 'Ажлын хөлс',
            'quantity': 2,
            'unitPrice': '30000',
            'total': '60000',
          },
          {
            'id': 'it-2',
            'kind': 'FEE',
            'description': 'Үйлчилгээний хураамж',
            'quantity': 1,
            'unitPrice': 5000,
          },
        ],
        'reports': [
          {
            'id': 'rep-1',
            'type': 'INSPECTION',
            'templateName': 'Ерөнхий үзлэг',
            'mileageAtReport': 82000,
            'createdAt': '2026-09-01T09:00:00.000Z',
          },
        ],
      });

      expect(detail.order.status, ServiceOrderStatus.partiallyPaid);
      expect(detail.note, 'Тэмдэглэл');
      expect(detail.items, hasLength(2));
      expect(detail.items[0].kind, ServiceOrderItemKind.labor);
      expect(detail.items[0].name, 'Ажлын хөлс');
      expect(detail.items[0].totalPrice, 60000); // 2 * 30000
      expect(detail.items[1].kind, ServiceOrderItemKind.fee);
      expect(detail.reports, hasLength(1));
      expect(detail.reports.single.templateName, 'Ерөнхий үзлэг');
      expect(detail.reports.single.mileageAtReport, 82000);
    });

    test('defaults items and reports to empty when absent', () {
      final detail = serviceOrderDetailFromJson({
        'id': 'ord-1',
        'paymentStatus': 'PAID',
        'createdAt': '2026-08-30T10:00:00.000Z',
        'totalAmount': 0,
        'paidAmount': 0,
        'tenant': {'name': 'X', 'slug': 'x'},
        'branch': {'name': 'B'},
      });
      expect(detail.items, isEmpty);
      expect(detail.reports, isEmpty);
      expect(detail.note, isNull);
    });
  });
}

Map<String, dynamic> _order({
  String id = 'ord-1',
  String paymentStatus = 'PAID',
}) => {
  'id': id,
  'paymentStatus': paymentStatus,
  'completedAt': '2026-09-01T10:00:00.000Z',
  'createdAt': '2026-08-30T10:00:00.000Z',
  'totalAmount': 1000,
  'paidAmount': 1000,
  'tenant': {'name': 'X', 'slug': 'x'},
  'branch': {'name': 'B'},
  'vehicle': {'plate': 'PLATE'},
};
