import 'package:carcare_customer_mobile/app/theme/app_surfaces.dart';
import 'package:carcare_customer_mobile/app/theme/app_theme.dart';
import 'package:carcare_customer_mobile/core/widgets/animations.dart';
import 'package:carcare_customer_mobile/core/widgets/offline_banner.dart';
import 'package:carcare_customer_mobile/core/widgets/skeletons.dart';
import 'package:carcare_customer_mobile/features/booking/domain/appointment.dart';
import 'package:carcare_customer_mobile/features/booking/domain/appointment_payment.dart';
import 'package:carcare_customer_mobile/features/booking/domain/appointment_status.dart';
import 'package:carcare_customer_mobile/features/booking/domain/service_progress.dart';
import 'package:carcare_customer_mobile/features/booking/domain/walk_in_order.dart';
import 'package:carcare_customer_mobile/features/auth/presentation/auth_controller.dart';
import 'package:carcare_customer_mobile/features/booking/presentation/controllers/appointments_controller.dart';
import 'package:carcare_customer_mobile/features/booking/presentation/controllers/appointments_state.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class AppointmentsScreen extends StatelessWidget {
  const AppointmentsScreen({
    required this.onLoginRequested,
    required this.onAppointmentSelected,
    required this.onPaymentRequested,
    required this.onWalkInOrderSelected,
    super.key,
  });

  final VoidCallback onLoginRequested;
  final ValueChanged<String> onAppointmentSelected;
  final ValueChanged<Appointment> onPaymentRequested;

  /// Захиалгагүй (walk-in) захиалгын дэлгэрэнгүй рүү шилжих — аргумент нь
  /// [WalkInOrder.progress.id] (Appointment.id-той адил нэр зайд, гэхдээ
  /// огт өөр entity).
  final ValueChanged<String> onWalkInOrderSelected;

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
                onAppointmentSelected: onAppointmentSelected,
                onPaymentRequested: onPaymentRequested,
                onWalkInOrderSelected: onWalkInOrderSelected,
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

class _AppointmentsBody extends StatefulWidget {
  const _AppointmentsBody({
    required this.controller,
    required this.onAppointmentSelected,
    required this.onPaymentRequested,
    required this.onWalkInOrderSelected,
  });

  final AppointmentsController controller;
  final ValueChanged<String> onAppointmentSelected;
  final ValueChanged<Appointment> onPaymentRequested;
  final ValueChanged<String> onWalkInOrderSelected;

  @override
  State<_AppointmentsBody> createState() => _AppointmentsBodyState();
}

class _AppointmentsBodyState extends State<_AppointmentsBody>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late final TextEditingController _searchController;
  final LayerLink _filterButtonLink = LayerLink();
  OverlayEntry? _filterOverlay;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _searchController = TextEditingController(
      text: widget.controller.searchQuery,
    );
  }

  @override
  void dispose() {
    _closeStatusFilterOverlay();
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.controller.state;
    if (state.status == AppointmentsStatus.initial ||
        state.status == AppointmentsStatus.loading) {
      return Semantics(
        container: true,
        liveRegion: true,
        label: 'Захиалгуудыг ачаалж байна',
        child: const SkeletonCardList(),
      );
    }
    if (state.status == AppointmentsStatus.error) {
      return _ErrorView(
        message: state.message ?? 'Тодорхойгүй алдаа гарлаа.',
        onRetry: widget.controller.load,
      );
    }
    if (state.status == AppointmentsStatus.empty) {
      return const _EmptyAppointments();
    }
    return Column(
      children: [
        if (state.isFromCache)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
            child: OfflineBanner(
              message:
                  'Сүлжээгүй байна — сүүлд ачаалсан захиалгуудыг харуулж байна',
              semanticsLabel:
                  'Сүлжээгүй байна. Сүүлд ачаалсан захиалгуудын жагсаалтыг харуулж байна.',
              retryKey: const ValueKey('appointments-offline-retry'),
              onRetry: widget.controller.load,
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  key: const ValueKey('appointments-search'),
                  controller: _searchController,
                  onChanged: widget.controller.setSearchQuery,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: 'Хайх (байгууллага, салбар, улсын дугаар)',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: widget.controller.searchQuery.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.close_rounded),
                            onPressed: () {
                              _searchController.clear();
                              widget.controller.setSearchQuery('');
                            },
                          ),
                    isDense: true,
                    filled: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              CompositedTransformTarget(
                link: _filterButtonLink,
                child: AnimatedBuilder(
                  animation: _tabController,
                  builder: (context, _) {
                    final hasActive = _tabController.index == 0
                        ? widget.controller.selectedAppointmentStatus != null
                        : widget.controller.selectedWalkInStatus != null;
                    return _FilterButton(
                      key: const ValueKey('appointments-filter-button'),
                      activeCount: hasActive ? 1 : 0,
                      onTap: _toggleStatusFilterOverlay,
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          child: TabBar(
            key: const ValueKey('appointments-tab-bar'),
            controller: _tabController,
            tabs: const [
              Tab(text: 'Цагийн захиалгууд'),
              Tab(text: 'Засварын захиалгууд'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _AppointmentsOnlyList(
                controller: widget.controller,
                onAppointmentSelected: widget.onAppointmentSelected,
                onPaymentRequested: widget.onPaymentRequested,
              ),
              _WalkInOrdersOnlyList(
                controller: widget.controller,
                onWalkInOrderSelected: widget.onWalkInOrderSelected,
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _toggleStatusFilterOverlay() {
    if (_filterOverlay != null) {
      _closeStatusFilterOverlay();
      return;
    }
    final overlay = Overlay.of(context);
    final entry = OverlayEntry(
      builder: (overlayContext) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _closeStatusFilterOverlay,
            ),
          ),
          CompositedTransformFollower(
            link: _filterButtonLink,
            showWhenUnlinked: false,
            targetAnchor: Alignment.bottomRight,
            followerAnchor: Alignment.topRight,
            offset: const Offset(0, 8),
            child: Align(
              alignment: Alignment.topRight,
              child: Material(
                elevation: 8,
                borderRadius: BorderRadius.circular(16),
                color: Theme.of(overlayContext).colorScheme.surface,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 280),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: AnimatedBuilder(
                      animation: Listenable.merge([
                        widget.controller,
                        _tabController,
                      ]),
                      builder: (context, _) {
                        final isAppointmentsTab = _tabController.index == 0;
                        return _StatusFilterOptions(
                          available: isAppointmentsTab
                              ? widget.controller.availableAppointmentStatuses
                              : widget.controller.availableWalkInStatuses,
                          selected: isAppointmentsTab
                              ? widget.controller.selectedAppointmentStatus
                              : widget.controller.selectedWalkInStatus,
                          onSelect: (label) {
                            if (isAppointmentsTab) {
                              widget.controller.selectAppointmentStatus(label);
                            } else {
                              widget.controller.selectWalkInStatus(label);
                            }
                            _closeStatusFilterOverlay();
                          },
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
    _filterOverlay = entry;
    overlay.insert(entry);
  }

  void _closeStatusFilterOverlay() {
    _filterOverlay?.remove();
    _filterOverlay = null;
  }
}

class _FilterButton extends StatelessWidget {
  const _FilterButton({
    required this.activeCount,
    required this.onTap,
    super.key,
  });

  final int activeCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasActive = activeCount > 0;
    final colorScheme = Theme.of(context).colorScheme;
    return Badge(
      isLabelVisible: hasActive,
      label: Text('$activeCount'),
      child: Material(
        color: hasActive
            ? colorScheme.primaryContainer
            : colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Icon(
              Icons.tune_rounded,
              color: hasActive ? colorScheme.onPrimaryContainer : null,
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusFilterOptions extends StatelessWidget {
  const _StatusFilterOptions({
    required this.available,
    required this.selected,
    required this.onSelect,
  });

  final List<String> available;
  final String? selected;

  /// Passing `null` clears the filter ("Бүгд").
  final ValueChanged<String?> onSelect;

  @override
  Widget build(BuildContext context) {
    if (available.isEmpty) {
      return Text(
        'Шүүх төлөв алга.',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _StatusFilterOption(
          key: const ValueKey('status-filter-option-all'),
          label: 'Бүгд',
          isSelected: selected == null,
          onTap: () => onSelect(null),
        ),
        for (final label in available)
          _StatusFilterOption(
            key: ValueKey('status-filter-option-$label'),
            label: label,
            isSelected: selected == label,
            onTap: () => onSelect(label),
          ),
      ],
    );
  }
}

class _StatusFilterOption extends StatelessWidget {
  const _StatusFilterOption({
    required this.label,
    required this.isSelected,
    required this.onTap,
    super.key,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? colorScheme.primary : null,
                ),
              ),
            ),
            if (isSelected)
              Icon(Icons.check_rounded, color: colorScheme.primary, size: 20),
          ],
        ),
      ),
    );
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

class _NoFilterResults extends StatelessWidget {
  const _NoFilterResults();

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.search_off_rounded,
            size: 52,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 12),
          Text(
            'Илэрц олдсонгүй',
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            'Хайлт эсвэл төлвийн шүүлтүүрээ өөрчилж үзээрэй.',
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

class _AppointmentsOnlyList extends StatelessWidget {
  const _AppointmentsOnlyList({
    required this.controller,
    required this.onAppointmentSelected,
    required this.onPaymentRequested,
  });

  final AppointmentsController controller;
  final ValueChanged<String> onAppointmentSelected;
  final ValueChanged<Appointment> onPaymentRequested;

  @override
  Widget build(BuildContext context) {
    final appointments = controller.sortedAppointments;
    if (appointments.isEmpty) return const _NoFilterResults();
    return RefreshIndicator(
      onRefresh: controller.load,
      child: ListView.separated(
        key: const PageStorageKey('appointments-only-list'),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        itemCount: appointments.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final appointment = appointments[index];
          return RiseIn(
            index: index,
            child: _AppointmentCard(
              appointment: appointment,
              isCancelling: controller.isCancelling(appointment.id),
              onTap: () => onAppointmentSelected(appointment.id),
              onCancel: appointment.status.canCancel
                  ? () => _confirmCancel(context, controller, appointment)
                  : null,
              onPaymentTap: appointment.canPayFee
                  ? () => onPaymentRequested(appointment)
                  : null,
            ),
          );
        },
      ),
    );
  }

  Future<void> _confirmCancel(
    BuildContext context,
    AppointmentsController controller,
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

class _WalkInOrdersOnlyList extends StatelessWidget {
  const _WalkInOrdersOnlyList({
    required this.controller,
    required this.onWalkInOrderSelected,
  });

  final AppointmentsController controller;
  final ValueChanged<String> onWalkInOrderSelected;

  @override
  Widget build(BuildContext context) {
    final walkInOrders = controller.visibleWalkInOrders;
    if (walkInOrders.isEmpty) return const _NoFilterResults();
    return RefreshIndicator(
      onRefresh: controller.load,
      child: ListView.separated(
        key: const PageStorageKey('walk-in-orders-only-list'),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        itemCount: walkInOrders.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final order = walkInOrders[index];
          return RiseIn(
            index: index,
            child: _WalkInOrderCard(
              order: order,
              onTap: () => onWalkInOrderSelected(order.progress.id),
            ),
          );
        },
      ),
    );
  }
}

/// Appointment-гүй (ажилтан шууд үүсгэсэн) захиалгын карт — цуцлах/хураамж
/// гэсэн ойлголт байхгүй, зөвхөн дэлгэрэнгүй рүү шилжинэ (харах:
/// `WalkInOrderDetailScreen`).
class _WalkInOrderCard extends StatelessWidget {
  const _WalkInOrderCard({required this.order, this.onTap});

  final WalkInOrder order;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => GlassSurface(
    key: ValueKey('walk-in-order-card-${order.progress.id}'),
    onTap: onTap,
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
            _ProgressStatusChip(status: order.progress.status),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          order.branchName,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '№${order.progress.number}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    ),
  );
}

class _ProgressStatusChip extends StatelessWidget {
  const _ProgressStatusChip({required this.status});

  final ServiceProgressStatus status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      ServiceProgressStatus.completed => AppColors.green,
      ServiceProgressStatus.cancelled => AppColors.red,
      ServiceProgressStatus.inProgress => AppColors.blue,
      ServiceProgressStatus.postponed => AppColors.purple,
      ServiceProgressStatus.pending ||
      ServiceProgressStatus.scheduled ||
      ServiceProgressStatus.unknown => Theme.of(
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
        style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12),
      ),
    );
  }
}

class _AppointmentCard extends StatelessWidget {
  const _AppointmentCard({
    required this.appointment,
    required this.isCancelling,
    this.onTap,
    this.onCancel,
    this.onPaymentTap,
  });

  final Appointment appointment;
  final bool isCancelling;
  final VoidCallback? onTap;
  final VoidCallback? onCancel;

  /// Non-null only when this appointment has an unpaid/underpaid/failed fee
  /// (`CUSTOMER_API_CONTRACT.md` §4.1) — tapping opens the payment screen.
  final VoidCallback? onPaymentTap;

  @override
  Widget build(BuildContext context) => GlassSurface(
    key: ValueKey('appointment-card-${appointment.id}'),
    onTap: onTap,
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
            appointment.serviceProgress != null
                ? _ProgressStatusChip(status: appointment.serviceProgress!.status)
                : _StatusChip(status: appointment.status),
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
              color: AppColors.red.withValues(alpha: 0.12),
              border: Border.all(color: AppColors.red.withValues(alpha: 0.35)),
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
                      color: AppColors.red,
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
        // Хураамж төлөгдсөнийг тусад нь харуулна — цаг захиалгын status
        // (Хүлээгдэж буй) төлбөрөөр өөрчлөгддөггүй (ажилтан баталгаажуулна).
        if (appointment.payment?.status == AppointmentFeeStatus.paid) ...[
          const SizedBox(height: 12),
          Container(
            key: ValueKey('fee-paid-${appointment.id}'),
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.green.withValues(alpha: 0.12),
              border: Border.all(color: AppColors.green.withValues(alpha: 0.35)),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Row(
              children: [
                Icon(Icons.check_circle_rounded, size: 16, color: AppColors.green),
                SizedBox(width: 8),
                Text(
                  'Хураамж төлөгдсөн',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.green,
                  ),
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
