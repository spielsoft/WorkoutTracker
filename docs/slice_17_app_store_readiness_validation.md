# Slice 17 App Store Readiness Validation

Slice 17 is a planning and configuration sanity check. It does not perform
store submission, signing setup, notarization, OAuth verification, or production
metadata work.

## Current Packaging State

### iOS App Store

- Status: structurally prepared.
- Flutter target present: `ios/`.
- Xcode project present: `ios/Runner.xcodeproj/project.pbxproj`.
- App metadata present: `ios/Runner/Info.plist`.
- App icon catalog present: `ios/Runner/Assets.xcassets/AppIcon.appiconset/`.
- Current bundle identifier: `com.spielman.workouttracker`.
- Version source: `pubspec.yaml` `version: 1.0.0+1`, surfaced to iOS through
  `FLUTTER_BUILD_NAME` and `FLUTTER_BUILD_NUMBER`.

Future App Store submission work will need an Apple Developer Program team,
a final unique bundle identifier, release signing, App Store Connect app record,
privacy answers, screenshots, support URL, privacy policy URL, and final app
metadata. This matches Flutter's iOS deployment flow, which includes registering
a Bundle ID, reviewing Xcode project settings, adding icons, and archiving for
App Store Connect:
https://docs.flutter.dev/deployment/ios

### macOS App Store

- Status: structurally prepared for a macOS `.app` bundle.
- Flutter target present: `macos/`.
- Xcode project present: `macos/Runner.xcodeproj/project.pbxproj`.
- App metadata present: `macos/Runner/Info.plist`.
- App icon catalog present: `macos/Runner/Assets.xcassets/AppIcon.appiconset/`.
- Current bundle identifier: `com.spielman.workouttracker`.
- Release entitlement file present: `macos/Runner/Release.entitlements`.
- Release sandbox entitlement: `com.apple.security.app-sandbox = true`.

Future macOS store submission work will need an Apple Developer Program team,
Mac App Store signing, final sandbox entitlements for Google/network access,
App Store Connect metadata, privacy answers, screenshots, support URL, and
privacy policy URL. If distribution outside the Mac App Store is later desired,
that will be a separate Developer ID signing and notarization path. Flutter's
macOS deployment guide covers building and releasing macOS apps:
https://docs.flutter.dev/deployment/macos

### Android Play Store

- Status: structurally prepared.
- Flutter target present: `android/`.
- Android Gradle application module present: `android/app/build.gradle.kts`.
- Manifest present: `android/app/src/main/AndroidManifest.xml`.
- Current application ID: `com.spielman.workouttracker`.
- Version source: `pubspec.yaml` `version: 1.0.0+1`, surfaced to Android as
  `versionName` and `versionCode`.

Future Play Store submission work will need a final package name decision,
release keystore, Play App Signing setup, app bundle generation, Play Console
app record, Data safety answers, privacy policy URL, screenshots, feature
graphic, content rating, target audience answers, and final app metadata.
Flutter's Android deployment guide covers app signing and app bundle release:
https://docs.flutter.dev/deployment/android

## Known Future Needs

- bundle identifiers: Apple and Android now use
  `com.spielman.workouttracker`; keep future OAuth, signing, and store
  registration aligned to that identifier.
- signing: configure Apple release signing for iOS/macOS and a non-debug
  Android release keystore. `android/app/build.gradle.kts` currently signs
  release builds with debug keys so local `flutter run --release` remains easy.
- entitlements: keep macOS sandbox enabled and add only the network/OAuth
  entitlements actually required by the GUI auth implementation. iOS may also
  need URL scheme configuration for a production OAuth redirect flow.
- OAuth consent: production Google access needs an OAuth consent screen, final
  client IDs per platform, authorized redirect/bundle/package settings, and the
  narrowest practical Sheets scope. The current backend development path is
  documented in `docs/google_sheets_development_auth.md`.
- privacy disclosures: App Store privacy details and Play Data safety answers
  must account for Google account identifiers, spreadsheet contents, fitness
  logging content, diagnostics if added later, and any third-party SDK behavior.
  Apple states that App Store submissions require privacy practice information:
  https://developer.apple.com/app-store/app-privacy-details/
  Google Play requires Data safety information in Play Console:
  https://support.google.com/googleplay/android-developer/answer/10787469
- store metadata: prepare app name, description, category, screenshots,
  support URL, privacy policy URL, content rating, and review notes explaining
  bring-your-own Google Sheet behavior.

## Dependency Review

No blocking dependencies were identified for future iOS App Store, macOS App
Store, or Android Play Store submission.

Current direct dependencies are Flutter SDK, `cupertino_icons`, `googleapis`,
`googleapis_auth`, and `http`. These do not introduce native ad, analytics,
payment, tracking, or private API SDKs. The Google API packages are appropriate
for the backend adapter and should remain behind an auth abstraction as the GUI
chooses the final platform sign-in flow.

No project architecture, framework choice, or package dependency blocker was
found. Local toolchain blockers discovered while attempting platform builds are
recorded in `issues/slice_17_toolchain_blockers.md` before GUI work proceeds.
The open store-readiness items above are expected future distribution tasks and
remain out of scope for the MVP's local/dev install target.

## Validation Results

- `flutter test test/platform_store_readiness_test.dart`: passed.
- `flutter test`: passed.
- `flutter build macos`: now passes after Xcode finished installing simulator
  support.
- `flutter build ios --simulator`: now passes after the iOS simulator runtime
  was installed.
- `flutter build appbundle`: blocked by local Android SDK configuration. Flutter
  reports no Android SDK and asks for `ANDROID_HOME`.
