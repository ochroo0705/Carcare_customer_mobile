import 'dart:async';

import 'package:carcare_customer_mobile/core/errors/app_failure.dart';
import 'package:carcare_customer_mobile/data/cache/in_memory_cache_store.dart';
import 'package:carcare_customer_mobile/features/history/domain/service_order.dart';
import 'package:carcare_customer_mobile/features/history/domain/service_order_status.dart';
import 'package:carcare_customer_mobile/features/history/data/fake_service_history_repository.dart';
import 'package:carcare_customer_mobile/features/history/domain/cancelled_appointment_summary.dart';
import 'package:carcare_customer_mobile/features/history/domain/service_history_repository.dart';
import 'package:carcare_customer_mobile/features/history/presentation/controllers/history_controller.dart';
import 'package:carcare_customer_mobile/features/history/presentation/controllers/history_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _ThrowingHistoryRepo extends Fake implements ServiceHistoryRepository {
  _ThrowingHistoryRepo(this.failure);
  final AppFailure failure;
  @override
  Future<ServiceHistoryPage> getServiceHistory({
    HistoryFilter filter = const HistoryFilter(),
  }) async => throw failure;
}

class _CancelledPagingRepo extends Fake implements ServiceHistoryRepository {
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
  Future<List<CancelledAppointmentSummary>> getCancelledAppointments() async =>
      const [];
}

ServiceOrder _order(String id) => ServiceOrder(
  id: id,
  tenantName: 'Tenant',
  tenantSlug: 'tenant',
  branchName: 'Branch',
  completedAt: DateTime(2026, 1, 1),
  status: ServiceOrderStatus.paid,
  totalAmount: 1000,
  paidAmount: 1000,
);

const _noNext = HistoryPagination(
  page: 1,
  pageSize: 20,
  total: 1,
  totalPages: 1,
  hasPrev: false,
  hasNext: false,
);

/// Succeeds while [fail] is false, then throws [NetworkFailure].
class _FlakyHistoryRepo extends Fake implements ServiceHistoryRepository {
  bool fail = false;
  @override
  Future<ServiceHistoryPage> getServiceHistory({
    HistoryFilter filter = const HistoryFilter(),
  }) async {
    if (fail) throw const NetworkFailure();
    return ServiceHistoryPage(
      orders: [_order('live')],
      cancelledAppointments: const [],
      pagination: _noNext,
      cancelledPagination: _noNext,
    );
  }
}

/// Orders end on page 1; cancelled appointments continue. Like the real
/// server, the exhausted orders list is clamped to its last page, so page 2
/// repeats page 1's orders.
class _ExhaustedOrdersRepo extends Fake implements ServiceHistoryRepository {
  _ExhaustedOrdersRepo({this.emptyPastEnd = false});

  /// Real backend behaviour (`app/api/v1/app/orders/route.ts`): past the end
  /// the rows are empty (skip beyond count) and only the metadata is clamped.
  final bool emptyPastEnd;

  @override
  Future<ServiceHistoryPage> getServiceHistory({
    HistoryFilter filter = const HistoryFilter(),
  }) async => ServiceHistoryPage(
    orders: emptyPastEnd && filter.page > 1 ? const [] : [_order('order-1')],
    cancelledAppointments: [
      CancelledAppointmentSummary(
        id: 'cancelled-${filter.page}',
        status: CancelledAppointmentStatus.cancelled,
        requestedAt: DateTime(2026, 1, filter.page),
        tenantName: 'Tenant',
        branchName: 'Branch',
      ),
    ],
    pagination: _noNext,
    cancelledPagination: HistoryPagination(
      page: filter.page,
      pageSize: 1,
      total: 2,
      totalPages: 2,
      hasPrev: filter.page > 1,
      hasNext: filter.page < 2,
    ),
  );
}

/// Cache whose read blocks until [release] is completed.
class _GatedCache extends InMemoryCacheStore {
  final release = Completer<void>();
  @override
  Future<List<ServiceOrder>?> readServiceOrders() async {
    await release.future;
    return super.readServiceOrders();
  }
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

  test(
    'surfaces an error state when the load fails (offline, no cache)',
    () async {
      final controller = HistoryController(
        _ThrowingHistoryRepo(const NetworkFailure()),
      );

      await controller.load();

      expect(controller.state.status, HistoryStatus.error);
      expect(controller.state.message, 'Сүлжээний холболтоо шалгана уу.');
    },
  );

  test('a server error surfaces its message', () async {
    final controller = HistoryController(
      _ThrowingHistoryRepo(const ServerFailure('boom')),
    );

    await controller.load();

    expect(controller.state.status, HistoryStatus.error);
    expect(controller.state.message, 'boom');
  });

  test(
    'advances pages from cancelled metadata when orders have no next page',
    () async {
      final repository = _CancelledPagingRepo();
      final controller = HistoryController(repository);
      addTearDown(controller.dispose);

      await controller.load();
      await controller.loadMore();
      await controller.loadMore();

      expect(repository.pages, [1, 2, 3]);
      expect(controller.state.cancelledAppointments, hasLength(3));
      expect(controller.state.page, 3);
    },
  );

  test('keeps history data and exposes append retry failures', () async {
    final repository = _CancelledPagingRepo()..failPageTwo = true;
    final controller = HistoryController(repository);
    addTearDown(controller.dispose);

    await controller.load();
    await controller.loadMore();

    expect(controller.state.cancelledAppointments, hasLength(1));
    expect(controller.state.loadMoreMessage, isNotNull);
  });

  test('a failed refresh keeps the live orders instead of the cache', () async {
    final cache = InMemoryCacheStore();
    await cache.writeServiceOrders([_order('stale-cache')]);
    final repository = _FlakyHistoryRepo();
    final controller = HistoryController(repository, cache: cache);
    addTearDown(controller.dispose);

    await controller.load();
    repository.fail = true;
    await controller.load();

    expect(controller.state.status, HistoryStatus.data);
    expect(controller.state.isFromCache, isFalse);
    expect(controller.state.orders.single.id, 'live');
    expect(controller.state.message, isNotNull);
  });

  test(
    'a failure under a non-default year never shows cached orders',
    () async {
      final cache = InMemoryCacheStore();
      await cache.writeServiceOrders([_order('current-year-cache')]);
      final controller = HistoryController(
        _ThrowingHistoryRepo(const NetworkFailure()),
        cache: cache,
      );
      addTearDown(controller.dispose);

      controller.setYear(DateTime.now().year - 1);
      await Future<void>.delayed(Duration.zero);

      expect(controller.state.status, HistoryStatus.error);
      expect(controller.state.orders, isEmpty);
    },
  );

  test('a failure under a search query never shows cached orders', () async {
    final cache = InMemoryCacheStore();
    await cache.writeServiceOrders([_order('current-year-cache')]);
    final controller = HistoryController(
      _ThrowingHistoryRepo(const NetworkFailure()),
      cache: cache,
    );
    addTearDown(controller.dispose);

    controller.setQuery('abc');
    await Future<void>.delayed(const Duration(milliseconds: 450));

    expect(controller.state.status, HistoryStatus.error);
    expect(controller.state.orders, isEmpty);
  });

  test('the default filter still falls back to the cache', () async {
    final cache = InMemoryCacheStore();
    await cache.writeServiceOrders([_order('cached')]);
    final controller = HistoryController(
      _ThrowingHistoryRepo(const NetworkFailure()),
      cache: cache,
    );
    addTearDown(controller.dispose);

    await controller.load();

    expect(controller.state.isFromCache, isTrue);
    expect(controller.state.orders.single.id, 'cached');
  });

  test('a slow cache fallback does not overwrite a newer load', () async {
    final cache = _GatedCache();
    await cache.writeServiceOrders([_order('cached')]);
    final repository = _FlakyHistoryRepo()..fail = true;
    final controller = HistoryController(repository, cache: cache);
    addTearDown(controller.dispose);

    final first = controller.load();
    await Future<void>.delayed(Duration.zero);
    repository.fail = false;
    await controller.load();
    expect(controller.state.orders.single.id, 'live');

    cache.release.complete();
    await first;

    expect(controller.state.orders.single.id, 'live');
    expect(controller.state.isFromCache, isFalse);
  });

  test('loadMore does not re-append a list whose hasNext is false', () async {
    final controller = HistoryController(_ExhaustedOrdersRepo());
    addTearDown(controller.dispose);

    await controller.load();
    await controller.loadMore();

    expect(controller.state.orders.map((o) => o.id), ['order-1']);
    expect(controller.state.cancelledAppointments, hasLength(2));
    expect(controller.state.pagination.hasNext, isFalse);
    expect(controller.hasNextPage, isFalse);
  });

  test(
    'loadMore keeps an exhausted list when the server returns it empty',
    () async {
      final controller = HistoryController(
        _ExhaustedOrdersRepo(emptyPastEnd: true),
      );
      addTearDown(controller.dispose);

      await controller.load();
      await controller.loadMore();

      expect(controller.state.orders.map((o) => o.id), ['order-1']);
      expect(controller.state.cancelledAppointments, hasLength(2));
      expect(controller.state.loadMoreMessage, isNull);
    },
  );

  test('setQuery marks results stale until the reload lands', () async {
    final controller = HistoryController(_FlakyHistoryRepo());
    addTearDown(controller.dispose);
    await controller.load();
    expect(controller.resultsStale, isFalse);

    controller.setQuery('x');
    expect(controller.resultsStale, isTrue);

    await Future<void>.delayed(const Duration(milliseconds: 450));
    expect(controller.resultsStale, isFalse);
  });

  test('a failed year change does not show the previous year rows', () async {
    final repository = _FlakyHistoryRepo();
    final controller = HistoryController(repository);
    addTearDown(controller.dispose);
    await controller.load();
    expect(controller.state.orders.single.id, 'live');

    repository.fail = true;
    controller.setYear(controller.year - 1);
    await Future<void>.delayed(Duration.zero);

    expect(controller.state.status, HistoryStatus.error);
    expect(controller.state.orders, isEmpty);
  });

  test('a failed query change does not show the previous query rows', () async {
    final repository = _FlakyHistoryRepo();
    final controller = HistoryController(repository);
    addTearDown(controller.dispose);
    await controller.load();

    repository.fail = true;
    controller.setQuery('abc');
    await Future<void>.delayed(const Duration(milliseconds: 450));

    expect(controller.state.status, HistoryStatus.error);
    expect(controller.state.orders, isEmpty);
  });

  test('resultsStale clears when the reload fails', () async {
    final controller = HistoryController(
      _ThrowingHistoryRepo(const NetworkFailure()),
    );
    addTearDown(controller.dispose);

    controller.setQuery('abc');
    expect(controller.resultsStale, isTrue);
    await Future<void>.delayed(const Duration(milliseconds: 450));

    expect(controller.state.status, HistoryStatus.error);
    expect(controller.resultsStale, isFalse);
  });

  test(
    'resultsStale clears when a same-filter refresh keeps live data',
    () async {
      final repository = _FlakyHistoryRepo();
      final controller = HistoryController(repository);
      addTearDown(controller.dispose);
      await controller.load();

      repository.fail = true;
      controller.setQuery('');
      await controller.load();

      expect(controller.state.orders.single.id, 'live');
      expect(controller.resultsStale, isFalse);
    },
  );
}
