import 'package:carcare_customer_mobile/app/theme/app_theme.dart';
import 'package:flutter/material.dart';

/// A slot chip grid for the branch's working-hours slots on a chosen date,
/// mirroring the web booking flow's time-slot picker — minus real
/// availability data (see `BranchDetail.slotsForDay`'s doc comment): every
/// slot shown here is selectable, since the app has no way to know which
/// ones are already booked ahead of submitting.
class TimeSlotGrid extends StatelessWidget {
  const TimeSlotGrid({
    required this.slots,
    required this.selected,
    required this.onSelected,
    super.key,
  });

  final List<({int hour, int minute})> slots;
  final ({int hour, int minute})? selected;
  final ValueChanged<({int hour, int minute})> onSelected;

  @override
  Widget build(BuildContext context) {
    if (slots.isEmpty) {
      return Text(
        'Энэ салбарын ажиллах цагийн мэдээлэл алга.',
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
            selected: selected == slot,
            scheme: scheme,
            onTap: () => onSelected(slot),
          ),
      ],
    );
  }
}

class _SlotChip extends StatelessWidget {
  const _SlotChip({
    required this.label,
    required this.selected,
    required this.scheme,
    required this.onTap,
    super.key,
  });

  final String label;
  final bool selected;
  final ColorScheme scheme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: selected ? AppColors.amber : scheme.surface,
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
            color: selected ? AppColors.onAmber : scheme.onSurface,
          ),
        ),
      ),
    ),
  );
}

String _formatSlot(({int hour, int minute}) slot) =>
    '${slot.hour.toString().padLeft(2, '0')}:${slot.minute.toString().padLeft(2, '0')}';
