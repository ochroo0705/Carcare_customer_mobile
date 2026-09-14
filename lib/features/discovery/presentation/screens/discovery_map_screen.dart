import 'package:carcare_customer_mobile/features/discovery/domain/branch.dart';
import 'package:carcare_customer_mobile/features/discovery/domain/organization.dart';
import 'package:carcare_customer_mobile/features/discovery/domain/organization_repository.dart';
import 'package:carcare_customer_mobile/features/discovery/presentation/controllers/discovery_controller.dart';
import 'package:carcare_customer_mobile/features/discovery/presentation/controllers/organization_detail_controller.dart';
import 'package:carcare_customer_mobile/features/discovery/presentation/widgets/discovery_map.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';

/// Бүтэн дэлгэцийн газрын зураг — Explore-ийн жагсаалт дотор шигтгээгүй тул
/// одоо floating товчоор нээгддэг тусдаа хуудас. Дарсан цэгээс тухайн
/// салбарынхаа мэдээллийг web-тэй ижил байдлаар дэлгэнэ (`onBranchSelected`).
class DiscoveryMapScreen extends StatefulWidget {
  const DiscoveryMapScreen({
    required this.onBranchSelected,
    required this.onBack,
    super.key,
  });

  final void Function(Organization organization, Branch branch)
  onBranchSelected;
  final VoidCallback onBack;

  @override
  State<DiscoveryMapScreen> createState() => _DiscoveryMapScreenState();
}

class _DiscoveryMapScreenState extends State<DiscoveryMapScreen> {
  MapViewport? _lastViewport;

  void _viewportChanged(LatLngBounds bounds, DiscoveryController controller) {
    final viewport = MapViewport(
      north: bounds.northeast.latitude,
      south: bounds.southwest.latitude,
      east: bounds.northeast.longitude,
      west: bounds.southwest.longitude,
    );
    _lastViewport = viewport;
    controller.requestMapMarkers(viewport);
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<DiscoveryController>();
    final detailController = context.read<OrganizationDetailController>();
    final mapOrganizations = controller.mapLoaded
        ? controller.mapMarkers.map((marker) => marker.toOrganization()).toList()
        : controller.visibleOrganizations;
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: widget.onBack),
        title: const Text('Газрын зураг'),
      ),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Stack(
            children: [
              LayoutBuilder(
                builder: (context, constraints) => DiscoveryMap(
                  organizations: mapOrganizations,
                  hasActiveFilters: controller.hasActiveFilters,
                  height: constraints.maxHeight,
                  organizationDetailController: detailController,
                  onViewportChanged: (bounds) =>
                      _viewportChanged(bounds, controller),
                  onBranchSelected: widget.onBranchSelected,
                  onShowList: widget.onBack,
                ),
              ),
              if ((!controller.mapLoaded && controller.mapLoading) ||
                  (controller.mapError != null &&
                      (!controller.mapLoaded || controller.mapMarkers.isEmpty)))
                Positioned(
                  top: 10,
                  left: 10,
                  right: 10,
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          if (controller.mapLoading)
                            const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          if (controller.mapLoading) const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              controller.mapError ??
                                  'Газрын зургийн цэгүүдийг шинэчилж байна…',
                            ),
                          ),
                          if (controller.mapError != null &&
                              _lastViewport != null)
                            TextButton(
                              onPressed: () => controller.requestMapMarkers(
                                _lastViewport!,
                                force: true,
                              ),
                              child: const Text('Дахин оролдох'),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              if (controller.mapTruncated)
                const Positioned(
                  left: 10,
                  bottom: 10,
                  child: Chip(
                    label: Text('Зарим цэгийг нуусан. Газрын зургийг томруулна уу.'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
