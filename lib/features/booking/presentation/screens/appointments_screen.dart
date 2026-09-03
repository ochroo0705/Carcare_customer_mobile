import 'package:carcare_customer_mobile/app/theme/app_surfaces.dart';
import 'package:carcare_customer_mobile/app/theme/app_theme.dart';
import 'package:carcare_customer_mobile/core/widgets/offline_banner.dart';
import 'package:carcare_customer_mobile/features/booking/domain/appointment.dart';
import 'package:carcare_customer_mobile/features/booking/domain/appointment_payment.dart';
import 'package:carcare_customer_mobile/features/booking/domain/appointment_status.dart';
import 'package:carcare_customer_mobile/features/auth/presentation/auth_controller.dart';
import 'package:carcare_customer_mobile/features/booking/presentation/controllers/appointments_controller.dart';
import 'package:carcare_customer_mobile/features/booking/presentation/controllers/appointments_state.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class AppointmentsScreen extends StatelessWidget {
  const AppointmentsScreen({
    required this.onLoginRequested,
    required this.onPaymentRequested,
    super.key,
  });

  final VoidCallback onLoginRequested;
  final ValueChanged<Appointment> onPaymentRequested;

  @override
  Widget build(BuildContext context) {
    final isAuthenticated = context.select<AuthController, bool>(
      (c) => c.isAuthenticated,
    );
    final controller = context.watch<AppointmentsController>();
    return AppShellBackground(
      child: SafeArea(
        child: isAuthenticated
            ? _AppointmentsBody(
                controller: controller,
                onPaymentRequested: onPaymentRequested,
              )
            : _UnauthenticatedPrompt(onLoginRequested: onLoginRequested),
      ),
    );
  }
}

class _UnauthenticatedPrompt extends StatelessWidget {
  const _UnauthenticatedPrompt({required this.onLoginRequested});

  final VoidCallback onLoginRequested;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.event_note_outlined,
            size: 58,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 18),
          Text(
            'Захиалгаа харахын тулд нэвтэрнэ үү',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            'Таны цагийн хүсэлтүүд энд харагдана.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            key: const ValueKey('appointments-login'),
            onPressed: onLoginRequested,
            icon: const Icon(Icons.login_rounded),
            label: const Text('Нэвтрэх'),
          ),
        ],
      ),
    ),
  );
}

class _AppointmentsBody extends StatelessWidget {
  const _AppointmentsBody({
    required this.controller,
    required this.onPaymentRequested,
  });

  final AppointmentsController controller;
  final ValueChanged<Appointment> onPaymentRequested;

  @override
  Widget build(BuildContext context) {
    final state = controller.state;
    return switch (state.status) {
      AppointmentsStatus.initial || AppointmentsStatus.loading => Semantics(
        container: true,
        liveRegion: true,
        label: 'Захиалгуудыг ачаалж байна',
        child: Center(child: CircularProgressIndicator()),
      ),
      AppointmentsStatus.error => _ErrorView(
        message: state.message ?? 'Тодорхойгүй алдаа гарлаа.',
        onRetry: controller.load,
      ),
      AppointmentsStatus.empty => const _EmptyAppointments(),
      AppointmentsStatus.data => _AppointmentsList(
        controller: controller,
        onPaymentRequested: onPaymentRequested,
      ),
    };
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    liveRegion: true,
    label: message,
    child: Center(
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
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            OutlinedButton(
              key: const ValueKey('appointments-retry'),
              onPressed: onRetry,
              child: const Text('Дахин оролдох'),
            ),
          ],
        ),
      ),
    ),
  );
}

class _EmptyAppointments extends StatelessWidget {
  const _EmptyAppointments();

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.event_available_outlined,
            size: 58,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 18),
          Text(
            'Цагийн хүсэлт алга',
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            'Байгууллага сонгож цаг захиалахад энд харагдана.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    ),
  );
}

class _AppointmentsList extends StatelessWidget {
  const _AppointmentsList({
    required this.controller,
    required this.onPaymentRequested,
  });

  final AppointmentsController controller;
  final ValueChanged<Appointment> onPaymentRequested;

  @override
  Widget build(BuildContext context) {
    final appointments = controller.sortedAppointments;
    final isFromCache = controller.state.isFromCache;
    final offset = isFromCache ? 2 : 1;
    return RefreshIndicator(
      onRefresh: controller.load,
      child: ListView.separated(
        key: const PageStorageKey('appointments-list'),
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
        itemCount: appointments.length + offset,
        separatorBuilder: (_, index) => SizedBox(height: index == 0 ? 18 : 12),
        itemBuilder: (context, index) {
          if (index == 0) {
            return const _AppointmentsHeader();
          }
          if (isFromCache && index == 1) {
            return OfflineBanner(
              message:
                  'Сүлжээгүй байна — сүүлд ачаалсан захиалгуудыг харуулж байна',
              semanticsLabel: 'Сүлжээгүй байна. Сүүлд ачаалсан захиалгуудын жагсаалтыг харуулж байна.',
              retryKey: const ValueKey('appointments-offline-retry'),
              onRetry: controller.load,
            );
          }
          final appointment = appointments[index - offset];
          return _AppointmentCard(
            appointment: appointment,
            isCancelling: controller.isCancelling(appointment.id),
            onCancel: appointment.status.canCancel
                ? () => _confirmCancel(context, appointment)
                : null,
            onPaymentTap:
                appointment.payment != null &&
                    appointment.payment!.status != AppointmentFeeStatus.paid
                ? () => onPaymentRequested(appointment)
                : null,
          );
        },
      ),
    );
  }

  Future<void> _confirmCancel(
    BuildContext context,
    Appointment appointment,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Захиалга цуцлах уу?'),
        content: Text('${appointment.tenantName} — ${appointment.branchName}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Үгүй'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Тийм, цуцлах'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final error = await controller.cancel(appointment.id);
    if (error != null && context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error)));
    }
  }
}

class _AppointmentsHeader extends StatelessWidget {
  const _AppointmentsHeader();

  @override
  Widget build(BuildContext context) => Text(
    'Миний захиалгууд',
    style: Theme.of(context).textTheme.headlineSmall
        ?.copyWith(fontWeight: FontWeight.w900),
  );
}

class _AppointmentCard extends StatelessWidget {
  const _AppointmentCard({
    required this.appointment,
    required this.isCancelling,
    this.onCancel,
    this.onPaymentTap,
  });

  final Appointment appointment;
  final bool isCancelling;
  final VoidCallback? onCancel;

  /// Non-null only when this appointment has an unpaid/underpaid/failed fee
  /// (`CUSTOMER_API_CONTRACT.md` §4.1) — tapping opens the payment screen.
  final VoidCallback? onPaymentTap;

  @override
  Widget build(BuildContext context) => GlassSurface(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                appointment.tenantName,
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(width: 8),
            _StatusChip(status: appointment.status),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          appointment.branchName,
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Icon(
              Icons.event_outlined,
              size: 16,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Text(_formatDateTime(appointment.requestedAt)),
          ],
        ),
        if (appointment.categoryName != null) ...[
          const SizedBox(height: 4),
          Text(
            'Ангилал: ${appointment.categoryName}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
        if (appointment.vehiclePlate != null) ...[
          const SizedBox(height: 4),
          Text(
            'Тээврийн хэрэгсэл: ${appointment.vehiclePlate}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
        if (appointment.note != null &&
            appointment.note!.trim().isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(appointment.note!, style: Theme.of(context).textTheme.bodySmall),
        ],
        if (onPaymentTap != null) ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.amber.withValues(alpha: 0.12),
              border: Border.all(color: AppColors.amber.withValues(alpha: 0.3)),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    appointment.payment!.status == AppointmentFeeStatus.failed
                        ? 'Хураамжийн QR үүсгэхэд алдаа гарсан'
                        : 'Цаг захиалгын хураамж төлөгдөөгүй',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.amberLightText,
                    ),
                  ),
                ),
                TextButton(
                  key: ValueKey('pay-${appointment.id}'),
                  onPressed: onPaymentTap,
                  child: const Text('Төлөх'),
                ),
              ],
            ),
          ),
        ],
        if (onCancel != null) ...[
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              key: ValueKey('cancel-${appointment.id}'),
              onPressed: isCancelling ? null : onCancel,
              child: isCancelling
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Цуцлах'),
            ),
          ),
        ],
      ],
    ),
  );
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final AppointmentStatus status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      AppointmentStatus.confirmed => AppColors.green,
      AppointmentStatus.pending => AppColors.blue,
      AppointmentStatus.rejected ||
      AppointmentStatus.cancelled => AppColors.red,
      AppointmentStatus.noShow || AppointmentStatus.unknown => Theme.of(
        context,
      ).colorScheme.onSurfaceVariant,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status.localizedLabel,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}

String _formatDateTime(DateTime value) =>
    '${value.year}.${value.month.toString().padLeft(2, '0')}.${value.day.toString().padLeft(2, '0')} '
    '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
