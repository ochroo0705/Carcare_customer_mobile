import 'package:carcare_customer_mobile/app/theme/app_surfaces.dart';
import 'package:carcare_customer_mobile/app/theme/app_theme.dart';
import 'package:carcare_customer_mobile/features/discovery/presentation/controllers/discovery_controller.dart';
import 'package:carcare_customer_mobile/features/discovery/presentation/widgets/branch_filter_panel.dart';
import 'package:carcare_customer_mobile/features/discovery/services/device_location_service.dart';
import 'package:flutter/material.dart';

class DiscoveryHeader extends StatelessWidget {
  const DiscoveryHeader({
    required this.controller,
    required this.searchController,
    required this.filtersExpanded,
    required this.onFiltersExpandedChanged,
    super.key,
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
                child: AmbientOrb(color: scheme.primary.withValues(alpha: 0.2)),
              ),
              Positioned(
                left: -76,
                bottom: -92,
                child: AmbientOrb(
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
                              child: DiscoveryFiltersPanel(
                                controller: controller,
                              ),
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
class DiscoveryFiltersPanel extends StatelessWidget {
  const DiscoveryFiltersPanel({required this.controller, super.key});

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

  // controller.cities/districts одоо сүүлийн ШҮҮЛТГҮЙ каталогоос тооцогддог
  // тул идэвхтэй сервер шүүлт 0 илэрцтэй болсон ч хоосрохгүй. Chip мөрийг
  // `hasCatalog`-оор харуулдаг нь шүүлтийг унтраах үед reload дуустал мөр
  // алга болохоос сэргийлнэ (дэлгэрэнгүйг DiscoveryController.hasCatalog).
  @override
  Widget build(BuildContext context) => BranchFilterPanel(
    city: controller.city,
    district: controller.district,
    cities: controller.cities,
    districts: controller.districts,
    onCityChanged: controller.setCity,
    onDistrictChanged: controller.setDistrict,
    tag: controller.tag,
    tagOptions: controller.tagOptions,
    onTagChanged: (id, name) => controller.setTag(id, name: name),
    nearMe: controller.nearMe,
    openNow: controller.openNow,
    weekend: controller.weekend,
    nearMePending: controller.nearMePending,
    openNowPending: controller.openNowPending,
    weekendPending: controller.weekendPending,
    onNearMeChanged: (selected) => _toggleNearMe(context, selected),
    onOpenNowChanged: controller.setOpenNow,
    onWeekendChanged: controller.setWeekend,
    showChips: controller.hasCatalog || controller.hasActiveFilters,
    leadingChips: [
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
          deleteButtonTooltipMessage: 'Хасах',
        ),
    ],
  );
}

/// Compact search + filters bar for map mode — a floating pill instead of
/// the list header's tall glass card, so the map underneath keeps most of
/// the screen.
class CompactDiscoveryBar extends StatelessWidget {
  const CompactDiscoveryBar({
    required this.controller,
    required this.searchController,
    required this.onOpenFilters,
    super.key,
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

class AmbientOrb extends StatelessWidget {
  const AmbientOrb({required this.color, this.size = 150, super.key});

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
