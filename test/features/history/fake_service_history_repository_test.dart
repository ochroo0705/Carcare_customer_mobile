import 'package:carcare_customer_mobile/core/errors/app_failure.dart';
import 'package:carcare_customer_mobile/features/history/data/fake_service_history_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('lists the seeded orders', () async {
    final repository = FakeServiceHistoryRepository();

    final orders = await repository.getServiceHistory();

    expect(orders, hasLength(4));
  });

  test('returns full line-item detail for a known order', () async {
    final repository = FakeServiceHistoryRepository();

    final detail = await repository.getServiceOrderDetail('seed-history-1');

    expect(detail.order.id, 'seed-history-1');
    expect(detail.items, isNotEmpty);
    expect(
      detail.items.fold<int>(0, (sum, item) => sum + item.totalPrice),
      detail.order.totalAmount,
    );
  });

  test('throws a not-found failure for an unknown order id', () async {
    final repository = FakeServiceHistoryRepository();

    expect(
      () => repository.getServiceOrderDetail('does-not-exist'),
      throwsA(isA<NotFoundFailure>()),
    );
  });
}
