# CarCare Customer Mobile

Customer-facing Flutter application for discovering automotive service organizations, selecting branches, and building toward online appointment booking.

## Current scope

- Public organization discovery with dummy repository data
- Text, city, and district filtering
- List and Google Maps views
- Organization details and branch selection
- Light/dark CarCare design system
- Android and iOS projects

The backend customer contract and complete booking flow are still under development. Placeholder behavior is kept behind repository/domain boundaries so it can be replaced safely.

## Local setup

1. Install the current stable Flutter SDK and Android/iOS platform tooling.
2. Install dependencies:

   ```bash
   flutter pub get
   ```

3. Copy the environment example:

   ```bash
   cp .env.example .env
   ```

   On Windows Command Prompt:

   ```bat
   copy .env.example .env
   ```

4. Fill in `.env`: a platform-restricted Google Maps key when available (see
   [`docs/GOOGLE_MAPS_SETUP.md`](docs/GOOGLE_MAPS_SETUP.md)), plus
   `API_BASE_URL`/`USE_FAKE_API` for the customer API you want to run
   against — see the comments in `.env.example`.
5. Run the app so it actually picks up `.env`:

   ```bash
   flutter run --dart-define-from-file=.env
   ```

   VS Code's Run panel already has a "carcare_customer_mobile (.env)"
   launch configuration (`.vscode/launch.json`) that does this
   automatically — plain `flutter run`/the bare "Run" button falls back to
   the compile-time defaults in `lib/core/config/app_environment.dart`
   instead of `.env`.

## Validation

```bash
flutter analyze
flutter test
flutter build apk --debug
```

Real `.env` files, build output, Flutter caches, and IDE-local files are intentionally excluded from Git.
