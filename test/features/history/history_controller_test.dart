import 'package:carcare_customer_mobile/core/errors/app_failure.dart';
import 'package:carcare_customer_mobile/features/history/data/fake_service_history_repository.dart';
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
  Future<List<ServiceOrder>> getServiceHistory() async => throw failure;
  @override
  Future<ServiceOrderDetail> getServiceOrderDetail(String id) async =>
      throw failure;
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
}
