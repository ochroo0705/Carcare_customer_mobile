import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FavoritesController extends ChangeNotifier {
  static const _preferenceKey = 'favorite_organization_slugs';

  Set<String> _slugs = const {};

  bool contains(String slug) => _slugs.contains(slug);

  Future<void> load() async {
    final preferences = await SharedPreferences.getInstance();
    _slugs = preferences.getStringList(_preferenceKey)?.toSet() ?? <String>{};
    notifyListeners();
  }

  Future<void> toggle(String slug) async {
    final next = {..._slugs};
    if (!next.remove(slug)) next.add(slug);
    _slugs = next;
    notifyListeners();
    final preferences = await SharedPreferences.getInstance();
    final values = next.toList()..sort();
    await preferences.setStringList(_preferenceKey, values);
  }
}
