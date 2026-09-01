import 'package:carcare_customer_mobile/app/theme/app_theme.dart';
import 'package:carcare_customer_mobile/features/vehicles/data/fake_vehicle_repository.dart';
import 'package:carcare_customer_mobile/features/vehicles/presentation/controllers/vehicles_controller.dart';
import 'package:carcare_customer_mobile/features/vehicles/presentation/screens/vehicles_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('keeps the header text readable across a live theme switch', (
    tester,
  ) async {
    final controller = VehiclesController(FakeVehicleRepository());
    await controller.load();

    Widget buildApp(ThemeData theme) => MaterialApp(
      theme: theme,
      home: Scaffold(
        body: VehiclesScreen(
          controller: controller,
          isAuthenticated: true,
          onLoginRequested: () {},
          onAddVehicle: () {},
        ),
      ),
    );

    // Mount already in dark mode, mirroring a tab kept alive inside
    // CustomerShell's IndexedStack before any theme change occurs.
    await tester.pumpWidget(buildApp(AppTheme.dark));
    await tester.pumpAndSettle();
    expect(
      tester.widget<Text>(find.text('Миний машинууд')).style?.color,
      AppColors.darkText,
    );

    // Live theme switch with the same widget tree staying mounted (no
    // unmount in between) — same class of bug as the Favorites header:
    // text built inline inside a ListView.separated itemBuilder closure
    // doesn't update when the theme changes while already mounted.
    await tester.pumpWidget(buildApp(AppTheme.light));
    await tester.pumpAndSettle();

    expect(
      tester.widget<Text>(find.text('Миний машинууд')).style?.color,
      AppColors.lightText,
    );
  });
}
