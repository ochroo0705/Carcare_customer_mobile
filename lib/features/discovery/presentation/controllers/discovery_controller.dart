import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:carcare_customer_mobile/core/errors/app_failure.dart';
import 'package:carcare_customer_mobile/data/cache/cache_store.dart';
import 'package:carcare_customer_mobile/features/discovery/domain/branch.dart';
import 'package:carcare_customer_mobile/features/discovery/domain/organization.dart';
import 'package:carcare_customer_mobile/features/discovery/domain/organization_repository.dart';
import 'package:carcare_customer_mobile/features/discovery/presentation/controllers/discovery_state.dart';

class _MapCoverage {
  const _MapCoverage({
    required this.filterKey,
    required this.north,
    required this.south,
    required this.east,
    required this.west,
  });

  factory _MapCoverage.from(MapViewport viewport, String filterKey) {
    final latitudeSpan = viewport.north - viewport.south;
    final north =
        (viewport.north + latitudeSpan * 0.3).clamp(-90.0, 90.0).toDouble();
    final south =
        (viewport.south - latitudeSpan * 0.3).clamp(-90.0, 90.0).toDouble();
    final longitudeSpan = _longitudeSpan(viewport);
    if (longitudeSpan * 1.3 >= 360) {
      return _MapCoverage(
        filterKey: filterKey,
        north: north,
        south: south,
        east: 180,
        west: -180,
      );
    }
    final center = _normalizeLongitude(
      _normalizeLongitude(viewport.west) + longitudeSpan / 2,
    );
    final halfSpan = longitudeSpan * 1.3 / 2;
    return _MapCoverage(
      filterKey: filterKey,
      north: north,
      south: south,
      east: _normalizeLongitude(center + halfSpan),
      west: _normalizeLongitude(center - halfSpan),
    );
  }

  final String filterKey;
  final double north;
  final double south;
  final double east;
  final double west;

  MapViewport get viewport => MapViewport(
        north: north,
        south: south,
        east: east,
        west: west,
      );

  bool contains(MapViewport viewport) {
    return viewport.south >= south && viewport.north <= north &&
        _longitudeContains(viewport.west, west, east) &&
        _longitudeContains(viewport.east, west, east);
  }
}

double _longitudeSpan(MapViewport viewport) {
  final span = viewport.east - viewport.west;
  return span >= 0 ? span : span + 360;
}

double _normalizeLongitude(double longitude) {
  var normalized = longitude;
  while (normalized > 180) normalized -= 360;
  while (normalized < -180) normalized += 360;
  return normalized;
}

bool _longitudeContains(double longitude, double west, double east) {
  final value = _normalizeLongitude(longitude);
  if (east >= west) return value >= west && value <= east;
  return value >= west || value <= east;
}
class DiscoveryController extends ChangeNotifier {
  DiscoveryController(this._repository, {CacheStore? cache})
    : _cache = cache ?? const NoopCacheStore();

  final OrganizationRepository _repository;
  final CacheStore _cache;
  DiscoveryState _state = const DiscoveryState();
  // Хамгийн сүүлд амжилттай ачаалсан ШҮҮЛТГҮЙ бүрэн каталог — cities/districts
  // сонголтуудыг үүнээс тооцно, `_state.organizations`-оос биш. Хэрэв тэднийг
  // (сервер) шүүлт идэвхтэй үед 0 илэрцтэй `_state.organizations`-оос тооцвол
  // сонголтын жагсаалт хоосорч, хот/дүүрэг шүүлтүүр бүхэлдээ алга болно (харах:
  // 2026-09-08 fix — "Амралтын өдөр ажилладаг" 0 илэрцтэй үед хот/дүүрэг мөн
  // алга болсон анхны репорт).
  List<Organization> _lastUnfiltered = const [];
  String _query = '';
  String _city = '';
  String _district = '';
  // Booking v2 серверийн шүүлт. Зай/эрэмбийн логик backend дээр — "ойролцоо"
  // асаахад координатыг серверт дамжуулж, салбар БҮРД distanceKm ирж, ойроор
  // эрэмбэлэгдэнэ (radius дамжуулахгүй тул юу ч хасахгүй). "Одоо нээлттэй" мөн
  // серверийн шүүлт (цаг/хуваарь list payload-д байхгүй).
  bool _nearMe = false;
  bool _openNow = false;
  bool _weekend = false;
  double? _lat;
  double? _lng;
  // Тухайн шүүлт байршил авах/дахин ачаалж буй эсэх (chip дээр spinner үзүүлэхэд).
  bool _nearMePending = false;
  bool _openNowPending = false;
  bool _weekendPending = false;
  Timer? _queryDebounce;
  Timer? _mapDebounce;
  int _requestGeneration = 0;
  int _mapGeneration = 0;
  String? _mapRequestKey;
  String? _mapInFlightKey;
  _MapCoverage? _mapCoverage;
  OrganizationMapPage _mapPage = const OrganizationMapPage(
    markers: [],
    count: 0,
    truncated: false,
    max: 500,
  );
  bool _mapLoading = false;
  bool _mapLoaded = false;
  String? _mapError;

  DiscoveryState get state => _state;
  String get query => _query;
  String get city => _city;
  String get district => _district;
  bool get nearMe => _nearMe;
  bool get openNow => _openNow;
  bool get weekend => _weekend;
  bool get nearMePending => _nearMePending;
  bool get openNowPending => _openNowPending;
  bool get weekendPending => _weekendPending;
  List<OrganizationMapMarker> get mapMarkers => _mapPage.markers;
  bool get mapLoading => _mapLoading;
  bool get mapLoaded => _mapLoaded;
  String? get mapError => _mapError;
  bool get mapTruncated => _mapPage.truncated;
  OrganizationFilter get currentFilter => _serverFilterForPage(1);
  bool get hasNextPage => _state.pagination.hasNext;
  /// Location snapshot used for the active near-me result. This is kept out of
  /// organization models because it belongs to the current discovery session.
  ({double lat, double lng})? get nearMeLocation =>
      _nearMe && _lat != null && _lng != null
          ? (lat: _lat!, lng: _lng!)
          : null;
  // Сүүлд ямар нэг өгөгдөл (шүүлтгүй) ачаалагдсан эсэх — chip мөрийг
  // харуулах эсэхэд ашиглана. `state.organizations`-аас ялгаатай нь энэ утга
  // reload-ын үед (`load()`-ийн шинэ хүсэлт хараахан дуусаагүй байхад)
  // өөрчлөгддөггүй, тул шүүлтийг унтраахад шинэ хариу ирэх хүртэл chip мөр
  // түр зуур алга болохгүй.
  bool get hasCatalog => _lastUnfiltered.isNotEmpty;
  bool get hasActiveFilters =>
      _query.isNotEmpty ||
      _city.isNotEmpty ||
      _district.isNotEmpty ||
      _nearMe ||
      _openNow ||
      _weekend;

  OrganizationFilter? get _serverFilter {
    // radius дамжуулахгүй — сервер бүх салбарт зай онооно, ойроор эрэмбэлнэ.
    if (_nearMe && _lat != null && _lng != null) {
      return OrganizationFilter(
        lat: _lat,
        lng: _lng,
        openNow: _openNow,
        weekend: _weekend,
      );
    }
    if (_openNow || _weekend) {
      return OrganizationFilter(openNow: _openNow, weekend: _weekend);
    }
    return null;
  }

  List<String> get cities {
    if (_state.facets.cities.isNotEmpty) return _state.facets.cities;
    final values = <String>{};
    for (final organization in _lastUnfiltered) {
      for (final branch in organization.branches) {
        if (branch.city.trim().isNotEmpty) values.add(branch.city.trim());
      }
    }
    return values.toList()..sort();
  }

  List<String> get districts {
    if (_state.facets.districts.isNotEmpty) return _state.facets.districts;
    final values = <String>{};
    for (final organization in _lastUnfiltered) {
      for (final branch in organization.branches) {
        if (_city.isNotEmpty && branch.city.trim() != _city) continue;
        if (branch.district.trim().isNotEmpty) {
          values.add(branch.district.trim());
        }
      }
    }
    return values.toList()..sort();
  }

  List<Organization> get visibleOrganizations {
    // Search and branch filters are applied by GET /orgs. The client only
    // presents the already-filtered page; filtering a page locally would make
    // pagination incomplete and could expose branches excluded by the API.
    return _state.organizations;
  }

  void setQuery(String value) {
    final next = value.trim();
    if (_query == next) return;
    _query = next;
    _invalidateCurrentResults();
    notifyListeners();
    _queryDebounce?.cancel();
    _queryDebounce = Timer(const Duration(milliseconds: 350), load);
  }

  void setCity(String? value) {
    final next = value?.trim() ?? '';
    if (_city == next) return;
    _city = next;
    _district = '';
    _invalidateCurrentResults();
    notifyListeners();
    load();
  }

  void setDistrict(String? value) {
    final next = value?.trim() ?? '';
    if (_district == next) return;
    _district = next;
    _invalidateCurrentResults();
    notifyListeners();
    load();
  }

  /// "Одоо нээлттэй" серверийн шүүлтийг асаах/унтраах — жагсаалтыг дахин ачаална.
  Future<void> setOpenNow(bool value) async {
    if (_openNow == value) return;
    _openNow = value;
    _invalidateMapForFilterChange();
    _openNowPending = true;
    notifyListeners();
    await load();
    _openNowPending = false;
    notifyListeners();
  }

  /// "Амралтын өдөр ажилладаг" серверийн шүүлтийг асаах/унтраах — жагсаалтыг
  /// дахин ачаална.
  Future<void> setWeekend(bool value) async {
    if (_weekend == value) return;
    _weekend = value;
    _invalidateMapForFilterChange();
    _weekendPending = true;
    notifyListeners();
    await load();
    _weekendPending = false;
    notifyListeners();
  }

  /// "Ойролцоо" серверийн шүүлт (координатыг backend дээр зай/эрэмбэд ашиглана).
  ///
  /// Optimistic: асаахад toggle-ийг ШУУД идэвхжүүлж (chip тэр даруй сонгогдоно),
  /// дараа нь [locate]-ээр координат авч жагсаалтыг дахин ачаална. Координат авч
  /// чадвал `true`, эс бөгөөс toggle-ийг буцааж унтрааж `false` буцаана.
  Future<bool> setNearMe(
    bool enabled, {
    Future<({double lat, double lng})?> Function()? locate,
  }) async {
    if (!enabled) {
      if (!_nearMe) return true;
      _nearMe = false;
      _lat = null;
      _lng = null;
      _invalidateMapForFilterChange();
      await load();
      return true;
    }
    // Optimistic — chip-ийг тэр даруй сонгогдсон харагдуулж, spinner асаана.
    _nearMe = true;
    _invalidateMapForFilterChange();
    _nearMePending = true;
    notifyListeners();
    final coords = await locate?.call();
    if (coords == null) {
      _nearMe = false;
      _invalidateMapForFilterChange();
      _nearMePending = false;
      notifyListeners();
      return false;
    }
    _lat = coords.lat;
    _lng = coords.lng;
    _invalidateMapForFilterChange();
    await load();
    _nearMePending = false;
    notifyListeners();
    return true;
  }

  void clearFilters() {
    if (!hasActiveFilters) return;
    _query = '';
    _city = '';
    _district = '';
    _nearMe = false;
    _openNow = false;
    _weekend = false;
    _lat = null;
    _lng = null;
    _invalidateMapForFilterChange();
    _queryDebounce?.cancel();
    _invalidateCurrentResults();
    notifyListeners();
    // Сервер шүүлт унтарсан бол шүүлтгүй жагсаалтыг дахин ачаална.
    load();
  }

  Future<void> load({bool append = false}) async {
    if (append && (_state.isLoadingMore || !_state.pagination.hasNext)) return;
    final generation = ++_requestGeneration;
    final filter = _serverFilterForPage(append ? _state.pagination.page + 1 : 1);
    if (append) {
      _state = DiscoveryState(
        status: DiscoveryStatus.data,
        organizations: _state.organizations,
        pagination: _state.pagination,
        facets: _state.facets,
        isFromCache: _state.isFromCache,
        isLoadingMore: true,
      );
      notifyListeners();
    } else {
      _state = DiscoveryState(
        status: DiscoveryStatus.loading,
        organizations: _state.organizations,
        pagination: _state.pagination,
        facets: _state.facets,
      );
      notifyListeners();
    }
    try {
      final result = await _repository.getOrganizations(filter: filter);
      if (generation != _requestGeneration) return;
      final organizations = append
          ? [..._state.organizations, ...result.organizations]
          : result.organizations;
      _state = DiscoveryState(
        status: organizations.isEmpty
            ? DiscoveryStatus.empty
            : DiscoveryStatus.data,
        organizations: organizations,
        pagination: result.pagination,
        facets: result.facets,
      );
      // Зөвхөн шүүлтгүй эхний хуудсыг offline cache-д хадгална (шүүсэн дэд
      // жагсаалт болон нэмэлт хуудсууд cache-ийг бохирдуулахгүй).
      if (!filter.hasTextFilters &&
          !filter.hasNearMe &&
          !filter.openNow &&
          !filter.weekend &&
          filter.page == 1) {
        await _cache.writeOrganizations(organizations);
        _lastUnfiltered = organizations;
      }
    } on AppFailure catch (failure) {
      if (generation != _requestGeneration) return;
      if (append) {
        _state = DiscoveryState(
          status: DiscoveryStatus.data,
          organizations: _state.organizations,
          pagination: _state.pagination,
          facets: _state.facets,
          loadMoreMessage: failure.message,
        );
      } else {
        _state = await _fallbackToCache(failure.message);
      }
    } catch (_) {
      if (generation != _requestGeneration) return;
      if (append) {
        _state = DiscoveryState(
          status: DiscoveryStatus.data,
          organizations: _state.organizations,
          pagination: _state.pagination,
          facets: _state.facets,
          loadMoreMessage: 'Тодорхойгүй алдаа гарлаа.',
        );
      } else {
        _state = await _fallbackToCache('Тодорхойгүй алдаа гарлаа.');
      }
    }
    notifyListeners();
  }

  Future<void> loadMore() => load(append: true);

  /// Map requests are independent of list pagination. Camera-idle events are
  /// debounced and generation-checked so a slow old viewport cannot repaint
  /// markers for a newer viewport or filter. Equivalent camera bounds are
  /// quantized and deduplicated; [force] is reserved for an explicit retry.
  void requestMapMarkers(MapViewport viewport, {bool force = false}) {
    final filter = currentFilter;
    final key = _mapRequestKeyFor(viewport, filter);
    final filterKey = _mapFilterKey(filter);
    final covered = _mapCoverage?.filterKey == filterKey &&
        _mapCoverage!.contains(viewport);
    if (!force &&
        (key == _mapRequestKey ||
            key == _mapInFlightKey ||
            covered)) {
      if (covered &&
          _mapLoaded &&
          _mapPage.markers.isNotEmpty &&
          _mapError != null) {
        _mapError = null;
        notifyListeners();
      }
      return;
    }
    _mapDebounce?.cancel();
    final generation = ++_mapGeneration;
    _mapInFlightKey = key;
    _mapError = null;
    notifyListeners();
    _mapDebounce = Timer(const Duration(milliseconds: 500), () async {
      if (generation != _mapGeneration) return;
      final coverage = _MapCoverage.from(viewport, filterKey);
      _mapLoading = true;
      notifyListeners();
      try {
        final result = await _repository.getMapMarkers(
          viewport: coverage.viewport,
          filter: filter,
        );
        if (generation != _mapGeneration) return;
        _mapPage = result;
        _mapLoaded = true;
        _mapLoading = false;
        _mapRequestKey = key;
        _mapInFlightKey = null;
        _mapCoverage = coverage;
      } on AppFailure catch (failure) {
        if (generation != _mapGeneration) return;
        _mapLoading = false;
        _mapError = failure.message;
        _mapRequestKey = key;
        _mapInFlightKey = null;
      } catch (_) {
        if (generation != _mapGeneration) return;
        _mapLoading = false;
        _mapError = 'Газрын зургийн цэгүүдийг ачаалж чадсангүй.';
        _mapRequestKey = key;
        _mapInFlightKey = null;
      }
      notifyListeners();
    });
  }

  String _mapRequestKeyFor(MapViewport viewport, OrganizationFilter filter) {
    // Google Maps can report tiny floating-point bound changes while markers
    // are being rebuilt. Four decimal places (~11m) is below the useful map
    // viewport precision and prevents those callbacks from refetching forever.
    int quantize(double value) => (value * 10000).round();
    return [
      quantize(viewport.north),
      quantize(viewport.south),
      quantize(viewport.east),
      quantize(viewport.west),
      _mapFilterKey(filter),
    ].join('|');
  }

  String _mapFilterKey(OrganizationFilter filter) => [
        filter.query,
        filter.city,
        filter.district,
        filter.lat == null ? '' : filter.lat,
        filter.lng == null ? '' : filter.lng,
        filter.radiusKm == null ? '' : filter.radiusKm,
        filter.openNow,
        filter.weekend,
      ].join('|');

  void _invalidateMapForFilterChange() {
    _mapGeneration++;
    _mapDebounce?.cancel();
    _mapRequestKey = null;
    _mapInFlightKey = null;
    _mapCoverage = null;
    _mapLoading = false;
    _mapError = null;
  }

  void _invalidateCurrentResults() {
    // Invalidate immediately, not only when the debounced request starts. A
    // slower previous response must never overwrite results for the new query
    // or be presented as if it matched the new city/district.
    _requestGeneration++;
    _invalidateMapForFilterChange();
    _state = DiscoveryState(
      status: DiscoveryStatus.loading,
      organizations: const [],
      pagination: _state.pagination,
      facets: _state.facets,
    );
  }

  OrganizationFilter _serverFilterForPage(int page) {
    final base = _serverFilter;
    return OrganizationFilter(
      query: _query,
      city: _city,
      district: _district,
      page: page,
      pageSize: 20,
      lat: base?.lat,
      lng: base?.lng,
      radiusKm: base?.radiusKm,
      openNow: _openNow,
      weekend: _weekend,
    );
  }

  @override
  void dispose() {
    _queryDebounce?.cancel();
    _mapDebounce?.cancel();
    super.dispose();
  }

  Organization? organizationBySlug(String slug) {
    for (final organization in _state.organizations) {
      if (organization.slug == slug) return organization;
    }
    return null;
  }

  Future<DiscoveryState> _fallbackToCache(String failureMessage) async {
    final cached = await _cache.readOrganizations();
    if (cached == null || cached.isEmpty) {
      return DiscoveryState(
        status: DiscoveryStatus.error,
        message: failureMessage,
      );
    }
    // Cache-д зөвхөн шүүлтгүй эхний хуудас бичигддэг (дээрх load()) тул
    // offline үед үүнийг сүүлд үзсэн каталогийн snapshot гэж үзнэ.
    _lastUnfiltered = cached;
    return DiscoveryState(
      status: DiscoveryStatus.data,
      organizations: cached,
      pagination: OrganizationPagination(
        page: 1,
        pageSize: cached.length,
        total: cached.length,
        totalPages: 1,
        hasPrev: false,
        hasNext: false,
      ),
      facets: OrganizationFacets(
        cities: cached.expand((o) => o.branches).map((b) => b.city).toSet().toList(),
        districts: cached.expand((o) => o.branches).map((b) => b.district).toSet().toList(),
      ),
      isFromCache: true,
      message: failureMessage,
    );
  }
}
