# Compile Release App Bundles

These commands build release artifacts from the repository root. They are not
debug builds.

## Prerequisites

- Xcode is installed and its license has been accepted.
- Apple signing is configured in Xcode for team `K77H93FM2M` and bundle ID
  `com.spielman.workouttracker` when producing signed deployment artifacts.
  IPA export requires an Apple account in Xcode, an iOS Distribution
  certificate, and a matching provisioning profile.

## Clean Build Setup

Remove previous outputs, then restore dependencies before either platform
build:

```sh
flutter clean
flutter pub get
```

Do not omit `flutter pub get` after `flutter clean`. It regenerates the
ephemeral Swift package used by the macOS and iOS projects. Build macOS before
iOS if both bundles should remain under `build/`, because another
`flutter clean` removes both outputs.

## macOS `.app`

Build the signed release macOS application bundle when the configured Apple
account and provisioning profile are available:

```sh
flutter build macos --release
```

If Xcode reports that no matching provisioning profile is available, build the
same release-mode app bundle without code signing:

```sh
cd macos
xcodebuild -workspace Runner.xcworkspace -scheme Runner -configuration Release -derivedDataPath ../build/macos CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY= build
cd ..
```

The app bundle is written to:

```text
build/macos/Build/Products/Release/Workout Tracker.app
```

Verify that the bundle is structurally complete after either signed or
unsigned compilation:

```sh
scripts/validate_macos_app_bundle.sh --compile-only \
  "build/macos/Build/Products/Release/Workout Tracker.app"
```

For a distribution candidate, omit `--compile-only`. Strict validation then
requires a trusted signature:

```sh
scripts/validate_macos_app_bundle.sh \
  "build/macos/Build/Products/Release/Workout Tracker.app"
```

The unsigned fallback is a release app bundle, but it must be signed before
distribution outside local development.

## iOS `.app` Bundle

Build the release iOS application bundle without code signing:

```sh
flutter build ios --release --no-codesign
```

The app bundle is written to:

```text
build/ios/iphoneos/Runner.app
```

This produces a release-mode app bundle, but it is not installable on a device
until it is signed. `Runner.app/Runner` should be an arm64 Mach-O executable.

## iOS Signed Deployment Archive

When a valid Apple development team, signing certificate, and provisioning
profile are available, build the signed deployment archive:

```sh
flutter build ipa --release
```

The signed IPA is written under:

```text
build/ios/ipa/
```

If archive creation succeeds but IPA export fails with missing account,
certificate, or profile errors, open the generated archive in Xcode and complete
signing/distribution there:

```text
build/ios/archive/Runner.xcarchive
```
