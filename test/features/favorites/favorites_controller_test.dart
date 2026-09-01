import 'package:carcare_customer_mobile/features/favorites/presentation/controllers/favorites_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('toggles and persists organization slugs', () async {
    SharedPreferences.setMockInitialValues({});
    final controller = FavoritesController();
    await controller.load();

    await controller.toggle('auto-doctor');
    expect(controller.contains('auto-doctor'), isTrue);

    final restored = FavoritesController();
    await restored.load();
    expect(restored.contains('auto-doctor'), isTrue);

    await restored.toggle('auto-doctor');
    expect(restored.contains('auto-doctor'), isFalse);

    controller.dispose();
    restored.dispose();
  });
}
