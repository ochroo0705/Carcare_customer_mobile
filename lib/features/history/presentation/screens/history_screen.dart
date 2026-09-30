import 'package:carcare_customer_mobile/app/theme/app_theme.dart';
import 'package:carcare_customer_mobile/app/theme/app_surfaces.dart';
import 'package:carcare_customer_mobile/core/widgets/coming_soon_view.dart';
import 'package:carcare_customer_mobile/core/widgets/animations.dart';
import 'package:carcare_customer_mobile/core/widgets/filter_controls.dart';
import 'package:carcare_customer_mobile/core/widgets/offline_banner.dart';
import 'package:carcare_customer_mobile/core/widgets/skeletons.dart';
import 'package:carcare_customer_mobile/features/diagnostics/domain/diagnostics_repository.dart';
import 'package:carcare_customer_mobile/features/diagnostics/presentation/controllers/diagnostics_controller.dart';
import 'package:carcare_customer_mobile/features/diagnostics/presentation/screens/diagnostics_screen.dart';
import 'package:carcare_customer_mobile/features/history/domain/cancelled_appointment_summary.dart';
import 'package:carcare_customer_mobile/features/history/domain/service_order.dart';
import 'package:carcare_customer_mobile/features/auth/presentation/auth_controller.dart';
import 'package:carcare_customer_mobile/features/history/presentation/controllers/history_controller.dart';
import 'package:carcare_customer_mobile/features/history/presentation/controllers/history_state.dart';
import 'package:carcare_customer_mobile/features/history/presentation/format_amount.dart';
import 'package:carcare_customer_mobile/features/history/presentation/widgets/service_order_status_chip.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:carcare_customer_mobile/core/widgets/state_views.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({
    required this.onLoginRequested,
    required this.onOrderSelected,
    required this.diagnosticsRepository,
    required this.onDiagnosticReportSelected,
    this.reconnects,
    super.key,
  });

  final VoidCallback onLoginRequested;
  final ValueChanged<String> onOrderSelected;

  /// "Оношилгооны жагсаалт" tab data source.
  final DiagnosticsRepository diagnosticsRepository;
  final ValueChanged<String> onDiagnosticReportSelected;

  /// Ticks on network reconnect; the diagnostics tab retries a failed load.
  final Listenable? reconnects;

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
                diagnosticsRepository: diagnosticsRepository,
                onDiagnosticReportSelected: onDiagnosticReportSelected,
                reconnects: reconnects,
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

/// Тавуур: "Засварын түүх" (order/cancelled appointment list) болон
/// "Оношилгоо" (diagnostics report list) хоёр tab-тай. Хоёр tab бие даасан
/// controller/state хэрэглэдэг тул алдаа/ачаалалт тус тусдаа харагдана.
class _HistoryBody extends StatefulWidget {
  const _HistoryBody({
    required this.controller,
    required this.onOrderSelected,
    required this.diagnosticsRepository,
    required this.onDiagnosticReportSelected,
    this.reconnects,
  });

  final HistoryController controller;
  final ValueChanged<String> onOrderSelected;
  final DiagnosticsRepository diagnosticsRepository;
  final ValueChanged<String> onDiagnosticReportSelected;
  final Listenable? reconnects;

  @override
  State<_HistoryBody> createState() => _HistoryBodyState();
}

class _HistoryBodyState extends State<_HistoryBody>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late final DiagnosticsController _diagnosticsController =
      DiagnosticsController(widget.diagnosticsRepository)..load();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    widget.reconnects?.addListener(_onReconnect);
  }

  @override
  void didUpdateWidget(covariant _HistoryBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reconnects != widget.reconnects) {
      oldWidget.reconnects?.removeListener(_onReconnect);
      widget.reconnects?.addListener(_onReconnect);
    }
  }

  void _onReconnect() {
    if (_diagnosticsController.status == DiagnosticsStatus.error) {
      _diagnosticsController.load();
    }
  }

  @override
  void dispose() {
    widget.reconnects?.removeListener(_onReconnect);
    _tabController.dispose();
    _diagnosticsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
        child: TabBar(
          key: const ValueKey('history-tab-bar'),
          controller: _tabController,
          tabs: const [
            Tab(text: 'Засварын түүх'),
            Tab(text: 'Оношилгооны жагсаалт'),
          ],
        ),
      ),
      Expanded(
        child: TabBarView(
          controller: _tabController,
          children: [
            _AppointmentHistoryTab(
              controller: widget.controller,
              onOrderSelected: widget.onOrderSelected,
            ),
            DiagnosticsListView(
              controller: _diagnosticsController,
              onReportSelected: widget.onDiagnosticReportSelected,
            ),
          ],
        ),
      ),
    ],
  );
}

/// Хайлт/шүүлтийн мөр (`SearchWithYearFilterBar`) энд, switch-ийн ГАДНА
/// байрлана — доорх төлөв (skeleton/error/empty) хэзээ ч энэ мөрийг unmount
/// хийхгүй. Өмнө нь хайлтын мөр `HistoryStatus.data`-гийн доторх
/// `_HistoryList`-д байсан бөгөөд query/year өөрчлөгдөх бүрт статус
/// `loading`/`empty` рүү шилжиж, `TextField`-ийг unmount хийснээр гар
/// товчлуур (keyboard) үсэг бүр дээр хаагдах алдаа гаргаж байсан.
class _AppointmentHistoryTab extends StatelessWidget {
  const _AppointmentHistoryTab({
    required this.controller,
    required this.onOrderSelected,
  });

  final HistoryController controller;
  final ValueChanged<String> onOrderSelected;

  @override
  Widget build(BuildContext context) {
    final state = controller.state;
    // A refresh that already has rows keeps them on screen rather than
    // dropping back to the skeleton: `load()` carries the previous orders
    // through `loading` (see HistoryController), and History reloads on
    // events the customer did not trigger here — an appointment cancelled on
    // another tab, a terminal push. The skeleton is for a first load only.
    final status =
        state.status == HistoryStatus.loading &&
            (state.orders.isNotEmpty || state.cancelledAppointments.isNotEmpty)
        ? HistoryStatus.data
        : state.status;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          child: SearchWithYearFilterBar(
            searchFieldKey: const ValueKey('history-search'),
            filterButtonKey: const ValueKey('history-filter-button'),
            hintText: 'Байгууллага, салбар, дугаараар хайх',
            initialQuery: controller.query,
            onQueryChanged: controller.setQuery,
            years: controller.availableYears,
            selectedYear: controller.year,
            onYearSelected: controller.setYear,
          ),
        ),
        Expanded(
          child: switch (status) {
            HistoryStatus.initial || HistoryStatus.loading => Semantics(
              container: true,
              liveRegion: true,
              label: 'Түүхийг ачаалж байна',
              child: const SkeletonCardList(showTrailing: true),
            ),
            HistoryStatus.error => ErrorView(
              message: state.message ?? 'Тодорхойгүй алдаа гарлаа.',
              onRetry: controller.load,
              retryKey: const ValueKey('history-retry'),
            ),
            HistoryStatus.empty => const EmptyView(
              icon: Icons.receipt_long_outlined,
              title: 'Засварын түүх алга',
              message: 'Үйлчилгээ авсны дараа энд харагдана.',
            ),
            HistoryStatus.unavailable => const ComingSoonView(
              icon: Icons.receipt_long_outlined,
              title: 'Тун удахгүй',
              message: 'Засварын түүх удахгүй энд харагдана.',
            ),
            HistoryStatus.data => _HistoryList(
              controller: controller,
              onOrderSelected: onOrderSelected,
            ),
          },
        ),
      ],
    );
  }
}

class _HistoryList extends StatefulWidget {
  const _HistoryList({required this.controller, required this.onOrderSelected});

  final HistoryController controller;
  final ValueChanged<String> onOrderSelected;

  @override
  State<_HistoryList> createState() => _HistoryListState();
}

class _HistoryListState extends State<_HistoryList> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      if (_scrollController.position.extentAfter < 400 &&
          widget.controller.hasNextPage &&
          widget.controller.state.loadMoreMessage == null) {
        widget.controller.loadMore();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final allOrders = widget.controller.state.orders;
    final allCancelled = widget.controller.state.cancelledAppointments;
    final orders = allOrders;
    final cancelledAppointments = allCancelled;
    final isFromCache = widget.controller.state.isFromCache;
    final hasFilter = widget.controller.query.isNotEmpty;
    final noResults =
        hasFilter && orders.isEmpty && cancelledAppointments.isEmpty;
    final offset = isFromCache ? 1 : 0;
    // D-085: cancelled/no-show/rejected appointments render after the order
    // cards, behind their own section header (only when there are any).
    final hasCancelledSection = cancelledAppointments.isNotEmpty;
    final itemCount =
        orders.length +
        offset +
        (hasCancelledSection ? 1 : 0) +
        cancelledAppointments.length +
        (widget.controller.hasNextPage ? 1 : 0);
    return noResults
        ? Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text(
                'Илэрц олдсонгүй',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          )
        : RefreshIndicator(
            onRefresh: widget.controller.load,
            child: ListView.separated(
              controller: _scrollController,
              key: const PageStorageKey('history-list'),
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
              itemCount: itemCount,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final contentCount =
                    orders.length +
                    offset +
                    (hasCancelledSection ? 1 : 0) +
                    cancelledAppointments.length;
                if (index >= contentCount) {
                  return Padding(
                    padding: const EdgeInsets.all(20),
                    child: Center(
                      child: widget.controller.state.loadMoreMessage == null
                          ? const CircularProgressIndicator()
                          : OutlinedButton(
                              onPressed: widget.controller.loadMore,
                              child: const Text('Дахин ачаалах'),
                            ),
                    ),
                  );
                }
                if (isFromCache && index == 0) {
                  return OfflineBanner(
                    message: 'Сүлжээгүй байна — сүүлд ачаалсан түүхийг харуулж байна',
                    semanticsLabel: 'Сүлжээгүй байна. Сүүлд ачаалсан засварын түүхийг харуулж байна.',
                    retryKey: const ValueKey('history-offline-retry'),
                    onRetry: widget.controller.load,
                  );
                }
                final ordersEnd = offset + orders.length;
                if (index < ordersEnd) {
                  final order = orders[index - offset];
                  return RiseIn(
                    index: index - offset,
                    child: _OrderCard(
                      order: order,
                      onTap: () => widget.onOrderSelected(order.id),
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
      style: Theme.of(context).textTheme.titleSmall
          ?.copyWith(fontWeight: FontWeight.w800),
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

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order, required this.onTap});

  final ServiceOrder order;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    key: ValueKey('history-order-${order.id}'),
    onTap: onTap,
    borderRadius: BorderRadius.circular(AppRadii.extraLarge),
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
