import 'package:carcare_customer_mobile/app/theme/app_surfaces.dart';
import 'package:carcare_customer_mobile/app/theme/app_theme.dart';
import 'package:carcare_customer_mobile/core/widgets/animations.dart';
import 'package:carcare_customer_mobile/core/widgets/offline_banner.dart';
import 'package:carcare_customer_mobile/core/widgets/skeletons.dart';
import 'package:carcare_customer_mobile/features/discovery/domain/branch.dart';
import 'package:carcare_customer_mobile/features/discovery/domain/organization.dart';
import 'package:carcare_customer_mobile/features/discovery/domain/organization_repository.dart';
import 'package:carcare_customer_mobile/features/discovery/presentation/controllers/discovery_controller.dart';
import 'package:carcare_customer_mobile/features/discovery/presentation/controllers/discovery_state.dart';
import 'package:carcare_customer_mobile/features/discovery/presentation/controllers/organization_detail_controller.dart';
import 'package:carcare_customer_mobile/features/discovery/presentation/widgets/branch_card.dart';
import 'package:carcare_customer_mobile/features/discovery/presentation/widgets/discovery_header.dart';
import 'package:carcare_customer_mobile/features/discovery/presentation/widgets/discovery_list_parts.dart';
import 'package:carcare_customer_mobile/features/discovery/presentation/widgets/discovery_map_controls.dart';
import 'package:carcare_customer_mobile/features/discovery/presentation/widgets/discovery_map.dart';
import 'package:carcare_customer_mobile/features/discovery/presentation/widgets/location_permission_banner.dart';
import 'package:carcare_customer_mobile/features/discovery/services/location_permission_service.dart';
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
  // Mirrors the map's location access so its banner can sit under the
  // floating search bar instead of behind it.
  LocationAccessState? _mapLocationAccess;
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
            child: DiscoveryHeader(
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

  // The map's organizations are re-derived only when the source list
  // instance (or which source is in use) changes — not on every controller
  // notification — so the map keeps receiving the same list and skips its
  // own marker work.
  List<Organization>? _mapOrganizations;
  Object? _mapOrganizationsSource;
  bool? _mapOrganizationsLoaded;

  List<Organization> _mapOrganizationsFor(DiscoveryController controller) {
    final loaded = controller.mapLoaded;
    final Object source = loaded
        ? controller.mapMarkers
        : controller.mapFallbackOrganizations;
    if (_mapOrganizations != null &&
        _mapOrganizationsLoaded == loaded &&
        identical(_mapOrganizationsSource, source)) {
      return _mapOrganizations!;
    }
    _mapOrganizationsLoaded = loaded;
    _mapOrganizationsSource = source;
    return _mapOrganizations = loaded
        ? controller.mapMarkers
              .map((marker) => marker.toOrganization())
              .toList()
        : controller.mapFallbackOrganizations;
  }

  /// Map-first Discover (2026-09-17): the map fills the whole screen (the
  /// shell hides its AppBar for this tab in this mode — see
  /// CustomerShell), with search, filters, and the notifications/list/zoom/
  /// locate-me controls floating on top instead of pushing the map down.
  /// The map fell back to the list on its own long before this (init
  /// failure, no located branches); this just makes that fallback the
  /// primary way most people reach the list, via the action stack's toggle.
  Widget _buildMapBody(DiscoveryController controller) {
    final detailController = context.read<OrganizationDetailController>();
    final mapOrganizations = _mapOrganizationsFor(controller);
    return LayoutBuilder(
      builder: (context, constraints) => Stack(
        children: [
          Positioned.fill(
            child: DiscoveryMap(
              key: _mapKey,
              organizations: mapOrganizations,
              hasActiveFilters: controller.hasActiveFilters,
              height: constraints.maxHeight,
              showLocationBanner: false,
              onLocationAccessChanged: (state) {
                if (state != _mapLocationAccess) {
                  setState(() => _mapLocationAccess = state);
                }
              },
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
                    CompactDiscoveryBar(
                      controller: controller,
                      searchController: _searchController,
                      onOpenFilters: () => _openFiltersSheet(controller),
                    ),
                    if (_mapLocationAccess != null &&
                        _mapLocationAccess != LocationAccessState.granted)
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: LocationPermissionBanner(
                          state: _mapLocationAccess!,
                          onRequest: () =>
                              _mapKey.currentState?.requestLocationPermission(),
                          onOpenSettings: () =>
                              _mapKey.currentState?.openLocationSettings(),
                        ),
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
                          child: MapRefreshSpinner(),
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
              child: MapActionStack(
                mapKey: _mapKey,
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
                      borderRadius: BorderRadius.circular(AppRadii.pill),
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
                  builder: (context, _) =>
                      DiscoveryFiltersPanel(controller: controller),
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
    return [...banner, ..._statusContent(state, organizations, controller)];
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
          child: DiscoveryMessageState(
            icon: Icons.storefront_outlined,
            title: 'Авто сервис олдсонгүй',
            message: 'Одоогоор цаг захиалга авч буй байгууллага алга байна.',
          ),
        ),
      ],
      DiscoveryStatus.error => [
        SliverFillRemaining(
          hasScrollBody: false,
          child: DiscoveryMessageState(
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
          child: DiscoveryMessageState(
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
        if (state.isLoadingMore ||
            state.loadMoreMessage != null ||
            state.pagination.hasNext)
          SliverToBoxAdapter(
            child: LoadMoreFooter(state: state, onRetry: controller.loadMore),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 32)),
      ],
    };
  }
}

