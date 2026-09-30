import 'package:carcare_customer_mobile/app/theme/app_surfaces.dart';
import 'package:carcare_customer_mobile/features/booking/presentation/controllers/booking_form_controller.dart';
import 'package:carcare_customer_mobile/features/booking/presentation/widgets/booking_locked_notices.dart';
import 'package:carcare_customer_mobile/features/booking/presentation/widgets/time_slot_grid.dart';
import 'package:flutter/material.dart';

/// Категорийн хэсэг: `lockCategories` үед зөвхөн товч тойм, эс бөгөөс
/// сонгох chip-үүд. Хоёуланд нь харуулах зүйл байхгүй бол хоосон.
class BookingCategorySection extends StatelessWidget {
  const BookingCategorySection({required this.form, super.key});

  final BookingFormController form;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final allCategories = form.allCategories;
    final selectedIds = form.selectedCategoryIds;
    if (form.lockCategories) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (form.lockedUnavailableCategoryNames.isNotEmpty) ...[
            const SizedBox(height: 16),
            LockedCategoriesWarning(
              unavailableNames: form.lockedUnavailableCategoryNames,
            ),
          ],
          if (selectedIds.isNotEmpty) ...[
            const SizedBox(height: 16),
            GlassSurface(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Үйлчилгээ',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final category in allCategories)
                        if (selectedIds.contains(category.id))
                          Chip(label: Text(category.name)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Нийт ойролцоогоор ${form.selectedDurationMinutes} мин',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      );
    }
    if (allCategories.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: GlassSurface(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Үйлчилгээ сонгох',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            if (selectedIds.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                'Нийт ойролцоогоор ${form.selectedDurationMinutes} мин',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final category in allCategories)
                  FilterChip(
                    label: Text(category.name),
                    // Checkmark-гүй — эс бөгөөс сонгоход chip өргөсөж
                    // Wrap-ийн бусад chip-үүд шилжинэ (jank).
                    showCheckmark: false,
                    selected: selectedIds.contains(category.id),
                    onSelected: (selected) =>
                        form.toggleCategory(category.id, selected),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Салбар сонгох хэсэг. Дэвийн шийдвэрээр: ангилал сонгогдоогүй бол НУУНА
/// (харин байгууллагад ангилал огт байхгүй бол харуулна). `lockCategories` /
/// `lockBranch` үед салбар аль хэдийн тодорхой тул огт харуулахгүй.
class BookingBranchSection extends StatelessWidget {
  const BookingBranchSection({required this.form, super.key});

  final BookingFormController form;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final visible =
        !form.lockCategories &&
        !form.lockBranch &&
        form.organization.branches.length > 1 &&
        (form.allCategories.isEmpty || form.selectedCategoryIds.isNotEmpty);
    if (!visible) return const SizedBox.shrink();
    final compatible = form.compatibleBranches;
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: GlassSurface(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Салбар сонгох',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            if (compatible.isEmpty)
              Text(
                'Сонгосон бүх үйлчилгээг нэгэн зэрэг санал болгодог '
                'салбар алга байна. Үйлчилгээнийхээ сонголтоо өөрчилнө үү.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              )
            else
              // Ганц салбар үлдсэн ч dropdown-г харуулсаар байна — эс бөгөөс
              // автоматаар сонгогдоод юу ч харагдахгүй болно.
              DropdownButtonFormField<String>(
                // Категори сольсноор selectedBranch энэ виджетээс ГАДУУР
                // өөрчлөгдөж болох тул value-г `key`-д оруулж, шинэ утгаараа
                // эхлүүлнэ (`initialValue` дотоод төлөв).
                key: ValueKey(
                  'booking-branch-dropdown-${form.selectedBranch?.id}',
                ),
                initialValue: form.selectedBranch?.id,
                decoration: const InputDecoration(labelText: 'Салбар'),
                hint: const Text('Салбараа сонгоно уу'),
                items: [
                  for (final branch in compatible)
                    DropdownMenuItem(
                      value: branch.id,
                      child: Text(branch.name),
                    ),
                ],
                onChanged: (id) {
                  if (id == null) return;
                  form.selectBranch(compatible.firstWhere((b) => b.id == id));
                },
              ),
          ],
        ),
      ),
    );
  }
}

/// "Цаг сонгох" хэсэг: ачаалж байна / алдаа / хаалттай өдөр / цагийн тор.
class BookingSlotSection extends StatelessWidget {
  const BookingSlotSection({required this.form, super.key});

  final BookingFormController form;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final availability = form.availability;
    final slotsError = form.slotsError;
    return GlassSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Цаг сонгох',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            availability != null
                ? 'Нэг захиалга ≈ ${availability.durationMinutes} мин'
                : (form.selectedBranch?.hoursLabel ?? ''),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          if (form.loadingSlots)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else if (slotsError != null)
            Text(
              slotsError,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            )
          else if (availability != null && !availability.open)
            Text(
              availability.reason ?? 'Энэ өдөр хаалттай.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            )
          else
            TimeSlotGrid(
              slots: availability?.slots ?? const [],
              selected: form.selectedSlot,
              onSelected: form.selectSlot,
            ),
        ],
      ),
    );
  }
}
