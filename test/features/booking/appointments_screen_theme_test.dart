import 'package:carcare_customer_mobile/app/theme/app_theme.dart';
import 'package:carcare_customer_mobile/features/auth/data/fake_auth_repository.dart';
import 'package:carcare_customer_mobile/features/auth/domain/account.dart';
import 'package:carcare_customer_mobile/features/auth/presentation/auth_controller.dart';
import 'package:carcare_customer_mobile/features/booking/data/fake_appointment_repository.dart';
import 'package:carcare_customer_mobile/features/booking/presentation/controllers/appointments_controller.dart';
import 'package:carcare_customer_mobile/features/booking/presentation/screens/appointments_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('keeps the header text readable across a live theme switch', (
    tester,
  ) async {
    final controller = AppointmentsController(FakeAppointmentRepository());
    await controller.load();
    final authController = AuthController(FakeAuthRepository())
      ..account = const Account(id: '1', phone: '99112233');

    Widget buildApp(ThemeData theme) => MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: controller),
        ChangeNotifierProvider.value(value: authController),
      ],
      child: MaterialApp(
        theme: theme,
        home: Scaffold(
          body: AppointmentsScreen(
            onLoginRequested: () {},
            onPaymentRequested: (_) {},
          ),
        ),
      ),
    );

    // Mount already in dark mode, mirroring a tab kept alive inside
    // CustomerShell's IndexedStack before any theme change occurs.
    await tester.pumpWidget(buildApp(AppTheme.dark));
    await tester.pumpAndSettle();
    expect(
      tester.widget<Text>(find.text('Миний захиалгууд')).style?.color,
      AppColors.darkText,
    );

    // Live theme switch with the same widget tree staying mounted (no
    // unmount in between) — same class of bug as the Favorites header:
    // text built inline inside a ListView.separated itemBuilder closure
    // doesn't update when the theme changes while already mounted.
    await tester.pumpWidget(buildApp(AppTheme.light));
    await tester.pumpAndSettle();

    expect(
      tester.widget<Text>(find.text('Миний захиалгууд')).style?.color,
      AppColors.lightText,
    );
  });
}
