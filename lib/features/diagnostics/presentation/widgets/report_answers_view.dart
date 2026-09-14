import 'package:carcare_customer_mobile/app/theme/app_surfaces.dart';
import 'package:carcare_customer_mobile/features/diagnostics/domain/report_severity.dart';
import 'package:carcare_customer_mobile/features/diagnostics/domain/template_schema.dart';
import 'package:carcare_customer_mobile/features/diagnostics/presentation/widgets/severity_chip.dart';
import 'package:flutter/material.dart';

/// Тайлангийн хариултуудыг хэсэг хэсгээр нь харуулна — worker web-ийн
/// `ReportAnswers`-тэй ижил бүтэц (харах: `carcare.mn`
/// `app/dashboard/diagnostics/reports/[id]/report-answers.tsx`).
///
/// `toneFilter` идэвхтэй үед зөвхөн "check" төрлийн зүйл/байрлал шүүгдэнэ —
/// хэмжилт, зураг, гарын үсэг зэрэг тона (өнгө ангилал)-гүй зүйлүүд
/// шүүлтээс үл хамааран үргэлж харагдана. Байршилтай (positions) зүйлд зөвхөн
/// тохирсон байршил үлдэнэ (тохироогүй хажуугийн зураг/тэмдэглэл хамт алга
/// болно). Check зүйлгүй болсон хэсэгт "тохирох зүйл олдсонгүй" гэсэн
/// тэмдэглэл харагдана.
class ReportAnswersView extends StatelessWidget {
  const ReportAnswersView({
    required this.schema,
    required this.data,
    this.toneFilter,
    super.key,
  });

  final TemplateSchema schema;
  final ReportData data;
  final CheckTone? toneFilter;

  bool _matches(ReportEntry entry, String itemType) {
    final filter = toneFilter;
    if (filter == null || itemType != 'check') return true;
    final value = entry.value;
    if (value is! String || value.isEmpty) return true;
    return checkOptionTone(value) == filter;
  }

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
          _SectionCard(section: section, data: data, matches: _matches),
          const SizedBox(height: 16),
        ],
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.section,
    required this.data,
    required this.matches,
  });

  final TemplateSection section;
  final ReportData data;
  final bool Function(ReportEntry entry, String itemType) matches;

  @override
  Widget build(BuildContext context) {
    final hasCheckItems = section.items.any((item) => item.type == 'check');
    final visibleItems = section.items
        .where((item) => _itemHasVisibleContent(item))
        .toList(growable: false);
    final showEmptyNote = hasCheckItems && visibleItems.isEmpty;
    return GlassSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showEmptyNote)
            Text(
              'Тохирох зүйл олдсонгүй.',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            )
          else
            for (final item in visibleItems) ...[
              _ItemView(item: item, data: data, matches: matches),
              if (item != visibleItems.last) const Divider(height: 20),
            ],
        ],
      ),
    );
  }

  bool _itemHasVisibleContent(TemplateItem item) {
    final positions = item.positions;
    if (positions == null) {
      return matches(data.entryFor(item.id), item.type);
    }
    return positions.any(
      (pos) => matches(data.entryFor(positionedKey(item.id, pos.code)), item.type),
    );
  }
}

class _ItemView extends StatelessWidget {
  const _ItemView({required this.item, required this.data, required this.matches});

  final TemplateItem item;
  final ReportData data;
  final bool Function(ReportEntry entry, String itemType) matches;

  @override
  Widget build(BuildContext context) {
    final positions = item.positions;
    final visiblePositions = positions
        ?.where((pos) => matches(data.entryFor(positionedKey(item.id, pos.code)), item.type))
        .toList(growable: false);
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
        if (visiblePositions != null)
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              for (final pos in visiblePositions)
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
