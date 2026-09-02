import 'package:carcare_customer_mobile/app/theme/app_theme.dart';
import 'package:flutter/material.dart';

const _weekdayLabels = ['Да', 'Мя', 'Лх', 'Пү', 'Ба', 'Бя', 'Ня'];

/// Monday-first month grid for picking a booking date, mirroring the web
/// booking flow's `BookingCalendar`. Only past dates are disabled — the
/// customer API publishes no per-weekday schedule (`CUSTOMER_API_CONTRACT.md`
/// / COWORK.md D-007), so a branch's closed days can't be greyed out here;
/// an unbookable day surfaces as a submit-time error instead.
class BookingCalendar extends StatelessWidget {
  const BookingCalendar({
    required this.month,
    required this.selectedDate,
    required this.onDateSelected,
    required this.onMonthChanged,
    super.key,
  });

  /// Any date within the displayed month.
  final DateTime month;
  final DateTime? selectedDate;
  final ValueChanged<DateTime> onDateSelected;
  final ValueChanged<DateTime> onMonthChanged;

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final todayKey = DateTime(today.year, today.month, today.day);
    final currentMonthKey = DateTime(month.year, month.month);
    final canGoBack = currentMonthKey.isAfter(
      DateTime(today.year, today.month),
    );
    final firstWeekday = DateTime(month.year, month.month).weekday;
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final leadingBlanks = firstWeekday - 1;
    final totalCells = ((leadingBlanks + daysInMonth) / 7).ceil() * 7;
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            IconButton(
              key: const ValueKey('booking-calendar-prev'),
              onPressed: canGoBack
                  ? () => onMonthChanged(
                      DateTime(currentMonthKey.year, currentMonthKey.month - 1),
                    )
                  : null,
              icon: const Icon(Icons.chevron_left_rounded),
            ),
            Expanded(
              child: Text(
                '${month.year}.${month.month.toString().padLeft(2, '0')}',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            IconButton(
              key: const ValueKey('booking-calendar-next'),
              onPressed: () => onMonthChanged(
                DateTime(currentMonthKey.year, currentMonthKey.month + 1),
              ),
              icon: const Icon(Icons.chevron_right_rounded),
            ),
          ],
        ),
        GridView.count(
          crossAxisCount: 7,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            for (final label in _weekdayLabels)
              Center(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.labelSmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ),
          ],
        ),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
          ),
          itemCount: totalCells,
          itemBuilder: (context, index) {
            final dayNumber = index - leadingBlanks + 1;
            if (dayNumber < 1 || dayNumber > daysInMonth) {
              return const SizedBox.shrink();
            }
            final date = DateTime(month.year, month.month, dayNumber);
            final isPast = date.isBefore(todayKey);
            final isToday = date == todayKey;
            final isSelected =
                selectedDate != null &&
                DateTime(
                      selectedDate!.year,
                      selectedDate!.month,
                      selectedDate!.day,
                    ) ==
                    date;
            return Padding(
              padding: const EdgeInsets.all(2),
              child: Material(
                color: isSelected ? AppColors.amber : Colors.transparent,
                shape: CircleBorder(
                  side: isToday && !isSelected
                      ? BorderSide(color: AppColors.amber)
                      : BorderSide.none,
                ),
                child: InkWell(
                  key: ValueKey(
                    'booking-date-${date.year}-${date.month}-${date.day}',
                  ),
                  onTap: isPast ? null : () => onDateSelected(date),
                  customBorder: const CircleBorder(),
                  child: Center(
                    child: Text(
                      '$dayNumber',
                      style: TextStyle(
                        fontWeight: isSelected
                            ? FontWeight.w800
                            : FontWeight.w500,
                        color: isSelected
                            ? AppColors.onAmber
                            : isPast
                            ? scheme.onSurfaceVariant.withValues(alpha: 0.35)
                            : scheme.onSurface,
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
