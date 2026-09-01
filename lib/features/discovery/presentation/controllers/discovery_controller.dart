import 'dart:convert';

import 'package:carcare_customer_mobile/core/errors/app_failure.dart';
import 'package:carcare_customer_mobile/features/discovery/domain/branch.dart';
import 'package:carcare_customer_mobile/features/discovery/domain/organization.dart';
import 'package:carcare_customer_mobile/features/discovery/domain/organization_repository.dart';
import 'package:carcare_customer_mobile/features/discovery/presentation/controllers/discovery_state.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DiscoveryController extends ChangeNotifier {
  DiscoveryController(this._repository);

  static const _cacheKey = 'discovery_organizations_cache_v1';

  final OrganizationRepository _repository;
  DiscoveryState _state = const DiscoveryState();
  String _query = '';
  String _city = '';
  String _district = '';

  DiscoveryState get state => _state;
  String get query => _query;
  String get city => _city;
  String get district => _district;
  bool get hasActiveFilters =>
      _query.isNotEmpty || _city.isNotEmpty || _district.isNotEmpty;

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

  void clearFilters() {
    if (!hasActiveFilters) return;
    _query = '';
    _city = '';
    _district = '';
    notifyListeners();
  }

  Future<void> load() async {
    _state = DiscoveryState(
      status: DiscoveryStatus.loading,
      organizations: _state.organizations,
    );
    notifyListeners();
    try {
      final organizations = await _repository.getOrganizations();
      _state = DiscoveryState(
        status: organizations.isEmpty
            ? DiscoveryStatus.empty
            : DiscoveryStatus.data,
        organizations: organizations,
      );
      await _saveCache(organizations);
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
    final cached = await _readCache();
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

  Future<void> _saveCache(List<Organization> organizations) async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final json = jsonEncode(organizations.map(_organizationToJson).toList());
      await preferences.setString(_cacheKey, json);
    } catch (_) {
      // Persisting the cache is a best-effort convenience; a write failure
      // here must never surface as a load failure.
    }
  }

  Future<List<Organization>?> _readCache() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final raw = preferences.getString(_cacheKey);
      if (raw == null) return null;
      final decoded = jsonDecode(raw);
      if (decoded is! List) return null;
      final organizations = decoded
          .map(_organizationFromJson)
          .whereType<Organization>()
          .toList();
      return organizations.isEmpty ? null : organizations;
    } catch (_) {
      return null;
    }
  }
}

Map<String, dynamic> _organizationToJson(Organization organization) => {
  'slug': organization.slug,
  'name': organization.name,
  'logoUrl': organization.logoUrl,
  'branches': organization.branches.map(_branchToJson).toList(),
};

Map<String, dynamic> _branchToJson(Branch branch) => {
  'id': branch.id,
  'name': branch.name,
  'city': branch.city,
  'district': branch.district,
  'latitude': branch.latitude,
  'longitude': branch.longitude,
};

Organization? _organizationFromJson(Object? value) {
  if (value is! Map) return null;
  final slug = value['slug'];
  final name = value['name'];
  final branchesRaw = value['branches'];
  if (slug is! String || name is! String || branchesRaw is! List) return null;
  return Organization(
    slug: slug,
    name: name,
    logoUrl: value['logoUrl'] is String ? value['logoUrl'] as String : null,
    branches: branchesRaw
        .map(_branchFromJson)
        .whereType<Branch>()
        .toList(growable: false),
  );
}

Branch? _branchFromJson(Object? value) {
  if (value is! Map) return null;
  final id = value['id'];
  final name = value['name'];
  final city = value['city'];
  final district = value['district'];
  if (id is! String ||
      name is! String ||
      city is! String ||
      district is! String) {
    return null;
  }
  return Branch(
    id: id,
    name: name,
    city: city,
    district: district,
    latitude: value['latitude'] is num
        ? (value['latitude'] as num).toDouble()
        : null,
    longitude: value['longitude'] is num
        ? (value['longitude'] as num).toDouble()
        : null,
  );
}
