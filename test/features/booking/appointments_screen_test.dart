import 'package:carcare_customer_mobile/app/app.dart';
import 'package:carcare_customer_mobile/app/theme/app_theme.dart';
import 'package:carcare_customer_mobile/features/auth/data/fake_auth_repository.dart';
import 'package:carcare_customer_mobile/features/auth/domain/account.dart';
import 'package:carcare_customer_mobile/features/auth/presentation/auth_controller.dart';
import 'package:carcare_customer_mobile/features/booking/data/fake_appointment_repository.dart';
import 'package:carcare_customer_mobile/features/booking/presentation/controllers/appointments_controller.dart';
import 'package:carcare_customer_mobile/features/booking/presentation/screens/appointments_screen.dart';
import 'package:carcare_customer_mobile/features/discovery/data/fake_organization_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('requires login before showing appointments, then lists them', (
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

    await tester.tap(find.text('Цаг'));
    await tester.pumpAndSettle();
    expect(find.text('Захиалгаа харахын тулд нэвтэрнэ үү'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('appointments-login')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('login-phone')),
      '99112233',
    );
    await tester.tap(find.text('Код авах →'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('login-otp')), '123456');
    await tester.tap(find.text('Нэвтрэх →'));
    await tester.pumpAndSettle();

    expect(find.text('Миний захиалгууд'), findsOneWidget);
    expect(find.text('Инфосистемс'), findsWidgets);
    expect(find.text('Тэсо Моторс'), findsOneWidget);
    expect(find.text('Баталгаажсан'), findsOneWidget);
    expect(find.text('Хүлээгдэж буй'), findsOneWidget);
    expect(find.text('Цуцалсан'), findsOneWidget);
  });

  testWidgets('cancels a pending appointment after confirmation', (
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

    await tester.tap(find.text('Цаг'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('appointments-login')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('login-phone')),
      '99112233',
    );
    await tester.tap(find.text('Код авах →'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('login-otp')), '123456');
    await tester.tap(find.text('Нэвтрэх →'));
    await tester.pumpAndSettle();

    final cancelButton = find.byKey(const ValueKey('cancel-seed-2'));
    await tester.ensureVisible(cancelButton);
    await tester.pumpAndSettle();
    await tester.tap(cancelButton);
    await tester.pumpAndSettle();
    expect(find.text('Захиалга цуцлах уу?'), findsOneWidget);

    await tester.tap(find.text('Тийм, цуцлах'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('cancel-seed-2')), findsNothing);
    expect(find.text('Цуцалсан'), findsNWidgets(2));
  });

  testWidgets('supports large accessibility text without overflow', (
    tester,
  ) async {
    final controller = AppointmentsController(FakeAppointmentRepository());
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
              body: AppointmentsScreen(
                onLoginRequested: () {},
                onAppointmentSelected: (_) {},
                onPaymentRequested: (_) {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Миний захиалгууд'), findsOneWidget);
  });
}
