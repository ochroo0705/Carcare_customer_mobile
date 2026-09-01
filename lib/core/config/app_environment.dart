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
    defaultValue: true,
  );
  static const bookingEnabled = bool.fromEnvironment(
    'BOOKING_ENABLED',
    defaultValue: true,
  );
}
