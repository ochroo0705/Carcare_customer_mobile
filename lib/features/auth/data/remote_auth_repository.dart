import 'package:carcare_customer_mobile/core/errors/app_failure.dart';
import 'package:carcare_customer_mobile/core/network/api_client.dart';
import 'package:carcare_customer_mobile/features/auth/data/secure_session_store.dart';
import 'package:carcare_customer_mobile/features/auth/domain/account.dart';
import 'package:carcare_customer_mobile/features/auth/domain/auth_repository.dart';

class RemoteAuthRepository implements AuthRepository {
  RemoteAuthRepository(this._client, this._sessionStore);

  final ApiClient _client;
  final SecureSessionStore _sessionStore;

  @override
  Future<Account?> restoreSession() => _sessionStore.readAccount();

  @override
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
    await _sessionStore.save(token: token, account: account);
    return account;
  }

  @override
  Future<void> signOut() => _sessionStore.clear();
}
