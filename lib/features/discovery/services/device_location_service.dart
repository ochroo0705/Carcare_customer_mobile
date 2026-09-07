import 'package:geolocator/geolocator.dart';

class DeviceLocation {
  const DeviceLocation(this.lat, this.lng);
  final double lat;
  final double lng;
}

/// Төхөөрөмжийн одоогийн байршлыг авах (discovery-ийн "ойролцоо" шүүлтэд).
abstract interface class DeviceLocationService {
  /// Одоогийн координат, эсвэл null (үйлчилгээ унтраалттай / зөвшөөрөл өгөөгүй /
  /// алдаа). Дуудагч null-ийг "ойролцоо-г идэвхжүүлж чадсангүй" гэж үзнэ.
  Future<DeviceLocation?> current();
}

class GeolocatorDeviceLocationService implements DeviceLocationService {
  const GeolocatorDeviceLocationService();

  @override
  Future<DeviceLocation?> current() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return null;
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }
      final position = await Geolocator.getCurrentPosition();
      return DeviceLocation(position.latitude, position.longitude);
    } catch (_) {
      return null;
    }
  }
}
