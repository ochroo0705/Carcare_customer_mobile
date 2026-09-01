import 'package:carcare_customer_mobile/features/auth/domain/account.dart';

abstract interface class AuthRepository {
  Future<Account?> restoreSession();
  Future<void> requestOtp(String phone);
  Future<Account> verifyOtp({
    required String phone,
    required String code,
    String? name,
  });
  Future<void> signOut();
}
