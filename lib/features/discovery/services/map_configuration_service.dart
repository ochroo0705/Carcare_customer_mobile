import 'package:flutter/services.dart';

/// Native Maps API key тохиргоог Flutter-д зөвхөн boolean-аар мэдээлнэ.
/// Key өөрөө Dart state эсвэл log руу дамжихгүй.
abstract interface class MapConfigurationService {
  Future<bool> isConfigured();
}

class NativeMapConfigurationService implements MapConfigurationService {
  const NativeMapConfigurationService();

  static const _channel = MethodChannel(
    'mn.carcare.carcare_customer_mobile/map_configuration',
  );

  @override
  Future<bool> isConfigured() async {
    try {
      return await _channel.invokeMethod<bool>('isConfigured') ?? false;
    } on MissingPluginException {
      // Widget tests and unsupported desktop platforms do not install the
      // native channel. Keep their existing map-widget behavior intact.
      return true;
    } on PlatformException {
      // Native тохиргоо уншихад алдаа гарвал map байгуулахгүй, list fallback
      // харуулна. Maps SDK-г буруу key-тэйгээр initialize хийхээс аюулгүй.
      return false;
    }
  }
}
