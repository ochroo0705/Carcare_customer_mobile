import 'package:carcare_customer_mobile/core/errors/app_failure.dart';
import 'package:carcare_customer_mobile/features/discovery/domain/organization.dart';
import 'package:carcare_customer_mobile/features/discovery/domain/organization_repository.dart';
import 'package:carcare_customer_mobile/features/discovery/presentation/controllers/discovery_state.dart';
import 'package:flutter/foundation.dart';

class DiscoveryController extends ChangeNotifier {
  DiscoveryController(this._repository);
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
    } on AppFailure catch (failure) {
      _state = DiscoveryState(
        status: DiscoveryStatus.error,
        message: failure.message,
      );
    } catch (_) {
      _state = const DiscoveryState(
        status: DiscoveryStatus.error,
        message: 'Тодорхойгүй алдаа гарлаа.',
      );
    }
    notifyListeners();
  }

  Organization? organizationBySlug(String slug) {
    for (final organization in _state.organizations) {
      if (organization.slug == slug) return organization;
    }
    return null;
  }
}
