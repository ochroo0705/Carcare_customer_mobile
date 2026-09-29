import 'package:carcare_customer_mobile/features/auth/domain/account.dart';

abstract interface class AuthRepository {
  Future<Account?> restoreSession();
  Future<void> requestOtp(String phone);

  /// `reactivated` бол server дээр өмнө нь deactivate хийсэн account энэ
  /// нэвтрэлтээр дахин идэвхжсэн гэсэн үг (зөвхөн `deactivatedAt`-г цэвэрлэнэ,
  /// `isActive=false` block-той account-ийг login дахин идэвхжүүлдэггүй).
  Future<({Account account, bool reactivated})> verifyOtp({
    required String phone,
    required String code,
    String? name,
  });
  Future<void> signOut();

  /// Account closure (deactivate/delete) хийхээс өмнө утсанд OTP илгээнэ.
  /// Буцаах утга нь бүтэн дугаар биш, тухайлбал `****1234` маягийн masked утас.
  Future<String> requestClosureOtp();

  /// Self-service deactivation: `isActive`-г хэвээр үлдээж зөвхөн
  /// `deactivatedAt`-г тэмдэглэнэ. Хэрэглэгч дахин нэвтэрч сэргээж болно.
  Future<void> deactivateAccount(String code);

  /// Backend дээр PII-г anonymize хийж, session/device/notification устгана.
  /// Буцаах боломжгүй — server талд `isActive=false` болно.
  Future<void> deleteAccount(String code);

  /// Fires whenever the session is invalidated from outside the current
  /// sign-in flow — e.g. any authenticated repository's request gets a 401
  /// and clears local storage. Lets `AuthController` drop its `account` even
  /// when the 401 happened on a screen that never wired up a dedicated
  /// unauthenticated callback.
  Stream<void> get onSessionInvalidated;
}
