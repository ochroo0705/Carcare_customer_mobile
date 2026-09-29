import 'package:carcare_customer_mobile/features/discovery/domain/branch.dart';
import 'package:flutter/material.dart';

/// The branch filter controls (city/district, business-type tag, and the
/// near-me / open-now / weekend chips), shared by Discovery and the Booking
/// tab's service-key picker. Stateless: each screen owns its own filter
/// values and passes them in, so filters set on one screen never leak into
/// the other.
class BranchFilterPanel extends StatelessWidget {
  const BranchFilterPanel({
    required this.city,
    required this.district,
    required this.cities,
    required this.districts,
    required this.onCityChanged,
    required this.onDistrictChanged,
    required this.tag,
    required this.tagOptions,
    required this.onTagChanged,
    required this.nearMe,
    required this.openNow,
    required this.weekend,
    required this.onNearMeChanged,
    required this.onOpenNowChanged,
    required this.onWeekendChanged,
    this.nearMePending = false,
    this.openNowPending = false,
    this.weekendPending = false,
    this.showChips = true,
    this.leadingChips = const [],
    super.key,
  });

  final String city;
  final String district;
  final List<String> cities;
  final List<String> districts;
  final ValueChanged<String?> onCityChanged;
  final ValueChanged<String?> onDistrictChanged;
  final String tag;
  final List<BranchTagOption> tagOptions;
  final void Function(String id, String name) onTagChanged;
  final bool nearMe;
  final bool openNow;
  final bool weekend;
  final ValueChanged<bool> onNearMeChanged;
  final ValueChanged<bool> onOpenNowChanged;
  final ValueChanged<bool> onWeekendChanged;
  final bool nearMePending;
  final bool openNowPending;
  final bool weekendPending;

  /// Whether to show the chip row. Discovery hides it until a catalog has
  /// loaded; the picker always shows it.
  final bool showChips;

  /// Extra chips placed before the standard ones (Discovery's active
  /// service-key chip).
  final List<Widget> leadingChips;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      if (cities.isNotEmpty || city.isNotEmpty) ...[
        Row(
          children: [
            Expanded(
              child: BranchLocationFilter(
                key: const ValueKey('branch-filter-city'),
                value: city,
                hint: 'Хот / аймаг',
                icon: Icons.location_city_outlined,
                values: cities,
                onChanged: onCityChanged,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: BranchLocationFilter(
                key: const ValueKey('branch-filter-district'),
                value: district,
                hint: 'Дүүрэг / сум',
                icon: Icons.place_outlined,
                values: districts,
                onChanged: onDistrictChanged,
              ),
            ),
          ],
        ),
      ],
      if (tagOptions.isNotEmpty || tag.isNotEmpty) ...[
        const SizedBox(height: 10),
        BranchTagFilter(
          key: const ValueKey('branch-filter-tag'),
          value: tag,
          options: tagOptions,
          onChanged: onTagChanged,
        ),
      ],
      if (showChips) ...[
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          // Wrap, not a horizontal scroll: on narrow screens a chip that
          // doesn't fit moves to the next line instead of hiding off-screen.
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ...leadingChips,
              FilterChip(
                key: const ValueKey('branch-filter-near-me'),
                label: const Text('Ойролцоо'),
                avatar: _chipAvatar(
                  Icons.near_me_outlined,
                  pending: nearMePending,
                ),
                selected: nearMe,
                onSelected: onNearMeChanged,
              ),
              FilterChip(
                key: const ValueKey('branch-filter-open-now'),
                label: const Text('Одоо нээлттэй'),
                avatar: _chipAvatar(
                  Icons.schedule_outlined,
                  pending: openNowPending,
                ),
                selected: openNow,
                onSelected: onOpenNowChanged,
              ),
              FilterChip(
                key: const ValueKey('branch-filter-weekend'),
                label: const Text('Амралтын өдөр ажилладаг'),
                avatar: _chipAvatar(
                  Icons.weekend_outlined,
                  pending: weekendPending,
                ),
                selected: weekend,
                onSelected: onWeekendChanged,
              ),
            ],
          ),
        ),
      ],
    ],
  );

  Widget _chipAvatar(IconData icon, {required bool pending}) {
    if (!pending) return Icon(icon, size: 18);
    return const SizedBox(
      width: 16,
      height: 16,
      child: CircularProgressIndicator(strokeWidth: 2),
    );
  }
}

/// City or district dropdown. The empty value is a real item labelled with
/// [hint], so an unset filter reads "Хот / аймаг" rather than a generic
/// "all".
class BranchLocationFilter extends StatelessWidget {
  const BranchLocationFilter({
    required this.value,
    required this.hint,
    required this.icon,
    required this.values,
    required this.onChanged,
    super.key,
  });

  final String value;
  final String hint;
  final IconData icon;
  final List<String> values;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    // The current value must always be an item — a dropdown whose value has
    // no matching item throws. It can drop out of [values] when the options
    // are recomputed (e.g. the picker's selection changed).
    final items = [
      if (value.isNotEmpty && !values.contains(value)) value,
      ...values,
    ];
    return DropdownButtonFormField<String>(
      // `initialValue` is only read once; keying on it lets an external
      // reset (city change clearing the district, "clear all") show up.
      key: ValueKey(value),
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(
        prefixIcon: Icon(icon, size: 19),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 12,
        ),
      ),
      hint: Text(hint, maxLines: 1, overflow: TextOverflow.ellipsis),
      items: [
        DropdownMenuItem(
          value: '',
          child: Text(hint, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
        ...items.map(
          (item) => DropdownMenuItem(
            value: item,
            child: Text(item, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
        ),
      ],
      onChanged: onChanged,
    );
  }
}

/// Business-type tag dropdown ("Угаалгын газар" etc.). Reports the name along
/// with the id because callers keep the name for display.
class BranchTagFilter extends StatelessWidget {
  const BranchTagFilter({
    required this.value,
    required this.options,
    required this.onChanged,
    super.key,
  });

  final String value;
  final List<BranchTagOption> options;
  final void Function(String id, String name) onChanged;

  @override
  Widget build(BuildContext context) {
    final known = options.any((o) => o.id == value);
    return DropdownButtonFormField<String>(
      key: ValueKey(value),
      initialValue: value.isEmpty || known ? value : '',
      isExpanded: true,
      decoration: const InputDecoration(
        prefixIcon: Icon(Icons.sell_outlined, size: 19),
        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      ),
      hint: const Text(
        'Салбарын төрөл',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      items: [
        const DropdownMenuItem(
          value: '',
          child: Text(
            'Салбарын төрөл',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        ...options.map(
          (option) => DropdownMenuItem(
            value: option.id,
            child: Text(
              option.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ],
      onChanged: (id) {
        if (id == null) return;
        final name = options
            .firstWhere(
              (o) => o.id == id,
              orElse: () => const BranchTagOption(id: '', name: ''),
            )
            .name;
        onChanged(id, name);
      },
    );
  }
}
