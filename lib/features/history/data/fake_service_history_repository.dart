import 'package:carcare_customer_mobile/core/errors/app_failure.dart';
import 'package:carcare_customer_mobile/features/history/domain/cancelled_appointment_summary.dart';
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
    ServiceOrder(
      id: 'seed-history-5',
      tenantName: 'Тэсо Моторс',
      tenantSlug: 'teso-motors',
      branchName: 'Хан-Уул салбар',
      completedAt: _now.subtract(const Duration(days: 15)),
      status: ServiceOrderStatus.unpaid,
      totalAmount: 0,
      paidAmount: 0,
      isCancelled: true,
    ),
  ];

  // D-085: cancelled/no-show/rejected appointments that never got a
  // ServiceOrder — separate list from _orders above.
  late final List<CancelledAppointmentSummary> _cancelledAppointments = [
    CancelledAppointmentSummary(
      id: 'seed-cancelled-appt-1',
      status: CancelledAppointmentStatus.noShow,
      requestedAt: _now.subtract(const Duration(days: 12)),
      tenantName: 'Улаанбаатар Авто',
      branchName: 'Сүхбаатар салбар',
      categoryName: 'Дугуй солих',
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
  Future<ServiceHistoryPage> getServiceHistory({HistoryFilter filter = const HistoryFilter()}) async {
    final q = filter.query.toLowerCase();
    final orders = _orders.where((order) {
      if (filter.year != null && order.completedAt.year != filter.year) return false;
      if (q.isEmpty) return true;
      return [order.tenantName, order.branchName, order.vehiclePlate ?? ''].any((value) => value.toLowerCase().contains(q));
    }).toList(growable: false);
    final cancelled = _cancelledAppointments.where((item) {
      if (filter.year != null && item.requestedAt.year != filter.year) return false;
      if (q.isEmpty) return true;
      return [item.tenantName, item.branchName, item.categoryName ?? ''].any((value) => value.toLowerCase().contains(q));
    }).toList(growable: false);
    final start = (filter.page - 1) * filter.pageSize;
    final pageItems = start >= orders.length ? const <ServiceOrder>[] : orders.skip(start).take(filter.pageSize).toList(growable: false);
    final pageCancelled = start >= cancelled.length ? const <CancelledAppointmentSummary>[] : cancelled.skip(start).take(filter.pageSize).toList(growable: false);
    HistoryPagination meta(int total) => HistoryPagination(page: filter.page, pageSize: filter.pageSize, total: total, totalPages: total == 0 ? 1 : (total / filter.pageSize).ceil(), hasPrev: filter.page > 1, hasNext: start + filter.pageSize < total);
    final availableYears = {
      ..._orders.map((order) => order.completedAt.year),
      ..._cancelledAppointments.map((item) => item.requestedAt.year),
    }.toList()..sort((a, b) => b.compareTo(a));
    return ServiceHistoryPage(orders: pageItems, cancelledAppointments: pageCancelled, pagination: meta(orders.length), cancelledPagination: meta(cancelled.length), availableYears: availableYears);
  }

  @override
  Future<List<CancelledAppointmentSummary>> getCancelledAppointments() async =>
      List.unmodifiable(_cancelledAppointments);

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
