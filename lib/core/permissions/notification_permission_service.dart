import 'package:permission_handler/permission_handler.dart';

/// Tri-state permission result, matching `LocationAccessState` in
/// `discovery/services/location_permission_service.dart` so both permissions
/// drive the same UI (grant / request-again / open-settings).
enum PermissionState { granted, denied, permanentlyDenied }

/// Notification permission (Android 13+ POST_NOTIFICATIONS; iOS alert/badge/
/// sound). Reusable by onboarding and any in-app re-prompt, so "permanently
/// denied → open settings" behaves identically everywhere. Mirrors the shape of
/// [LocationPermissionService].
abstract interface class NotificationPermissionService {
  Future<PermissionState> check();
  Future<PermissionState> request();
  Future<bool> openSettings();
}

class PermissionHandlerNotificationPermissionService
    implements NotificationPermissionService {
  const PermissionHandlerNotificationPermissionService();

  @override
  Future<PermissionState> check() => _map(Permission.notification.status);

  @override
  Future<PermissionState> request() => _map(Permission.notification.request());

  @override
  Future<bool> openSettings() => openAppSettings();

  Future<PermissionState> _map(Future<PermissionStatus> future) async {
    final status = await future;
    if (status.isGranted || status.isLimited || status.isProvisional) {
      return PermissionState.granted;
    }
    if (status.isPermanentlyDenied || status.isRestricted) {
      return PermissionState.permanentlyDenied;
    }
    return PermissionState.denied;
  }
}
