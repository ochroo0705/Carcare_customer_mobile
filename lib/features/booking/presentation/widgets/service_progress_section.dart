import 'package:carcare_customer_mobile/app/theme/app_surfaces.dart';
import 'package:carcare_customer_mobile/app/theme/app_theme.dart';
import 'package:carcare_customer_mobile/features/booking/domain/service_progress.dart';
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
        ],
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

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              item.name,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            item.status.localizedLabel,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

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
