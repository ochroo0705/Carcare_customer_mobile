import 'package:carcare_customer_mobile/app/theme/app_theme.dart';
import 'package:carcare_customer_mobile/features/booking/domain/appointment.dart';
import 'package:carcare_customer_mobile/features/booking/domain/appointment_payment.dart';
import 'package:carcare_customer_mobile/features/booking/domain/appointment_repository.dart';
import 'package:carcare_customer_mobile/features/booking/presentation/screens/appointment_payment_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Repository whose QPay checkout initially failed and succeeds on retry.
class _RetryRepository implements AppointmentRepository {
  int retries = 0;

  // A fresh pending invoice WITH a QR (a 1×1 PNG) — a pending payment without a
  // QR image is itself treated as "failed" by the screen, so a real retry must
  // yield a scannable invoice.
  static const _qrPng =
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=';

  @override
  Future<AppointmentPayment?> retryPayment(String id) async {
    retries++;
    return const AppointmentPayment(
      status: AppointmentFeeStatus.pending,
      amount: 5000,
      currency: 'MNT',
      qrText: 'qpay://new-invoice',
      qrImageBase64: _qrPng,
    );
  }

  @override
  Future<AppointmentPayment?> getPayment(String id) async => null;
  @override
  Future<AppointmentPaymentCheckResult> checkPayment(String id) async =>
      const AppointmentPaymentCheckResult(paid: false);
  @override
  Future<List<Appointment>> getAppointments() async => const [];
  @override
  Future<void> cancelAppointment(String id) async {}
  @override
  Future<CreatedAppointment> createAppointment({
    required String branchId,
    required DateTime requestedAt,
    String? note,
    String? accountVehicleId,
  }) => throw UnimplementedError();
}

/// Reports "not paid" for the first [paidAfter]-1 checks, then "paid".
/// Counts calls so a test can assert polling stopped.
class _PaysAfterRepository implements AppointmentRepository {
  _PaysAfterRepository({this.paidAfter = 1});
  final int paidAfter;
  int checks = 0;

  @override
  Future<AppointmentPaymentCheckResult> checkPayment(String id) async {
    checks++;
    return AppointmentPaymentCheckResult(paid: checks >= paidAfter);
  }

  @override
  Future<AppointmentPayment?> getPayment(String id) async => null;
  @override
  Future<AppointmentPayment?> retryPayment(String id) async => null;
  @override
  Future<List<Appointment>> getAppointments() async => const [];
  @override
  Future<void> cancelAppointment(String id) async {}
  @override
  Future<CreatedAppointment> createAppointment({
    required String branchId,
    required DateTime requestedAt,
    String? note,
    String? accountVehicleId,
  }) => throw UnimplementedError();
}

const _pendingWithQr = AppointmentPayment(
  status: AppointmentFeeStatus.pending,
  amount: 5000,
  currency: 'MNT',
  qrImageBase64: _RetryRepository._qrPng,
);

Future<void> _pumpPayment(
  WidgetTester tester,
  AppointmentRepository repository, {
  VoidCallback? onPaymentUpdated,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: AppointmentPaymentScreen(
        appointmentId: 'apt-1',
        repository: repository,
        initialPayment: _pendingWithQr,
        onPaymentUpdated: onPaymentUpdated,
        onBack: () {},
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('auto-polls a pending fee and flips to paid without a manual tap',
      (tester) async {
    final repository = _PaysAfterRepository(paidAfter: 2);
    var updated = 0;
    await _pumpPayment(tester, repository, onPaymentUpdated: () => updated++);

    // Not paid yet — the check button is visible, no success banner.
    expect(find.text('Төлбөр амжилттай төлөгдсөн.'), findsNothing);

    // First poll tick: still unpaid.
    await tester.pump(const Duration(seconds: 4));
    await tester.pump();
    expect(find.text('Төлбөр амжилттай төлөгдсөн.'), findsNothing);

    // Second poll tick: paid — the screen flips on its own.
    await tester.pump(const Duration(seconds: 4));
    await tester.pump();
    expect(find.text('Төлбөр амжилттай төлөгдсөн.'), findsOneWidget);
    expect(updated, 1);
  });

  testWidgets('stops polling once paid — no further checks', (tester) async {
    final repository = _PaysAfterRepository(paidAfter: 1);
    await _pumpPayment(tester, repository);

    await tester.pump(const Duration(seconds: 4));
    await tester.pump();
    expect(find.text('Төлбөр амжилттай төлөгдсөн.'), findsOneWidget);
    final callsAtPaid = repository.checks;

    // Advance well past several intervals — the timer must be cancelled.
    await tester.pump(const Duration(seconds: 20));
    await tester.pump();
    expect(repository.checks, callsAtPaid);
  });

  testWidgets('re-checks immediately on app resume (B)', (tester) async {
    final repository = _PaysAfterRepository(paidAfter: 1);
    await _pumpPayment(tester, repository);

    // Simulate leaving to the bank app and returning.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();

    expect(find.text('Төлбөр амжилттай төлөгдсөн.'), findsOneWidget);
  });

  testWidgets('retrying a failed invoice calls retryPayment and clears the '
      'failed banner', (tester) async {
    final repository = _RetryRepository();

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: AppointmentPaymentScreen(
          appointmentId: 'apt-1',
          repository: repository,
          initialPayment: const AppointmentPayment(
            status: AppointmentFeeStatus.failed,
            amount: 5000,
            currency: 'MNT',
          ),
          onBack: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Failed invoice → the retry affordance is shown.
    expect(find.text('Invoice үүсгэхэд алдаа гарсан байна.'), findsOneWidget);

    await tester.tap(find.text('Дахин оролдох'));
    await tester.pumpAndSettle();

    expect(repository.retries, 1);
    // New invoice is pending now — the failed banner is gone.
    expect(find.text('Invoice үүсгэхэд алдаа гарсан байна.'), findsNothing);
  });

  testWidgets('shows the bank-picker button and lists banks when the payment '
      'carries QPay urls', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: AppointmentPaymentScreen(
          appointmentId: 'apt-1',
          repository: _RetryRepository(),
          initialPayment: const AppointmentPayment(
            status: AppointmentFeeStatus.pending,
            amount: 5000,
            currency: 'MNT',
            qrImageBase64: _RetryRepository._qrPng,
            urls: [
              QpayBankUrl(
                name: 'Khan bank',
                nameMn: 'Хаан банк',
                logo: '',
                link: 'khanbank://q?qr=X',
              ),
              QpayBankUrl(
                name: 'TDB',
                nameMn: 'Худалдаа хөгжлийн банк',
                logo: '',
                link: 'tdbbank://q?qr=X',
              ),
            ],
          ),
          onBack: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Multi-bank → the generic "pay via bank app" button, which opens a picker.
    final button = find.byKey(const ValueKey('payment-pick-bank'));
    expect(button, findsOneWidget);

    await tester.tap(button);
    await tester.pumpAndSettle();

    // The picker sheet lists both banks by their Mongolian label.
    expect(find.text('Хаан банк'), findsOneWidget);
    expect(find.text('Худалдаа хөгжлийн банк'), findsOneWidget);
  });

  testWidgets('hides the bank-picker button when the payment has no urls '
      '(QR-only fallback)', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: AppointmentPaymentScreen(
          appointmentId: 'apt-1',
          repository: _RetryRepository(),
          initialPayment: const AppointmentPayment(
            status: AppointmentFeeStatus.pending,
            amount: 5000,
            currency: 'MNT',
            qrImageBase64: _RetryRepository._qrPng,
            // urls omitted → empty (pre-feature invoice, or fee-less flow).
          ),
          onBack: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('payment-pick-bank')), findsNothing);
    // The QR is still shown so the user can pay from another device.
    expect(find.byType(Image), findsOneWidget);
  });
}
