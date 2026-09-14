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
  String? _message;
  ReportSeverity? _severityFilter;

  List<DiagnosticReportListItem> get _filteredReports {
    final filter = _severityFilter;
    if (filter == null) return _reports;
    return _reports
        .where((report) => report.severity == filter)
        .toList(growable: false);
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _status = _ListStatus.loading);
    try {
      final reports = await widget.repository.getDiagnostics();
      if (!mounted) return;
      setState(() {
        _reports = reports;
        _status = reports.isEmpty ? _ListStatus.empty : _ListStatus.data;
      });
    } on AppFailure catch (failure) {
      if (!mounted) return;
      setState(() {
        _message = failure.message;
        _status = _ListStatus.error;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _message = 'Тодорхойгүй алдаа гарлаа.';
        _status = _ListStatus.error;
      });
    }
  }

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
    _ListStatus.empty => Center(
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
    ),
    _ListStatus.data => Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
          child: _SeverityFilterRow(
            selected: _severityFilter,
            onChanged: (severity) =>
                setState(() => _severityFilter = severity),
          ),
        ),
        Expanded(
          child: _filteredReports.isEmpty
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
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                    itemCount: _filteredReports.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final report = _filteredReports[index];
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
