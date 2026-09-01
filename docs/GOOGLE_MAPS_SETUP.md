# Google Maps setup

The customer app reads the Google Maps API key from the project-local `.env` file during the native Android/iOS build. The file is ignored by Git and is not bundled as a Flutter asset.

## Add the key

Edit `carcare_customer_mobile/.env`:

```dotenv
GOOGLE_MAP_API_KEY=your_key_here
```

Then stop and rebuild the application. Hot reload cannot update native API-key configuration.

```powershell
flutter clean
flutter pub get
flutter run
```

When the key is absent, the app deliberately keeps discovery usable by showing
the list fallback instead of constructing a native map view. Release builds
must still provide a real key; this fallback is for safe local diagnosis, not a
replacement for Maps configuration.

## Google Cloud requirements

Enable billing and the platform APIs used by the build:

- Maps SDK for Android
- Maps SDK for iOS

The Android application ID is:

```text
mn.carcare.carcare_customer_mobile
```

Use an application-restricted API key before release. Google recommends separate restricted keys for Android and iOS. The current development setup intentionally uses the requested shared `GOOGLE_MAP_API_KEY` variable; split it into platform-specific variables before production if both platforms ship.

## Implementation locations

- Android `.env` loading: `android/app/build.gradle.kts`
- Android key metadata: `android/app/src/main/AndroidManifest.xml`
- iOS `.env` inclusion: `ios/Flutter/Debug.xcconfig` and `Release.xcconfig`
- iOS key forwarding: `ios/Runner/Info.plist` and `AppDelegate.swift`
- Flutter map widget: `lib/features/discovery/presentation/widgets/discovery_map.dart`

Organizations without branch coordinates remain available in list view. If no visible organization has coordinates, the map view shows an explicit empty-location state.

On iOS, `NSLocationWhenInUseUsageDescription` is required for the map's
nearby-location capability. It is declared in `Runner/Info.plist`; changing it
requires a full reinstall or rebuild before it appears in iOS Settings.

## Blank map troubleshooting

The capability message `AdvancedMarkers: false: Capabilities unavailable without a Map ID` is informational for this app. It uses standard markers, so a Map ID is not required.

If the Google logo and controls appear but the ROADMAP tiles remain blank:

1. Confirm billing is active and **Maps SDK for Android** is enabled in the same Google Cloud project as the key.
2. If the key has Android application restrictions, configure package name `mn.carcare.carcare_customer_mobile` and the SHA-1 fingerprint of the certificate used to sign the current build. The debug and release fingerprints can differ.
3. Use an emulator system image that includes Google Play or Google APIs, confirm it has working internet access, and update Google Play services. Prefer a current x86_64 image over the older Android 9 image.
4. Stop the app and perform a full rebuild. Hot reload does not replace native manifest metadata.
5. Filter Logcat for `Google Maps Android API`; an authorization failure normally states whether the SDK, billing, key, package name, or SHA-1 restriction is incorrect.

Messages about `FrameEvents`, `EGL_emulation`, or a renderer shutting down are commonly emulator/platform-view rendering noise. Diagnose them separately unless the app crashes or a physical device shows the same rendering failure.
