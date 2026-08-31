import 'package:carcare_customer_mobile/app/theme/app_theme.dart';
import 'package:carcare_customer_mobile/features/discovery/domain/organization.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class DiscoveryMap extends StatelessWidget {
  const DiscoveryMap({
    required this.organizations,
    required this.onOrganizationSelected,
    super.key,
  });

  final List<Organization> organizations;
  final ValueChanged<String> onOrganizationSelected;

  static const _ulaanbaatar = LatLng(47.918, 106.917);

  @override
  Widget build(BuildContext context) {
    final markers = <Marker>{};
    final positions = <LatLng>[];
    for (final organization in organizations) {
      for (final branch in organization.branches) {
        final latitude = branch.latitude;
        final longitude = branch.longitude;
        if (latitude == null || longitude == null) continue;
        final position = LatLng(latitude, longitude);
        positions.add(position);
        markers.add(
          Marker(
            markerId: MarkerId('${organization.slug}:${branch.id}'),
            position: position,
            infoWindow: InfoWindow(
              title: organization.name,
              snippet: '${branch.name} · ${branch.hours}',
              onTap: () => onOrganizationSelected(organization.slug),
            ),
            onTap: () {},
          ),
        );
      }
    }

    if (markers.isEmpty) {
      return const _NoMapLocations();
    }

    final initialTarget = positions.length == 1
        ? positions.first
        : _ulaanbaatar;
    return Container(
      height: 430,
      decoration: BoxDecoration(
        border: Border.all(color: CarCareTheme.of(context).glassBorder),
        borderRadius: BorderRadius.circular(AppRadii.large),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadii.large),
        child: GoogleMap(
          initialCameraPosition: CameraPosition(
            target: initialTarget,
            zoom: positions.length == 1 ? 14 : 11.5,
          ),
          markers: markers,
          mapToolbarEnabled: false,
          myLocationButtonEnabled: false,
          compassEnabled: false,
          zoomControlsEnabled: false,
          buildingsEnabled: false,
          rotateGesturesEnabled: false,
          tiltGesturesEnabled: false,
          minMaxZoomPreference: const MinMaxZoomPreference(5, 19),
        ),
      ),
    );
  }
}

class _NoMapLocations extends StatelessWidget {
  const _NoMapLocations();

  @override
  Widget build(BuildContext context) => Container(
    height: 280,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: CarCareTheme.of(context).glass,
      border: Border.all(color: CarCareTheme.of(context).glassBorder),
      borderRadius: BorderRadius.circular(AppRadii.large),
    ),
    child: const Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.location_off_outlined, size: 42),
        SizedBox(height: 12),
        Text('Газрын зурагт харуулах байршил алга'),
      ],
    ),
  );
}
