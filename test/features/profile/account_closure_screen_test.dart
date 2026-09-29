import 'package:carcare_customer_mobile/app/theme/app_theme.dart';
import 'package:carcare_customer_mobile/features/auth/data/fake_auth_repository.dart';
import 'package:carcare_customer_mobile/features/auth/presentation/auth_controller.dart';
import 'package:carcare_customer_mobile/features/profile/presentation/screens/account_closure_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

Widget _testApp(FakeAuthRepository repo) {
  final controller = AuthController(repo);
  return ChangeNotifierProvider<AuthController>.value(
    value: controller,
    child: MaterialApp(
      theme: AppTheme.light,
      home: const AccountClosureScreen(),
    ),
  );
}

void main() {
  testWidgets('delete forever requires typing confirmation and OTP', (
    tester,
  ) async {
    final repo = FakeAuthRepository(signedIn: true);
    await tester.pumpWidget(_testApp(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Бүрмөсөн устгах'));
    await tester.pumpAndSettle();
    expect(find.textContaining('буцаах боломжгүй'), findsOneWidget);

    await tester.tap(find.text('Код авах'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, '123456');
    await tester.tap(find.text('Устгах'));
    await tester.pumpAndSettle();

    expect(find.text('Бүрмөсөн устгах уу?'), findsOneWidget);
    await tester.tap(find.text('Тийм, устгах'));
    await tester.pumpAndSettle();

    expect(repo.lastClosure, ('delete', '123456'));
  });

  testWidgets('deactivate explains that login restores the account', (
    tester,
  ) async {
    await tester.pumpWidget(_testApp(FakeAuthRepository(signedIn: true)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Идэвхгүй болгох'));
    await tester.pumpAndSettle();
    expect(find.textContaining('дахин нэвтэрч'), findsOneWidget);
  });

  testWidgets('deactivate succeeds without an extra confirm dialog', (
    tester,
  ) async {
    final repo = FakeAuthRepository(signedIn: true);
    await tester.pumpWidget(_testApp(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Идэвхгүй болгох'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Код авах'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, '654321');
    await tester.tap(find.text('Идэвхгүй болгох').last);
    await tester.pumpAndSettle();

    expect(repo.lastClosure, ('deactivate', '654321'));
  });

  testWidgets('wrong code keeps the entered code and shows the error', (
    tester,
  ) async {
    final repo = FakeAuthRepository(signedIn: true)
      ..closureShouldFail = true;
    await tester.pumpWidget(_testApp(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Идэвхгүй болгох'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Код авах'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, '000000');
    await tester.tap(find.text('Идэвхгүй болгох').last);
    await tester.pumpAndSettle();

    expect(find.text('Код буруу эсвэл хугацаа дууссан.'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField).last).controller?.text,
      '000000',
    );
  });

  testWidgets('a failed code request shows the error on the request step', (
    tester,
  ) async {
    final repo = FakeAuthRepository(signedIn: true)
      ..closureOtpShouldFail = true;
    await tester.pumpWidget(_testApp(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Идэвхгүй болгох'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Код авах'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('account_closure_request_error')),
      findsOneWidget,
    );
    expect(find.text('Хэт олон код хүслээ.'), findsOneWidget);
    expect(find.text('Код авах'), findsOneWidget);
  });
}
