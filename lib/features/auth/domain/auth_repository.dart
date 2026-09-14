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

  /// Fires whenever the session is invalidated from outside the current
  /// sign-in flow — e.g. any authenticated repository's request gets a 401
  /// and clears local storage. Lets `AuthController` drop its `account` even
  /// when the 401 happened on a screen that never wired up a dedicated
  /// unauthenticated callback.
  Stream<void> get onSessionInvalidated;
}
