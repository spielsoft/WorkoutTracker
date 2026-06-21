# Google Sheets App Auth

WorkoutTracker uses native Google Sign-In for runnable iOS and macOS apps.
When the user taps Validate, creates a history block, or saves a set, the app
requests the needed Google Sheets scope through the platform account-picker
flow.

## OAuth Configuration

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

The platform `Info.plist` files expose those values to the `google_sign_in`
plugin as `GIDClientID` and `CFBundleURLTypes`.

Current OAuth clients in the `workouttracker-16285` Google Cloud project:

- iOS/macOS app client:
  `657151291920-5j2u9pdgrn9b99nrk4np4dcnooal2ksk.apps.googleusercontent.com`
- Web client:
  `657151291920-la859t7i7i8b0kjs1f4cn6c09kd72376.apps.googleusercontent.com`
- MacOS Desktop client:
  `657151291920-lro68joadl4o0m3h1c537tm94t30eonq.apps.googleusercontent.com`

The exported Desktop OAuth JSON includes a client secret, so local credential
exports and API keys are stored only in visible, git-ignored JSON files under:

```text
local_google_credentials/
```

See `local_google_credentials/README.md` for the current file layout.

Enable the Google Sheets API in the same Google Cloud project as the OAuth
client:

```text
https://console.cloud.google.com/apis/library/sheets.googleapis.com?project=657151291920
```

Google Drive Picker is used for choosing an existing spreadsheet, and
Google-backed sheet creation initializes a new WorkoutTracker spreadsheet in
Drive. Picker selection uses the checked-in web OAuth client ID for the
`workouttracker-16285` Google Cloud project:

```text
657151291920-la859t7i7i8b0kjs1f4cn6c09kd72376.apps.googleusercontent.com
```

## Sheets Scopes

Validation, history block creation, set logging, exercise authoring, and app
spreadsheet initialization all request the writable Sheets spreadsheet scope:

```text
https://www.googleapis.com/auth/spreadsheets
```

Future Google Drive sheet selection or creation work may need the Drive file
scope:

```text
https://www.googleapis.com/auth/drive.file
```

The app does not request full-drive access for the MVP sheet contract.

## macOS GUI validation

For macOS native Google Sign-In, open `macos/Runner.xcworkspace` in Xcode,
select the `Runner` target, and choose a development team under Signing &
Capabilities. The plugin requires keychain sharing, which cannot be used by an
unsigned macOS target. The Picker loopback callback also requires local network
server entitlement in macOS builds. The entitlements are already present in the
project.

Build the macOS bundle:

```sh
flutter build macos
```

Run the app and press Validate. A browser/account-picker prompt should appear
when Google authorization is needed:

```sh
open build/macos/Build/Products/Release/workout_tracker.app
```

## iOS simulator validation

Boot an available simulator and run the app through Flutter so the simulator
installs and launches the bundle:

```sh
flutter devices
flutter run -d <simulator-id>
```

The iOS simulator build can be checked without live Google access:

```sh
flutter build ios --simulator
```

Press Validate in the launched simulator app. The Google account-picker flow
should appear when authorization is needed.

## Development Spreadsheet

The development spreadsheet for Google integration validation is:

```text
https://docs.google.com/spreadsheets/d/1zQrmCYelrNqRMv4WtJcOrtezSxoaVniXzXi4XgKva_E/edit?gid=0#gid=0
```
