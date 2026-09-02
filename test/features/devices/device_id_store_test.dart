import 'package:carcare_customer_mobile/features/devices/data/device_id_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('creates a device id once and reuses it on subsequent calls', () async {
    final store = DeviceIdStore();

    final first = await store.getOrCreate();
    final second = await store.getOrCreate();

    expect(first, second);
    expect(first, isNotEmpty);
  });

  test('a fresh store instance reads the same persisted id', () async {
    final firstId = await DeviceIdStore().getOrCreate();

    final secondId = await DeviceIdStore().getOrCreate();

    expect(secondId, firstId);
  });
}
