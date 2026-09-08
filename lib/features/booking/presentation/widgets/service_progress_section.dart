import 'package:carcare_customer_mobile/app/theme/app_surfaces.dart';
import 'package:carcare_customer_mobile/app/theme/app_theme.dart';
import 'package:carcare_customer_mobile/features/booking/domain/service_progress.dart';
import 'package:carcare_customer_mobile/features/history/domain/service_order_item.dart'
    show ServiceOrderItemKindUi;
import 'package:carcare_customer_mobile/features/history/presentation/format_amount.dart';
import 'package:flutter/material.dart';

/// Customer-facing read-only view of the repair progress created from an
/// appointment. Payment status stays in its own section on the detail page.
class ServiceProgressSection extends StatelessWidget {
  const ServiceProgressSection({required this.progress, super.key});

  final AppointmentServiceProgress progress;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final hasItems = progress.items.isNotEmpty;
    final completed = progress.completedItemCount;

    return GlassSurface(
      key: const ValueKey('appointment-progress'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  'Үйлчилгээний явц',
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              _ProgressStatusChip(status: progress.status),
            ],
          ),
          if (progress.number.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Засварын хуудас №${progress.number}',
              style: textTheme.bodySmall?.copyWith(color: muted),
            ),
          ],
          if (progress.vehiclePlate != null) ...[
            const SizedBox(height: 2),
            Text(
              [
                progress.vehiclePlate,
                if (progress.vehicleMake != null || progress.vehicleModel != null)
                  [
                    progress.vehicleMake,
                    progress.vehicleModel,
                  ].whereType<String>().join(' '),
                if (progress.vehicleYear != null) '${progress.vehicleYear}',
              ].whereType<String>().where((s) => s.isNotEmpty).join(' · '),
              style: textTheme.bodySmall?.copyWith(color: muted),
            ),
          ],
          if (progress.estimatedDurationMinutes != null ||
              progress.expectedFinishAt != null) ...[
            const SizedBox(height: 10),
            _TimingInfo(progress: progress),
          ],
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: progress.completionRatio.clamp(0.0, 1.0).toDouble(),
              minHeight: 7,
              backgroundColor: muted.withValues(alpha: 0.16),
              valueColor: const AlwaysStoppedAnimation(AppColors.green),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            hasItems
                ? '$completed/${progress.items.length} үйлчилгээ дууссан'
                : progress.status.localizedLabel,
            style: textTheme.bodySmall?.copyWith(color: muted),
          ),
          if (hasItems) ...[
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 6),
            for (final item in progress.items)
              _ProgressItemRow(
                key: ValueKey('appointment-progress-${item.id}'),
                item: item,
              ),
          ],
          if (progress.totalAmount != null) ...[
            const SizedBox(height: 10),
            _TotalsBlock(progress: progress),
          ],
        ],
      ),
    );
  }
}

class _TotalsBlock extends StatelessWidget {
  const _TotalsBlock({required this.progress});

  final AppointmentServiceProgress progress;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: muted.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Нийт дүн', style: textTheme.bodySmall?.copyWith(color: muted)),
                Text(
                  '${formatAmount(progress.totalAmount!.round())}₮',
                  style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800),
                ),
              ],
            ),
            if (progress.paidAmount != null) ...[
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Төлсөн', style: textTheme.bodySmall?.copyWith(color: muted)),
                  Text(
                    '${formatAmount(progress.paidAmount!.round())}₮',
                    style: textTheme.bodySmall,
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ProgressItemRow extends StatelessWidget {
  const _ProgressItemRow({required this.item, super.key});

  final AppointmentServiceItemProgress item;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final (icon, color) = switch (item.status) {
      ServiceProgressStatus.completed =>
        (Icons.check_circle_rounded, AppColors.green),
      ServiceProgressStatus.inProgress =>
        (Icons.play_circle_fill_rounded, AppColors.amber),
      ServiceProgressStatus.cancelled => (Icons.cancel_rounded, AppColors.red),
      _ => (Icons.radio_button_unchecked_rounded, muted),
    };

    final textTheme = Theme.of(context).textTheme;
    final hasPrice = item.total != null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (hasPrice)
                  Text(
                    '${item.kind.localizedLabel} · ${item.quantity ?? 1} × '
                    '${formatAmount((item.unitPrice ?? 0).round())}₮',
                    style: textTheme.bodySmall?.copyWith(color: muted),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                item.status.localizedLabel,
                style: textTheme.bodySmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (hasPrice)
                Text(
                  '${formatAmount(item.total!.round())}₮',
                  style: textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Хугацааны тооцоолол — item-completion хувиас тусад нь харуулна (эх
/// tооцоолол болон одоогийн таамаг өөр өөр зүйл учир андуурч болохгүй).
class _TimingInfo extends StatelessWidget {
  const _TimingInfo({required this.progress});

  final AppointmentServiceProgress progress;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final delayed = progress.isDelayed;
    final color = delayed ? AppColors.red : muted;

    final parts = <String>[];
    if (progress.estimatedDurationMinutes != null) {
      parts.add('Ойролцоо хугацаа: ${_formatEstimatedMinutes(progress.estimatedDurationMinutes!)}');
    }
    if (progress.expectedFinishAt != null) {
      parts.add(
        delayed
            ? 'Дуусах ёстой байсан: ${_formatDateTime(progress.expectedFinishAt!)}'
            : 'Дуусах хугацаа: ${_formatDateTime(progress.expectedFinishAt!)}',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final part in parts)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              part,
              style: textTheme.bodySmall?.copyWith(
                color: color,
                fontWeight: delayed ? FontWeight.w700 : null,
              ),
            ),
          ),
        if (delayed)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              'Төлөвлөснөөс хожимдож байна',
              style: textTheme.bodySmall?.copyWith(
                color: AppColors.red,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
      ],
    );
  }
}

String _formatEstimatedMinutes(int totalMinutes) {
  final hours = totalMinutes ~/ 60;
  final minutes = totalMinutes % 60;
  if (hours > 0 && minutes > 0) return '$hours ц $minutes мин';
  if (hours > 0) return '$hours ц';
  return '$minutes мин';
}

String _formatDateTime(DateTime value) =>
    '${value.year}.${value.month.toString().padLeft(2, '0')}.${value.day.toString().padLeft(2, '0')} '
    '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';

class _ProgressStatusChip extends StatelessWidget {
  const _ProgressStatusChip({required this.status});

  final ServiceProgressStatus status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      ServiceProgressStatus.completed => AppColors.green,
      ServiceProgressStatus.cancelled => AppColors.red,
      ServiceProgressStatus.inProgress || ServiceProgressStatus.waitingParts =>
        AppColors.amber,
      _ => Theme.of(context).colorScheme.onSurfaceVariant,
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        child: Text(
          status.localizedLabel,
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}
