import 'package:carcare_customer_mobile/core/errors/app_failure.dart';
import 'package:carcare_customer_mobile/data/cache/in_memory_cache_store.dart';
import 'package:carcare_customer_mobile/features/discovery/data/caching_organization_repository.dart';
import 'package:carcare_customer_mobile/features/discovery/domain/organization.dart';
import 'package:carcare_customer_mobile/features/discovery/domain/organization_repository.dart';
import 'package:flutter_test/flutter_test.dart';

const _detail = OrganizationDetail(
  slug: 'auto-doctor',
  name: 'Auto Doctor',
  phone: '7700 1122',
  branches: [],
);

class _CountingDelegate implements OrganizationRepository {
  int calls = 0;
  bool fail = false;

  @override
  Future<List<Organization>> getOrganizations() async => const [];

  @override
  Future<OrganizationDetail> getOrganization(String slug) async {
    calls++;
    if (fail) throw const NetworkFailure();
    return _detail;
  }
}

void main() {
  test('serves a fresh cached detail without hitting the delegate', () async {
    final delegate = _CountingDelegate();
    final repo = CachingOrganizationRepository(
      delegate,
      InMemoryCacheStore(),
      ttl: const Duration(hours: 1),
    );

    await repo.getOrganization('auto-doctor'); // fetch + cache
    final second = await repo.getOrganization('auto-doctor'); // from cache

    expect(delegate.calls, 1);
    expect(second.phone, '7700 1122');
  });

  test('re-fetches once the cached copy is older than the TTL', () async {
    final delegate = _CountingDelegate();
    final repo = CachingOrganizationRepository(
      delegate,
      InMemoryCacheStore(),
      ttl: Duration.zero, // nothing is ever "fresh"
    );

    await repo.getOrganization('auto-doctor');
    await repo.getOrganization('auto-doctor');

    expect(delegate.calls, 2);
  });

  test('falls back to a stale cached copy when the fetch fails', () async {
    final delegate = _CountingDelegate();
    final repo = CachingOrganizationRepository(
      delegate,
      InMemoryCacheStore(),
      ttl: Duration.zero,
    );

    await repo.getOrganization('auto-doctor'); // warms the cache
    delegate.fail = true;
    final stale = await repo.getOrganization('auto-doctor'); // fetch fails

    expect(stale.phone, '7700 1122'); // stale copy returned, no throw
  });

  test('rethrows when the fetch fails and there is no cache', () async {
    final delegate = _CountingDelegate()..fail = true;
    final repo = CachingOrganizationRepository(delegate, InMemoryCacheStore());

    expect(
      () => repo.getOrganization('auto-doctor'),
      throwsA(isA<NetworkFailure>()),
    );
  });
}
