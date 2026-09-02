import 'package:carcare_customer_mobile/core/network/api_client.dart';
import 'package:carcare_customer_mobile/features/devices/domain/device_repository.dart';

/// `POST /api/v1/app/devices` / `DELETE /api/v1/app/devices/[deviceId]`, per
/// `CUSTOMER_API_CONTRACT.md` "Push device registration". Best-effort: a
/// failure here should never block login/logout, so callers swallow errors.
class RemoteDeviceRepository implements DeviceRepository {
  RemoteDeviceRepository(this._client);

  final ApiClient _client;

  @override
  Future<void> registerDevice({
    required String deviceId,
    required String platform,
    required String firebaseToken,
    String? name,
    String? model,
    String? os,
  }) async {
    await _client.postJson('/devices', {
      'deviceId': deviceId,
      'platform': platform,
      'firebaseToken': firebaseToken,
      if (name != null && name.trim().isNotEmpty) 'name': name.trim(),
      if (model != null && model.trim().isNotEmpty) 'model': model.trim(),
      if (os != null && os.trim().isNotEmpty) 'os': os.trim(),
    });
  }

  @override
  Future<void> removeDevice(String deviceId) async {
    await _client.deleteJson('/devices/$deviceId');
  }
}
