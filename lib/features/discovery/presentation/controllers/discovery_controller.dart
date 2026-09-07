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
  String _query = '';
  String _city = '';
  String _district = '';
  // Booking v2 серверийн шүүлт. Зай/эрэмбийн логик backend дээр — "ойролцоо"
  // асаахад координатыг серверт дамжуулж, салбар БҮРД distanceKm ирж, ойроор
  // эрэмбэлэгдэнэ (radius дамжуулахгүй тул юу ч хасахгүй). "Одоо нээлттэй" мөн
  // серверийн шүүлт (цаг/хуваарь list payload-д байхгүй).
  bool _nearMe = false;
  bool _openNow = false;
  double? _lat;
  double? _lng;
  // Тухайн шүүлт байршил авах/дахин ачаалж буй эсэх (chip дээр spinner үзүүлэхэд).
  bool _nearMePending = false;
  bool _openNowPending = false;

  DiscoveryState get state => _state;
  String get query => _query;
  String get city => _city;
  String get district => _district;
  bool get nearMe => _nearMe;
  bool get openNow => _openNow;
  bool get nearMePending => _nearMePending;
  bool get openNowPending => _openNowPending;
  bool get hasActiveFilters =>
      _query.isNotEmpty ||
      _city.isNotEmpty ||
      _district.isNotEmpty ||
      _nearMe ||
      _openNow;

  OrganizationFilter? get _serverFilter {
    // radius дамжуулахгүй — сервер бүх салбарт зай онооно, ойроор эрэмбэлнэ.
    if (_nearMe && _lat != null && _lng != null) {
      return OrganizationFilter(lat: _lat, lng: _lng, openNow: _openNow);
    }
    if (_openNow) return const OrganizationFilter(openNow: true);
    return null;
  }

  List<String> get cities {
    final values = <String>{};
    for (final organization in _state.organizations) {
      for (final branch in organization.branches) {
        if (branch.city.trim().isNotEmpty) values.add(branch.city.trim());
      }
    }
    return values.toList()..sort();
  }

  List<String> get districts {
    final values = <String>{};
    for (final organization in _state.organizations) {
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
    final normalizedQuery = _query.toLowerCase();
    final results = <Organization>[];
    for (final organization in _state.organizations) {
      final organizationMatches = organization.name.toLowerCase().contains(
        normalizedQuery,
      );
      final branches = organization.branches
          .where((branch) {
            if (_city.isNotEmpty && branch.city.trim() != _city) return false;
            if (_district.isNotEmpty && branch.district.trim() != _district) {
              return false;
            }
            if (normalizedQuery.isEmpty || organizationMatches) return true;
            return <String>[
              branch.name,
              branch.city,
              branch.district,
            ].any((value) => value.toLowerCase().contains(normalizedQuery));
          })
          .toList(growable: false);
      if (branches.isEmpty) continue;
      // Зай (distanceKm) болон ойрын эрэмбэ серверээс ирнэ — client дахин
      // эрэмбэлэхгүй (сервер аль хэдийн ойроор эрэмбэлсэн).
      results.add(
        Organization(
          slug: organization.slug,
          name: organization.name,
          logoUrl: organization.logoUrl,
          branches: branches,
        ),
      );
    }
    return results;
  }

  void setQuery(String value) {
    final next = value.trim();
    if (_query == next) return;
    _query = next;
    notifyListeners();
  }

  void setCity(String? value) {
    final next = value?.trim() ?? '';
    if (_city == next) return;
    _city = next;
    _district = '';
    notifyListeners();
  }

  void setDistrict(String? value) {
    final next = value?.trim() ?? '';
    if (_district == next) return;
    _district = next;
    notifyListeners();
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
    final hadServerFilter = _nearMe || _openNow;
    _query = '';
    _city = '';
    _district = '';
    _nearMe = false;
    _openNow = false;
    _lat = null;
    _lng = null;
    notifyListeners();
    // Сервер шүүлт унтарсан бол шүүлтгүй жагсаалтыг дахин ачаална.
    if (hadServerFilter) load();
  }

  Future<void> load() async {
    final filter = _serverFilter;
    _state = DiscoveryState(
      status: DiscoveryStatus.loading,
      organizations: _state.organizations,
    );
    notifyListeners();
    try {
      final organizations = await _repository.getOrganizations(filter: filter);
      _state = DiscoveryState(
        status: organizations.isEmpty
            ? DiscoveryStatus.empty
            : DiscoveryStatus.data,
        organizations: organizations,
      );
      // Зөвхөн шүүлтгүй бүрэн жагсаалтыг offline cache-д хадгална (шүүсэн дэд
      // жагсаалт cache-ийг бохирдуулахгүй).
      if (filter == null) await _cache.writeOrganizations(organizations);
    } on AppFailure catch (failure) {
      _state = await _fallbackToCache(failure.message);
    } catch (_) {
      _state = await _fallbackToCache('Тодорхойгүй алдаа гарлаа.');
    }
    notifyListeners();
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
    return DiscoveryState(
      status: DiscoveryStatus.data,
      organizations: cached,
      isFromCache: true,
      message: failureMessage,
    );
  }
}
