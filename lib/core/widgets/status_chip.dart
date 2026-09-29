import 'package:carcare_customer_mobile/app/theme/app_theme.dart';
import 'package:flutter/material.dart';

/// Shared pill for statuses. [color] is the base status color; the text and
/// icon use a light-mode readable variant via [AppColors.readable].
class StatusChip extends StatelessWidget {
  const StatusChip({
    required this.label,
    required this.color,
    this.icon,
    this.bordered = false,
    super.key,
  });

  final String label;
  final Color color;
  final IconData? icon;
  final bool bordered;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fg = AppColors.readable(color, theme.brightness);
    final text = Text(
      label,
      style: theme.textTheme.labelMedium?.copyWith(
        color: fg,
        fontWeight: FontWeight.w700,
      ),
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppRadii.pill),
        border: bordered
            ? Border.all(color: color.withValues(alpha: 0.35))
            : null,
      ),
      child: icon == null
          ? text
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 14, color: fg),
                const SizedBox(width: 4),
                text,
              ],
            ),
    );
  }
}
