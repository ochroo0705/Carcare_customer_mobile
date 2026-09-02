/// Compile-time environment flags. All values come from `--dart-define`,
/// normally supplied automatically by running/building with
/// `--dart-define-from-file=.env` (see `.env.example` and
/// `docs/GOOGLE_MAPS_SETUP.md`) rather than passing each `--dart-define`
/// flag by hand — a `.vscode/launch.json` entry already does this for VS
/// Code. A missing/absent `.env` file falls back to the defaults below.
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
