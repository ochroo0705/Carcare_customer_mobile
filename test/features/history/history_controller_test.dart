import 'package:carcare_customer_mobile/core/errors/app_failure.dart';
import 'package:carcare_customer_mobile/features/history/data/fake_service_history_repository.dart';
import 'package:carcare_customer_mobile/features/history/domain/cancelled_appointment_summary.dart';
import 'package:carcare_customer_mobile/features/history/domain/service_history_repository.dart';
import 'package:carcare_customer_mobile/features/history/domain/service_order.dart';
import 'package:carcare_customer_mobile/features/history/domain/service_order_detail.dart';
import 'package:carcare_customer_mobile/features/history/presentation/controllers/history_controller.dart';
import 'package:carcare_customer_mobile/features/history/presentation/controllers/history_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _ThrowingHistoryRepo implements ServiceHistoryRepository {
  const _ThrowingHistoryRepo(this.failure);
  final AppFailure failure;
  @override
  Future<ServiceHistoryPage> getServiceHistory({HistoryFilter filter = const HistoryFilter()}) async => throw failure;
  @override
  Future<ServiceOrderDetail> getServiceOrderDetail(String id) async =>
      throw failure;
  @override
  Future<List<CancelledAppointmentSummary>> getCancelledAppointments() async =>
      throw failure;
}

class _CancelledPagingRepo implements ServiceHistoryRepository {
  final pages = <int>[];
  bool failPageTwo = false;

  CancelledAppointmentSummary _appointment(int page) =>
      CancelledAppointmentSummary(
        id: 'cancelled-$page',
        status: CancelledAppointmentStatus.cancelled,
        requestedAt: DateTime(2026, 1, page),
        tenantName: 'Tenant',
        branchName: 'Branch',
      );

  @override
  Future<ServiceHistoryPage> getServiceHistory({
    HistoryFilter filter = const HistoryFilter(),
  }) async {
    pages.add(filter.page);
    if (failPageTwo && filter.page == 2) throw const NetworkFailure();
    final item = _appointment(filter.page);
    return ServiceHistoryPage(
      orders: const [],
      cancelledAppointments: [item],
      pagination: const HistoryPagination(
        page: 1,
        pageSize: 20,
        total: 0,
        totalPages: 1,
        hasPrev: false,
        hasNext: false,
      ),
      cancelledPagination: HistoryPagination(
        page: filter.page,
        pageSize: 1,
        total: 3,
        totalPages: 3,
        hasPrev: filter.page > 1,
        hasNext: filter.page < 3,
      ),
    );
  }

  @override
  Future<ServiceOrderDetail> getServiceOrderDetail(String id) =>
      throw UnimplementedError();

  @override
  Future<List<CancelledAppointmentSummary>> getCancelledAppointments() async =>
      const [];
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('loads the seeded orders sorted most-recent-first', () async {
    final controller = HistoryController(FakeServiceHistoryRepository());

    await controller.load();

    expect(controller.state.status, HistoryStatus.data);
    final dates = controller.state.orders.map((o) => o.completedAt).toList();
    for (var i = 1; i < dates.length; i++) {
      expect(
        dates[i - 1].isAfter(dates[i]) || dates[i - 1] == dates[i],
        isTrue,
      );
    }
  });

  test('reset returns to the initial state', () async {
    final controller = HistoryController(FakeServiceHistoryRepository());
    await controller.load();
    expect(controller.state.status, HistoryStatus.data);

    controller.reset();

    expect(controller.state.status, HistoryStatus.initial);
    expect(controller.state.orders, isEmpty);
  });

  test('surfaces an error state when the load fails (offline, no cache)', () async {
    final controller = HistoryController(
      const _ThrowingHistoryRepo(NetworkFailure()),
    );

    await controller.load();

    expect(controller.state.status, HistoryStatus.error);
    expect(controller.state.message, 'Сүлжээний холболтоо шалгана уу.');
  });

  test('a server error surfaces its message', () async {
    final controller = HistoryController(
      const _ThrowingHistoryRepo(ServerFailure('boom')),
    );

    await controller.load();

    expect(controller.state.status, HistoryStatus.error);
    expect(controller.state.message, 'boom');
  });

  test('advances pages from cancelled metadata when orders have no next page', () async {
    final repository = _CancelledPagingRepo();
    final controller = HistoryController(repository);
    addTearDown(controller.dispose);

    await controller.load();
    await controller.loadMore();
    await controller.loadMore();

    expect(repository.pages, [1, 2, 3]);
    expect(controller.state.cancelledAppointments, hasLength(3));
    expect(controller.state.page, 3);
  });

  test('keeps history data and exposes append retry failures', () async {
    final repository = _CancelledPagingRepo()..failPageTwo = true;
    final controller = HistoryController(repository);
    addTearDown(controller.dispose);

    await controller.load();
    await controller.loadMore();

    expect(controller.state.cancelledAppointments, hasLength(1));
    expect(controller.state.loadMoreMessage, isNotNull);
  });
}
