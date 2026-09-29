import 'package:carcare_customer_mobile/features/booking/domain/service_progress.dart';
import 'package:flutter_test/flutter_test.dart';

/// Paid-only history (2026-09-24): a completed order that is not fully paid
/// stays on the appointments tab with a "Төлбөр дутуу · X₮" badge.
AppointmentServiceProgress _progress({
  ServiceProgressStatus status = ServiceProgressStatus.completed,
  OrderPaymentStatus payment = OrderPaymentStatus.partiallyPaid,
  num? total = 50000,
  num? paid = 20000,
}) => AppointmentServiceProgress(
  id: 'o1',
  number: 'ORD-001',
  status: status,
  items: const [],
  paymentStatus: payment,
  totalAmount: total,
  paidAmount: paid,
);

void main() {
  test('completed + partially paid has an outstanding balance of total - paid', () {
    final p = _progress();
    expect(p.hasOutstandingBalance, isTrue);
    expect(p.outstandingAmount, 30000);
  });

  test('completed + unpaid with no paid amount owes the full total', () {
    final p = _progress(payment: OrderPaymentStatus.unpaid, paid: null);
    expect(p.hasOutstandingBalance, isTrue);
    expect(p.outstandingAmount, 50000);
  });

  test('fully paid or still in progress shows no badge', () {
    expect(_progress(payment: OrderPaymentStatus.paid).hasOutstandingBalance, isFalse);
    expect(
      _progress(status: ServiceProgressStatus.inProgress).hasOutstandingBalance,
      isFalse,
    );
  });

  test('unknown total yields a badge without an amount', () {
    final p = _progress(total: null);
    expect(p.hasOutstandingBalance, isTrue);
    expect(p.outstandingAmount, isNull);
  });
}
