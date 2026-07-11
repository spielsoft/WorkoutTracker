# Local Google Configuration

This is the repository's single location for builder-owned Google Cloud
exports and generated build values. Keep real files here; everything except
this guide and sanitized `*.example.*` templates is ignored by Git.

Create the local files from the tracked examples:

```sh
cp local_google_credentials/flutter_dart_defines.example.json \
  local_google_credentials/flutter_dart_defines.json
cp local_google_credentials/AppleBuild.example.xcconfig \
  local_google_credentials/AppleBuild.xcconfig
```

Replace every `YOUR_...` value. The bundle ID must be unique, and the Apple
team must own its signing identity. The client ID in both files must be the
same native OAuth client ID for that bundle. The reversed client ID is that
client's URL scheme. A server client ID is optional because this app has no
token-handling backend; remove its entry or leave it empty when unused.

You may also keep downloaded files such as platform-specific
`GoogleService-Info.plist` exports and OAuth JSON exports here. Do not copy
those exports into `ios/`, `macos/`, or another tracked directory. The app's
checked-in Apple configuration loads `AppleBuild.xcconfig` from this folder.
Flutter receives the matching runtime value with:

```sh
flutter run -d macos \
  --dart-define-from-file=local_google_credentials/flutter_dart_defines.json
```

The runtime validator rejects a missing or malformed
`WORKOUT_TRACKER_GOOGLE_CLIENT_ID` before native login starts and points back
to the setup guide. It never includes the configured value in its error.

See [`docs/google_sheets_development_auth.md`](../docs/google_sheets_development_auth.md)
for Cloud Console, consent-screen, signing, and platform setup.
