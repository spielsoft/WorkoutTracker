# Build WorkoutTracker from Source

This is the authoritative clone-to-run and clean-release guide for the source
MVP. The repository does not distribute signed public application bundles.

## Platform Status

| Platform | Status |
| --- | --- |
| macOS | Prepared development and release-build target. A signed build is required to validate native Google login and stable keychain behavior. |
| iOS | Prepared mobile target. An unsigned release build proves compilation only; signing, provisioning, and a physical device are required to validate installation and Google login. |
| Linux and Windows | Unvalidated Flutter scaffolding. Google account access is not configured, so any experimental build success is not a support or release-readiness claim. |
| Android | Deferred and not release-ready. SDK/toolchain build validation, release networking and network permission, package/signing identity, OAuth client setup, and physical-device authentication testing remain undone. |

Android is deliberately excluded from the source-MVP build gate. Generated
Flutter scaffolding is not evidence that a platform is supported.

## 1. Install Prerequisites

Install:

- Git;
- a Flutter SDK compatible with the Dart constraint in `pubspec.yaml`; and
- Xcode with its requested components and license accepted.

Confirm that Flutter sees a working Apple toolchain:

```sh
flutter doctor -v
```

Resolve reported Flutter or Xcode failures before continuing.

## 2. Clone and Install Dependencies

```sh
git clone https://github.com/ispielma/WorkoutTracker.git
cd WorkoutTracker
flutter pub get
```

Run all remaining commands from the repository root unless a step explicitly
changes directory.

## 3. Supply Builder-Owned Google and Apple Configuration

Every builder owns their Google Cloud project, consent screen, quotas, native
OAuth clients, and any verification obligations. The repository owner's Cloud
project and credentials are not a shared service for source builds.

Create the ignored local files from the sanitized examples:

```sh
cp local_google_credentials/flutter_dart_defines.example.json \
  local_google_credentials/flutter_dart_defines.json
cp local_google_credentials/AppleBuild.example.xcconfig \
  local_google_credentials/AppleBuild.xcconfig
```

Replace every placeholder. In Google Cloud Console, enable the Google Drive
and Google Sheets APIs, configure the OAuth consent screen, and add every
account that will test the app while the consent screen remains in Testing.

For each Apple target, choose a unique bundle identifier and a developer-owned
Apple team, then create a matching native Google OAuth client. The ignored
`AppleBuild.xcconfig` supplies `WORKOUT_TRACKER_BUNDLE_ID`, `DEVELOPMENT_TEAM`,
the client ID, and its reversed-client URL scheme to both Apple projects. Keep
that client ID identical to `WORKOUT_TRACKER_GOOGLE_CLIENT_ID` in the ignored
Dart-defines file. Open `ios/Runner.xcworkspace` or
`macos/Runner.xcworkspace` in Xcode to resolve signing and provisioning.

Follow [`docs/google_sheets_development_auth.md`](docs/google_sheets_development_auth.md)
for the complete configuration contract. Do not commit real exports, generated
values, API keys, or local credential files.

## 4. Run the Credential-Free Local Gate

```sh
flutter analyze
flutter test
```

These checks use application-owned fakes. They do not prove Google, OAuth,
Firebase, or native sign-in behavior.

## 5. Run a Prepared Target

Run macOS with local configuration:

```sh
flutter run -d macos \
  --dart-define-from-file=local_google_credentials/flutter_dart_defines.json
```

For iOS, list devices, select a signed physical device, and substitute its ID:

```sh
flutter devices
flutter run --release -d <device-id> \
  --dart-define-from-file=local_google_credentials/flutter_dart_defines.json
```

A signed physical-device run is required for release-facing iOS login
validation. Simulator or unsigned build success is only a narrower compile or
UI signal.

## 6. Make Clean Release Builds

Clean once, restore dependencies, then build both targets. Cleaning between
the two builds removes the first artifact.

```sh
flutter clean
flutter pub get
```

With macOS signing configured:

```sh
flutter build macos --release \
  --dart-define-from-file=local_google_credentials/flutter_dart_defines.json
```

The artifact is:

```text
build/macos/Build/Products/Release/Workout Tracker.app
```

When signing is unavailable, compile with Xcode instead:

```sh
cd macos
xcodebuild -workspace Runner.xcworkspace \
  -scheme Runner \
  -configuration Release \
  -derivedDataPath ../build/macos \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY= \
  build
cd ..
```

Inspect the compile-only bundle:

```sh
scripts/validate_macos_app_bundle.sh --compile-only \
  "build/macos/Build/Products/Release/Workout Tracker.app"
```

Omit `--compile-only` when inspecting a signed distribution candidate. An
unsigned macOS bundle proves compilation and bundle structure only; it does not
establish stable keychain access, native Google login, launch on another Mac,
notarization, or distribution readiness.

Build the unsigned iOS release bundle:

```sh
flutter build ios --release --no-codesign \
  --dart-define-from-file=local_google_credentials/flutter_dart_defines.json
```

The compile-only artifact is:

```text
build/ios/iphoneos/Runner.app
```

It is not device-installable and does not validate Google login. With valid
Apple distribution signing, create an archive and IPA instead:

```sh
flutter build ipa --release \
  --dart-define-from-file=local_google_credentials/flutter_dart_defines.json
```

Flutter writes results under `build/ios/archive/` and `build/ios/ipa/`. Resolve
signing failures in Xcode; do not work around them by unexpectedly changing an
established bundle identity.

## 7. Run the Opt-In Live Google Gate

The live integration test destructively resets and writes only the named
development fixture documented in [`docs/testing.md`](docs/testing.md). Run it
only with explicit approval and a prepared macOS login session:

```sh
WORKOUT_TRACKER_RUN_LIVE_GOOGLE_TESTS=1 \
  flutter test integration_test/live_logging_flow_test.dart -d macos \
  --dart-define-from-file=local_google_credentials/flutter_dart_defines.json
```

Without the environment flag, the test skips before authentication. Report a
skipped live run as skipped, not as passing Google integration, and report any
fixture reset failure distinctly.

## Source-MVP Authorization Limit

The current app uses native Google Sign-In plus custom Flutter chooser UI
backed by Drive `files.list`. It requests:

```text
https://www.googleapis.com/auth/drive.metadata.readonly
https://www.googleapis.com/auth/spreadsheets
```

These sensitive and restricted scopes are acceptable only for the source MVP,
where each builder controls the Cloud project and audience. They are not the
intended authorization design for an unrestricted store release. A future,
separately gated plan will evaluate Google Picker and per-file access. This
release does not add Picker, a WebView, hosted callbacks, or scope migration.
