import 'dart:async';

import 'package:carcare_customer_mobile/core/errors/app_failure.dart';
import 'package:carcare_customer_mobile/data/cache/in_memory_cache_store.dart';
import 'package:carcare_customer_mobile/features/discovery/data/fake_organization_repository.dart';
import 'package:carcare_customer_mobile/features/discovery/domain/branch.dart';
import 'package:carcare_customer_mobile/features/discovery/domain/organization.dart';
import 'package:carcare_customer_mobile/features/discovery/domain/organization_repository.dart';
import 'package:carcare_customer_mobile/features/discovery/presentation/controllers/discovery_controller.dart';
import 'package:carcare_customer_mobile/features/discovery/presentation/controllers/discovery_state.dart';
import 'package:flutter_test/flutter_test.dart';

/// Delegates to the fake catalogue until [fail] is set, then throws.
class _FlakyOrganizationRepo extends Fake implements OrganizationRepository {
  final _inner = FakeOrganizationRepository(delay: Duration.zero);
  bool fail = false;

  @override
  Future<OrganizationPage> getOrganizations({
    OrganizationFilter? filter,
  }) async {
    if (fail) throw const NetworkFailure();
    return _inner.getOrganizations(filter: filter);
  }
}

/// Cache whose read blocks until [release] is completed.
class _GatedCache extends InMemoryCacheStore {
  final release = Completer<void>();
  @override
  Future<List<Organization>?> readOrganizations() async {
    await release.future;
    return super.readOrganizations();
  }
}

void main() {
  test(
    'a failed refresh keeps the live organizations, not the cache',
    () async {
      final cache = InMemoryCacheStore();
      final repository = _FlakyOrganizationRepo();
      final controller = DiscoveryController(repository, cache: cache);
      addTearDown(controller.dispose);

      await controller.load();
      final live = controller.state.organizations;
      expect(live, isNotEmpty);
      await cache.writeOrganizations(live.take(1).toList());

      repository.fail = true;
      await controller.load();

      expect(controller.state.status, DiscoveryStatus.data);
      expect(controller.state.isFromCache, isFalse);
      expect(controller.state.organizations, live);
      expect(controller.state.message, isNotNull);
    },
  );

  test('a slow cache fallback does not overwrite a newer load', () async {
    final cache = _GatedCache();
    final repository = _FlakyOrganizationRepo();
    await cache.writeOrganizations(
      (await FakeOrganizationRepository(
        delay: Duration.zero,
      ).getOrganizations()).organizations.take(1).toList(),
    );
    final controller = DiscoveryController(repository, cache: cache);
    addTearDown(controller.dispose);

    repository.fail = true;
    final first = controller.load();
    await Future<void>.delayed(Duration.zero);
    repository.fail = false;
    await controller.load();
    final live = controller.state.organizations;
    expect(controller.state.isFromCache, isFalse);

    cache.release.complete();
    await first;

    expect(controller.state.isFromCache, isFalse);
    expect(controller.state.organizations, live);
  });
}
