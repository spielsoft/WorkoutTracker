# Apple Release Builds

WorkoutTracker currently prepares macOS and iOS release bundles. Android and
other desktop targets are not release-ready.

## Prerequisites

- Install Flutter and Xcode; accept the Xcode license.
- Run `flutter doctor` and resolve Apple toolchain failures.
- Configure a developer-owned Apple team, bundle identifiers, signing assets,
  and matching Google OAuth clients. Do not reuse another builder's team or
  credentials.
- Follow [`docs/google_sheets_development_auth.md`](docs/google_sheets_development_auth.md)
  to create the ignored local Google configuration files. All runtime-capable
  Flutter commands below require
  `local_google_credentials/flutter_dart_defines.json`.

## Clean Setup

From the repository root:

```sh
flutter clean
flutter pub get
```

`flutter pub get` is required after cleaning because it regenerates Flutter's
ephemeral Apple dependencies. If both bundles are needed, clean once and build
both; another clean removes prior outputs.

## macOS

With signing configured:

```sh
flutter build macos --release \
  --dart-define-from-file=local_google_credentials/flutter_dart_defines.json
```

For a local compile-only bundle when signing is unavailable:

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

Artifact:

```text
build/macos/Build/Products/Release/Workout Tracker.app
```

Validate a local unsigned build:

```sh
scripts/validate_macos_app_bundle.sh --compile-only \
  "build/macos/Build/Products/Release/Workout Tracker.app"
```

Omit `--compile-only` for a signed distribution candidate. An unsigned bundle
is suitable for compilation checks, not distribution.

## iOS

Build an unsigned release bundle:

```sh
flutter build ios --release --no-codesign \
  --dart-define-from-file=local_google_credentials/flutter_dart_defines.json
```

Artifact:

```text
build/ios/iphoneos/Runner.app
```

It is not device-installable until signed. For a signed archive/IPA with valid
Apple distribution configuration:

```sh
flutter build ipa --release \
  --dart-define-from-file=local_google_credentials/flutter_dart_defines.json
```

Artifacts are written under `build/ios/archive/` and `build/ios/ipa/`. Resolve
signing failures in Xcode; do not work around them by changing established
product identity unexpectedly.

## Release Gate

Before handing off a candidate:

```sh
flutter analyze
flutter test
```

Then perform the clean builds above and report whether signing and live Google
validation were completed or intentionally skipped. Live test instructions are
in [`docs/testing.md`](docs/testing.md).
