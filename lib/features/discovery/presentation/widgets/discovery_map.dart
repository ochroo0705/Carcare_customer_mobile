import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:carcare_customer_mobile/app/theme/app_theme.dart';
import 'package:carcare_customer_mobile/features/discovery/domain/branch.dart';
import 'package:carcare_customer_mobile/features/discovery/domain/organization.dart';
import 'package:carcare_customer_mobile/features/discovery/presentation/map_location_limiter.dart';
import 'package:carcare_customer_mobile/features/discovery/presentation/widgets/location_permission_banner.dart';
import 'package:carcare_customer_mobile/features/discovery/services/location_permission_service.dart';
import 'package:carcare_customer_mobile/features/discovery/services/map_configuration_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class DiscoveryMap extends StatefulWidget {
  const DiscoveryMap({
    required this.organizations,
    this.hasActiveFilters = false,
    required this.onOrganizationSelected,
    required this.onShowList,
    this.locationPermissionService =
        const PermissionHandlerLocationPermissionService(),
    this.mapConfigurationService = const NativeMapConfigurationService(),
    super.key,
  });

  final List<Organization> organizations;
  final bool hasActiveFilters;
  final ValueChanged<String> onOrganizationSelected;
  final VoidCallback onShowList;
  final LocationPermissionService locationPermissionService;
  final MapConfigurationService mapConfigurationService;

  @override
  State<DiscoveryMap> createState() => _DiscoveryMapState();
}

class _DiscoveryMapState extends State<DiscoveryMap>
    with WidgetsBindingObserver {
  LocationAccessState? _locationAccessState;
  ({Organization organization, Branch branch})? _selected;
  BitmapDescriptor? _openPin;
  BitmapDescriptor? _closedPin;
  BitmapDescriptor? _selectedPin;
  String? _lightMapStyle;
  String? _darkMapStyle;
  Timer? _initializationTimer;
  _MapLoadState _mapLoadState = _MapLoadState.loading;
  int _mapInstance = 0;
  GoogleMapController? _mapController;
  LatLngBounds? _visibleBounds;

  static const _ulaanbaatar = LatLng(47.918, 106.917);

  static List<LatLng> _mapPositions(List<Organization> organizations) => [
    for (final organization in organizations)
      for (final branch in organization.branches)
        if (branch.latitude != null && branch.longitude != null)
          LatLng(branch.latitude!, branch.longitude!),
  ];

  static String _locationSignature(List<Organization> organizations) {
    final entries = [
      for (final organization in organizations)
        for (final branch in organization.branches)
          if (branch.latitude != null && branch.longitude != null)
            '${organization.slug}:${branch.id}:${branch.latitude}:${branch.longitude}',
    ];
    entries.sort();
    return entries.join('|');
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeMap();
  }

  @override
  void didUpdateWidget(covariant DiscoveryMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.hasActiveFilters == widget.hasActiveFilters &&
        _locationSignature(oldWidget.organizations) ==
            _locationSignature(widget.organizations)) {
      return;
    }
    _visibleBounds = null;
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _fitCameraToLocations(),
    );
  }

  Future<void> _initializeMap() async {
    final configured = await widget.mapConfigurationService.isConfigured();
    if (!mounted) return;
    if (!configured) {
      setState(() => _mapLoadState = _MapLoadState.unavailable);
      return;
    }
    _requestLocationPermission();
    _loadPinIcons();
    _loadMapStyles();
    _startInitializationTimer();
  }

  void _startInitializationTimer() {
    _initializationTimer?.cancel();
    _initializationTimer = Timer(const Duration(seconds: 12), () {
      if (!mounted || _mapLoadState == _MapLoadState.ready) return;
      setState(() => _mapLoadState = _MapLoadState.failed);
    });
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    _initializationTimer?.cancel();
    if (!mounted) return;
    setState(() => _mapLoadState = _MapLoadState.ready);
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _fitCameraToLocations(),
    );
  }

  void _retryMap() {
    if (_mapLoadState == _MapLoadState.unavailable) return;
    _mapController?.dispose();
    _mapController = null;
    setState(() {
      _mapLoadState = _MapLoadState.loading;
      _mapInstance++;
      _visibleBounds = null;
    });
    _startInitializationTimer();
  }

  Future<void> _loadMapStyles() async {
    final styles = await Future.wait([
      rootBundle.loadString('assets/maps/light.json'),
      rootBundle.loadString('assets/maps/dark.json'),
    ]);
    if (!mounted) return;
    setState(() {
      _lightMapStyle = styles[0];
      _darkMapStyle = styles[1];
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _initializationTimer?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        _locationAccessState != LocationAccessState.granted) {
      _checkLocationPermission();
    }
  }

  Future<void> _requestLocationPermission() async {
    final status = await widget.locationPermissionService.request();
    if (!mounted) return;
    setState(() => _locationAccessState = status);
  }

  Future<void> _checkLocationPermission() async {
    final status = await widget.locationPermissionService.check();
    if (!mounted) return;
    setState(() => _locationAccessState = status);
  }

  Future<void> _openLocationSettings() async {
    await widget.locationPermissionService.openSettings();
  }

  Future<void> _updateVisibleRegion() async {
    final controller = _mapController;
    if (controller == null || _mapLoadState != _MapLoadState.ready) return;
    try {
      final bounds = await controller.getVisibleRegion();
      if (!mounted) return;
      setState(() => _visibleBounds = bounds);
    } catch (_) {
      // The dependable list remains available if the native view disappears.
    }
  }

  Future<void> _fitCameraToLocations() async {
    final controller = _mapController;
    if (controller == null || _mapLoadState != _MapLoadState.ready) return;
    if (!widget.hasActiveFilters) {
      try {
        await controller.animateCamera(
          CameraUpdate.newLatLngZoom(_ulaanbaatar, 11.5),
        );
        await _updateVisibleRegion();
      } catch (_) {
        // The map remains usable at its existing viewport if fitting fails.
      }
      return;
    }
    final positions = _mapPositions(widget.organizations);
    if (positions.isEmpty) return;
    try {
      if (positions.length == 1) {
        await controller.animateCamera(
          CameraUpdate.newLatLngZoom(positions.single, 14),
        );
      } else {
        var south = positions.first.latitude;
        var north = south;
        var west = positions.first.longitude;
        var east = west;
        for (final position in positions.skip(1)) {
          south = math.min(south, position.latitude);
          north = math.max(north, position.latitude);
          west = math.min(west, position.longitude);
          east = math.max(east, position.longitude);
        }
        if (north - south < 0.01) {
          south -= 0.01;
          north += 0.01;
        }
        if (east - west < 0.01) {
          west -= 0.01;
          east += 0.01;
        }
        await controller.animateCamera(
          CameraUpdate.newLatLngBounds(
            LatLngBounds(
              southwest: LatLng(south, west),
              northeast: LatLng(north, east),
            ),
            52,
          ),
        );
      }
      await _updateVisibleRegion();
    } catch (_) {
      // The map remains usable at its existing viewport if fitting fails.
    }
  }

  Future<void> _loadPinIcons() async {
    final data = await rootBundle.load('assets/brand/mark.png');
    final codec = await ui.instantiateImageCodec(
      data.buffer.asUint8List(),
      targetWidth: 256,
    );
    final logo = (await codec.getNextFrame()).image;
    final icons = await Future.wait([
      _createPinIcon(logo, AppColors.green, selected: false),
      _createPinIcon(logo, const Color(0xFF9CA3AF), selected: false),
      _createPinIcon(logo, AppColors.amber, selected: true),
    ]);
    logo.dispose();
    codec.dispose();
    if (!mounted) return;
    setState(() {
      _openPin = icons[0];
      _closedPin = icons[1];
      _selectedPin = icons[2];
    });
  }

  Future<BitmapDescriptor> _createPinIcon(
    ui.Image logo,
    Color borderColor, {
    required bool selected,
  }) async {
    const pixelRatio = 2.0;
    final logicalWidth = selected ? 52.0 : 44.0;
    final logicalHeight = selected ? 64.0 : 54.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)..scale(pixelRatio);
    final center = Offset(logicalWidth / 2, logicalWidth / 2);
    final radius = selected ? 21.5 : 18.5;
    final strokeWidth = selected ? 3.5 : 3.0;

    final tail = Path()
      ..moveTo(center.dx - 7, center.dy + radius - 3)
      ..lineTo(center.dx + 7, center.dy + radius - 3)
      ..lineTo(center.dx, logicalHeight - 2)
      ..close();
    canvas.drawShadow(tail, Colors.black, 5, true);
    canvas.drawPath(tail, Paint()..color = borderColor);

    final badge = Path()
      ..addOval(Rect.fromCircle(center: center, radius: radius + strokeWidth));
    canvas.drawShadow(badge, Colors.black, 5, true);
    canvas.drawCircle(
      center,
      radius + strokeWidth,
      Paint()..color = borderColor,
    );
    canvas.drawCircle(center, radius, Paint()..color = Colors.white);

    final logoRect = Rect.fromCircle(center: center, radius: radius * 0.58);
    canvas.drawImageRect(
      logo,
      Rect.fromLTWH(0, 0, logo.width.toDouble(), logo.height.toDouble()),
      logoRect,
      Paint()..filterQuality = FilterQuality.high,
    );

    final image = await recorder.endRecording().toImage(
      (logicalWidth * pixelRatio).round(),
      (logicalHeight * pixelRatio).round(),
    );
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    if (bytes == null) throw StateError('Could not render map pin');
    return BitmapDescriptor.bytes(
      bytes.buffer.asUint8List(),
      imagePixelRatio: pixelRatio,
    );
  }

  @override
  Widget build(BuildContext context) {
    final locations = <_BranchMapLocation>[];
    final positions = <LatLng>[];
    ({Organization organization, Branch branch})? visibleSelection;
    for (final organization in widget.organizations) {
      for (final branch in organization.branches) {
        final latitude = branch.latitude;
        final longitude = branch.longitude;
        if (latitude == null || longitude == null) continue;
        final position = LatLng(latitude, longitude);
        positions.add(position);
        final isSelected =
            _selected?.organization.slug == organization.slug &&
            _selected?.branch.id == branch.id;
        if (isSelected) {
          visibleSelection = (organization: organization, branch: branch);
        }
        locations.add(
          _BranchMapLocation(
            organization: organization,
            branch: branch,
            position: position,
            selected: isSelected,
          ),
        );
      }
    }

    if (locations.isEmpty) {
      return const _NoMapLocations();
    }

    final bounds = _visibleBounds;
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
                ? (_selectedPin ?? BitmapDescriptor.defaultMarker)
                : (_closedPin ?? _openPin ?? BitmapDescriptor.defaultMarker),
            zIndexInt: location.selected ? 1000 : 0,
            infoWindow: InfoWindow.noText,
            onTap: () => setState(
              () => _selected = (
                organization: location.organization,
                branch: location.branch,
              ),
            ),
          ),
        )
        .toSet();

    final initialTarget = positions.length == 1
        ? positions.first
        : _ulaanbaatar;
    final mapUnavailable = _mapLoadState == _MapLoadState.unavailable;
    return Container(
      height: 430,
      decoration: BoxDecoration(
        border: Border.all(color: CarCareTheme.of(context).glassBorder),
        borderRadius: BorderRadius.circular(AppRadii.large),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadii.large),
        child: Stack(
          children: [
            if (!mapUnavailable)
              Semantics(
                container: true,
                label: 'Сервисийн байршлын интерактив газрын зураг',
                child: GoogleMap(
                  key: ValueKey('discovery-map-$_mapInstance'),
                  onMapCreated: _onMapCreated,
                  onCameraIdle: _updateVisibleRegion,
                  style: Theme.of(context).brightness == Brightness.dark
                      ? _darkMapStyle
                      : _lightMapStyle,
                  initialCameraPosition: CameraPosition(
                    target: initialTarget,
                    zoom: positions.length == 1 ? 14 : 11.5,
                  ),
                  markers: markers,
                  padding: EdgeInsets.only(
                    top: _locationAccessState == LocationAccessState.granted
                        ? 0
                        : 68,
                  ),
                  gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
                    Factory<EagerGestureRecognizer>(EagerGestureRecognizer.new),
                  },
                  mapToolbarEnabled: false,
                  myLocationEnabled:
                      _locationAccessState == LocationAccessState.granted,
                  myLocationButtonEnabled:
                      _locationAccessState == LocationAccessState.granted,
                  compassEnabled: false,
                  scrollGesturesEnabled: true,
                  zoomControlsEnabled: true,
                  buildingsEnabled: false,
                  rotateGesturesEnabled: false,
                  tiltGesturesEnabled: false,
                  minMaxZoomPreference: const MinMaxZoomPreference(5, 19),
                ),
              ),
            if (_mapLoadState == _MapLoadState.ready &&
                _locationAccessState != null &&
                _locationAccessState != LocationAccessState.granted)
              Positioned(
                top: 10,
                left: 10,
                right: 10,
                child: LocationPermissionBanner(
                  state: _locationAccessState!,
                  onRequest: _requestLocationPermission,
                  onOpenSettings: _openLocationSettings,
                ),
              ),
            if (visibleSelection != null)
              Positioned(
                left: 10,
                right: 10,
                bottom: 10,
                child: _SelectedBranchCard(
                  organization: visibleSelection.organization,
                  branch: visibleSelection.branch,
                  onClose: () => setState(() => _selected = null),
                  onDetails: () => widget.onOrganizationSelected(
                    visibleSelection!.organization.slug,
                  ),
                ),
              ),
            if (_mapLoadState == _MapLoadState.loading)
              const Positioned.fill(child: _MapLoadingOverlay()),
            if (_mapLoadState == _MapLoadState.failed)
              Positioned.fill(
                child: _MapFailureOverlay(
                  onRetry: _retryMap,
                  onShowList: widget.onShowList,
                ),
              ),
            if (mapUnavailable)
              Positioned.fill(
                child: _MapUnavailableOverlay(onShowList: widget.onShowList),
              ),
          ],
        ),
      ),
    );
  }
}

enum _MapLoadState { loading, ready, failed, unavailable }

class _BranchMapLocation {
  const _BranchMapLocation({
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

class _MapLoadingOverlay extends StatelessWidget {
  const _MapLoadingOverlay();

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    liveRegion: true,
    label: 'Газрын зураг ачаалж байна',
    child: ColoredBox(
      color: Theme.of(context).colorScheme.surface,
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 14),
            Text('Газрын зураг ачаалж байна…'),
          ],
        ),
      ),
    ),
  );
}

class _MapFailureOverlay extends StatelessWidget {
  const _MapFailureOverlay({required this.onRetry, required this.onShowList});

  final VoidCallback onRetry;
  final VoidCallback onShowList;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    liveRegion: true,
    label: 'Газрын зураг ачаалсангүй',
    child: ColoredBox(
      color: Theme.of(context).colorScheme.surface,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.map_outlined,
                size: 48,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 14),
              Text(
                'Газрын зураг ачаалсангүй',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 7),
              Text(
                'Сервисүүдийг жагсаалтаар харах эсвэл дахин оролдоно уу.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                key: const ValueKey('map-show-list'),
                onPressed: onShowList,
                icon: const Icon(Icons.view_list_outlined),
                label: const Text('Жагсаалтаар харах'),
              ),
              TextButton.icon(
                key: const ValueKey('map-retry'),
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Дахин оролдох'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _MapUnavailableOverlay extends StatelessWidget {
  const _MapUnavailableOverlay({required this.onShowList});

  final VoidCallback onShowList;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    liveRegion: true,
    label: 'Газрын зураг энэ хувилбарт тохируулагдаагүй байна',
    child: ColoredBox(
      color: Theme.of(context).colorScheme.surface,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.map_outlined,
                size: 48,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 14),
              Text(
                'Газрын зураг ашиглах боломжгүй байна',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 7),
              Text(
                'Энэ хувилбарт газрын зургийн тохиргоо дутуу байна. Сервисүүдийг жагсаалтаар харна уу.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                key: const ValueKey('map-unavailable-show-list'),
                onPressed: onShowList,
                icon: const Icon(Icons.view_list_outlined),
                label: const Text('Жагсаалтаар харах'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _SelectedBranchCard extends StatelessWidget {
  const _SelectedBranchCard({
    required this.organization,
    required this.branch,
    required this.onClose,
    required this.onDetails,
  });

  final Organization organization;
  final Branch branch;
  final VoidCallback onClose;
  final VoidCallback onDetails;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface,
      elevation: 12,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 360),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: CarCareTheme.of(context).glassBorder,
                      ),
                    ),
                    child: Image.asset('assets/brand/mark.png'),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          organization.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        Text(
                          branch.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: onClose,
                    tooltip: 'Хаах',
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _CardDetail(
                icon: Icons.place_outlined,
                text: branch.locationLabel,
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: onDetails,
                  icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                  label: const Text('Дэлгэрэнгүй'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CardDetail extends StatelessWidget {
  const _CardDetail({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(
        icon,
        size: 17,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          text,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ),
    ],
  );
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
