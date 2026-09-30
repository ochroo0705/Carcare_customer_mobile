import 'package:carcare_customer_mobile/features/discovery/domain/branch.dart';
import 'package:carcare_customer_mobile/features/discovery/domain/organization.dart';
import 'package:carcare_customer_mobile/features/discovery/presentation/map_location_limiter.dart';
import 'package:carcare_customer_mobile/features/discovery/presentation/widgets/map_pin_icons.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class MapSnapshot {
  const MapSnapshot({
    required this.hasLocations,
    required this.positions,
    required this.visibleSelection,
    required this.markers,
  });

  final bool hasLocations;
  final List<LatLng> positions;
  final ({Organization organization, Branch branch})? visibleSelection;
  final Set<Marker> markers;
}

class BranchMapLocation {
  const BranchMapLocation({
    required this.organization,
    required this.branch,
    required this.position,
    required this.selected,
  });

  final Organization organization;
  final Branch branch;
  final LatLng position;
  final bool selected;
}

MapSnapshot buildMapSnapshot({
  required List<Organization> organizations,
  required ({Organization organization, Branch branch})? selected,
  required LatLngBounds? visibleBounds,
  required MapPinIcons? pins,
  required void Function(Organization organization, Branch branch) onMarkerTap,
}) {
  final locations = <BranchMapLocation>[];
  final positions = <LatLng>[];
  ({Organization organization, Branch branch})? visibleSelection;
  for (final organization in organizations) {
    for (final branch in organization.branches) {
      final latitude = branch.latitude;
      final longitude = branch.longitude;
      if (latitude == null || longitude == null) continue;
      final position = LatLng(latitude, longitude);
      positions.add(position);
      final isSelected =
          selected?.organization.slug == organization.slug &&
          selected?.branch.id == branch.id;
      if (isSelected) {
        visibleSelection = (organization: organization, branch: branch);
      }
      locations.add(
        BranchMapLocation(
          organization: organization,
          branch: branch,
          position: position,
          selected: isSelected,
        ),
      );
    }
  }

  final bounds = visibleBounds;
  final displayedLocations = bounds == null
      ? locations.take(150).toList()
      : limitMapLocations(
          locations.map(
            (location) => MapLocationCandidate(
              value: location,
              latitude: location.position.latitude,
              longitude: location.position.longitude,
              selected: location.selected,
            ),
          ),
          south: bounds.southwest.latitude,
          north: bounds.northeast.latitude,
          west: bounds.southwest.longitude,
          east: bounds.northeast.longitude,
        );
  final markers = displayedLocations
      .map(
        (location) => Marker(
          markerId: MarkerId(
            '${location.organization.slug}:${location.branch.id}',
          ),
          position: location.position,
          anchor: const Offset(0.5, 1),
          icon: location.selected
              ? (pins?.selected ?? BitmapDescriptor.defaultMarker)
              : (pins?.closed ?? pins?.open ?? BitmapDescriptor.defaultMarker),
          zIndexInt: location.selected ? 1000 : 0,
          clusterManagerId: const ClusterManagerId('discovery'),
          infoWindow: InfoWindow.noText,
          onTap: () => onMarkerTap(location.organization, location.branch),
        ),
      )
      .toSet();

  return MapSnapshot(
    hasLocations: locations.isNotEmpty,
    positions: positions,
    visibleSelection: visibleSelection,
    markers: markers,
  );
}
