import 'package:carcare_customer_mobile/features/auth/domain/account.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Account token болон identity-г OS-backed secure storage-д хадгална.
/// SharedPreferences-д token хийхгүй: API token нь нууц мэдээлэл бөгөөд
/// app-ийн энгийн тохиргоо/кэштэй ижил хадгалалтын түвшинд байж болохгүй.
class SecureSessionStore {
  SecureSessionStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _tokenKey = 'account_access_token';
  static const _idKey = 'account_id';
  static const _phoneKey = 'account_phone';
  static const _nameKey = 'account_name';
  final FlutterSecureStorage _storage;

  /// API client-д Authorization header үүсгэхэд хэрэглэнэ.
  Future<String?> readToken() => _storage.read(key: _tokenKey);

  /// Token, id, phone гурав бүрэн байж session хүчинтэй гэж үзнэ.
  Future<Account?> readAccount() async {
    final values = await _storage.readAll();
    final token = values[_tokenKey];
    final id = values[_idKey];
    final phone = values[_phoneKey];
    if (token == null || id == null || phone == null) return null;
    return Account(id: id, phone: phone, name: values[_nameKey]);
  }

  /// Session-ийн заавал байх талбаруудыг хадгална. Account-ийн нэр optional
  /// тул байхгүй үед storage-д бичихгүй.
  Future<void> save({required String token, required Account account}) async {
    await Future.wait([
      _storage.write(key: _tokenKey, value: token),
      _storage.write(key: _idKey, value: account.id),
      _storage.write(key: _phoneKey, value: account.phone),
      if (account.name != null)
        _storage.write(key: _nameKey, value: account.name),
    ]);
  }

  /// Logout/401-ийн дараа бүх session key-г хамтад нь устгана.
  Future<void> clear() => _storage.deleteAll();
}
