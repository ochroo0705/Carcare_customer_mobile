import 'dart:async';

import 'package:carcare_customer_mobile/features/auth/domain/account.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Account token болон identity-г OS-backed secure storage-д хадгална.
/// SharedPreferences-д token хийхгүй: API token нь нууц мэдээлэл бөгөөд
/// app-ийн энгийн тохиргоо/кэштэй ижил хадгалалтын түвшинд байж болохгүй.
class SecureSessionStore {
  SecureSessionStore({
    FlutterSecureStorage? storage,
    Future<SharedPreferences> Function()? preferences,
  }) : _storage = storage ?? const FlutterSecureStorage(),
       _preferences = preferences ?? SharedPreferences.getInstance;

  static const _tokenKey = 'account_access_token';
  static const _idKey = 'account_id';
  static const _phoneKey = 'account_phone';
  static const _nameKey = 'account_name';
  static const _installMarkerKey = 'session_store_install_marker';
  final FlutterSecureStorage _storage;
  final Future<SharedPreferences> Function() _preferences;
  Future<void>? _installCheck;
  final _cleared = StreamController<void>.broadcast();

  // In-memory copy of the stored session: every API request reads the token,
  // and each read otherwise hits the platform keychain. Written through by
  // [save], dropped by [clear]. [_generation] stops a read that was already
  // in flight from re-populating the cache with pre-save/pre-clear data.
  Map<String, String>? _cache;
  int _generation = 0;

  /// Fires every time [clear] runs — a signout as well as a repository's
  /// `onUnauthorized` 401 handler both go through here, so anything holding
  /// authenticated UI state (see `AuthController`) can react regardless of
  /// which screen's API call happened to trigger the 401.
  Stream<void> get onCleared => _cleared.stream;

  /// API client-д Authorization header үүсгэхэд хэрэглэнэ.
  ///
  /// Returns the token only while the session is complete (see
  /// [readAccount]), so a half-written session never sends a Bearer header.
  Future<String?> readToken() async {
    final values = await _readAll();
    return _isComplete(values) ? values[_tokenKey] : null;
  }

  /// Token, id, phone гурав бүрэн байж session хүчинтэй гэж үзнэ.
  Future<Account?> readAccount() async {
    final values = await _readAll();
    if (!_isComplete(values)) return null;
    return Account(
      id: values[_idKey]!,
      phone: values[_phoneKey]!,
      name: values[_nameKey],
    );
  }

  static bool _isComplete(Map<String, String> values) =>
      values[_tokenKey] != null &&
      values[_idKey] != null &&
      values[_phoneKey] != null;

  /// Reads the whole store, treating an unreadable store as signed out.
  ///
  /// Secure storage can throw when its data exists but its key doesn't —
  /// e.g. an encrypted store carried to a new device, where the hardware
  /// key didn't come along. That state can never recover, so it is wiped
  /// rather than crashing every launch and every request.
  Future<Map<String, String>> _readAll() async {
    final cached = _cache;
    if (cached != null) return cached;
    await (_installCheck ??= _discardIfReinstalled());
    final generation = _generation;
    try {
      final values = await _storage.readAll();
      if (generation == _generation) _cache = Map.unmodifiable(values);
      return values;
    } catch (_) {
      await _deleteAllQuietly();
      return const {};
    }
  }

  /// iOS keeps keychain items after the app is uninstalled, so a reinstall
  /// would silently sign the previous user back in. SharedPreferences, by
  /// contrast, is removed with the app: no marker *and* no other prefs means
  /// a fresh install, so any session left in the keychain is discarded. An
  /// app update keeps its prefs, so an existing user is not signed out.
  Future<void> _discardIfReinstalled() async {
    try {
      final prefs = await _preferences();
      if (prefs.containsKey(_installMarkerKey)) return;
      if (prefs.getKeys().isEmpty) await _deleteAllQuietly();
      await prefs.setBool(_installMarkerKey, true);
    } catch (_) {
      // Best-effort: failing this check must never block restoring a session.
    }
  }

  Future<void> _deleteAllQuietly() async {
    try {
      await _storage.deleteAll();
    } catch (_) {}
  }

  /// Session-ийн заавал байх талбаруудыг хадгална. Account-ийн нэр optional
  /// тул байхгүй үед storage-д бичихгүй.
  Future<void> save({required String token, required Account account}) async {
    _generation++;
    _cache = null;
    await Future.wait([
      _storage.write(key: _tokenKey, value: token),
      _storage.write(key: _idKey, value: account.id),
      _storage.write(key: _phoneKey, value: account.phone),
      account.name != null
          ? _storage.write(key: _nameKey, value: account.name)
          : _storage.delete(key: _nameKey),
    ]);
    _generation++;
    _cache = Map.unmodifiable({
      _tokenKey: token,
      _idKey: account.id,
      _phoneKey: account.phone,
      if (account.name != null) _nameKey: account.name!,
    });
  }

  /// Logout/401-ийн дараа бүх session key-г хамтад нь устгана.
  Future<void> clear() async {
    _generation++;
    _cache = null;
    await _deleteAllQuietly();
    // A read that started during the delete may have cached pre-delete data.
    _generation++;
    _cache = null;
    _cleared.add(null);
  }
}
