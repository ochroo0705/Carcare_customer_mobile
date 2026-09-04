import 'package:carcare_customer_mobile/core/errors/app_failure.dart';
import 'package:carcare_customer_mobile/features/history/domain/diagnostic_report_summary.dart';
import 'package:carcare_customer_mobile/features/history/domain/service_history_repository.dart';
import 'package:carcare_customer_mobile/features/history/domain/service_order.dart';
import 'package:carcare_customer_mobile/features/history/domain/service_order_detail.dart';
import 'package:carcare_customer_mobile/features/history/domain/service_order_item.dart';
import 'package:carcare_customer_mobile/features/history/domain/service_order_status.dart';

class FakeServiceHistoryRepository implements ServiceHistoryRepository {
  FakeServiceHistoryRepository() : _now = DateTime.now();

  final DateTime _now;

  late final List<ServiceOrder> _orders = [
    ServiceOrder(
      id: 'seed-history-1',
      tenantName: 'Инфосистемс',
      tenantSlug: 'infosystems',
      branchName: 'Үндсэн салбар',
      completedAt: _now.subtract(const Duration(days: 20)),
      status: ServiceOrderStatus.paid,
      totalAmount: 145000,
      paidAmount: 145000,
      vehiclePlate: '1234 УБА',
    ),
    ServiceOrder(
      id: 'seed-history-2',
      tenantName: 'Тэсо Моторс',
      tenantSlug: 'teso-motors',
      branchName: 'Хан-Уул салбар',
      completedAt: _now.subtract(const Duration(days: 8)),
      status: ServiceOrderStatus.partiallyPaid,
      totalAmount: 320000,
      paidAmount: 150000,
      vehiclePlate: '1234 УБА',
    ),
    ServiceOrder(
      id: 'seed-history-3',
      tenantName: 'Инфосистемс',
      tenantSlug: 'infosystems',
      branchName: 'Баянзүрх салбар',
      completedAt: _now.subtract(const Duration(days: 45)),
      status: ServiceOrderStatus.unpaid,
      totalAmount: 60000,
      paidAmount: 0,
    ),
    ServiceOrder(
      id: 'seed-history-4',
      tenantName: 'Улаанбаатар Авто',
      tenantSlug: 'ulaanbaatar-avto',
      branchName: 'Сүхбаатар салбар',
      completedAt: _now.subtract(const Duration(days: 2)),
      status: ServiceOrderStatus.paid,
      totalAmount: 85000,
      paidAmount: 85000,
      vehiclePlate: '5678 УНӨ',
    ),
  ];

  late final Map<String, List<ServiceOrderItem>> _items = {
    'seed-history-1': const [
      ServiceOrderItem(
        kind: ServiceOrderItemKind.diagnostic,
        name: 'Ерөнхий үзлэг',
        quantity: 1,
        unitPrice: 10000,
      ),
      ServiceOrderItem(
        kind: ServiceOrderItemKind.part,
        name: 'Тоормосны феродо',
        quantity: 1,
        unitPrice: 90000,
      ),
      ServiceOrderItem(
        kind: ServiceOrderItemKind.labor,
        name: 'Тоормосны феродо солих',
        quantity: 1,
        unitPrice: 45000,
      ),
    ],
    'seed-history-2': const [
      ServiceOrderItem(
        kind: ServiceOrderItemKind.part,
        name: 'Хөдөлгүүрийн тос',
        quantity: 4,
        unitPrice: 25000,
      ),
      ServiceOrderItem(
        kind: ServiceOrderItemKind.part,
        name: 'Тосны шүүр',
        quantity: 2,
        unitPrice: 100000,
      ),
      ServiceOrderItem(
        kind: ServiceOrderItemKind.labor,
        name: 'Тос солих ажил',
        quantity: 1,
        unitPrice: 20000,
      ),
    ],
    'seed-history-3': const [
      ServiceOrderItem(
        kind: ServiceOrderItemKind.diagnostic,
        name: 'Ерөнхий оношилгоо',
        quantity: 1,
        unitPrice: 60000,
      ),
    ],
    'seed-history-4': const [
      ServiceOrderItem(
        kind: ServiceOrderItemKind.part,
        name: 'Дугуй',
        quantity: 1,
        unitPrice: 55000,
      ),
      ServiceOrderItem(
        kind: ServiceOrderItemKind.labor,
        name: 'Дугуй солих',
        quantity: 1,
        unitPrice: 30000,
      ),
    ],
  };

  @override
  Future<List<ServiceOrder>> getServiceHistory() async =>
      List.unmodifiable(_orders);

  @override
  Future<ServiceOrderDetail> getServiceOrderDetail(String id) async {
    final order = _orders.where((order) => order.id == id).firstOrNull;
    if (order == null) throw const NotFoundFailure();
    return ServiceOrderDetail(
      order: order,
      items: _items[id] ?? const [],
      reports: _reports[id] ?? const [],
    );
  }

  /// Fake mode-д оношилгооны тайлангийн хэсгийг харуулах цөөн жишээ.
  late final Map<String, List<DiagnosticReportSummary>> _reports = {
    'seed-history-1': [
      DiagnosticReportSummary(
        id: 'seed-report-1',
        templateName: 'Ерөнхий үзлэг',
        type: 'INSPECTION',
        createdAt: _now.subtract(const Duration(days: 30)),
        mileageAtReport: 82000,
      ),
    ],
  };
}
