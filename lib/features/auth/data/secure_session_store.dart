import 'package:carcare_customer_mobile/features/auth/domain/account.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureSessionStore {
  SecureSessionStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _tokenKey = 'account_access_token';
  static const _idKey = 'account_id';
  static const _phoneKey = 'account_phone';
  static const _nameKey = 'account_name';
  final FlutterSecureStorage _storage;

  Future<String?> readToken() => _storage.read(key: _tokenKey);

  Future<Account?> readAccount() async {
    final values = await _storage.readAll();
    final token = values[_tokenKey];
    final id = values[_idKey];
    final phone = values[_phoneKey];
    if (token == null || id == null || phone == null) return null;
    return Account(id: id, phone: phone, name: values[_nameKey]);
  }

  Future<void> save({required String token, required Account account}) async {
    await Future.wait([
      _storage.write(key: _tokenKey, value: token),
      _storage.write(key: _idKey, value: account.id),
      _storage.write(key: _phoneKey, value: account.phone),
      if (account.name != null)
        _storage.write(key: _nameKey, value: account.name),
    ]);
  }

  Future<void> clear() => _storage.deleteAll();
}
