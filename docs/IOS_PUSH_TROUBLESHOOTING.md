# iOS push troubleshooting

## Current evidence — 2026-09-05

A notification sent through the production backend did not appear on an iOS simulator, reportedly iOS 17 on a Mac mini. Mac chip, macOS/Xcode versions, current simulator token, provider response and app foreground/background state are unknown. The developer has no production deployment logs. This does not establish whether the fault is in the app, APNs/Firebase or backend targeting.

The checked-in GoogleService-Info.plist uses project `carcare-bf796` and bundle ID `mn.infosystems.carcare.customer`, matching the Xcode target. It is included in build resources. Remote-notification background mode is present and Firebase swizzling is not disabled. Push entitlements are absent from this checkout; the developer enables the capability on the Mac before archiving. Confirm it is also enabled for the build used to run the simulator, before testing.

Uploading an APNs key to the same Firebase iOS app normally does not require replacing GoogleService-Info.plist. Verify the Firebase app/project/bundle identity rather than downloading configuration as a first troubleshooting step.

## Next workplace test

1. Record Mac chip, macOS, Xcode and simulated iOS versions. Apple introduced real simulator APNs support with iOS 16, macOS 13 and Apple silicon or T2 hardware. The simulator uses APNs sandbox. An unspecified Mac mini model is insufficient to establish compatibility. Prefer a physical iPhone as an additional comparison.
2. In Xcode, confirm Runner's Push Notifications capability applies to the simulator Debug build, and check the bundle ID. Enable the Firebase-documented background modes. Archive-time setup alone does not verify the earlier simulator run.
3. In Firebase project settings → Cloud Messaging → the correct Apple app, verify APNs authentication is configured for development/sandbox delivery as well as the production environment you intend to use. Check Team ID and Key ID. A production-only credential can leave simulator delivery broken.
4. Launch the app, allow notifications, complete onboarding and sign in. Use real API mode for backend registration. In a local debugger, inspect `FirebaseMessaging.instance.getAPNSToken()` and then `FirebaseMessaging.instance.getToken()` after APNs is ready. Keep actual token values private; record only presence or the error code in shared diagnostics. Use this installation's current FCM token, not its APNs token or an Android token.
5. Put the app in the background using Home, leaving it installed and running. In Firebase Messaging, send a test notification with a visible title/body to that current FCM token. Record any error and whether a banner or notification-center entry arrives. This bypasses production backend selection and registration logic. Firebase accepting a send alone is not proof of delivery.
6. If direct Firebase delivery works, repeat the original production action for the same signed-in account. Ask the backend owner to verify that account's device record, platform, current token match, Firebase project and send result. Request sanitized provider error codes if delivery fails; no production log access is needed for the initial direct-Firebase test.
7. After background delivery works, test foreground display and tapping from background/terminated states separately. This app uses its local-notification service for foreground presentation, so a foreground-only failure is a different investigation.

## Interpret the first failing checkpoint

| Observation | Next investigation |
|---|---|
| APNs token stays absent | Simulator compatibility, Debug capabilities, native registration errors, network access to APNs. |
| APNs exists but FCM token fails | Exact Firebase error code, Firebase initialization/project identity and APNs-to-FCM registration timing. |
| Current FCM token exists but direct Firebase notification fails | Notification permission/presentation, APNs sandbox credentials, bundle/team identity and Firebase send errors. Token existence does not prove delivery credentials are valid. |
| Firebase test arrives but production notification does not | Backend device registration, correct recipient and trigger, current token selection, sender project and provider result. |
| Background arrives but foreground does not display | `onMessage` receipt and local notification initialization/display. |

`xcrun simctl push` and dragged `.apns` files can test local simulator handling but bypass actual Firebase/APNs delivery. They cannot validate Firebase credentials or the production sender.

## Code change and limits

`FirebaseRemotePushService` now checks APNs before requesting FCM on Apple platforms, with twenty 500 ms retry delays and shared concurrent acquisition. Native API call duration is additional. Missing APNs returns null after retries; existing token-refresh handling and later sign-ins can try registration again. This addresses a source-level startup race, not a confirmed explanation for the failed production test. Router guards prevent delayed registration from starting after disposal or an observed account change; they do not cancel a request already in flight.

Six unit tests cover token sequencing, bounded retries/recovery, error handling, concurrent acquisition and the non-Apple path. Flutter/Dart are unavailable in the current Windows workspace, so these tests and iOS delivery have not been executed. On a Flutter-equipped machine run:

```sh
flutter analyze
flutter test test/core/notifications/remote_push_service_test.dart
flutter test test/app/notification_deep_link_test.dart
```

Complete a physical-device delivery test before treating iOS push as release-verified.

## Official references

- [Apple Xcode 14 release notes: simulator remote notifications](https://developer.apple.com/documentation/xcode-release-notes/xcode-14-release-notes)
- [Firebase Flutter client setup: capabilities, APNs credentials and token ordering](https://firebase.google.com/docs/cloud-messaging/flutter/get-started)
- [Firebase Apple client setup and test notifications](https://firebase.google.com/docs/cloud-messaging/ios/get-started)
