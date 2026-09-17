import 'package:carcare_customer_mobile/app/theme/app_surfaces.dart';
import 'package:carcare_customer_mobile/app/theme/app_theme.dart';
import 'package:carcare_customer_mobile/core/widgets/animations.dart';
import 'package:carcare_customer_mobile/core/widgets/offline_banner.dart';
import 'package:carcare_customer_mobile/core/widgets/skeletons.dart';
import 'package:carcare_customer_mobile/features/auth/presentation/auth_controller.dart';
import 'package:carcare_customer_mobile/features/discovery/domain/branch.dart';
import 'package:carcare_customer_mobile/features/discovery/domain/organization.dart';
import 'package:carcare_customer_mobile/features/discovery/domain/organization_repository.dart';
import 'package:carcare_customer_mobile/features/discovery/presentation/controllers/discovery_controller.dart';
import 'package:carcare_customer_mobile/features/discovery/presentation/controllers/discovery_state.dart';
import 'package:carcare_customer_mobile/features/discovery/presentation/controllers/organization_detail_controller.dart';
import 'package:carcare_customer_mobile/features/discovery/presentation/widgets/branch_card.dart';
import 'package:carcare_customer_mobile/features/discovery/presentation/widgets/discovery_map.dart';
import 'package:carcare_customer_mobile/features/discovery/services/device_location_service.dart';
import 'package:carcare_customer_mobile/features/notifications/presentation/controllers/notifications_controller.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class DiscoveryScreen extends StatefulWidget {
  const DiscoveryScreen({
    required this.onBranchSelected,
    required this.onNotificationsRequested,
    super.key,
  });
  final void Function(Organization organization, Branch branch)
  onBranchSelected;
  final VoidCallback onNotificationsRequested;

  @override
  State<DiscoveryScreen> createState() => _DiscoveryScreenState();
}

class _DiscoveryScreenState extends State<DiscoveryScreen> {
  bool _filtersExpanded = false;
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  final _mapKey = GlobalKey<DiscoveryMapState>();
  MapViewport? _lastMapViewport;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => context.read<DiscoveryController>().loadTagOptions(),
    );
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.extentAfter < 500) {
      context.read<DiscoveryController>().loadMore();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<DiscoveryController>();
    // Map mode wants the whole screen, status bar included (the shell hides
    // its AppBar for this same reason) — SafeArea is applied per-overlay
    // inside _buildMapBody instead of around the whole body.
    return AppShellBackground(
      child: controller.mapView
          ? _buildMapBody(controller)
          : SafeArea(child: _buildListBody(controller)),
    );
  }

  Widget _buildListBody(DiscoveryController controller) => RefreshIndicator(
    onRefresh: controller.load,
    child: CustomScrollView(
      controller: _scrollController,
      key: const PageStorageKey('discovery-scroll'),
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
          sliver: SliverToBoxAdapter(
            child: _DiscoveryHeader(
              controller: controller,
              searchController: _searchController,
              filtersExpanded: _filtersExpanded,
              onFiltersExpandedChanged: (expanded) =>
                  setState(() => _filtersExpanded = expanded),
            ),
          ),
        ),
        ..._content(controller),
      ],
    ),
  );

  /// Map-first Discover (2026-09-17): the map fills the whole screen (the
  /// shell hides its AppBar for this tab in this mode — see
  /// CustomerShell), with search, filters, and the notifications/list/zoom/
  /// locate-me controls floating on top instead of pushing the map down.
  /// The map fell back to the list on its own long before this (init
  /// failure, no located branches); this just makes that fallback the
  /// primary way most people reach the list, via the action stack's toggle.
  Widget _buildMapBody(DiscoveryController controller) {
    final detailController = context.read<OrganizationDetailController>();
    final mapOrganizations = controller.mapLoaded
        ? controller.mapMarkers.map((marker) => marker.toOrganization()).toList()
        : controller.mapFallbackOrganizations;
    final account = context.watch<AuthController>().account;
    final unreadCount = context.watch<NotificationsController>().unreadCount;
    return LayoutBuilder(
      builder: (context, constraints) => Stack(
        children: [
          Positioned.fill(
            child: DiscoveryMap(
              key: _mapKey,
              organizations: mapOrganizations,
              hasActiveFilters: controller.hasActiveFilters,
              height: constraints.maxHeight,
              organizationDetailController: detailController,
              refitSignal: controller.mapRefitSignal,
              onViewportChanged: (bounds) {
                final viewport = MapViewport(
                  north: bounds.northeast.latitude,
                  south: bounds.southwest.latitude,
                  east: bounds.northeast.longitude,
                  west: bounds.southwest.longitude,
                );
                _lastMapViewport = viewport;
                controller.requestMapMarkers(viewport);
              },
              onBranchSelected: widget.onBranchSelected,
              onShowList: () => controller.setMapView(false),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Column(
                  children: [
                    _CompactDiscoveryBar(
                      controller: controller,
                      searchController: _searchController,
                      onOpenFilters: () => _openFiltersSheet(controller),
                    ),
                    // A search/filter change re-fetches markers for the
                    // current viewport in the background (see
                    // DiscoveryController._invalidateMapForFilterChange)
                    // without hiding the map — this is the only sign that
                    // fetch is happening, so dropping it (as the
                    // map-default rewrite originally did) made a working
                    // refresh look like a stall.
                    if (controller.mapLoading && controller.mapError == null)
                      const Padding(
                        padding: EdgeInsets.only(top: 10),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: _MapRefreshSpinner(),
                        ),
                      ),
                    if (controller.mapError != null &&
                        (!controller.mapLoaded ||
                            controller.mapMarkers.isEmpty))
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            child: Row(
                              children: [
                                Expanded(child: Text(controller.mapError!)),
                                if (_lastMapViewport != null)
                                  TextButton(
                                    onPressed: () =>
                                        controller.requestMapMarkers(
                                          _lastMapViewport!,
                                          force: true,
                                        ),
                                    child: const Text('Дахин оролдох'),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          if (controller.mapTruncated)
            const Positioned(
              left: 16,
              bottom: 16,
              child: SafeArea(
                child: Chip(
                  label: Text(
                    'Зарим цэгийг нуусан. Газрын зургийг томруулна уу.',
                  ),
                ),
              ),
            ),
          Positioned(
            right: 16,
            bottom: 16,
            child: SafeArea(
              child: _MapActionStack(
                mapKey: _mapKey,
                showNotifications: account != null,
                unreadCount: unreadCount,
                onNotificationsRequested: widget.onNotificationsRequested,
                onToggleList: () => controller.setMapView(false),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openFiltersSheet(DiscoveryController controller) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 12,
            bottom: 20 + MediaQuery.of(sheetContext).viewInsets.bottom,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                ListenableBuilder(
                  listenable: controller,
                  builder: (context, _) => Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Шүүлтүүрүүд',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      if (controller.hasActiveFilters)
                        TextButton(
                          onPressed: () {
                            _searchController.clear();
                            controller.clearFilters();
                          },
                          child: const Text('Бүгдийг арилгах'),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                ListenableBuilder(
                  listenable: controller,
                  builder: (context, _) => _FiltersPanel(controller: controller),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _content(DiscoveryController controller) {
    final state = controller.state;
    final organizations = controller.visibleOrganizations;
    final banner = state.isFromCache
        ? [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
              sliver: SliverToBoxAdapter(
                child: OfflineBanner(
                  message: 'Сүлжээгүй байна — сүүлд ачаалсан жагсаалтыг харуулж байна',
                  semanticsLabel: 'Сүлжээгүй байна. Сүүлд ачаалсан авто сервисийн жагсаалтыг харуулж байна.',
                  retryKey: const ValueKey('discovery-offline-retry'),
                  onRetry: controller.load,
                ),
              ),
            ),
          ]
        : const <Widget>[];
    return [
      ...banner,
      ..._statusContent(state, organizations, controller),
    ];
  }

  List<Widget> _statusContent(
    DiscoveryState state,
    List<Organization> organizations,
    DiscoveryController controller,
  ) {
    // Жагсаалт одоо байгууллагын биш салбарын түвшинд харагддаг тул
    // байгууллага бүрийг өөрийн салбаруудаар нь тэгшлэв — эзэн байгууллагын
    // нэрийг картын дэд гарчиг болгон ашиглахын тулд хосолсон хэвээр үлдээв.
    final branchEntries = [
      for (final organization in organizations)
        for (final branch in organization.branches)
          (organization: organization, branch: branch),
    ];
    // Шүүлт солиход (reload) өмнөх жагсаалт хэвээр байвал skeleton руу
    // "гялсхийхгүй" — өмнөх өгөгдлийг үзүүлсээр байна (зөвхөн анхны ачаалалд
    // skeleton). Ингэснээр filter section болон жагсаалт тогтвортой харагдана.
    final effectiveStatus =
        state.status == DiscoveryStatus.loading &&
            state.organizations.isNotEmpty
        ? DiscoveryStatus.data
        : state.status;
    return switch (effectiveStatus) {
      DiscoveryStatus.initial || DiscoveryStatus.loading => const [
        SliverFillRemaining(
          hasScrollBody: true,
          child: SkeletonAvatarCardList(),
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
      DiscoveryStatus.data when branchEntries.isEmpty => [
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
      DiscoveryStatus.data => [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
          sliver: SliverList.separated(
            itemCount: branchEntries.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final entry = branchEntries[index];
              return RiseIn(
                index: index,
                child: BranchCard(
                  organization: entry.organization,
                  branch: entry.branch,
                  onTap: () =>
                      widget.onBranchSelected(entry.organization, entry.branch),
                ),
              );
            },
          ),
        ),
        if (state.isLoadingMore || state.loadMoreMessage != null ||
            state.pagination.hasNext)
          SliverToBoxAdapter(
            child: _LoadMoreFooter(
              state: state,
              onRetry: controller.loadMore,
            ),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 32)),
      ],
    };
  }
}

class _LoadMoreFooter extends StatelessWidget {
  const _LoadMoreFooter({required this.state, required this.onRetry});

  final DiscoveryState state;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (state.isLoadingMore) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (state.loadMoreMessage != null) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Center(
          child: OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Дахин ачаалах'),
          ),
        ),
      );
    }
    return const Padding(
      padding: EdgeInsets.all(12),
      child: SizedBox(height: 1),
    );
  }
}

class _DiscoveryHeader extends StatelessWidget {
  const _DiscoveryHeader({
    required this.controller,
    required this.searchController,
    required this.filtersExpanded,
    required this.onFiltersExpandedChanged,
  });

  final DiscoveryController controller;
  final TextEditingController searchController;
  final bool filtersExpanded;
  final ValueChanged<bool> onFiltersExpandedChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // Идэвхтэй шүүлт байвал хэрэглэгч түүнийг далдлагдсан хэсэгт
    // "мартахгүйн" тулд үргэлж дэлгэсэн байлгана — гар аргаар хаасан ч.
    final showFilters = filtersExpanded || controller.hasActiveFilters;

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
                    TextField(
                      controller: searchController,
                      onChanged: controller.setQuery,
                      textInputAction: TextInputAction.search,
                      onSubmitted: (_) => FocusScope.of(context).unfocus(),
                      decoration: InputDecoration(
                        hintText: 'Нэр, хот эсвэл дүүргээр хайх',
                        prefixIcon: IconButton(
                          key: const ValueKey('discovery-search-submit'),
                          onPressed: () => FocusScope.of(context).unfocus(),
                          tooltip: 'Хайх',
                          icon: const Icon(Icons.search),
                        ),
                        suffixIcon: controller.hasActiveFilters
                            ? IconButton(
                                onPressed: () {
                                  searchController.clear();
                                  controller.clearFilters();
                                },
                                tooltip: 'Шүүлтүүр цэвэрлэх',
                                icon: const Icon(Icons.close_rounded),
                              )
                            : null,
                      ),
                    ),
                    // Хайлтын мөрийн зэрэгцээ дан icon товч байсан нь
                    // "хайх" товч мэт андуурагдах эрсдэлтэй тул хайлтын мөртэй
                    // адил өргөнтэй, тодорхой бичигтэй товч болгов — далд
                    // байдлаар анхны төлөвт хаалттай (хот/дүүрэг, ойролцоо/
                    // нээлттэй/амралтын өдөр хайлтын мөрийг бөглөрүүлж
                    // байсан); идэвхтэй шүүлттэй үед автоматаар дэлгэгдсэн
                    // хэвээр үлдэнэ (`showFilters`).
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.tonalIcon(
                        key: const ValueKey('discovery-filters-toggle'),
                        onPressed: () =>
                            onFiltersExpandedChanged(!filtersExpanded),
                        icon: Icon(
                          filtersExpanded
                              ? Icons.expand_less_rounded
                              : Icons.tune_rounded,
                        ),
                        label: Text(
                          filtersExpanded
                              ? 'Шүүлтүүрүүд нуух'
                              : 'Шүүлтүүрүүд харуулах',
                        ),
                      ),
                    ),
                    AnimatedSize(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeInOut,
                      alignment: Alignment.topCenter,
                      child: !showFilters
                          ? const SizedBox.shrink()
                          : Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: _FiltersPanel(controller: controller),
                            ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The filter controls (city/district, business-type tag, server chips)
/// shared between the list header's expandable section and the map view's
/// bottom sheet — kept as one widget so a filter added in one place is never
/// forgotten in the other.
class _FiltersPanel extends StatelessWidget {
  const _FiltersPanel({required this.controller});

  final DiscoveryController controller;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      // controller.cities/districts одоо сүүлийн ШҮҮЛТГҮЙ каталогоос
      // тооцогддог тул идэвхтэй сервер шүүлт 0 илэрцтэй болсон ч хоосрохгүй
      // — гэхдээ анхны ачаалалт өмнө (өгөгдөл огт ирээгүй) хоёуланг нь
      // шалгасаар байна.
      if (controller.cities.isNotEmpty) ...[
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
      // Бизнесийн төрлийн шошго (жиш: "Угаалгын газар") — олон болоход
      // хэвтээ chip мөр хэт өргөсдөг тул dropdown болгов (нэг дор зөвхөн
      // нэг сонголт хэвээр, харах: DiscoveryController.setTag).
      // Ачаалагдаагүй/хоосон үед юу ч харуулахгүй.
      if (controller.tagOptions.isNotEmpty) ...[
        const SizedBox(height: 10),
        _TagFilter(
          value: controller.tag,
          options: controller.tagOptions,
          onChanged: (id, name) => controller.setTag(id, name: name),
        ),
      ],
      // Сервер шүүлтийн chip-үүд (ойролцоо/одоо нээлттэй/амралтын өдөр) нь
      // одоогийн үр дүнгээс ХАРААТГҮЙ — идэвхтэй шүүлт байвал (тэр байтугай
      // 0 илэрцтэй үед ч) харагдаж байх ёстой, эс бөгөөс хэрэглэгч буцааж
      // унтраах товчгүй үлдэнэ. `state.organizations` биш
      // `controller.hasCatalog` ашигласан нь чухал: шүүлтийг унтраахад
      // `load()` шинэ хариу авах хүртэл `state.organizations` өмнөх (0
      // байсан) утгаараа "loading" төлөвт хадгалагдсан хэвээр байдаг тул
      // унтраасан даруйдаа chip мөр түр зуур бүр алга болдог байсан
      // (`hasActiveFilters` мөн шууд false болчихсон учир хоёулаа false
      // болно) — `hasCatalog` нь сүүлийн шүүлтгүй ачаалалтаас тооцогддог
      // тул reload-ын үед өөрчлөгддөггүй.
      if (controller.hasCatalog || controller.hasActiveFilters) ...[
        const SizedBox(height: 8),
        _ServerFilterChips(controller: controller),
      ],
    ],
  );
}

/// A bare, unobtrusive spinner over the map's top-left corner, shown while a
/// filter/search change is re-fetching markers for the on-screen viewport.
/// Deliberately not a banner with text — the map itself is the content here.
class _MapRefreshSpinner extends StatelessWidget {
  const _MapRefreshSpinner();

  @override
  Widget build(BuildContext context) => Container(
    key: const ValueKey('discovery-map-refreshing'),
    width: 30,
    height: 30,
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.9),
      shape: BoxShape.circle,
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.15),
          blurRadius: 6,
        ),
      ],
    ),
    padding: const EdgeInsets.all(6),
    child: const CircularProgressIndicator(strokeWidth: 2.5),
  );
}

/// Everything that would otherwise be Google Maps' own platform controls
/// (zoom, locate-me) plus the shell's notifications bell and map/list
/// toggle, combined into one compact stack — the platform controls can't be
/// repositioned or restyled, and with the AppBar hidden in map mode the
/// notifications bell needs a new home anyway.
class _MapActionStack extends StatelessWidget {
  const _MapActionStack({
    required this.mapKey,
    required this.showNotifications,
    required this.unreadCount,
    required this.onNotificationsRequested,
    required this.onToggleList,
  });

  final GlobalKey<DiscoveryMapState> mapKey;
  final bool showNotifications;
  final int unreadCount;
  final VoidCallback onNotificationsRequested;
  final VoidCallback onToggleList;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      if (showNotifications) ...[
        _RoundMapButton(
          key: const ValueKey('discovery-map-notifications'),
          icon: Icons.notifications_outlined,
          badgeCount: unreadCount,
          onPressed: onNotificationsRequested,
        ),
        const SizedBox(height: 10),
      ],
      _RoundMapButton(
        key: const ValueKey('discovery-map-list-toggle'),
        icon: Icons.view_list_outlined,
        onPressed: onToggleList,
      ),
      const SizedBox(height: 10),
      _MapZoomButtonGroup(mapKey: mapKey),
      const SizedBox(height: 10),
      _RoundMapButton(
        key: const ValueKey('discovery-map-locate-me'),
        icon: Icons.my_location_rounded,
        onPressed: () => mapKey.currentState?.locateMe(),
      ),
    ],
  );
}

class _RoundMapButton extends StatelessWidget {
  const _RoundMapButton({
    required this.icon,
    required this.onPressed,
    this.badgeCount = 0,
    super.key,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final int badgeCount;

  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.surface,
    shape: const CircleBorder(),
    elevation: 4,
    child: InkWell(
      customBorder: const CircleBorder(),
      onTap: onPressed,
      child: SizedBox(
        width: 44,
        height: 44,
        child: Center(
          child: Badge(
            isLabelVisible: badgeCount > 0,
            label: Text(badgeCount > 9 ? '9+' : '$badgeCount'),
            child: Icon(icon, size: 22),
          ),
        ),
      ),
    ),
  );
}

/// Stand-in for the platform zoom control, which Google Maps always pins to
/// the bottom-right and can't be moved or restyled.
class _MapZoomButtonGroup extends StatelessWidget {
  const _MapZoomButtonGroup({required this.mapKey});

  final GlobalKey<DiscoveryMapState> mapKey;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface,
      elevation: 4,
      borderRadius: BorderRadius.circular(22),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            key: const ValueKey('discovery-map-zoom-in'),
            onTap: () => mapKey.currentState?.zoomIn(),
            child: const SizedBox(
              width: 44,
              height: 40,
              child: Center(child: Icon(Icons.add, size: 20)),
            ),
          ),
          Divider(height: 1, color: scheme.outlineVariant),
          InkWell(
            key: const ValueKey('discovery-map-zoom-out'),
            onTap: () => mapKey.currentState?.zoomOut(),
            child: const SizedBox(
              width: 44,
              height: 40,
              child: Center(child: Icon(Icons.remove, size: 20)),
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact search + filters bar for map mode — a floating pill instead of
/// the list header's tall glass card, so the map underneath keeps most of
/// the screen.
class _CompactDiscoveryBar extends StatelessWidget {
  const _CompactDiscoveryBar({
    required this.controller,
    required this.searchController,
    required this.onOpenFilters,
  });

  final DiscoveryController controller;
  final TextEditingController searchController;
  final VoidCallback onOpenFilters;

  @override
  Widget build(BuildContext context) => GlassSurface(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
    child: Row(
      children: [
        Expanded(
          child: TextField(
            controller: searchController,
            onChanged: controller.setQuery,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => FocusScope.of(context).unfocus(),
            decoration: InputDecoration(
              isDense: true,
              border: InputBorder.none,
              hintText: 'Нэр, хот эсвэл дүүргээр хайх',
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: controller.hasActiveFilters
                  ? IconButton(
                      onPressed: () {
                        searchController.clear();
                        controller.clearFilters();
                      },
                      tooltip: 'Шүүлтүүр цэвэрлэх',
                      icon: const Icon(Icons.close_rounded, size: 20),
                    )
                  : null,
            ),
          ),
        ),
        IconButton(
          key: const ValueKey('discovery-map-filters-toggle'),
          onPressed: onOpenFilters,
          tooltip: 'Шүүлтүүрүүд',
          icon: Badge(
            isLabelVisible: controller.hasActiveFilters,
            smallSize: 8,
            child: const Icon(Icons.tune_rounded),
          ),
        ),
      ],
    ),
  );
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
      // `hint` дээрх зорилготой ижил текст — `value` хоосон ('') үед `hint`
      // widget биш яг ЭНЭ item-ийн текст харагддаг (DropdownButtonFormField-
      // ийн зан төлөв: `initialValue`-д тохирох item байвал үргэлж түүнийг
      // харуулна, `hint`-ийг зөвхөн утга null үед ашиглана). "Бүгд" гэсэн
      // ерөнхий үг оронд аль шүүлтүүр вэ (Хот, Дүүрэг г.м.) гэдгийг харуулж,
      // ялгаагүй гурван dropdown "Бүгд" гэж харагдахаас сэргийлнэ.
      DropdownMenuItem(
        value: '',
        child: Text(hint, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
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

/// Бизнесийн төрлийн шошгын (жиш: "Угаалгын газар") сонголт — `_LocationFilter`-
/// тэй ижил dropdown хэлбэр, гагцхүү утга нь id/нэр хос (`BranchTagOption`)
/// тул сонгоход нэрийг нь давхар дамжуулна (`DiscoveryController.setTag`-д
/// шаардлагатай, дэлгэц/chip дээр харуулах нэрийг тусад нь хадгалдаг тул).
class _TagFilter extends StatelessWidget {
  const _TagFilter({
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String value;
  final List<BranchTagOption> options;
  final void Function(String id, String name) onChanged;

  @override
  Widget build(BuildContext context) => DropdownButtonFormField<String>(
    initialValue: value,
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
        child: Text('Салбарын төрөл', maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      ...options.map(
        (option) => DropdownMenuItem(
          value: option.id,
          child: Text(option.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      ),
    ],
    onChanged: (id) {
      if (id == null) return;
      final name = options.firstWhere(
        (o) => o.id == id,
        orElse: () => const BranchTagOption(id: '', name: ''),
      ).name;
      onChanged(id, name);
    },
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

/// Booking v2 — серверийн "ойролцоо" / "одоо нээлттэй" шүүлтийн toggle-ууд.
class _ServerFilterChips extends StatelessWidget {
  const _ServerFilterChips({required this.controller});

  final DiscoveryController controller;

  Future<void> _toggleNearMe(BuildContext context, bool selected) async {
    // Optimistic: chip тэр даруй сонгогдоно; байршил авч чадаагүй бол буцна.
    final ok = await controller.setNearMe(
      selected,
      locate: selected
          ? () async {
              final location = await const GeolocatorDeviceLocationService()
                  .current();
              return location == null
                  ? null
                  : (lat: location.lat, lng: location.lng);
            }
          : null,
    );
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Байршлыг авч чадсангүй. Байршлын зөвшөөрөл, тохиргоогоо шалгана уу.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // 3 chip-тэй болсноор нарийн дэлгэц дээр Row дүүрч болзошгүй тул Wrap
    // ашиглав — багтахгүй бол дараагийн chip доод мөрөнд бүрэн харагдана,
    // хэрэглэгч анзаарахгүй өнгөрч болзошгүй хэвтээ гүйдлээс илүү.
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (controller.serviceKey.isNotEmpty)
          InputChip(
            key: const ValueKey('discovery-service-key-chip'),
            label: Text(
              controller.serviceKeyName.isEmpty
                  ? 'Сонгосон ажил'
                  : controller.serviceKeyName,
            ),
            avatar: const Icon(Icons.build_outlined, size: 18),
            onDeleted: () => controller.setServiceKey(''),
          ),
        FilterChip(
          label: const Text('Ойролцоо'),
          avatar: _chipAvatar(
            Icons.near_me_outlined,
            pending: controller.nearMePending,
          ),
          selected: controller.nearMe,
          onSelected: (selected) => _toggleNearMe(context, selected),
        ),
        FilterChip(
          label: const Text('Одоо нээлттэй'),
          avatar: _chipAvatar(
            Icons.schedule_outlined,
            pending: controller.openNowPending,
          ),
          selected: controller.openNow,
          onSelected: controller.setOpenNow,
        ),
        FilterChip(
          label: const Text('Амралтын өдөр ажилладаг'),
          avatar: _chipAvatar(
            Icons.weekend_outlined,
            pending: controller.weekendPending,
          ),
          selected: controller.weekend,
          onSelected: controller.setWeekend,
        ),
      ],
    );
  }

  Widget _chipAvatar(IconData icon, {required bool pending}) {
    if (!pending) return Icon(icon, size: 18);
    return const SizedBox(
      width: 16,
      height: 16,
      child: CircularProgressIndicator(strokeWidth: 2),
    );
  }
}
