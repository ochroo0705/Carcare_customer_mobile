import 'package:carcare_customer_mobile/app/theme/app_surfaces.dart';
import 'package:carcare_customer_mobile/core/widgets/coming_soon_view.dart';
import 'package:carcare_customer_mobile/core/widgets/animations.dart';
import 'package:carcare_customer_mobile/core/widgets/offline_banner.dart';
import 'package:carcare_customer_mobile/core/widgets/skeletons.dart';
import 'package:carcare_customer_mobile/features/history/domain/cancelled_appointment_summary.dart';
import 'package:carcare_customer_mobile/features/history/domain/service_order.dart';
import 'package:carcare_customer_mobile/features/auth/presentation/auth_controller.dart';
import 'package:carcare_customer_mobile/features/history/presentation/controllers/history_controller.dart';
import 'package:carcare_customer_mobile/features/history/presentation/controllers/history_state.dart';
import 'package:carcare_customer_mobile/features/history/presentation/format_amount.dart';
import 'package:carcare_customer_mobile/features/history/presentation/widgets/service_order_status_chip.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({
    required this.onLoginRequested,
    required this.onOrderSelected,
    this.onDiagnosticsRequested,
    super.key,
  });

  final VoidCallback onLoginRequested;
  final ValueChanged<String> onOrderSelected;

  /// "Оношилгооны түүх"-рүү орох товч дарахад дуудагдана.
  final VoidCallback? onDiagnosticsRequested;

  @override
  Widget build(BuildContext context) {
    final isAuthenticated = context.select<AuthController, bool>(
      (c) => c.isAuthenticated,
    );
    final controller = context.watch<HistoryController>();
    return AppShellBackground(
      child: SafeArea(
        child: isAuthenticated
            ? _HistoryBody(
                controller: controller,
                onOrderSelected: onOrderSelected,
                onDiagnosticsRequested: onDiagnosticsRequested,
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
            Icons.receipt_long_outlined,
            size: 58,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 18),
          Text(
            'Түүхээ харахын тулд нэвтэрнэ үү',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            'Таны хийлгэсэн засварын түүх энд харагдана.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            key: const ValueKey('history-login'),
            onPressed: onLoginRequested,
            icon: const Icon(Icons.login_rounded),
            label: const Text('Нэвтрэх'),
          ),
        ],
      ),
    ),
  );
}

class _HistoryBody extends StatelessWidget {
  const _HistoryBody({
    required this.controller,
    required this.onOrderSelected,
    this.onDiagnosticsRequested,
  });

  final HistoryController controller;
  final ValueChanged<String> onOrderSelected;
  final VoidCallback? onDiagnosticsRequested;

  @override
  Widget build(BuildContext context) {
    final state = controller.state;
    return switch (state.status) {
      HistoryStatus.initial || HistoryStatus.loading => Semantics(
        container: true,
        liveRegion: true,
        label: 'Түүхийг ачаалж байна',
        child: const SkeletonCardList(showTrailing: true),
      ),
      HistoryStatus.error => _ErrorView(
        message: state.message ?? 'Тодорхойгүй алдаа гарлаа.',
        onRetry: controller.load,
      ),
      HistoryStatus.empty => const _EmptyHistory(),
      HistoryStatus.unavailable => const ComingSoonView(
        icon: Icons.receipt_long_outlined,
        title: 'Тун удахгүй',
        message: 'Засварын түүх удахгүй энд харагдана.',
      ),
      HistoryStatus.data => _HistoryList(
        controller: controller,
        onOrderSelected: onOrderSelected,
        onDiagnosticsRequested: onDiagnosticsRequested,
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
              key: const ValueKey('history-retry'),
              onPressed: onRetry,
              child: const Text('Дахин оролдох'),
            ),
          ],
        ),
      ),
    ),
  );
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory();

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.receipt_long_outlined,
            size: 58,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 18),
          Text(
            'Засварын түүх алга',
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            'Үйлчилгээ авсны дараа энд харагдана.',
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

class _HistoryList extends StatelessWidget {
  const _HistoryList({
    required this.controller,
    required this.onOrderSelected,
    this.onDiagnosticsRequested,
  });

  final HistoryController controller;
  final ValueChanged<String> onOrderSelected;
  final VoidCallback? onDiagnosticsRequested;

  @override
  Widget build(BuildContext context) {
    final orders = controller.state.orders;
    final cancelledAppointments = controller.state.cancelledAppointments;
    final isFromCache = controller.state.isFromCache;
    final offset = isFromCache ? 2 : 1;
    // D-085: cancelled/no-show/rejected appointments render after the order
    // cards, behind their own section header (only when there are any).
    final hasCancelledSection = cancelledAppointments.isNotEmpty;
    final itemCount =
        orders.length + offset + (hasCancelledSection ? 1 : 0) + cancelledAppointments.length;
    return RefreshIndicator(
      onRefresh: controller.load,
      child: ListView.separated(
        key: const PageStorageKey('history-list'),
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
        itemCount: itemCount,
        separatorBuilder: (_, index) => SizedBox(height: index == 0 ? 18 : 12),
        itemBuilder: (context, index) {
          if (index == 0) {
            return _HistoryHeader(onDiagnosticsRequested: onDiagnosticsRequested);
          }
          if (isFromCache && index == 1) {
            return OfflineBanner(
              message: 'Сүлжээгүй байна — сүүлд ачаалсан түүхийг харуулж байна',
              semanticsLabel: 'Сүлжээгүй байна. Сүүлд ачаалсан засварын түүхийг харуулж байна.',
              retryKey: const ValueKey('history-offline-retry'),
              onRetry: controller.load,
            );
          }
          final ordersEnd = offset + orders.length;
          if (index < ordersEnd) {
            final order = orders[index - offset];
            return RiseIn(
              index: index - offset,
              child: _OrderCard(
                order: order,
                onTap: () => onOrderSelected(order.id),
              ),
            );
          }
          if (hasCancelledSection && index == ordersEnd) {
            return const _CancelledSectionHeader();
          }
          final appt = cancelledAppointments[index - ordersEnd - 1];
          return RiseIn(
            index: index - offset,
            child: _CancelledAppointmentCard(appointment: appt),
          );
        },
      ),
    );
  }
}

class _CancelledSectionHeader extends StatelessWidget {
  const _CancelledSectionHeader();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 6),
    child: Text(
      'Цуцлагдсан / ирээгүй цагууд',
      style: Theme.of(
        context,
      ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
    ),
  );
}

class _CancelledAppointmentCard extends StatelessWidget {
  const _CancelledAppointmentCard({required this.appointment});

  final CancelledAppointmentSummary appointment;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return GlassSurface(
      key: ValueKey('history-cancelled-${appointment.id}'),
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
              CancelledOrderChip(label: appointment.status.localizedLabel),
            ],
          ),
          const SizedBox(height: 4),
          Text(appointment.branchName, style: TextStyle(color: muted)),
          if (appointment.categoryName != null) ...[
            const SizedBox(height: 4),
            Text(appointment.categoryName!, style: TextStyle(color: muted)),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.event_outlined, size: 16, color: muted),
              const SizedBox(width: 6),
              Text(_formatDate(appointment.requestedAt)),
            ],
          ),
        ],
      ),
    );
  }
}

class _HistoryHeader extends StatelessWidget {
  const _HistoryHeader({this.onDiagnosticsRequested});

  final VoidCallback? onDiagnosticsRequested;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      Expanded(
        child: Text(
          'Миний түүх',
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
        ),
      ),
      if (onDiagnosticsRequested != null)
        TextButton.icon(
          key: const ValueKey('history-diagnostics-link'),
          onPressed: onDiagnosticsRequested,
          icon: const Icon(Icons.fact_check_outlined, size: 18),
          label: const Text('Оношилгоо'),
        ),
    ],
  );
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order, required this.onTap});

  final ServiceOrder order;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    key: ValueKey('history-order-${order.id}'),
    onTap: onTap,
    borderRadius: BorderRadius.circular(20),
    child: GlassSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  order.tenantName,
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(width: 8),
              order.isCancelled
                  ? const CancelledOrderChip()
                  : ServiceOrderStatusChip(status: order.status),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            order.branchName,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
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
              Text(_formatDate(order.completedAt)),
            ],
          ),
          if (order.vehiclePlate != null) ...[
            const SizedBox(height: 4),
            Text(
              'Тээврийн хэрэгсэл: ${order.vehiclePlate}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          const SizedBox(height: 8),
          Text(
            '${formatAmount(order.totalAmount)}₮',
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    ),
  );
}

String _formatDate(DateTime value) =>
    '${value.year}.${value.month.toString().padLeft(2, '0')}.${value.day.toString().padLeft(2, '0')}';
