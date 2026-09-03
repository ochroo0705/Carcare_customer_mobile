/// Compile-time орчны тохиргоо. Бүх утга `--dart-define`-ээр орж ирнэ.
/// Ихэвчлэн тус бүрийг гараар өгөхөөс илүү
/// `--dart-define-from-file=.env` ашиглана (`.env.example` болон
/// `docs/GOOGLE_MAPS_SETUP.md`-г үзнэ үү). `.env` байхгүй бол доорх
/// default утгууд хэрэглэгдэнэ — ингэснээр debug app хоосон тохиргоотойгоор
/// ч асаж, тохиргооны алдаа нь compile-time биш runtime-д илэрнэ.
abstract final class AppEnvironment {
  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:4000/api/v1/app',
  );
  static const environmentName = String.fromEnvironment(
    'APP_ENV',
    defaultValue: 'development',
  );
  static const useFakeApi = bool.fromEnvironment(
    'USE_FAKE_API',
    defaultValue: false,
  );
  static const bookingEnabled = bool.fromEnvironment(
    'BOOKING_ENABLED',
    defaultValue: true,
  );
}
