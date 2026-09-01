import 'package:permission_handler/permission_handler.dart';

enum LocationAccessState { granted, denied, permanentlyDenied }

abstract interface class LocationPermissionService {
  Future<LocationAccessState> check();
  Future<LocationAccessState> request();
  Future<bool> openSettings();
}

class PermissionHandlerLocationPermissionService
    implements LocationPermissionService {
  const PermissionHandlerLocationPermissionService();

  @override
  Future<LocationAccessState> check() =>
      _map(Permission.locationWhenInUse.status);

  @override
  Future<LocationAccessState> request() =>
      _map(Permission.locationWhenInUse.request());

  @override
  Future<bool> openSettings() => openAppSettings();

  Future<LocationAccessState> _map(Future<PermissionStatus> future) async {
    final status = await future;
    if (status.isGranted || status.isLimited) {
      return LocationAccessState.granted;
    }
    if (status.isPermanentlyDenied || status.isRestricted) {
      return LocationAccessState.permanentlyDenied;
    }
    return LocationAccessState.denied;
  }
}
