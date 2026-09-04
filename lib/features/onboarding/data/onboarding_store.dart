import 'package:shared_preferences/shared_preferences.dart';

/// Persists whether the first-run onboarding has been completed, so it shows
/// exactly once. A read failure is treated as "not seen" (show onboarding)
/// rather than crashing launch.
class OnboardingStore {
  const OnboardingStore();

  static const _key = 'onboarding_completed_v1';

  Future<bool> hasCompleted() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_key) ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> markCompleted() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_key, true);
    } catch (_) {
      // Non-fatal: worst case onboarding shows again next launch.
    }
  }
}
