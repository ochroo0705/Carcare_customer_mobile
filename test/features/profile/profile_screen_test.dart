import 'package:carcare_customer_mobile/app/bootstrap_flags.dart';
import 'package:carcare_customer_mobile/app/app.dart';
import 'package:carcare_customer_mobile/app/theme/app_theme.dart';
import 'package:carcare_customer_mobile/features/auth/data/fake_auth_repository.dart';
import 'package:carcare_customer_mobile/features/auth/domain/account.dart';
import 'package:carcare_customer_mobile/features/auth/presentation/auth_controller.dart';
import 'package:carcare_customer_mobile/features/discovery/data/fake_organization_repository.dart';
import 'package:carcare_customer_mobile/features/profile/presentation/screens/profile_screen.dart';
import 'package:carcare_customer_mobile/features/vehicles/data/fake_vehicle_repository.dart';
import 'package:carcare_customer_mobile/features/vehicles/presentation/controllers/vehicles_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _login(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('profile-login')));
  await tester.pumpAndSettle();
  await tester.enterText(find.byKey(const ValueKey('login-phone')), '99112233');
  await tester.tap(find.text('Код авах →'));
  await tester.pumpAndSettle();
  await tester.enterText(find.byKey(const ValueKey('login-otp')), '123456');
  await tester.tap(find.text('Нэвтрэх →'));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => debugDisableAppBootstrap = true);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
    'requires login before showing the profile, then lists vehicles',
    (tester) async {
      await tester.pumpWidget(
        CarCareCustomerApp(
          organizationRepository: FakeOrganizationRepository(
            delay: Duration.zero,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Профайл'));
      await tester.pumpAndSettle();
      expect(find.text('Профайлаа харахын тулд нэвтэрнэ үү'), findsOneWidget);

      await _login(tester);

      expect(find.text('Миний машинууд'), findsOneWidget);
      expect(find.text('Hyundai Sonata'), findsOneWidget);
      expect(find.text('9911УБЕ · 2019'), findsOneWidget);
    },
  );

  testWidgets('shows the account header with a working sign-out button', (
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

    await tester.tap(find.text('Профайл'));
    await tester.pumpAndSettle();
    await _login(tester);

    expect(find.byKey(const ValueKey('profile-sign-out')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('profile-sign-out')));
    await tester.pumpAndSettle();

    expect(find.text('Профайлаа харахын тулд нэвтэрнэ үү'), findsOneWidget);
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

    await tester.tap(find.text('Профайл'));
    await tester.pumpAndSettle();
    await _login(tester);

    await tester.tap(find.byKey(const ValueKey('profile-add-vehicle-fab')));
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

    await tester.tap(find.text('Профайл'));
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
    final authController = AuthController(FakeAuthRepository())
      ..account = const Account(id: '1', phone: '99112233');

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: controller),
          ChangeNotifierProvider.value(value: authController),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: Scaffold(
              body: ProfileScreen(onLoginRequested: () {}, onAddVehicle: () {}),
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
