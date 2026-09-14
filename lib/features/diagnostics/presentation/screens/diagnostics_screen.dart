import 'dart:async';

import 'package:carcare_customer_mobile/app/theme/app_surfaces.dart';
import 'package:carcare_customer_mobile/core/errors/app_failure.dart';
import 'package:carcare_customer_mobile/core/widgets/skeletons.dart';
import 'package:carcare_customer_mobile/features/diagnostics/domain/diagnostic_report_list_item.dart';
import 'package:carcare_customer_mobile/features/diagnostics/domain/diagnostics_repository.dart';
import 'package:carcare_customer_mobile/features/diagnostics/domain/report_severity.dart';
import 'package:carcare_customer_mobile/features/diagnostics/presentation/widgets/severity_chip.dart';
import 'package:flutter/material.dart';

enum _ListStatus { loading, data, empty, error }

/// "Оношилгооны түүх" — зөвхөн өнгөрсөн оношилгооны тайлангуудын жагсаалт
/// (машин бүрээр биш, бүх байгууллага дамнасан), Түүх дэлгэцтэй ижил
/// sparse-list/rich-detail зарчимтай. Дарахад бүрэн тайлан нээгдэнэ.
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
  _ListStatus _status = _ListStatus.loading;
  List<DiagnosticReportListItem> _reports = const [];
  DiagnosticPagination _pagination = const DiagnosticPagination(
    page: 1,
    pageSize: 20,
    total: 0,
    totalPages: 1,
    hasPrev: false,
    hasNext: false,
  );
  List<int> _availableYears = const [];
  String? _message;
  ReportSeverity? _severityFilter;
  String _query = '';
  int? _year;
  Timer? _debounce;
  int _generation = 0;
  bool _loadingMore = false;
  bool _resultsStale = false;
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      if (_scrollController.position.extentAfter < 400 &&
          _pagination.hasNext &&
          !_loadingMore &&
          _message == null) {
        _load(append: true);
      }
    });
    _load();
  }

  Future<void> _load({bool append = false}) async {
    if (append && _loadingMore) return;
    if (append) _loadingMore = true;
    final generation = ++_generation;
    if (!append) setState(() => _status = _ListStatus.loading);
    try {
      final result = await widget.repository.getDiagnostics(
        filter: DiagnosticFilter(
          query: _query,
          severity: _severityFilter,
          year: _year,
          page: append ? _pagination.page + 1 : 1,
        ),
      );
      if (!mounted) {
        _loadingMore = false;
        return;
      }
      if (generation != _generation) {
        _loadingMore = false;
        return;
      }
      setState(() {
        _message = null;
        _resultsStale = false;
        _reports = append ? [..._reports, ...result.reports] : result.reports;
        _pagination = result.pagination;
        _availableYears = result.availableYears;
        _status = _reports.isEmpty ? _ListStatus.empty : _ListStatus.data;
      });
      _loadingMore = false;
    } on AppFailure catch (failure) {
      _loadingMore = false;
      if (!mounted) return;
      if (generation != _generation) return;
      if (append) {
        setState(() => _message = failure.message);
        return;
      }
      setState(() {
        _message = failure.message;
        _status = _ListStatus.error;
      });
    } catch (_) {
      _loadingMore = false;
      if (!mounted) return;
      if (generation != _generation) return;
      if (append) {
        setState(() => _message = 'Тодорхойгүй алдаа гарлаа.');
        return;
      }
      setState(() {
        _message = 'Тодорхойгүй алдаа гарлаа.';
        _status = _ListStatus.error;
      });
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _queryChanged(String value) {
    setState(() {
      _query = value.trim();
      _resultsStale = true;
    });
    _generation++;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), _load);
  }

  void _severityChanged(ReportSeverity? severity) {
    setState(() {
      _severityFilter = severity;
    });
    _generation++;
    _load();
  }

  void _yearChanged(int? year) {
    setState(() => _year = year);
    _generation++;
    _load();
  }

  Widget _filters() => Padding(
    padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
    child: Column(
      children: [
        TextField(
          key: const ValueKey('diagnostics-search'),
          onChanged: _queryChanged,
          decoration: const InputDecoration(hintText: 'Тайлан, машин, салбараар хайх'),
        ),
        const SizedBox(height: 10),
        _SeverityFilterRow(selected: _severityFilter, onChanged: _severityChanged),
        if (_availableYears.isNotEmpty)
          Wrap(
            spacing: 8,
            children: [
              FilterChip(label: const Text('Бүгд'), selected: _year == null, onSelected: (_) => _yearChanged(null)),
              for (final year in _availableYears)
                FilterChip(label: Text('$year'), selected: _year == year, onSelected: (_) => _yearChanged(year)),
            ],
          ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      leading: BackButton(onPressed: widget.onBack),
      title: const Text('Оношилгооны түүх'),
    ),
    body: AppShellBackground(child: SafeArea(top: false, child: _body())),
  );

  Widget _body() => switch (_status) {
    _ListStatus.loading => Semantics(
      container: true,
      liveRegion: true,
      label: 'Оношилгооны түүхийг ачаалж байна',
      child: const SkeletonCardList(showTrailing: true),
    ),
    _ListStatus.error => Center(
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
            OutlinedButton(onPressed: _load, child: const Text('Дахин оролдох')),
          ],
        ),
      ),
    ),
    _ListStatus.empty => Column(
      children: [
        _filters(),
        Expanded(child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.fact_check_outlined,
              size: 58,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 18),
            Text(
              'Оношилгооны тайлан алга',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              'Үйлчилгээ хийгдэж, тайлан бөглөгдсөний дараа энд харагдана.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
            ),
          ),
        )),
      ],
    ),
    _ListStatus.data => Column(
      children: [
        _filters(),
        Expanded(
          child: _resultsStale
              ? const Center(child: CircularProgressIndicator())
              : _reports.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      'Сонгосон төлөвтэй тайлан алга.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                    itemCount: _reports.length + (_pagination.hasNext ? 1 : 0),
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      if (index >= _reports.length) {
                        return Padding(
                          padding: const EdgeInsets.all(20),
                          child: Center(
                            child: _message == null
                                ? const CircularProgressIndicator()
                                : OutlinedButton(
                                    onPressed: () => _load(append: true),
                                    child: const Text('Дахин ачаалах'),
                                  ),
                          ),
                        );
                      }
                      final report = _reports[index];
                      return _ReportCard(
                        report: report,
                        onTap: () => widget.onReportSelected(report.id),
                      );
                    },
                  ),
                ),
        ),
      ],
    ),
  };
}

/// Нэг гэрлэн, 4 хэсэгт хуваагдсан сегментийн товч ("segmented control") —
/// нэг хэсэгт дарахад тэр даруй тод харагдаж, шүүлтийг сольж байна гэдгийг
/// ил харуулна.
class _SeverityFilterRow extends StatelessWidget {
  const _SeverityFilterRow({required this.selected, required this.onChanged});

  final ReportSeverity? selected;
  final ValueChanged<ReportSeverity?> onChanged;

  @override
  Widget build(BuildContext context) => SegmentedButton<ReportSeverity?>(
    key: const ValueKey('diagnostics-severity-filter'),
    showSelectedIcon: false,
    style: const ButtonStyle(visualDensity: VisualDensity.compact),
    segments: [
      const ButtonSegment(value: null, label: Text('Бүгд')),
      for (final severity in ReportSeverity.values)
        ButtonSegment(
          value: severity,
          label: Text(
            // "Солих шаардлагатай" энд хэт урт тул богиносгов — картан дээрх
            // чипэнд бүтэн үг хэвээрээ ("severity.localizedLabel").
            severity == ReportSeverity.bad ? 'Солих' : severity.localizedLabel,
          ),
        ),
    ],
    selected: {selected},
    onSelectionChanged: (values) => onChanged(values.first),
  );
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
      borderRadius: BorderRadius.circular(20),
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
