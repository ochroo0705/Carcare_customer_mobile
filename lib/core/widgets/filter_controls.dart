import 'package:carcare_customer_mobile/app/theme/app_theme.dart';
import 'package:flutter/material.dart';

/// Icon button opening an anchored filter dropdown — shows a numeric badge
/// when [activeCount] is non-zero. Shared by the Түүх (history) and
/// Оношилгоо (diagnostics) list filters so both look and behave the same.
class FilterIconButton extends StatelessWidget {
  const FilterIconButton({
    required this.icon,
    required this.activeCount,
    required this.onTap,
    super.key,
  });

  final IconData icon;
  final int activeCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasActive = activeCount > 0;
    final colorScheme = Theme.of(context).colorScheme;
    return Badge(
      isLabelVisible: hasActive,
      label: Text('$activeCount'),
      child: Material(
        color: hasActive
            ? colorScheme.primaryContainer
            : colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadii.medium),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadii.medium),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Icon(
              icon,
              color: hasActive ? colorScheme.onPrimaryContainer : null,
            ),
          ),
        ),
      ),
    );
  }
}

/// A single row inside an anchored filter dropdown — label plus a checkmark
/// when selected.
class FilterOptionTile extends StatelessWidget {
  const FilterOptionTile({
    required this.label,
    required this.isSelected,
    required this.onTap,
    super.key,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.medium),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? colorScheme.primary : null,
                  ),
                ),
              ),
              if (isSelected)
                Icon(Icons.check_rounded, color: colorScheme.primary, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

/// Single-select year list for an anchored filter dropdown — shared by the
/// Түүх (history) and Оношилгоо (diagnostics) date filters so both behave
/// identically.
class YearFilterOptions extends StatelessWidget {
  const YearFilterOptions({
    required this.years,
    required this.selectedYear,
    required this.onYearSelected,
    super.key,
  });

  final List<int> years;
  final int selectedYear;
  final ValueChanged<int> onYearSelected;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Жил',
          style: Theme.of(context).textTheme.labelLarge
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        for (final year in years)
          FilterOptionTile(
            key: ValueKey('year-filter-option-$year'),
            label: '$year',
            isSelected: selectedYear == year,
            onTap: () => onYearSelected(year),
          ),
      ],
    ),
  );
}

/// A search field plus an anchored year-filter dropdown button, in one row.
/// Shared by the Түүх and Оношилгоо tabs so a single bar placed above a tab
/// switcher can drive either tab's (independent) search/filter state — pass
/// a different [key] per tab so switching tabs remounts this with the right
/// [initialQuery] instead of carrying over the previous tab's typed text.
class SearchWithYearFilterBar extends StatefulWidget {
  const SearchWithYearFilterBar({
    required this.searchFieldKey,
    required this.filterButtonKey,
    required this.hintText,
    required this.initialQuery,
    required this.onQueryChanged,
    required this.years,
    required this.selectedYear,
    required this.onYearSelected,
    super.key,
  });

  final Key searchFieldKey;
  final Key filterButtonKey;
  final String hintText;
  final String initialQuery;
  final ValueChanged<String> onQueryChanged;
  final List<int> years;
  final int selectedYear;
  final ValueChanged<int> onYearSelected;

  @override
  State<SearchWithYearFilterBar> createState() =>
      _SearchWithYearFilterBarState();
}

class _SearchWithYearFilterBarState extends State<SearchWithYearFilterBar> {
  late final TextEditingController _searchController = TextEditingController(
    text: widget.initialQuery,
  );
  final LayerLink _filterButtonLink = LayerLink();
  OverlayEntry? _filterOverlay;

  @override
  void dispose() {
    _closeFilterOverlay();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        child: TextField(
          key: widget.searchFieldKey,
          controller: _searchController,
          onChanged: widget.onQueryChanged,
          decoration: InputDecoration(
            hintText: widget.hintText,
            prefixIcon: const Icon(Icons.search),
          ),
        ),
      ),
      const SizedBox(width: 8),
      CompositedTransformTarget(
        link: _filterButtonLink,
        child: FilterIconButton(
          key: widget.filterButtonKey,
          icon: Icons.event_outlined,
          activeCount: widget.selectedYear != DateTime.now().year ? 1 : 0,
          onTap: _toggleFilterOverlay,
        ),
      ),
    ],
  );

  void _toggleFilterOverlay() {
    if (_filterOverlay != null) {
      _closeFilterOverlay();
      return;
    }
    _filterOverlay = showAnchoredFilterOverlay(
      context: context,
      link: _filterButtonLink,
      onDismiss: _closeFilterOverlay,
      contentBuilder: (context) => YearFilterOptions(
        years: widget.years,
        selectedYear: widget.selectedYear,
        onYearSelected: (year) {
          widget.onYearSelected(year);
          _closeFilterOverlay();
        },
      ),
    );
  }

  void _closeFilterOverlay() {
    _filterOverlay?.remove();
    _filterOverlay = null;
  }
}

/// Inserts an [OverlayEntry] anchored below-right of [link] via
/// `CompositedTransformFollower`, dismissed by an outside tap. Callers keep
/// the returned entry to remove it themselves (e.g. on selection or dispose).
OverlayEntry showAnchoredFilterOverlay({
  required BuildContext context,
  required LayerLink link,
  required VoidCallback onDismiss,
  required WidgetBuilder contentBuilder,
}) {
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (overlayContext) => Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onDismiss,
          ),
        ),
        CompositedTransformFollower(
          link: link,
          showWhenUnlinked: false,
          targetAnchor: Alignment.bottomRight,
          followerAnchor: Alignment.topRight,
          offset: const Offset(0, 8),
          child: Align(
            alignment: Alignment.topRight,
            child: Material(
              elevation: 8,
              borderRadius: BorderRadius.circular(AppRadii.large),
              color: Theme.of(overlayContext).colorScheme.surface,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 280),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Builder(builder: contentBuilder),
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
  Overlay.of(context).insert(entry);
  return entry;
}
