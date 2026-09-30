import 'dart:async';
import 'dart:math' as math;

import 'package:carcare_customer_mobile/app/theme/app_theme.dart';
import 'package:carcare_customer_mobile/features/discovery/domain/branch.dart';
import 'package:carcare_customer_mobile/features/discovery/domain/organization.dart';
import 'package:carcare_customer_mobile/features/discovery/presentation/controllers/organization_detail_controller.dart';
import 'package:carcare_customer_mobile/features/discovery/presentation/widgets/discovery_map_overlays.dart';
import 'package:carcare_customer_mobile/features/discovery/presentation/widgets/location_permission_banner.dart';
import 'package:carcare_customer_mobile/features/discovery/presentation/widgets/map_pin_icons.dart';
import 'package:carcare_customer_mobile/features/discovery/presentation/widgets/map_snapshot.dart';
import 'package:carcare_customer_mobile/features/discovery/presentation/widgets/selected_branch_card.dart';
import 'package:carcare_customer_mobile/features/discovery/services/device_location_service.dart';
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
  MapPinIcons? _pins;
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
    final pins = await loadMapPinIcons();
    if (!mounted) return;
    setState(() => _pins = pins);
  }

  // Everything derived from (organizations, selection, visible bounds, pins)
  // — the branch list, the pin positions, and the whole Marker set — is
  // rebuilt only when one of those inputs changes, not on every build (a
  // parent rebuild, detail-controller tick or load-state change repaints
  // the tree without re-deriving markers).
  MapSnapshot? _snapshot;
  List<Organization>? _snapshotOrganizations;
  ({Organization organization, Branch branch})? _snapshotSelected;
  LatLngBounds? _snapshotBounds;
  MapPinIcons? _snapshotPins;

  MapSnapshot _currentSnapshot() {
    final pins = _pins;
    final cached = _snapshot;
    if (cached != null &&
        identical(_snapshotOrganizations, widget.organizations) &&
        _snapshotSelected == _selected &&
        _snapshotBounds == _visibleBounds &&
        identical(_snapshotPins, pins)) {
      return cached;
    }
    final snapshot = buildMapSnapshot(
      organizations: widget.organizations,
      selected: _selected,
      visibleBounds: _visibleBounds,
      pins: pins,
      onMarkerTap: (organization, branch) {
        setState(
          () => _selected = (organization: organization, branch: branch),
        );
        widget.organizationDetailController.load(organization.slug);
      },
    );
    _snapshot = snapshot;
    _snapshotOrganizations = widget.organizations;
    _snapshotSelected = _selected;
    _snapshotBounds = _visibleBounds;
    _snapshotPins = pins;
    return snapshot;
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = _currentSnapshot();
    if (!snapshot.hasLocations) {
      return const NoMapLocations();
    }
    final positions = snapshot.positions;
    final visibleSelection = snapshot.visibleSelection;
    final markers = snapshot.markers;

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
                child: SelectedBranchCard(
                  organization: visibleSelection.organization,
                  branch: visibleSelection.branch,
                  detailController: widget.organizationDetailController,
                  onClose: _dismissSelection,
                  onDetails: () => widget.onBranchSelected(
                    visibleSelection.organization,
                    visibleSelection.branch,
                  ),
                ),
              ),
            if (_mapLoadState == _MapLoadState.loading)
              const Positioned.fill(child: MapLoadingOverlay()),
            if (_mapLoadState == _MapLoadState.failed)
              Positioned.fill(
                child: MapFailureOverlay(
                  onRetry: _retryMap,
                  onShowList: widget.onShowList,
                ),
              ),
            if (mapUnavailable)
              Positioned.fill(
                child: MapUnavailableOverlay(onShowList: widget.onShowList),
              ),
          ],
        ),
      ),
    );
  }
}

enum _MapLoadState { loading, ready, failed, unavailable }
