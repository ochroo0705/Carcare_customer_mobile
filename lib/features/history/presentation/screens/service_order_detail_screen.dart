import 'package:carcare_customer_mobile/app/theme/app_surfaces.dart';
import 'package:carcare_customer_mobile/core/errors/app_failure.dart';
import 'package:carcare_customer_mobile/features/history/domain/diagnostic_report_summary.dart';
import 'package:carcare_customer_mobile/features/history/domain/service_history_repository.dart';
import 'package:carcare_customer_mobile/features/history/domain/service_order_detail.dart';
import 'package:carcare_customer_mobile/features/history/domain/service_order_item.dart';
import 'package:carcare_customer_mobile/features/history/presentation/format_amount.dart';
import 'package:flutter/material.dart';

enum _DetailStatus { loading, data, error }

class ServiceOrderDetailScreen extends StatefulWidget {
  const ServiceOrderDetailScreen({
    required this.repository,
    required this.orderId,
    required this.onBack,
    super.key,
  });

  final ServiceHistoryRepository repository;
  final String orderId;
  final VoidCallback onBack;

  @override
  State<ServiceOrderDetailScreen> createState() =>
      _ServiceOrderDetailScreenState();
}

class _ServiceOrderDetailScreenState extends State<ServiceOrderDetailScreen> {
  _DetailStatus _status = _DetailStatus.loading;
  ServiceOrderDetail? _detail;
  String? _message;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _status = _DetailStatus.loading);
    try {
      final detail = await widget.repository.getServiceOrderDetail(
        widget.orderId,
      );
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

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      leading: BackButton(onPressed: widget.onBack),
      title: const Text('Захиалгын дэлгэрэнгүй'),
    ),
    body: AppShellBackground(child: SafeArea(top: false, child: _body())),
  );

  Widget _body() => switch (_status) {
    _DetailStatus.loading => const Center(child: CircularProgressIndicator()),
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
            OutlinedButton(
              onPressed: _load,
              child: const Text('Дахин оролдох'),
            ),
          ],
        ),
      ),
    ),
    _DetailStatus.data => _DetailBody(detail: _detail!),
  };
}

class _DetailBody extends StatelessWidget {
  const _DetailBody({required this.detail});

  final ServiceOrderDetail detail;

  @override
  Widget build(BuildContext context) {
    final order = detail.order;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        GlassSurface(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                order.tenantName,
                style: Theme.of(context).textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w900),
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
                '${order.completedAt.year}.${order.completedAt.month.toString().padLeft(2, '0')}.${order.completedAt.day.toString().padLeft(2, '0')}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (order.vehiclePlate != null) ...[
                const SizedBox(height: 4),
                Text(
                  'Тээврийн хэрэгсэл: ${order.vehiclePlate}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              if (detail.note != null && detail.note!.trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  detail.note!,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Дэлгэрэнгүй',
          style: Theme.of(context).textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        GlassSurface(
          child: Column(
            children: [
              for (final item in detail.items) _ItemRow(item: item),
              if (detail.items.isNotEmpty) const Divider(height: 24),
              _TotalsRow(label: 'Нийт дүн', value: order.totalAmount),
              const SizedBox(height: 4),
              _TotalsRow(label: 'Төлсөн', value: order.paidAmount),
            ],
          ),
        ),
        if (detail.reports.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            'Оношилгооны тайлан',
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          GlassSurface(
            child: Column(
              children: [
                for (final report in detail.reports)
                  _ReportRow(report: report),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _ReportRow extends StatelessWidget {
  const _ReportRow({required this.report});

  final DiagnosticReportSummary report;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final date =
        '${report.createdAt.year}.${report.createdAt.month.toString().padLeft(2, '0')}.${report.createdAt.day.toString().padLeft(2, '0')}';
    final subtitle = report.mileageAtReport != null
        ? '$date · ${report.mileageAtReport} км'
        : date;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(Icons.assignment_outlined, size: 18, color: scheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  report.templateName,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({required this.item});

  final ServiceOrderItem item;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.name,
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              Text(
                '${item.kind.localizedLabel} · ${item.quantity} ширхэг',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        Text('${formatAmount(item.totalPrice)}₮'),
      ],
    ),
  );
}

class _TotalsRow extends StatelessWidget {
  const _TotalsRow({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(label, style: Theme.of(context).textTheme.bodyMedium),
      Text(
        '${formatAmount(value)}₮',
        style: Theme.of(context).textTheme.bodyMedium
            ?.copyWith(fontWeight: FontWeight.w800),
      ),
    ],
  );
}
