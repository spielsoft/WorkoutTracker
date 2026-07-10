# Google Sheets App Auth

WorkoutTracker now uses one runtime Google account model on iOS and macOS:

- Native `google_sign_in` owns account restore, sign-in, sign-out, and scoped
  token refresh.
- Existing sheet selection runs through the Drive API and a Flutter-native
  chooser screen.
- The chooser does not launch its own web OAuth flow or embed Google Picker in
  a WebView.

This keeps account state under the app's control while matching Google's
current desktop/mobile Picker guidance.

## Runtime flow

1. App startup restores the native Google session when the platform still has
   one.
2. Choosing a sheet requests Drive metadata scope through native Google
   Sign-In if the scope is not already granted.
3. The app opens a Flutter-native chooser and lists recent or searched Google
   Sheets through `files.list`.
4. Selecting a sheet persists the chosen spreadsheet and uses the native
   account for later Sheets API work.
5. Sheet creation uses the same native session and writable Sheets scope, but
   stays in Flutter rather than using Picker-owned auth state.

## Native OAuth configuration

Create iOS and macOS OAuth client configuration in Firebase or Google Cloud for
the app bundle identifier:

```text
com.spielman.workouttracker
```

Copy the `CLIENT_ID` and `REVERSED_CLIENT_ID` values from the platform
`GoogleService-Info.plist` into:

```text
ios/Flutter/GoogleSignIn.xcconfig
macos/Runner/Configs/AppInfo.xcconfig
```

The platform `Info.plist` files expose those values to `google_sign_in` as
`GIDClientID` and `CFBundleURLTypes`.

Current OAuth clients in the `workouttracker-16285` Google Cloud project:

- iOS/macOS app client:
  `657151291920-5j2u9pdgrn9b99nrk4np4dcnooal2ksk.apps.googleusercontent.com`
- Web client:
  `657151291920-la859t7i7i8b0kjs1f4cn6c09kd72376.apps.googleusercontent.com`
- macOS desktop client:
  `657151291920-lro68joadl4o0m3h1c537tm94t30eonq.apps.googleusercontent.com`

Local credential exports stay git-ignored under:

```text
local_google_credentials/
```

The local Dart defines file should still hold any native sign-in values needed
for your environment:

```text
local_google_credentials/flutter_dart_defines.json
```

Current native auth defines:

```text
WORKOUT_TRACKER_GOOGLE_CLIENT_ID
WORKOUT_TRACKER_GOOGLE_SERVER_CLIENT_ID
```

## Google Cloud and Firebase setup

Use the same Google Cloud project for native auth, Sheets API, and Drive API:

```text
657151291920
```

Enable:

- Google Sheets API
- Google Drive API

Firebase Hosting remains a static-site dependency for support/privacy pages. It
is not an app backend and it does not store workout data.

Production Hosting origins:

```text
https://workouttracker-16285.web.app
https://workouttracker-16285.firebaseapp.com
```

Support and privacy URLs for the OAuth consent screen:

```text
https://workouttracker-16285.web.app/
https://workouttracker-16285.web.app/privacy.html
```

## Scopes

Choosing a sheet uses:

```text
https://www.googleapis.com/auth/drive.metadata.readonly
```

Validation, workbook initialization, history writes, set logging, and sheet
creation use:

```text
https://www.googleapis.com/auth/spreadsheets
```

The MVP does not request full-drive read/write access.

## Local test boundaries

Local tests may verify app-owned contracts such as:

- requested scopes
- chooser query inputs
- selected-sheet persistence
- API adapter inputs
- planned sheet writes

They do not prove Google Sign-In, Drive API, Sheets, or Firebase Hosting
behavior. When external behavior matters, use opt-in live validation and
document the HITL step explicitly.

## macOS validation

For macOS native sign-in, open `macos/Runner.xcworkspace` in Xcode, select the
`Runner` target, and choose a development team under Signing & Capabilities.
The plugin requires keychain sharing, which will not work on an unsigned macOS
target.

Build the app:

```sh
flutter build macos
```

Run it:

```sh
open build/macos/Build/Products/Release/workout_tracker.app
```

Expected validation flow:

1. Sign in with Google once.
2. Tap Choose workout sheet.
3. Confirm the Flutter chooser opens inside the app.
4. Search for or pick a recent spreadsheet and confirm the app returns with the
   chosen sheet.
5. Restart the app and confirm the account restores without reselecting the
   sheet.

## iOS validation

Use a physical device for release-facing validation:

```sh
flutter devices
flutter run --release -d <device-id>
```

Simulator checks are useful for layout and basic flow only:

```sh
flutter build ios --simulator
flutter run -d <simulator-id>
```

Expected validation flow matches macOS: one native sign-in, then an in-app
Flutter sheet chooser, then persisted sheet selection on later launches.

## Development spreadsheet

The development spreadsheet for live Google validation is:

```text
https://docs.google.com/spreadsheets/d/1zQrmCYelrNqRMv4WtJcOrtezSxoaVniXzXi4XgKva_E/edit?gid=0#gid=0
```
