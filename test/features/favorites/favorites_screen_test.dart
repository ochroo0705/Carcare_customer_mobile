import 'package:carcare_customer_mobile/app/theme/app_theme.dart';
import 'package:carcare_customer_mobile/features/discovery/data/fake_organization_repository.dart';
import 'package:carcare_customer_mobile/features/discovery/presentation/controllers/discovery_controller.dart';
import 'package:carcare_customer_mobile/features/favorites/presentation/controllers/favorites_controller.dart';
import 'package:carcare_customer_mobile/features/favorites/presentation/screens/favorites_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('keeps the header text readable across a live theme switch', (
    tester,
  ) async {
    final discoveryController = DiscoveryController(
      FakeOrganizationRepository(delay: Duration.zero),
    );
    await discoveryController.load();
    final favoritesController = FavoritesController();
    await favoritesController.load();
    await favoritesController.toggle(
      discoveryController.state.organizations.first.slug,
    );

    Widget buildApp(ThemeData theme) => MaterialApp(
      theme: theme,
      home: Scaffold(
        body: FavoritesScreen(
          discoveryController: discoveryController,
          favoritesController: favoritesController,
          onOrganizationSelected: (_) {},
        ),
      ),
    );

    // Mount already in dark mode, mirroring a tab kept alive inside
    // CustomerShell's IndexedStack before any theme change occurs.
    await tester.pumpWidget(buildApp(AppTheme.dark));
    await tester.pumpAndSettle();
    expect(
      tester.widget<Text>(find.text('Хадгалсан сервисүүд')).style?.color,
      AppColors.darkText,
    );

    // Live theme switch with the same widget tree staying mounted (no
    // unmount in between) — regression test: this text used to keep
    // rendering in the *old* theme's color instead of updating, because
    // its style was computed inline inside a ListView.separated itemBuilder
    // closure instead of a dedicated widget.
    await tester.pumpWidget(buildApp(AppTheme.light));
    await tester.pumpAndSettle();

    expect(
      tester.widget<Text>(find.text('Хадгалсан сервисүүд')).style?.color,
      AppColors.lightText,
    );
  });
}
