import 'package:carcare_customer_mobile/core/errors/app_failure.dart';
import 'package:carcare_customer_mobile/features/discovery/data/fake_organization_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FakeOrganizationRepository', () {
    test('returns representative organization data', () async {
      final repository = FakeOrganizationRepository(delay: Duration.zero);
      final organizations = await repository.getOrganizations();
      expect(organizations, hasLength(3));
      expect(organizations.first.branches, hasLength(2));
      expect(organizations.first.branches, isNotEmpty);
    });

    test('supports an empty scenario', () async {
      final repository = FakeOrganizationRepository(
        scenario: FakeOrganizationScenario.empty,
        delay: Duration.zero,
      );
      expect(await repository.getOrganizations(), isEmpty);
    });

    test('supports an error scenario', () async {
      final repository = FakeOrganizationRepository(
        scenario: FakeOrganizationScenario.error,
        delay: Duration.zero,
      );
      expect(repository.getOrganizations(), throwsA(isA<ServerFailure>()));
    });
  });
}
