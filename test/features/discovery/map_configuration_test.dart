import 'package:carcare_customer_mobile/app/theme/app_theme.dart';
import 'package:carcare_customer_mobile/features/discovery/domain/branch.dart';
import 'package:carcare_customer_mobile/features/discovery/domain/organization.dart';
import 'package:carcare_customer_mobile/features/discovery/presentation/widgets/discovery_map.dart';
import 'package:carcare_customer_mobile/features/discovery/services/map_configuration_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('does not construct a native map when Maps is unconfigured', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: DiscoveryMap(
            organizations: const [
              Organization(
                slug: 'test-service',
                name: 'Test Service',
                branches: [
                  Branch(
                    id: 'test-branch',
                    name: 'Test Branch',
                    city: 'Ulaanbaatar',
                    district: 'Sukhbaatar',
                    latitude: 47.9,
                    longitude: 106.9,
                  ),
                ],
              ),
            ],
            onOrganizationSelected: (_) {},
            onShowList: () {},
            mapConfigurationService: const _UnconfiguredMaps(),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Газрын зураг ашиглах боломжгүй байна'), findsOneWidget);
    expect(find.byKey(const ValueKey('discovery-map-0')), findsNothing);
  });
}

class _UnconfiguredMaps implements MapConfigurationService {
  const _UnconfiguredMaps();

  @override
  Future<bool> isConfigured() async => false;
}
