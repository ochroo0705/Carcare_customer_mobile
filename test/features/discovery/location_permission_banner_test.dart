import 'package:carcare_customer_mobile/features/discovery/presentation/widgets/location_permission_banner.dart';
import 'package:carcare_customer_mobile/features/discovery/services/location_permission_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('offers another request after a normal denial', (tester) async {
    var requested = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LocationPermissionBanner(
            state: LocationAccessState.denied,
            onRequest: () => requested = true,
            onOpenSettings: () {},
          ),
        ),
      ),
    );

    expect(find.text('Зөвшөөрөх'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('location-request-again')));
    expect(requested, isTrue);
  });

  testWidgets('opens settings after permanent denial', (tester) async {
    var openedSettings = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LocationPermissionBanner(
            state: LocationAccessState.permanentlyDenied,
            onRequest: () {},
            onOpenSettings: () => openedSettings = true,
          ),
        ),
      ),
    );

    expect(find.text('Тохиргоо'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('location-open-settings')));
    expect(openedSettings, isTrue);
  });

  testWidgets('supports large accessibility text without overflow', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: Scaffold(
            body: LocationPermissionBanner(
              state: LocationAccessState.permanentlyDenied,
              onRequest: () {},
              onOpenSettings: () {},
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Тохиргоо'), findsOneWidget);
  });
}
