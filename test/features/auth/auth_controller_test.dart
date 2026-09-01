import 'package:carcare_customer_mobile/features/auth/data/fake_auth_repository.dart';
import 'package:carcare_customer_mobile/features/auth/presentation/auth_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('requests OTP and verifies an Account session', () async {
    final controller = AuthController(FakeAuthRepository());

    expect(await controller.requestOtp('99112233'), isTrue);
    expect(controller.step, AuthStep.otp);
    expect(await controller.verifyOtp('123456'), isTrue);
    expect(controller.isAuthenticated, isTrue);
    expect(controller.account?.phone, '99112233');
  });

  test('keeps the user on phone step for invalid phone', () async {
    final controller = AuthController(FakeAuthRepository());

    expect(await controller.requestOtp('123'), isFalse);
    expect(controller.step, AuthStep.phone);
    expect(controller.errorMessage, isNotNull);
  });
}
