import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:carcare_customer_mobile/app/theme/app_theme.dart';
import 'package:carcare_customer_mobile/features/discovery/domain/branch.dart';
import 'package:carcare_customer_mobile/features/discovery/domain/organization.dart';
import 'package:carcare_customer_mobile/features/discovery/presentation/controllers/organization_detail_controller.dart';
import 'package:carcare_customer_mobile/features/discovery/presentation/map_location_limiter.dart';
import 'package:carcare_customer_mobile/features/discovery/presentation/widgets/location_permission_banner.dart';
import 'package:carcare_customer_mobile/features/discovery/services/device_location_service.dart';
import 'package:carcare_customer_mobile/features/discovery/services/location_permission_service.dart';
import 'package:carcare_customer_mobile/features/discovery/services/map_configuration_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class DiscoveryMap extends StatefulWidget {
  const DiscoveryMap({
    required this.organizations,
    this.hasActiveFilters = false,
    required this.onBranchSelected,
    required this.onShowList,
    required this.organizationDetailController,
    this.onViewportChanged,
    this.refitSignal,
    this.height = 430,
    this.showLocationBanner = true,
    this.onLocationAccessChanged,
    this.locationPermissionService =
        const PermissionHandlerLocationPermissionService(),
    this.mapConfigurationService = const NativeMapConfigurationService(),
    this.deviceLocationService = const GeolocatorDeviceLocationService(),
    super.key,
  });

  final List<Organization> organizations;
  final bool hasActiveFilters;
  final void Function(Organization organization, Branch branch)
  onBranchSelected;
  final VoidCallback onShowList;
  // Пин дарахад дэлгэрэнгүй (цаг/хаяг/утас/ангилал) картыг web-тэй ижил
  // түвшинд харуулахын тулд тухайн байгууллагын дэлгэрэнгүйг цөөнгүй
  // ачаална — жагсаалтын `Organization`/`Branch`-д эдгээр талбар алга.
  final OrganizationDetailController organizationDetailController;
  final ValueChanged<LatLngBounds>? onViewportChanged;
  // Bumping this (e.g. DiscoveryController.mapRefitSignal) tells the map a
  // search/filter change just produced new results, so it should recenter
  // on them even though [onViewportChanged] otherwise disables auto-fit to
  // avoid fighting the user's own panning/zooming.
  final int? refitSignal;
  final double height;
  // A parent with its own top overlay (the discovery screen's floating
  // search bar) sets this false and renders [LocationPermissionBanner]
  // itself, below that overlay, driven by [onLocationAccessChanged] and
  // [DiscoveryMapState.requestLocationPermission] / [openLocationSettings].
  final bool showLocationBanner;
  final ValueChanged<LocationAccessState>? onLocationAccessChanged;
  final LocationPermissionService locationPermissionService;
  final MapConfigurationService mapConfigurationService;
  final DeviceLocationService deviceLocationService;

  @override
  State<DiscoveryMap> createState() => DiscoveryMapState();
}

/// Public so a parent screen can drive zoom/locate-me from its own custom
/// buttons (e.g. a combined bottom-right control stack) via a `GlobalKey`,
/// instead of Google Maps' own platform controls, which can't be
/// repositioned or restyled.
class DiscoveryMapState extends State<DiscoveryMap>
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
    widget.organizationDetailController.addListener(_handleDetailChanged);
    _initializeMap();
  }

  void _handleDetailChanged() {
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(covariant DiscoveryMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.refitSignal != null &&
        widget.refitSignal != oldWidget.refitSignal) {
      _visibleBounds = null;
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _fitCameraToLocations(),
      );
      return;
    }
    // Viewport-backed marker responses are otherwise incremental data
    // updates (plain panning/zooming). Fitting here would recenter the
    // camera after every response and trigger another camera-idle request
    // indefinitely.
    if (widget.onViewportChanged != null) return;
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
    // Check only — onboarding already offered the prompt. Asking again here
    // would spend iOS's single prompt (and one of Android's two) on a user
    // who just skipped it; the banner and locate-me ask on an explicit tap.
    _checkLocationPermission();
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
    widget.organizationDetailController.removeListener(_handleDetailChanged);
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

  Future<void> requestLocationPermission() async {
    _setLocationAccess(await widget.locationPermissionService.request());
  }

  Future<void> _checkLocationPermission() async {
    _setLocationAccess(await widget.locationPermissionService.check());
  }

  void _setLocationAccess(LocationAccessState status) {
    if (!mounted) return;
    setState(() => _locationAccessState = status);
    widget.onLocationAccessChanged?.call(status);
  }

  Future<void> openLocationSettings() async {
    await widget.locationPermissionService.openSettings();
  }

  void zoomIn() => _mapController?.animateCamera(CameraUpdate.zoomIn());

  void zoomOut() => _mapController?.animateCamera(CameraUpdate.zoomOut());

  /// Stand-in for Google Maps' own locate-me button, which (like the zoom
  /// control) is pinned by the platform and can't be moved or restyled.
  Future<void> locateMe() async {
    final controller = _mapController;
    if (controller == null) return;
    // current() prompts if still undecided; re-read the result so the
    // banner and blue dot follow whatever the user just chose.
    final location = await widget.deviceLocationService.current();
    if (!mounted) return;
    await _checkLocationPermission();
    if (location == null || !mounted) return;
    await controller.animateCamera(
      CameraUpdate.newLatLngZoom(LatLng(location.lat, location.lng), 15),
    );
  }

  Future<void> _updateVisibleRegion() async {
    final controller = _mapController;
    if (controller == null || _mapLoadState != _MapLoadState.ready) return;
    try {
      final bounds = await controller.getVisibleRegion();
      if (!mounted) return;
      setState(() => _visibleBounds = bounds);
      widget.onViewportChanged?.call(bounds);
    } catch (_) {
      // The dependable list remains available if the native view disappears.
    }
  }

  /// Сонгосон салбарын картыг хаана. Газрын зураг дээрх хоосон хэсэгт
  /// хүрэхэд (`GoogleMap.onTap`) болон картын өөрийн хаах товчинд хоёуланд
  /// хэрэглэгдэнэ. `onTap` нь пин эсвэл кластер дээрх хүрэлтэнд ажиллахгүй
  /// тул өөр пин дарахад карт хаагдалгүй тэр салбар руу шилжинэ.
  void _dismissSelection() {
    if (_selected == null) return;
    setState(() => _selected = null);
  }

  Future<void> _handleClusterTap(Cluster cluster) async {
    final controller = _mapController;
    if (controller == null || _mapLoadState != _MapLoadState.ready) return;
    final bounds = cluster.bounds;
    final latitudeSpan = (bounds.northeast.latitude - bounds.southwest.latitude)
        .abs();
    final longitudeDelta =
        bounds.northeast.longitude - bounds.southwest.longitude;
    final longitudeSpan = longitudeDelta >= 0
        ? longitudeDelta
        : longitudeDelta + 360;
    try {
      // Native bounds can collapse to a point when several branches share
      // coordinates. In that case, zoom in by a bounded increment instead of
      // asking the map to fit a zero-area LatLngBounds forever.
      if (latitudeSpan < 0.0001 && longitudeSpan < 0.0001) {
        final zoom = await controller.getZoomLevel();
        if (zoom >= 19) return;
        await controller.animateCamera(
          CameraUpdate.newLatLngZoom(
            cluster.position,
            (zoom + 2).clamp(0, 19).toDouble(),
          ),
        );
        return;
      }
      await controller.animateCamera(CameraUpdate.newLatLngBounds(bounds, 72));
    } catch (_) {
      // Keep the current map usable if a native camera update races map teardown.
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
      _createPinIcon(logo, AppColors.accent, selected: true),
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
            clusterManagerId: const ClusterManagerId('discovery'),
            infoWindow: InfoWindow.noText,
            onTap: () {
              setState(
                () => _selected = (
                  organization: location.organization,
                  branch: location.branch,
                ),
              );
              widget.organizationDetailController.load(
                location.organization.slug,
              );
            },
          ),
        )
        .toSet();

    final initialTarget = positions.length == 1
        ? positions.first
        : _ulaanbaatar;
    final mapUnavailable = _mapLoadState == _MapLoadState.unavailable;
    return Container(
      height: widget.height,
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
                  onTap: (_) => _dismissSelection(),
                  style: Theme.of(context).brightness == Brightness.dark
                      ? _darkMapStyle
                      : _lightMapStyle,
                  initialCameraPosition: CameraPosition(
                    target: initialTarget,
                    zoom: positions.length == 1 ? 14 : 11.5,
                  ),
                  markers: markers,
                  clusterManagers: <ClusterManager>{
                    ClusterManager(
                      clusterManagerId: ClusterManagerId('discovery'),
                      onClusterTap: _handleClusterTap,
                    ),
                  },
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
                  // Same story as zoomControlsEnabled — pinned bottom-right
                  // by the platform, replaced by a custom button.
                  myLocationButtonEnabled: false,
                  compassEnabled: false,
                  scrollGesturesEnabled: true,
                  // The platform's own zoom control is pinned to the
                  // bottom-right by the SDK — no padding/position knob
                  // moves it, and that corner is where the shell's map/list
                  // toggle FAB sits. Use our own buttons instead, placed
                  // wherever fits.
                  zoomControlsEnabled: false,
                  buildingsEnabled: false,
                  rotateGesturesEnabled: false,
                  tiltGesturesEnabled: false,
                  minMaxZoomPreference: const MinMaxZoomPreference(5, 19),
                ),
              ),
            if (widget.showLocationBanner &&
                _mapLoadState == _MapLoadState.ready &&
                _locationAccessState != null &&
                _locationAccessState != LocationAccessState.granted)
              Positioned(
                top: 10,
                left: 10,
                right: 10,
                child: LocationPermissionBanner(
                  state: _locationAccessState!,
                  onRequest: requestLocationPermission,
                  onOpenSettings: openLocationSettings,
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
                  detailController: widget.organizationDetailController,
                  onClose: _dismissSelection,
                  onDetails: () => widget.onBranchSelected(
                    visibleSelection!.organization,
                    visibleSelection.branch,
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

/// Пин дарахад гарч ирэх карт — web-ийн газрын зураг дээрх карттай ижил
/// түвшний мэдээлэл (лого, нээлттэй/хаалттай төлөв + цаг, хаяг, утас,
/// ангилалууд) харуулахын тулд тухайн байгууллагын дэлгэрэнгүйг (`detailController`)
/// цөөнгүй ачаалж, ирэх хүртэл зөвхөн жагсаалтаас аль хэдийн байгаа
/// нэр/зай мэдээллийг харуулна.
/// This card is a quick preview meant to fit alongside the map — it shows a
/// handful of categories plus a "+N" count rather than every single one
/// (unlike the organization detail page, which has room for the full list).
const _maxPreviewCategories = 4;

class _SelectedBranchCard extends StatelessWidget {
  const _SelectedBranchCard({
    required this.organization,
    required this.branch,
    required this.detailController,
    required this.onClose,
    required this.onDetails,
  });

  final Organization organization;
  final Branch branch;
  final OrganizationDetailController detailController;
  final VoidCallback onClose;
  final VoidCallback onDetails;

  BranchDetail? _matchingBranch(OrganizationDetail detail) {
    for (final candidate in detail.branches) {
      if (candidate.id == branch.id) return candidate;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final detail = detailController.organization;
    final detailMatches = detail != null && detail.slug == organization.slug;
    final loadingDetail =
        detailController.status == OrganizationDetailStatus.loading &&
        !detailMatches;
    final branchDetail = detailMatches ? _matchingBranch(detail) : null;
    return Material(
      color: scheme.surface,
      elevation: 12,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 420),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _CardLogo(organization: organization),
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
                        if (branchDetail != null) ...[
                          const SizedBox(height: 6),
                          _OpenStatusLine(branch: branchDetail),
                        ],
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
              if (branch.distanceLabel != null) ...[
                _CardDetail(
                  icon: Icons.near_me_outlined,
                  text: branch.distanceLabel!,
                ),
                const SizedBox(height: 6),
              ],
              _CardDetail(
                icon: Icons.place_outlined,
                text: branchDetail?.fullAddress ?? branch.locationLabel,
              ),
              if (branchDetail != null) ...[
                const SizedBox(height: 6),
                _CardDetail(
                  icon: Icons.schedule_rounded,
                  text: branchDetail.hoursLabel,
                ),
              ],
              if (detail?.phone != null) ...[
                const SizedBox(height: 6),
                _PhoneLine(phone: detail!.phone!),
              ],
              if (loadingDetail) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Дэлгэрэнгүй ачаалж байна…',
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ],
              if (branchDetail != null &&
                  branchDetail.categories.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    // Quick preview card: a taste of what's offered, not the
                    // full list — that's what the detail page is for.
                    for (final category in branchDetail.categories.take(
                      _maxPreviewCategories,
                    ))
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainer,
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Text(
                          category.name,
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      ),
                    if (branchDetail.categories.length > _maxPreviewCategories)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainer,
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Text(
                          '+${branchDetail.categories.length - _maxPreviewCategories}',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ),
                  ],
                ),
              ],
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

class _CardLogo extends StatelessWidget {
  const _CardLogo({required this.organization});

  final Organization organization;

  @override
  Widget build(BuildContext context) {
    final letter = Center(
      child: Text(
        organization.name.characters.isEmpty
            ? '?'
            : organization.name.characters.first.toUpperCase(),
        style: Theme.of(context).textTheme.titleMedium
            ?.copyWith(fontWeight: FontWeight.w800),
      ),
    );
    final logoUrl = organization.logoUrl?.trim();
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: CarCareTheme.of(context).glassBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: logoUrl == null || logoUrl.isEmpty
          ? letter
          : CachedNetworkImage(
              imageUrl: logoUrl,
              fit: BoxFit.cover,
              placeholder: (_, _) => letter,
              errorWidget: (_, _, _) => letter,
            ),
    );
  }
}

class _OpenStatusLine extends StatelessWidget {
  const _OpenStatusLine({required this.branch});

  final BranchDetail branch;

  @override
  Widget build(BuildContext context) {
    final status = branch.openStatusAt(DateTime.now());
    final color = switch (status) {
      BranchOpenStatus.open => AppColors.green,
      BranchOpenStatus.closed => Theme.of(context).colorScheme.error,
      BranchOpenStatus.unknown => Theme.of(
        context,
      ).colorScheme.onSurfaceVariant,
    };
    final label = switch (status) {
      BranchOpenStatus.open => 'Нээлттэй',
      BranchOpenStatus.closed => 'Хаалттай',
      BranchOpenStatus.unknown => 'Төлөв тодорхойгүй',
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall
              ?.copyWith(color: color, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

class _PhoneLine extends StatelessWidget {
  const _PhoneLine({required this.phone});

  final String phone;

  Future<void> _call() async {
    final uri = Uri(scheme: 'tel', path: phone);
    await launchUrl(uri);
  }

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: _call,
    borderRadius: BorderRadius.circular(8),
    child: Row(
      children: [
        Icon(
          Icons.phone_outlined,
          size: 17,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            phone,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );
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
