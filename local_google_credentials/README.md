# Local Google Configuration

This is the repository's single location for builder-owned Google Cloud
exports and generated build values. Keep real files here; everything except
this guide and sanitized `*.example.*` templates is ignored by Git.

Create the local file from the tracked example:

```sh
cp local_google_credentials/AppleBuild.example.xcconfig \
  local_google_credentials/AppleBuild.xcconfig
```

Replace every `YOUR_...` value. The bundle ID must be unique, and the Apple
team must own its signing identity. The client ID must be the native OAuth
client for that bundle. The reversed client ID is that client's URL scheme.

You may also keep downloaded files such as platform-specific
`GoogleService-Info.plist` exports and OAuth JSON exports here. Do not copy
those exports into `ios/`, `macos/`, or another tracked directory. The app's
checked-in Apple configuration loads `AppleBuild.xcconfig` from this folder.
The resulting `Info.plist` values are read directly by native Google Sign-In,
so ordinary Flutter run and build commands need no credential flags.

Dart client-ID defines remain optional overrides for nonstandard runs. The app
validates an override when supplied but does not require one on Apple.

See [`docs/google_sheets_development_auth.md`](../docs/google_sheets_development_auth.md)
for Cloud Console, consent-screen, signing, and platform setup.
