import 'package:carcare_customer_mobile/app/theme/app_theme.dart';
import 'package:carcare_customer_mobile/features/booking/domain/availability.dart';
import 'package:flutter/material.dart';

/// A slot chip grid driven by the branch availability endpoint (booking v2):
/// slots are sized to the selected categories' summed duration, and slots that
/// are full or in the past render disabled.
class TimeSlotGrid extends StatelessWidget {
  const TimeSlotGrid({
    required this.slots,
    required this.selected,
    required this.onSelected,
    super.key,
  });

  final List<AvailabilitySlot> slots;
  final ({int hour, int minute})? selected;
  final ValueChanged<({int hour, int minute})> onSelected;

  @override
  Widget build(BuildContext context) {
    if (slots.isEmpty) {
      return Text(
        'Энэ өдөр сул цаг алга.',
        style: Theme.of(context).textTheme.bodySmall
            ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
      );
    }
    final scheme = Theme.of(context).colorScheme;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final slot in slots)
          _SlotChip(
            key: ValueKey('booking-slot-${slot.hour}-${slot.minute}'),
            label: _formatSlot(slot),
            selected: selected == slot.time,
            enabled: slot.available,
            scheme: scheme,
            onTap: slot.available ? () => onSelected(slot.time) : null,
          ),
      ],
    );
  }
}

class _SlotChip extends StatelessWidget {
  const _SlotChip({
    required this.label,
    required this.selected,
    required this.enabled,
    required this.scheme,
    required this.onTap,
    super.key,
  });

  final String label;
  final bool selected;
  final bool enabled;
  final ColorScheme scheme;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final Color background;
    final Color foreground;
    if (selected) {
      background = AppColors.accent;
      foreground = AppColors.onAccent;
    } else if (!enabled) {
      background = scheme.surface;
      foreground = scheme.onSurfaceVariant.withValues(alpha: 0.5);
    } else {
      background = scheme.surface;
      foreground = scheme.onSurface;
    }
    return Material(
      color: background,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? Colors.transparent : scheme.outlineVariant,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: foreground,
              decoration: enabled ? null : TextDecoration.lineThrough,
            ),
          ),
        ),
      ),
    );
  }
}

String _formatSlot(AvailabilitySlot slot) =>
    '${slot.hour.toString().padLeft(2, '0')}:${slot.minute.toString().padLeft(2, '0')}';
