import 'dart:async';

import 'package:carcare_customer_mobile/core/errors/app_failure.dart';
import 'package:carcare_customer_mobile/data/cache/cache_store.dart';
import 'package:carcare_customer_mobile/features/discovery/domain/branch.dart';
import 'package:carcare_customer_mobile/features/discovery/domain/organization.dart';
import 'package:carcare_customer_mobile/features/discovery/domain/organization_repository.dart';
import 'package:carcare_customer_mobile/features/discovery/presentation/controllers/discovery_state.dart';
import 'package:flutter/foundation.dart';

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
  int _requestGeneration = 0;

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
      await load();
      return true;
    }
    // Optimistic — chip-ийг тэр даруй сонгогдсон харагдуулж, spinner асаана.
    _nearMe = true;
    _nearMePending = true;
    notifyListeners();
    final coords = await locate?.call();
    if (coords == null) {
      _nearMe = false;
      _nearMePending = false;
      notifyListeners();
      return false;
    }
    _lat = coords.lat;
    _lng = coords.lng;
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

  void _invalidateCurrentResults() {
    // Invalidate immediately, not only when the debounced request starts. A
    // slower previous response must never overwrite results for the new query
    // or be presented as if it matched the new city/district.
    _requestGeneration++;
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
