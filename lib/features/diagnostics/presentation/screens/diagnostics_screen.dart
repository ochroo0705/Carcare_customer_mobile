import 'package:carcare_customer_mobile/app/theme/app_theme.dart';
import 'package:carcare_customer_mobile/app/theme/app_surfaces.dart';
import 'package:carcare_customer_mobile/core/widgets/filter_controls.dart';
import 'package:carcare_customer_mobile/core/widgets/skeletons.dart';
import 'package:carcare_customer_mobile/features/diagnostics/domain/diagnostic_report_list_item.dart';
import 'package:carcare_customer_mobile/features/diagnostics/domain/diagnostics_repository.dart';
import 'package:carcare_customer_mobile/features/diagnostics/presentation/controllers/diagnostics_controller.dart';
import 'package:carcare_customer_mobile/features/diagnostics/presentation/widgets/severity_chip.dart';
import 'package:flutter/material.dart';
import 'package:carcare_customer_mobile/core/widgets/state_views.dart';

/// "Оношилгооны түүх" — зөвхөн өнгөрсөн оношилгооны тайлангуудын жагсаалт
/// (машин бүрээр биш, бүх байгууллага дамнасан), Түүх дэлгэцтэй ижил
/// sparse-list/rich-detail зарчимтай. Дарахад бүрэн тайлан нээгдэнэ.
///
/// Own `Scaffold`/`AppBar` + own [DiagnosticsController] — used for the
/// standalone deep-linked route. The Түүх (History) tab instead owns the
/// controller itself and embeds [DiagnosticsListView] directly (it renders
/// its own search/filter bar either way).
class DiagnosticsScreen extends StatefulWidget {
  const DiagnosticsScreen({
    required this.repository,
    required this.onBack,
    required this.onReportSelected,
    super.key,
  });

  final DiagnosticsRepository repository;
  final VoidCallback onBack;
  final ValueChanged<String> onReportSelected;

  @override
  State<DiagnosticsScreen> createState() => _DiagnosticsScreenState();
}

class _DiagnosticsScreenState extends State<DiagnosticsScreen> {
  late final DiagnosticsController _controller = DiagnosticsController(
    widget.repository,
  )..load();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      leading: BackButton(onPressed: widget.onBack),
      title: const Text('Оношилгооны түүх'),
    ),
    body: AppShellBackground(
      child: SafeArea(
        top: false,
        child: DiagnosticsListView(
          controller: _controller,
          onReportSelected: widget.onReportSelected,
        ),
      ),
    ),
  );
}

/// The diagnostics report list, with its own search field + year-filter
/// button above it — driven by [controller], owned by whoever embeds this
/// (the standalone [DiagnosticsScreen], or the Түүх tab).
class DiagnosticsListView extends StatefulWidget {
  const DiagnosticsListView({
    required this.controller,
    required this.onReportSelected,
    super.key,
  });

  final DiagnosticsController controller;
  final ValueChanged<String> onReportSelected;

  @override
  State<DiagnosticsListView> createState() => _DiagnosticsListViewState();
}

class _DiagnosticsListViewState extends State<DiagnosticsListView> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      if (_scrollController.position.extentAfter < 400 &&
          widget.controller.hasNextPage &&
          !widget.controller.isLoadingMore &&
          widget.controller.message == null) {
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
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.controller,
    builder: (context, _) => Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
          child: SearchWithYearFilterBar(
            searchFieldKey: const ValueKey('diagnostics-search'),
            filterButtonKey: const ValueKey('diagnostics-filter-button'),
            hintText: 'Тайлан, машин, салбараар хайх',
            initialQuery: widget.controller.query,
            onQueryChanged: widget.controller.setQuery,
            years: widget.controller.availableYears,
            selectedYear: widget.controller.year,
            onYearSelected: widget.controller.setYear,
          ),
        ),
        Expanded(child: _body(context)),
      ],
    ),
  );

  Widget _body(BuildContext context) => switch (widget.controller.status) {
    DiagnosticsStatus.initial || DiagnosticsStatus.loading => Semantics(
      container: true,
      liveRegion: true,
      label: 'Оношилгооны түүхийг ачаалж байна',
      child: const SkeletonCardList(showTrailing: true),
    ),
    DiagnosticsStatus.error => ErrorView(
      message: widget.controller.message ?? 'Тодорхойгүй алдаа гарлаа.',
      onRetry: widget.controller.load,
    ),
    DiagnosticsStatus.empty => const EmptyView(
      icon: Icons.fact_check_outlined,
      title: 'Оношилгооны тайлан алга',
      message: 'Үйлчилгээ хийгдэж, тайлан бөглөгдсөний дараа энд харагдана.',
    ),
    DiagnosticsStatus.data =>
      widget.controller.resultsStale
          ? const SkeletonCardList(showTrailing: true)
          : widget.controller.reports.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  'Сонгосон шүүлтэд тохирох тайлан алга.',
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
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                itemCount:
                    widget.controller.reports.length +
                    (widget.controller.hasNextPage ? 1 : 0),
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final reports = widget.controller.reports;
                  if (index >= reports.length) {
                    return Padding(
                      padding: const EdgeInsets.all(20),
                      child: Center(
                        child: widget.controller.message == null
                            ? const CircularProgressIndicator()
                            : OutlinedButton(
                                onPressed: widget.controller.loadMore,
                                child: const Text('Дахин ачаалах'),
                              ),
                      ),
                    );
                  }
                  final report = reports[index];
                  return _ReportCard(
                    report: report,
                    onTap: () => widget.onReportSelected(report.id),
                  );
                },
              ),
            ),
  };
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({required this.report, required this.onTap});

  final DiagnosticReportListItem report;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final date =
        '${report.createdAt.year}.${report.createdAt.month.toString().padLeft(2, '0')}.${report.createdAt.day.toString().padLeft(2, '0')}';
    final subtitle = report.mileageAtReport != null
        ? '$date · ${report.branchName} · ${report.mileageAtReport} км'
        : '$date · ${report.branchName}';
    return InkWell(
      key: ValueKey('diagnostic-report-${report.id}'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.extraLarge),
      child: GlassSurface(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    report.templateName,
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${report.vehicleMake} ${report.vehicleModel} · ${report.vehiclePlate}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (report.severity != null) ...[
              const SizedBox(width: 8),
              SeverityChip(severity: report.severity!),
            ],
          ],
        ),
      ),
    );
  }
}
