import 'package:carcare_customer_mobile/app/theme/app_surfaces.dart';
import 'package:carcare_customer_mobile/app/theme/app_theme.dart';
import 'package:carcare_customer_mobile/features/discovery/domain/organization.dart';
import 'package:carcare_customer_mobile/features/discovery/presentation/controllers/discovery_controller.dart';
import 'package:carcare_customer_mobile/features/discovery/presentation/controllers/discovery_state.dart';
import 'package:carcare_customer_mobile/features/discovery/presentation/widgets/discovery_map.dart';
import 'package:carcare_customer_mobile/features/discovery/presentation/widgets/organization_card.dart';
import 'package:carcare_customer_mobile/features/favorites/presentation/controllers/favorites_controller.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

enum _DiscoveryView { list, map }

enum _FavoritesFilter { all, saved }

class DiscoveryScreen extends StatefulWidget {
  const DiscoveryScreen({required this.onOrganizationSelected, super.key});
  final ValueChanged<String> onOrganizationSelected;

  @override
  State<DiscoveryScreen> createState() => _DiscoveryScreenState();
}

class _DiscoveryScreenState extends State<DiscoveryScreen> {
  _DiscoveryView _view = _DiscoveryView.list;
  _FavoritesFilter _favoritesFilter = _FavoritesFilter.all;
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<DiscoveryController>();
    final favoritesController = context.watch<FavoritesController>();
    return AppShellBackground(
      child: SafeArea(
        child: RefreshIndicator(
          onRefresh: controller.load,
          child: CustomScrollView(
            key: const PageStorageKey('discovery-scroll'),
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
                sliver: SliverToBoxAdapter(
                  child: _DiscoveryHeader(
                    controller: controller,
                    searchController: _searchController,
                    view: _view,
                    onViewChanged: (view) => setState(() => _view = view),
                    favoritesFilter: _favoritesFilter,
                    onFavoritesFilterChanged: (filter) =>
                        setState(() => _favoritesFilter = filter),
                  ),
                ),
              ),
              ..._content(controller, favoritesController),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _content(
    DiscoveryController controller,
    FavoritesController favoritesController,
  ) {
    final state = controller.state;
    final organizations = _favoritesFilter == _FavoritesFilter.saved
        ? controller.visibleOrganizations
              .where(
                (organization) =>
                    favoritesController.contains(organization.slug),
              )
              .toList(growable: false)
        : controller.visibleOrganizations;
    final banner = state.isFromCache
        ? [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
              sliver: SliverToBoxAdapter(
                child: _OfflineBanner(onRetry: controller.load),
              ),
            ),
          ]
        : const <Widget>[];
    return [
      ...banner,
      ..._statusContent(state, organizations, controller, favoritesController),
    ];
  }

  List<Widget> _statusContent(
    DiscoveryState state,
    List<Organization> organizations,
    DiscoveryController controller,
    FavoritesController favoritesController,
  ) {
    return switch (state.status) {
      DiscoveryStatus.initial || DiscoveryStatus.loading => const [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(child: CircularProgressIndicator()),
        ),
      ],
      DiscoveryStatus.empty => const [
        SliverFillRemaining(
          hasScrollBody: false,
          child: _MessageState(
            icon: Icons.storefront_outlined,
            title: 'Авто сервис олдсонгүй',
            message: 'Одоогоор цаг захиалга авч буй байгууллага алга байна.',
          ),
        ),
      ],
      DiscoveryStatus.error => [
        SliverFillRemaining(
          hasScrollBody: false,
          child: _MessageState(
            icon: Icons.cloud_off_outlined,
            title: 'Мэдээлэл ачаалсангүй',
            message: state.message ?? 'Дахин оролдоно уу.',
            actionLabel: 'Дахин оролдох',
            onAction: controller.load,
          ),
        ),
      ],
      DiscoveryStatus.data
          when organizations.isEmpty &&
              _favoritesFilter == _FavoritesFilter.saved =>
        [
          SliverFillRemaining(
            hasScrollBody: false,
            child: _MessageState(
              icon: Icons.favorite_border_rounded,
              title: 'Хадгалсан сервис алга',
              message: 'Сервисийн зүрхэн тэмдгийг дарж энд хадгалаарай.',
              actionLabel: 'Бүгдийг харах',
              onAction: () =>
                  setState(() => _favoritesFilter = _FavoritesFilter.all),
            ),
          ),
        ],
      DiscoveryStatus.data when organizations.isEmpty => [
        SliverFillRemaining(
          hasScrollBody: false,
          child: _MessageState(
            icon: Icons.search_off_rounded,
            title: 'Илэрц олдсонгүй',
            message: 'Хайлт эсвэл байршлын шүүлтүүрээ өөрчилж үзээрэй.',
            actionLabel: 'Шүүлтүүр цэвэрлэх',
            onAction: () {
              _searchController.clear();
              controller.clearFilters();
            },
          ),
        ),
      ],
      DiscoveryStatus.data when _view == _DiscoveryView.map => [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 32),
          sliver: SliverToBoxAdapter(
            child: DiscoveryMap(
              organizations: organizations,
              hasActiveFilters: controller.hasActiveFilters,
              onOrganizationSelected: widget.onOrganizationSelected,
              onShowList: () => setState(() => _view = _DiscoveryView.list),
            ),
          ),
        ),
      ],
      DiscoveryStatus.data => [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 32),
          sliver: SliverList.separated(
            itemCount: organizations.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final organization = organizations[index];
              return OrganizationCard(
                organization: organization,
                isFavorite: favoritesController.contains(organization.slug),
                onFavoriteToggle: () =>
                    favoritesController.toggle(organization.slug),
                onTap: () => widget.onOrganizationSelected(organization.slug),
              );
            },
          ),
        ),
      ],
    };
  }
}

class _DiscoveryHeader extends StatelessWidget {
  const _DiscoveryHeader({
    required this.controller,
    required this.searchController,
    required this.view,
    required this.onViewChanged,
    required this.favoritesFilter,
    required this.onFavoritesFilterChanged,
  });

  final DiscoveryController controller;
  final TextEditingController searchController;
  final _DiscoveryView view;
  final ValueChanged<_DiscoveryView> onViewChanged;
  final _FavoritesFilter favoritesFilter;
  final ValueChanged<_FavoritesFilter> onFavoritesFilterChanged;

  @override
  Widget build(BuildContext context) {
    final state = controller.state;
    final organizations = controller.visibleOrganizations;
    final branchCount = organizations.fold<int>(
      0,
      (total, organization) => total + organization.branches.length,
    );
    final scheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        GlassSurface(
          padding: EdgeInsets.zero,
          child: Stack(
            children: [
              Positioned(
                right: -54,
                top: -68,
                child: _AmbientOrb(
                  color: scheme.primary.withValues(alpha: 0.2),
                ),
              ),
              Positioned(
                left: -76,
                bottom: -92,
                child: _AmbientOrb(
                  color: AppColors.blue.withValues(alpha: 0.13),
                  size: 180,
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: scheme.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(99),
                        border: Border.all(
                          color: scheme.primary.withValues(alpha: 0.24),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 7,
                            height: 7,
                            decoration: const BoxDecoration(
                              color: AppColors.green,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 7),
                          Text(
                            'ОНЛАЙН ЦАГ ЗАХИАЛГА',
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  color: scheme.primary,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.7,
                                ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text.rich(
                      TextSpan(
                        children: [
                          const TextSpan(text: 'Авто сервисээ\n'),
                          TextSpan(
                            text: 'хялбархан олоорой',
                            style: TextStyle(color: scheme.primary),
                          ),
                        ],
                      ),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(
                            fontWeight: FontWeight.w900,
                            height: 1.08,
                            letterSpacing: -0.8,
                          ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Ойрхон сервисээ сонгож, өөрт тохирох салбартаа цаг захиалаарай.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 18),
                    TextField(
                      controller: searchController,
                      onChanged: controller.setQuery,
                      decoration: InputDecoration(
                        hintText: 'Нэр, хот эсвэл дүүргээр хайх',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: controller.hasActiveFilters
                            ? IconButton(
                                onPressed: () {
                                  searchController.clear();
                                  controller.clearFilters();
                                },
                                tooltip: 'Шүүлтүүр цэвэрлэх',
                                icon: const Icon(Icons.close_rounded),
                              )
                            : const Icon(Icons.tune_rounded),
                      ),
                    ),
                    if (state.status == DiscoveryStatus.data &&
                        controller.cities.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _LocationFilter(
                              value: controller.city,
                              hint: 'Хот / аймаг',
                              icon: Icons.location_city_outlined,
                              values: controller.cities,
                              onChanged: controller.setCity,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _LocationFilter(
                              value: controller.district,
                              hint: 'Дүүрэг / сум',
                              icon: Icons.place_outlined,
                              values: controller.districts,
                              onChanged: controller.setDistrict,
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (state.status == DiscoveryStatus.data) ...[
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          _DiscoveryMetric(
                            value: '${organizations.length}',
                            label: 'сервис',
                          ),
                          _MetricDivider(
                            color: CarCareTheme.of(context).glassBorder,
                          ),
                          _DiscoveryMetric(
                            value: '$branchCount',
                            label: 'салбар',
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Авто сервисүүд',
                    style: Theme.of(context).textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    state.status == DiscoveryStatus.data
                        ? '${organizations.length} байгууллагаас сонгох'
                        : 'Танд тохирох газраа олоорой',
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            SegmentedButton<_DiscoveryView>(
              key: const ValueKey('discovery-view-toggle'),
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(
                  value: _DiscoveryView.list,
                  icon: Icon(Icons.view_list_outlined),
                  tooltip: 'Жагсаалт',
                ),
                ButtonSegment(
                  value: _DiscoveryView.map,
                  icon: Icon(Icons.map_outlined),
                  tooltip: 'Газрын зураг',
                ),
              ],
              selected: {view},
              onSelectionChanged: (selection) {
                onViewChanged(selection.first);
              },
            ),
          ],
        ),
        const SizedBox(height: 12),
        SegmentedButton<_FavoritesFilter>(
          key: const ValueKey('discovery-favorites-filter'),
          showSelectedIcon: false,
          style: const ButtonStyle(visualDensity: VisualDensity.compact),
          segments: const [
            ButtonSegment(
              value: _FavoritesFilter.all,
              label: Text('Бүгд'),
              icon: Icon(Icons.explore_outlined),
            ),
            ButtonSegment(
              value: _FavoritesFilter.saved,
              label: Text('Хадгалсан'),
              icon: Icon(Icons.favorite_border_rounded),
            ),
          ],
          selected: {favoritesFilter},
          onSelectionChanged: (selection) {
            onFavoritesFilterChanged(selection.first);
          },
        ),
      ],
    );
  }
}

class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner({required this.onRetry});

  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final largeText = MediaQuery.textScalerOf(context).scale(1) >= 1.4;
    final message = Text(
      'Сүлжээгүй байна — сүүлд ачаалсан жагсаалтыг харуулж байна',
      style: Theme.of(context).textTheme.bodySmall
          ?.copyWith(fontWeight: FontWeight.w600),
    );
    final action = TextButton(
      key: const ValueKey('discovery-offline-retry'),
      onPressed: onRetry,
      child: const Text('Дахин оролдох'),
    );
    return Semantics(
      container: true,
      liveRegion: true,
      label: 'Сүлжээгүй байна. Сүүлд ачаалсан авто сервисийн жагсаалтыг харуулж байна.',
      child: Material(
        color: Theme.of(context).colorScheme.surface,
        elevation: 5,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
          child: largeText
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.cloud_off_outlined,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 9),
                        Expanded(child: message),
                      ],
                    ),
                    Align(alignment: Alignment.centerRight, child: action),
                  ],
                )
              : Row(
                  children: [
                    Icon(
                      Icons.cloud_off_outlined,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 9),
                    Expanded(child: message),
                    action,
                  ],
                ),
        ),
      ),
    );
  }
}

class _LocationFilter extends StatelessWidget {
  const _LocationFilter({
    required this.value,
    required this.hint,
    required this.icon,
    required this.values,
    required this.onChanged,
  });

  final String value;
  final String hint;
  final IconData icon;
  final List<String> values;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) => DropdownButtonFormField<String>(
    initialValue: value,
    isExpanded: true,
    decoration: InputDecoration(
      prefixIcon: Icon(icon, size: 19),
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
    ),
    hint: Text(hint, maxLines: 1, overflow: TextOverflow.ellipsis),
    items: [
      const DropdownMenuItem(value: '', child: Text('Бүгд')),
      ...values.map(
        (value) => DropdownMenuItem(
          value: value,
          child: Text(value, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      ),
    ],
    onChanged: onChanged,
  );
}

class _AmbientOrb extends StatelessWidget {
  const _AmbientOrb({required this.color, this.size = 150});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    ),
  );
}

class _DiscoveryMetric extends StatelessWidget {
  const _DiscoveryMetric({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall
              ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      ],
    ),
  );
}

class _MetricDivider extends StatelessWidget {
  const _MetricDivider({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) =>
      Container(width: 1, height: 32, color: color);
}

class _MessageState extends StatelessWidget {
  const _MessageState({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(32),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 48, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 16),
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Text(message, textAlign: TextAlign.center),
        if (actionLabel != null && onAction != null) ...[
          const SizedBox(height: 18),
          FilledButton(onPressed: onAction, child: Text(actionLabel!)),
        ],
      ],
    ),
  );
}
