abstract interface class DeviceRepository {
  Future<void> registerDevice({
    required String deviceId,
    required String platform,
    required String firebaseToken,
    String? name,
    String? model,
    String? os,
  });

  Future<void> removeDevice(String deviceId);
}
