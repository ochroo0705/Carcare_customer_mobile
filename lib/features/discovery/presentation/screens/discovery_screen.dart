import 'package:carcare_customer_mobile/app/theme/app_surfaces.dart';
import 'package:carcare_customer_mobile/app/theme/app_theme.dart';
import 'package:carcare_customer_mobile/core/widgets/animations.dart';
import 'package:carcare_customer_mobile/core/widgets/offline_banner.dart';
import 'package:carcare_customer_mobile/core/widgets/skeletons.dart';
import 'package:carcare_customer_mobile/features/discovery/domain/branch.dart';
import 'package:carcare_customer_mobile/features/discovery/domain/organization.dart';
import 'package:carcare_customer_mobile/features/discovery/presentation/controllers/discovery_controller.dart';
import 'package:carcare_customer_mobile/features/discovery/presentation/controllers/discovery_state.dart';
import 'package:carcare_customer_mobile/features/discovery/presentation/widgets/branch_card.dart';
import 'package:carcare_customer_mobile/features/discovery/services/device_location_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class DiscoveryScreen extends StatefulWidget {
  const DiscoveryScreen({required this.onBranchSelected, super.key});
  final void Function(Organization organization, Branch branch)
  onBranchSelected;

  @override
  State<DiscoveryScreen> createState() => _DiscoveryScreenState();
}

class _DiscoveryScreenState extends State<DiscoveryScreen> {
  bool _filtersExpanded = false;
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<DiscoveryController>();
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
                    filtersExpanded: _filtersExpanded,
                    onFiltersExpandedChanged: (expanded) =>
                        setState(() => _filtersExpanded = expanded),
                  ),
                ),
              ),
              ..._content(controller),
            ],
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
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 32),
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
      ],
    };
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
                          : Column(
                              children: [
                                // controller.cities/districts одоо сүүлийн
                                // ШҮҮЛТГҮЙ каталогоос тооцогддог тул идэвхтэй
                                // сервер шүүлт 0 илэрцтэй болсон ч хоосрохгүй
                                // — гэхдээ анхны ачаалалт өмнө (өгөгдөл огт
                                // ирээгүй) хоёуланг нь шалгасаар байна.
                                if (controller.cities.isNotEmpty) ...[
                                  const SizedBox(height: 10),
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
                                // Сервер шүүлтийн chip-үүд (ойролцоо/одоо
                                // нээлттэй/амралтын өдөр) нь одоогийн үр
                                // дүнгээс ХАРААТГҮЙ — идэвхтэй шүүлт байвал
                                // (тэр байтугай 0 илэрцтэй үед ч) харагдаж
                                // байх ёстой, эс бөгөөс хэрэглэгч буцааж
                                // унтраах товчгүй үлдэнэ. `state.organizations`
                                // биш `controller.hasCatalog` ашигласан нь
                                // чухал: шүүлтийг унтраахад `load()` шинэ
                                // хариу авах хүртэл `state.organizations`
                                // өмнөх (0 байсан) утгаараа "loading" төлөвт
                                // хадгалагдсан хэвээр байдаг тул унтраасан
                                // даруйдаа chip мөр түр зуур бүр алга болдог
                                // байсан (`hasActiveFilters` мөн шууд false
                                // болчихсон учир хоёулаа false болно) —
                                // `hasCatalog` нь сүүлийн шүүлтгүй
                                // ачаалалтаас тооцогддог тул reload-ын үед
                                // өөрчлөгддөггүй.
                                if (controller.hasCatalog ||
                                    controller.hasActiveFilters) ...[
                                  const SizedBox(height: 8),
                                  _ServerFilterChips(controller: controller),
                                ],
                              ],
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
