import 'package:carcare_customer_mobile/app/theme/theme_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('loads and persists the selected theme mode', () async {
    SharedPreferences.setMockInitialValues({'theme_mode': 'dark'});
    final controller = ThemeController();

    await controller.load();
    expect(controller.mode, ThemeMode.dark);

    await controller.setMode(ThemeMode.light);
    expect(controller.mode, ThemeMode.light);

    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getString('theme_mode'), 'light');

    controller.dispose();
  });
}
