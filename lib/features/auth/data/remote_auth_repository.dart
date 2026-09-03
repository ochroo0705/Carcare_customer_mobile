import 'package:carcare_customer_mobile/core/errors/app_failure.dart';
import 'package:carcare_customer_mobile/core/network/api_client.dart';
import 'package:carcare_customer_mobile/features/auth/data/secure_session_store.dart';
import 'package:carcare_customer_mobile/features/auth/domain/account.dart';
import 'package:carcare_customer_mobile/features/auth/domain/auth_repository.dart';

/// Account realm-ийн phone + OTP authentication adapter.
///
/// OTP амжилттай бол server-ийн access token болон Account-ийг нэг session
/// болгон secure storage-д хадгална. Customer API нь refresh endpoint-гүй тул
/// дараагийн app launch дээр token-ийг дахин ашиглах нь зориудын хэрэгжилт.
class RemoteAuthRepository implements AuthRepository {
  RemoteAuthRepository(this._client, this._sessionStore);

  final ApiClient _client;
  final SecureSessionStore _sessionStore;

  @override
  /// Өмнө хадгалсан session-ийг сэргээнэ. Secure storage-д шаардлагатай
  /// талбарын аль нэг нь дутуу бол хагас session үүсгэхгүй.
  Future<Account?> restoreSession() => _sessionStore.readAccount();

  @override
  /// OTP хүсэх endpoint зөвхөн phone-г хүлээн авна; кодыг client талд
  /// хадгалахгүй, verify алхам дээр хэрэглэгч дахин оруулна.
  Future<void> requestOtp(String phone) async {
    await _client.postJson('/auth/request-otp', {'phone': phone});
  }

  @override
  Future<Account> verifyOtp({
    required String phone,
    required String code,
    String? name,
  }) async {
    final json = await _client.postJson('/auth/verify-otp', {
      'phone': phone,
      'code': code,
      if (name != null && name.trim().isNotEmpty) 'name': name.trim(),
    });
    final token = json['accessToken'];
    final accountJson = json['account'];
    if (token is! String || token.isEmpty || accountJson is! Map) {
      throw const UnexpectedFailure('Нэвтрэх хариу буруу байна.');
    }
    final map = Map<String, dynamic>.from(accountJson);
    final id = map['id'];
    final accountPhone = map['phone'];
    if (id is! String || accountPhone is! String) {
      throw const UnexpectedFailure('Хэрэглэгчийн мэдээлэл буруу байна.');
    }
    final account = Account(
      id: id,
      phone: accountPhone,
      name: map['name'] is String ? map['name'] as String : null,
    );
    // Token болон identity-г хамтад нь хадгална. Нэг нь хадгалагдаад нөгөө нь
    // тасарвал launch үеийн restore нь буруу authenticated төлөв үүсгэхээс
    // сэргийлж incomplete session-ийг хүлээж авахгүй.
    await _sessionStore.save(token: token, account: account);
    return account;
  }

  @override
  /// Local session-г цэвэрлэнэ. Device registration removal нь тусдаа
  /// best-effort урсгалд хийгддэг бөгөөд authentication logout-ийг блоклохгүй.
  Future<void> signOut() => _sessionStore.clear();
}
