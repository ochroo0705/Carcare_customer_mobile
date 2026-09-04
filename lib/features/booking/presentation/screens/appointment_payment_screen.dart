import 'dart:async';
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

class _AppointmentPaymentScreenState extends State<AppointmentPaymentScreen>
    with WidgetsBindingObserver {
  _LoadStatus _status = _LoadStatus.loading;
  AppointmentPayment? _payment;
  String? _message;
  bool _checking = false; // manual check in flight — drives the button label
  bool _retrying = false;

  // Auto-confirm (A): while the fee is still open, quietly poll the same
  // server-verified, idempotent `checkPayment` the button calls, so a user who
  // pays and simply waits sees the screen flip to "paid" on its own. Bounded —
  // stops on a terminal status, on the deadline, and on dispose — so it can
  // never become a runaway request loop.
  Timer? _pollTimer;
  DateTime? _pollDeadline;
  bool _checkInFlight = false; // guards manual + auto from overlapping
  static const _pollInterval = Duration(seconds: 4);
  static const _pollMaxDuration = Duration(minutes: 3);

  /// A fee that could still transition to paid if more money arrives. Terminal
  /// states (`paid`, `failed`) and "no fee" are not pollable.
  bool get _isPollable =>
      _payment != null &&
      (_payment!.status == AppointmentFeeStatus.pending ||
          _payment!.status == AppointmentFeeStatus.underpaid);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final initial = widget.initialPayment;
    if (initial != null) {
      _payment = initial;
      _status = _LoadStatus.data;
      _maybeStartPolling();
    } else {
      _load();
    }
  }

  @override
  void dispose() {
    _stopPolling();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Resume-check (B): the user typically leaves to their bank app and comes
  // back — re-check immediately on resume so the flip feels instant, and make
  // sure polling is running (a backgrounded timer may have been throttled).
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _isPollable) {
      _runCheck(silent: true);
      _maybeStartPolling();
    }
  }

  void _maybeStartPolling() {
    if (!_isPollable) {
      _stopPolling();
      return;
    }
    if (_pollTimer != null) return; // already polling
    _pollDeadline = DateTime.now().add(_pollMaxDuration);
    _pollTimer = Timer.periodic(_pollInterval, (_) => _autoPoll());
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
    _pollDeadline = null;
  }

  Future<void> _autoPoll() async {
    if (!_isPollable ||
        (_pollDeadline != null && DateTime.now().isAfter(_pollDeadline!))) {
      _stopPolling();
      return;
    }
    await _runCheck(silent: true);
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
      _maybeStartPolling();
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

  /// Manual "Төлбөр шалгах" tap. Same logic as the auto-poll, but not silent —
  /// it surfaces "not paid yet" / errors as snackbars and shows the button
  /// spinner.
  void _check() => _runCheck(silent: false);

  /// Confirms payment against the server. [silent] auto-polls suppress the
  /// button spinner and the "not paid yet"/error snackbars (a poll every few
  /// seconds must not spam the user); state transitions still apply.
  Future<void> _runCheck({required bool silent}) async {
    if (_checkInFlight) return;
    _checkInFlight = true;
    if (!silent) setState(() => _checking = true);
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
        _stopPolling();
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
              urls: current.urls,
              underpaidAmount: result.underpaidAmount,
            );
          });
        }
        if (!silent) {
          _showSnack(
            result.message ?? 'Дутуу төлбөр ирсэн байна.',
            isError: true,
          );
        }
      } else if (!silent) {
        _showSnack(
          result.message ?? 'Төлбөр төлөгдөөгүй байна. Банкны аппаар QR-аа уншуулсны дараа дахин шалгана уу.',
        );
      }
    } on AppFailure catch (failure) {
      if (mounted && !silent) _showSnack(failure.message, isError: true);
    } catch (_) {
      if (mounted && !silent) {
        _showSnack('Тодорхойгүй алдаа гарлаа.', isError: true);
      }
    } finally {
      _checkInFlight = false;
      if (mounted && !silent) setState(() => _checking = false);
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
      _maybeStartPolling(); // a fresh pending invoice — resume auto-confirm
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

  Future<void> _openBankLink(String link) async {
    final uri = Uri.tryParse(link);
    if (uri == null) {
      if (mounted) _showSnack('Банкны холбоос буруу байна.', isError: true);
      return;
    }
    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && mounted) {
        // Апп суулгаагүй, эсвэл scheme-ийг Android <queries>/iOS
        // LSApplicationQueriesSchemes-д зарлаагүй үед false буцаана.
        _showSnack(
          'Банкны апп нээгдсэнгүй. Уг банкны апп суусан эсэхээ шалгана уу.',
          isError: true,
        );
      }
    } catch (_) {
      if (mounted) _showSnack('Банкны апп нээгдсэнгүй.', isError: true);
    }
  }

  Future<void> _pickBank(List<QpayBankUrl> urls) async {
    // Ганц банк бол шууд нээнэ; олон бол сонголтын хуудас гаргана.
    if (urls.length == 1) {
      await _openBankLink(urls.first.link);
      return;
    }
    final selected = await showModalBottomSheet<QpayBankUrl>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => _BankPickerSheet(urls: urls),
    );
    if (selected != null) await _openBankLink(selected.link);
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
                  onPickBank: _pickBank,
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
    required this.onPickBank,
    required this.onDone,
  });

  final AppointmentPayment payment;
  final bool checking;
  final bool retrying;
  final VoidCallback onCheck;
  final VoidCallback onRetry;
  final ValueChanged<List<QpayBankUrl>> onPickBank;
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
            if (payment.urls.isNotEmpty) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.tonalIcon(
                  key: const ValueKey('payment-pick-bank'),
                  onPressed: () => onPickBank(payment.urls),
                  icon: const Icon(Icons.account_balance_rounded, size: 18),
                  label: Text(
                    payment.urls.length == 1
                        ? '${payment.urls.first.label}-аар төлөх'
                        : 'Банкны аппаар төлөх',
                  ),
                ),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              payment.urls.isNotEmpty
                  ? 'Банкаа сонгож апп руугаа шилжин төлнө үү, эсвэл өөр '
                        'утсаараа QR-аа уншуулна уу. Дараа нь доорх товчоор '
                        'шалгана уу.'
                  : 'Утсаараа банкны апп нээж QR-аа уншуулна уу. Төлбөр '
                        'төлөгдсөний дараа доорх товчоор шалгана уу.',
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

/// Банк сонгох доод хуудас — QPay `urls`-аас нэг банкыг буцаана. Лого татаж
/// чадаагүй бол банкны нэрний эхний үсгээр орлуулна (сүлжээ/CSP асуудалд
/// найдваргүй болгохгүй).
class _BankPickerSheet extends StatelessWidget {
  const _BankPickerSheet({required this.urls});

  final List<QpayBankUrl> urls;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: Text(
              'Банкаа сонгоно уу',
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.only(bottom: 8),
              itemCount: urls.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final bank = urls[i];
                return ListTile(
                  key: ValueKey('bank-${bank.name}-$i'),
                  leading: CircleAvatar(
                    backgroundColor: scheme.surfaceContainerHighest,
                    foregroundImage: bank.logo.isNotEmpty
                        ? NetworkImage(bank.logo)
                        : null,
                    child: Text(
                      bank.label.isNotEmpty
                          ? bank.label.substring(0, 1).toUpperCase()
                          : '?',
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    ),
                  ),
                  title: Text(bank.label),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.of(context).pop(bank),
                );
              },
            ),
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
