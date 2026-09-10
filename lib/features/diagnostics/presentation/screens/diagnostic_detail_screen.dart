import 'package:carcare_customer_mobile/app/theme/app_surfaces.dart';
import 'package:carcare_customer_mobile/core/errors/app_failure.dart';
import 'package:carcare_customer_mobile/core/widgets/skeletons.dart';
import 'package:carcare_customer_mobile/features/diagnostics/domain/diagnostic_report_detail.dart';
import 'package:carcare_customer_mobile/features/diagnostics/domain/diagnostics_repository.dart';
import 'package:carcare_customer_mobile/features/diagnostics/presentation/diagnostic_pdf_export.dart';
import 'package:carcare_customer_mobile/features/diagnostics/presentation/widgets/report_answers_view.dart';
import 'package:carcare_customer_mobile/features/diagnostics/presentation/widgets/severity_chip.dart';
import 'package:flutter/material.dart';

enum _DetailStatus { loading, data, error }

/// Нэг оношилгооны тайлангийн БҮРЭН (schema-driven) харагдац — жагсаалтаас,
/// эсвэл захиалгын дэлгэрэнгүй дэх товч мөрөнд дарснаас нээгдэнэ. Зөвхөн
/// уншихад зориулсан — worker web-ийн дэлгэрэнгүй хуудастай ижил мэдээлэл.
class DiagnosticDetailScreen extends StatefulWidget {
  const DiagnosticDetailScreen({
    required this.repository,
    required this.reportId,
    required this.onBack,
    super.key,
  });

  final DiagnosticsRepository repository;
  final String reportId;
  final VoidCallback onBack;

  @override
  State<DiagnosticDetailScreen> createState() => _DiagnosticDetailScreenState();
}

class _DiagnosticDetailScreenState extends State<DiagnosticDetailScreen> {
  _DetailStatus _status = _DetailStatus.loading;
  DiagnosticReportDetail? _detail;
  String? _message;
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _status = _DetailStatus.loading);
    try {
      final detail = await widget.repository.getDiagnosticDetail(widget.reportId);
      if (!mounted) return;
      setState(() {
        _detail = detail;
        _status = _DetailStatus.data;
      });
    } on AppFailure catch (failure) {
      if (!mounted) return;
      setState(() {
        _message = failure.message;
        _status = _DetailStatus.error;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _message = 'Тодорхойгүй алдаа гарлаа.';
        _status = _DetailStatus.error;
      });
    }
  }

  Future<void> _sharePdf() async {
    final detail = _detail;
    if (detail == null || _isExporting) return;
    setState(() => _isExporting = true);
    try {
      await shareDiagnosticPdf(detail);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PDF бэлтгэхэд алдаа гарлаа. Дахин оролдоно уу.')),
      );
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      leading: BackButton(onPressed: widget.onBack),
      title: const Text('Оношилгооны тайлан'),
    ),
    body: AppShellBackground(child: SafeArea(top: false, child: _body())),
  );

  Widget _body() => switch (_status) {
    _DetailStatus.loading => const SkeletonDetail(),
    _DetailStatus.error => Center(
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
    _DetailStatus.data => _DetailBody(
      detail: _detail!,
      onExport: _sharePdf,
      isExporting: _isExporting,
    ),
  };
}

class _DetailBody extends StatelessWidget {
  const _DetailBody({
    required this.detail,
    required this.onExport,
    required this.isExporting,
  });

  final DiagnosticReportDetail detail;
  final VoidCallback onExport;
  final bool isExporting;

  @override
  Widget build(BuildContext context) {
    final date =
        '${detail.createdAt.year}.${detail.createdAt.month.toString().padLeft(2, '0')}.${detail.createdAt.day.toString().padLeft(2, '0')}';
    final subtitle = detail.mileageAtReport != null
        ? '$date · ${detail.branchName} · ${detail.mileageAtReport} км'
        : '$date · ${detail.branchName}';
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        GlassSurface(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      detail.templateName,
                      style: Theme.of(context).textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.w900),
                    ),
                  ),
                  if (detail.severity != null) ...[
                    const SizedBox(width: 8),
                    SeverityChip(severity: detail.severity!),
                  ],
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${detail.vehicleMake} ${detail.vehicleModel} · ${detail.vehiclePlate}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
              if (detail.notes != null && detail.notes!.trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(detail.notes!, style: Theme.of(context).textTheme.bodySmall),
              ],
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: isExporting ? null : onExport,
                  icon: isExporting
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.picture_as_pdf_outlined),
                  label: Text(isExporting ? 'Бэлтгэж байна...' : 'PDF татах'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        ReportAnswersView(schema: detail.schema, data: detail.data),
      ],
    );
  }
}
