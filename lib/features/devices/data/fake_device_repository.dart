import 'package:carcare_customer_mobile/features/devices/domain/device_repository.dart';
import 'package:flutter/foundation.dart';

/// No-op under `USE_FAKE_API=true` — there is nothing to register with.
class FakeDeviceRepository implements DeviceRepository {
  @override
  Future<void> registerDevice({
    required String deviceId,
    required String platform,
    required String firebaseToken,
    String? name,
    String? model,
    String? os,
  }) async {
    debugPrint(
      'FakeDeviceRepository: would register device $deviceId ($platform)',
    );
  }

  @override
  Future<void> removeDevice(String deviceId) async {
    debugPrint('FakeDeviceRepository: would remove device $deviceId');
  }
}
