import 'dart:convert';

import 'package:carcare_customer_mobile/app/theme/app_surfaces.dart';
import 'package:carcare_customer_mobile/app/theme/app_theme.dart';
import 'package:carcare_customer_mobile/core/errors/app_failure.dart';
import 'package:carcare_customer_mobile/features/booking/domain/appointment_payment.dart';
import 'package:carcare_customer_mobile/features/booking/domain/appointment_repository.dart';
import 'package:carcare_customer_mobile/features/history/presentation/format_amount.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// The QPay booking-fee flow — mirrors the web `AppointmentPaymentPanel`
/// (`carcare.mn/app/(app)/account/appointments/[id]/pay/payment-panel.tsx`):
/// a QR code + bank-app deeplink, a manual "check" button (no auto-polling,
/// matching web), and a retry path if QPay checkout itself failed to create.
class AppointmentPaymentScreen extends StatefulWidget {
  const AppointmentPaymentScreen({
    required this.appointmentId,
    required this.repository,
    required this.onBack,
    this.initialPayment,
    this.onPaymentUpdated,
    super.key,
  });

  final String appointmentId;
  final AppointmentRepository repository;
  final VoidCallback onBack;

  /// Skips the initial fetch when the payment info is already known (e.g.
  /// fresh off a successful booking response) — falls back to fetching via
  /// [AppointmentRepository.getPayment] when `null`.
  final AppointmentPayment? initialPayment;

  /// Fired whenever the payment state changes (paid, retried) so the caller
  /// can refresh anything that shows a payment-status badge (the
  /// appointments list).
  final VoidCallback? onPaymentUpdated;

  @override
  State<AppointmentPaymentScreen> createState() =>
      _AppointmentPaymentScreenState();
}

enum _LoadStatus { loading, data, error }

class _AppointmentPaymentScreenState extends State<AppointmentPaymentScreen> {
  _LoadStatus _status = _LoadStatus.loading;
  AppointmentPayment? _payment;
  String? _message;
  bool _checking = false;
  bool _retrying = false;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialPayment;
    if (initial != null) {
      _payment = initial;
      _status = _LoadStatus.data;
    } else {
      _load();
    }
  }

  Future<void> _load() async {
    setState(() => _status = _LoadStatus.loading);
    try {
      final payment = await widget.repository.getPayment(widget.appointmentId);
      if (!mounted) return;
      setState(() {
        _payment = payment;
        _status = _LoadStatus.data;
      });
    } on AppFailure catch (failure) {
      if (!mounted) return;
      setState(() {
        _message = failure.message;
        _status = _LoadStatus.error;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _message = 'Тодорхойгүй алдаа гарлаа.';
        _status = _LoadStatus.error;
      });
    }
  }

  Future<void> _check() async {
    if (_checking) return;
    setState(() => _checking = true);
    try {
      final result = await widget.repository.checkPayment(widget.appointmentId);
      if (!mounted) return;
      if (result.paid) {
        setState(() {
          _payment = AppointmentPayment(
            status: AppointmentFeeStatus.paid,
            amount: _payment?.amount ?? 0,
            currency: _payment?.currency ?? 'MNT',
          );
        });
        widget.onPaymentUpdated?.call();
      } else if (result.underpaidAmount != null) {
        final current = _payment;
        if (current != null) {
          setState(() {
            _payment = AppointmentPayment(
              status: AppointmentFeeStatus.underpaid,
              amount: current.amount,
              currency: current.currency,
              qrImageBase64: current.qrImageBase64,
              qrText: current.qrText,
              underpaidAmount: result.underpaidAmount,
            );
          });
        }
        _showSnack(
          result.message ?? 'Дутуу төлбөр ирсэн байна.',
          isError: true,
        );
      } else {
        _showSnack(
          result.message ?? 'Төлбөр төлөгдөөгүй байна. Банкны аппаар QR-аа уншуулсны дараа дахин шалгана уу.',
        );
      }
    } on AppFailure catch (failure) {
      if (mounted) _showSnack(failure.message, isError: true);
    } catch (_) {
      if (mounted) {
        _showSnack('Тодорхойгүй алдаа гарлаа.', isError: true);
      }
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _retry() async {
    if (_retrying) return;
    setState(() => _retrying = true);
    try {
      final payment = await widget.repository.retryPayment(
        widget.appointmentId,
      );
      if (!mounted) return;
      setState(() => _payment = payment);
      widget.onPaymentUpdated?.call();
    } on AppFailure catch (failure) {
      if (mounted) _showSnack(failure.message, isError: true);
    } catch (_) {
      if (mounted) {
        _showSnack('Тодорхойгүй алдаа гарлаа.', isError: true);
      }
    } finally {
      if (mounted) setState(() => _retrying = false);
    }
  }

  void _showSnack(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.red : null,
      ),
    );
  }

  Future<void> _openBankApp(String qrText) async {
    final uri = Uri.tryParse(qrText);
    if (uri == null) return;
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && mounted) {
      _showSnack('Банкны апп нээгдсэнгүй.', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      leading: BackButton(onPressed: widget.onBack),
      title: const Text('Цаг захиалгын хураамж'),
    ),
    body: AppShellBackground(child: SafeArea(top: false, child: _body())),
  );

  Widget _body() => switch (_status) {
    _LoadStatus.loading => const Center(child: CircularProgressIndicator()),
    _LoadStatus.error => Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 52,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              _message ?? 'Тодорхойгүй алдаа гарлаа.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: _load,
              child: const Text('Дахин оролдох'),
            ),
          ],
        ),
      ),
    ),
    _LoadStatus.data =>
      _payment == null
          ? _NoFeeRequired(onDone: widget.onBack)
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _PaymentPanel(
                  payment: _payment!,
                  checking: _checking,
                  retrying: _retrying,
                  onCheck: _check,
                  onRetry: _retry,
                  onOpenBankApp: _openBankApp,
                  onDone: widget.onBack,
                ),
              ],
            ),
  };
}

class _NoFeeRequired extends StatelessWidget {
  const _NoFeeRequired({required this.onDone});

  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.check_circle_outline_rounded,
            size: 52,
            color: AppColors.green,
          ),
          const SizedBox(height: 16),
          const Text(
            'Энэ цаг захиалгад хураамж шаардлагагүй.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          FilledButton(onPressed: onDone, child: const Text('Дуусгах')),
        ],
      ),
    ),
  );
}

class _PaymentPanel extends StatelessWidget {
  const _PaymentPanel({
    required this.payment,
    required this.checking,
    required this.retrying,
    required this.onCheck,
    required this.onRetry,
    required this.onOpenBankApp,
    required this.onDone,
  });

  final AppointmentPayment payment;
  final bool checking;
  final bool retrying;
  final VoidCallback onCheck;
  final VoidCallback onRetry;
  final ValueChanged<String> onOpenBankApp;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final failed =
        payment.status != AppointmentFeeStatus.paid &&
        payment.qrImageBase64 == null;
    return GlassSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            'ЦАГ ЗАХИАЛГЫН ХУРААМЖ',
            style: Theme.of(context).textTheme.labelSmall
                ?.copyWith(color: scheme.onSurfaceVariant, letterSpacing: 1),
          ),
          const SizedBox(height: 8),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: formatAmount(payment.amount.round()),
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: scheme.primary,
                  ),
                ),
                TextSpan(
                  text: ' ${payment.currency}',
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (payment.status == AppointmentFeeStatus.underpaid)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _Banner(
                color: AppColors.amber,
                text:
                    'Дутуу төлбөр ирсэн: '
                    '${formatAmount((payment.underpaidAmount ?? 0).round())}${payment.currency} / '
                    '${formatAmount(payment.amount.round())}${payment.currency}. '
                    'Үлдэгдлийг дахин уншуулж нөхнө үү.',
              ),
            ),
          if (payment.status == AppointmentFeeStatus.paid) ...[
            const _Banner(
              color: AppColors.green,
              text: 'Төлбөр амжилттай төлөгдсөн.',
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: onDone,
                child: const Text('Дуусгах'),
              ),
            ),
          ] else if (failed) ...[
            const _Banner(
              color: AppColors.red,
              text: 'Invoice үүсгэхэд алдаа гарсан байна.',
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: retrying ? null : onRetry,
              child: Text(retrying ? 'Оролдож...' : 'Дахин оролдох'),
            ),
          ] else if (payment.qrImageBase64 != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Image.memory(
                base64Decode(payment.qrImageBase64!),
                width: 220,
                height: 220,
                fit: BoxFit.contain,
              ),
            ),
            if (payment.qrText != null) ...[
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => onOpenBankApp(payment.qrText!),
                child: const Text('Банкны апп руу шилжих →'),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              'Утсаараа банкны апп нээж QR-аа уншуулна уу. Төлбөр төлөгдсөний '
              'дараа доорх товчоор шалгана уу.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            FilledButton(
              key: const ValueKey('payment-check'),
              onPressed: checking ? null : onCheck,
              child: Text(checking ? 'Шалгаж байна...' : 'Төлбөр шалгах'),
            ),
          ] else
            Text(
              'QR үүсэхэд хүлээнэ үү...',
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
        ],
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.color, required this.text});

  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      border: Border.all(color: color.withValues(alpha: 0.3)),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Text(
      text,
      textAlign: TextAlign.center,
      style: TextStyle(color: color),
    ),
  );
}
