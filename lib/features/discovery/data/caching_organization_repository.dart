import 'package:carcare_customer_mobile/core/errors/app_failure.dart';
import 'package:carcare_customer_mobile/data/cache/cache_store.dart';
import 'package:carcare_customer_mobile/features/discovery/domain/organization.dart';
import 'package:carcare_customer_mobile/features/discovery/domain/organization_repository.dart';

/// Wraps an [OrganizationRepository] with a cache-first-with-TTL layer for
/// `getOrganization` (the detail — hours/address/phone). A detail seen within
/// [ttl] is served straight from the local DB, skipping the network entirely
/// (fewer calls, instant render); past that it re-fetches and refreshes the
/// cache. If a fetch fails but *any* cached copy exists it returns the stale
/// copy, so the detail still shows offline. `getOrganizations` (the discovery
/// list) is passed straight through — that list is cached separately by the
/// discovery controller, so caching it here too would be redundant.
class CachingOrganizationRepository implements OrganizationRepository {
  CachingOrganizationRepository(
    this._delegate,
    this._cache, {
    this.ttl = const Duration(hours: 6),
  });

  final OrganizationRepository _delegate;
  final CacheStore _cache;
  final Duration ttl;

  @override
  Future<List<Organization>> getOrganizations() => _delegate.getOrganizations();

  @override
  Future<OrganizationDetail> getOrganization(String slug) async {
    final cached = await _cache.readOrganizationDetail(slug);
    if (cached != null && DateTime.now().difference(cached.cachedAt) < ttl) {
      return cached.detail;
    }
    try {
      final fresh = await _delegate.getOrganization(slug);
      await _cache.writeOrganizationDetail(fresh);
      return fresh;
    } on AppFailure {
      if (cached != null) return cached.detail;
      rethrow;
    }
  }
}
