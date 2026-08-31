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

4. Add a platform-restricted Google Maps key to `.env` when available. See [`docs/GOOGLE_MAPS_SETUP.md`](docs/GOOGLE_MAPS_SETUP.md).
5. Run the app:

   ```bash
   flutter run
   ```

## Validation

```bash
flutter analyze
flutter test
flutter build apk --debug
```

Real `.env` files, build output, Flutter caches, and IDE-local files are intentionally excluded from Git.
