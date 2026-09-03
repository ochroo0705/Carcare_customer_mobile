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

void main() {
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
}
