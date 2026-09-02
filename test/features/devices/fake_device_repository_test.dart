import 'package:carcare_customer_mobile/features/devices/data/fake_device_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('registerDevice and removeDevice complete without throwing', () async {
    final repository = FakeDeviceRepository();

    await repository.registerDevice(
      deviceId: 'test-device',
      platform: 'ANDROID',
      firebaseToken: 'fake-token',
    );
    await repository.removeDevice('test-device');
  });
}
