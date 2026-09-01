import 'package:carcare_customer_mobile/app/app.dart';
import 'package:carcare_customer_mobile/app/theme/app_theme.dart';
import 'package:carcare_customer_mobile/features/discovery/data/fake_organization_repository.dart';
import 'package:carcare_customer_mobile/features/vehicles/data/fake_vehicle_repository.dart';
import 'package:carcare_customer_mobile/features/vehicles/presentation/controllers/vehicles_controller.dart';
import 'package:carcare_customer_mobile/features/vehicles/presentation/screens/vehicles_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _login(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('vehicles-login')));
  await tester.pumpAndSettle();
  await tester.enterText(find.byKey(const ValueKey('login-phone')), '99112233');
  await tester.tap(find.text('Код авах →'));
  await tester.pumpAndSettle();
  await tester.enterText(find.byKey(const ValueKey('login-otp')), '123456');
  await tester.tap(find.text('Нэвтрэх →'));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('requires login before showing vehicles, then lists them', (
    tester,
  ) async {
    await tester.pumpWidget(
      CarCareCustomerApp(
        organizationRepository: FakeOrganizationRepository(
          delay: Duration.zero,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Машин'));
    await tester.pumpAndSettle();
    expect(find.text('Машинаа харахын тулд нэвтэрнэ үү'), findsOneWidget);

    await _login(tester);

    expect(find.text('Миний машинууд'), findsOneWidget);
    expect(find.text('Hyundai Sonata'), findsOneWidget);
    expect(find.text('9911УБЕ · 2019'), findsOneWidget);
  });

  testWidgets('adds a vehicle using HUR lookup autofill', (tester) async {
    await tester.pumpWidget(
      CarCareCustomerApp(
        organizationRepository: FakeOrganizationRepository(
          delay: Duration.zero,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Машин'));
    await tester.pumpAndSettle();
    await _login(tester);

    await tester.tap(find.byKey(const ValueKey('vehicles-add-fab')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('vehicle-plate')),
      '1234УБА',
    );
    await tester.tap(find.byKey(const ValueKey('vehicle-lookup')));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextField, 'Toyota'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Prius'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('vehicle-submit')));
    await tester.pumpAndSettle();

    expect(find.text('Машин нэмэгдлээ.'), findsOneWidget);
    expect(find.text('Toyota Prius'), findsOneWidget);
    expect(find.text('Hyundai Sonata'), findsOneWidget);
  });

  testWidgets('deletes a vehicle after confirmation', (tester) async {
    await tester.pumpWidget(
      CarCareCustomerApp(
        organizationRepository: FakeOrganizationRepository(
          delay: Duration.zero,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Машин'));
    await tester.pumpAndSettle();
    await _login(tester);

    final deleteButton = find.byKey(
      const ValueKey('delete-vehicle-seed-vehicle-1'),
    );
    await tester.ensureVisible(deleteButton);
    await tester.pumpAndSettle();
    await tester.tap(deleteButton);
    await tester.pumpAndSettle();
    expect(find.text('Машин устгах уу?'), findsOneWidget);

    await tester.tap(find.text('Тийм, устгах'));
    await tester.pumpAndSettle();

    expect(find.text('Бүртгэсэн машин алга'), findsOneWidget);
  });

  testWidgets('supports large accessibility text without overflow', (
    tester,
  ) async {
    final controller = VehiclesController(FakeVehicleRepository());
    await controller.load();

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: Scaffold(
            body: VehiclesScreen(
              controller: controller,
              isAuthenticated: true,
              onLoginRequested: () {},
              onAddVehicle: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Миний машинууд'), findsOneWidget);
  });
}
