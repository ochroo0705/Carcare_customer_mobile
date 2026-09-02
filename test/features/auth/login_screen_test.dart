import 'package:carcare_customer_mobile/app/theme/app_theme.dart';
import 'package:carcare_customer_mobile/features/auth/data/fake_auth_repository.dart';
import 'package:carcare_customer_mobile/features/auth/presentation/auth_controller.dart';
import 'package:carcare_customer_mobile/features/auth/presentation/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('enables OTP resend after a 60 second cooldown', (tester) async {
    final repository = _CountingAuthRepository();
    final controller = AuthController(repository);

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: controller,
        child: MaterialApp(
          theme: AppTheme.dark,
          home: LoginScreen(onAuthenticated: () {}, onBack: () {}),
        ),
      ),
    );

    await tester.enterText(
      find.byKey(const ValueKey('login-phone')),
      '99112233',
    );
    await tester.tap(find.text('Код авах →'));
    await tester.pump();

    expect(find.text('Код дахин авах (1:00)'), findsOneWidget);
    expect(
      tester
          .widget<TextButton>(
            find.widgetWithText(TextButton, 'Код дахин авах (1:00)'),
          )
          .onPressed,
      isNull,
    );

    await tester.pump(const Duration(seconds: 59));
    expect(find.text('Код дахин авах (0:01)'), findsOneWidget);

    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Код дахин авах'), findsOneWidget);
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, 'Код дахин авах'))
          .onPressed,
      isNotNull,
    );

    await tester.tap(find.text('Код дахин авах'));
    await tester.pump();
    expect(repository.requestCount, 2);
    expect(find.text('Код дахин авах (1:00)'), findsOneWidget);
  });
}

class _CountingAuthRepository extends FakeAuthRepository {
  int requestCount = 0;

  @override
  Future<void> requestOtp(String phone) async {
    requestCount++;
    await super.requestOtp(phone);
  }
}
