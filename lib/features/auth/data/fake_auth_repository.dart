import 'package:carcare_customer_mobile/core/errors/app_failure.dart';
import 'package:carcare_customer_mobile/features/auth/domain/account.dart';
import 'package:carcare_customer_mobile/features/auth/domain/auth_repository.dart';

class FakeAuthRepository implements AuthRepository {
  Account? _account;

  @override
  Future<Account?> restoreSession() async => _account;

  @override
  Future<void> requestOtp(String phone) async {
    if (!RegExp(r'^\d{8}$').hasMatch(phone)) {
      throw const ValidationFailure('8 оронтой утасны дугаар оруулна уу.');
    }
  }

  @override
  Future<Account> verifyOtp({
    required String phone,
    required String code,
    String? name,
  }) async {
    if (!RegExp(r'^\d{6}$').hasMatch(code)) {
      throw const ValidationFailure('6 оронтой код оруулна уу.');
    }
    return _account = Account(
      id: 'fake-account',
      phone: phone,
      name: name?.trim().isEmpty ?? true ? null : name!.trim(),
    );
  }

  @override
  Future<void> signOut() async => _account = null;
}
