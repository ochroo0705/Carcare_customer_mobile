import 'package:carcare_customer_mobile/app/theme/app_surfaces.dart';
import 'package:carcare_customer_mobile/features/diagnostics/domain/template_schema.dart';
import 'package:carcare_customer_mobile/features/diagnostics/presentation/widgets/severity_chip.dart';
import 'package:flutter/material.dart';

/// Тайлангийн хариултуудыг хэсэг хэсгээр нь харуулна — worker web-ийн
/// `ReportAnswers`-тэй ижил бүтэц (харах: `carcare.mn`
/// `app/dashboard/diagnostics/reports/[id]/report-answers.tsx`), зөвхөн
/// уншихад зориулсан тул хариултаар шүүх chip-үүд алгасав.
class ReportAnswersView extends StatelessWidget {
  const ReportAnswersView({required this.schema, required this.data, super.key});

  final TemplateSchema schema;
  final ReportData data;

  @override
  Widget build(BuildContext context) {
    final sections = schema.sections
        .where((s) => s.items.isNotEmpty)
        .toList(growable: false);
    if (sections.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final section in sections) ...[
          Text(
            section.title,
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          GlassSurface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final item in section.items) ...[
                  _ItemView(item: item, data: data),
                  if (item != section.items.last) const Divider(height: 20),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
      ],
    );
  }
}

class _ItemView extends StatelessWidget {
  const _ItemView({required this.item, required this.data});

  final TemplateItem item;
  final ReportData data;

  @override
  Widget build(BuildContext context) {
    final positions = item.positions;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          item.label,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 6),
        if (positions != null)
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              for (final pos in positions)
                _EntryView(
                  label: pos.label,
                  entry: data.entryFor(positionedKey(item.id, pos.code)),
                  itemType: item.type,
                ),
            ],
          )
        else
          _EntryView(entry: data.entryFor(item.id), itemType: item.type),
      ],
    );
  }
}

class _EntryView extends StatelessWidget {
  const _EntryView({required this.entry, required this.itemType, this.label});

  final ReportEntry entry;
  final String itemType;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final value = entry.value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null) ...[
          Text(
            label!,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 2),
        ],
        _renderValue(context, value),
        if (entry.photos.isNotEmpty) ...[
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final photo in entry.photos)
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(
                    photo,
                    width: 84,
                    height: 84,
                    fit: BoxFit.cover,
                  ),
                ),
            ],
          ),
        ],
        if (itemType == 'signature' && value is String && value.isNotEmpty) ...[
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.network(value, width: 180, height: 90, fit: BoxFit.contain),
          ),
        ],
        if (entry.note != null && entry.note!.trim().isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            'Тэмдэглэл: ${entry.note}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontStyle: FontStyle.italic,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }

  Widget _renderValue(BuildContext context, Object? value) {
    if (value == null || (value is String && value.isEmpty)) {
      return Text(
        '—',
        style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
      );
    }
    if (itemType == 'signature') return const SizedBox.shrink();
    if (value is bool) return Text(value ? 'Тийм' : 'Үгүй');
    if (itemType == 'check' && value is String) {
      return CheckValueChip(value: value);
    }
    return Text(
      value.toString(),
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
    );
  }
}
