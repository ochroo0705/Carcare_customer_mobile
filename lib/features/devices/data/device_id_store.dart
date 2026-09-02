import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// A stable per-install device id, created once and persisted forever —
/// matches the API contract's "reusing a stable install ID makes this
/// operation an upsert" requirement. Not sensitive, so plain
/// `shared_preferences` (same store `FavoritesController` already uses) is
/// sufficient; it doesn't need OS-backed secure storage.
class DeviceIdStore {
  static const _key = 'device_install_id';

  Future<String> getOrCreate() async {
    final preferences = await SharedPreferences.getInstance();
    final existing = preferences.getString(_key);
    if (existing != null && existing.isNotEmpty) return existing;
    final generated = const Uuid().v4();
    await preferences.setString(_key, generated);
    return generated;
  }
}
