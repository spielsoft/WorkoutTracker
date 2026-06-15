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

Enable the Google Sheets API in the same Google Cloud project as the OAuth
client:

```text
https://console.cloud.google.com/apis/library/sheets.googleapis.com?project=657151291920
```

## Sheets Scopes

Validation reads spreadsheet structure and cell display/formula data with the
minimum read-only Sheets scope:

```text
https://www.googleapis.com/auth/spreadsheets.readonly
```

History block creation and set logging use the Sheets spreadsheet scope:

```text
https://www.googleapis.com/auth/spreadsheets
```

The app does not require Drive scopes for the current MVP sheet contract.

## macOS GUI validation

For macOS native Google Sign-In, open `macos/Runner.xcworkspace` in Xcode,
select the `Runner` target, and choose a development team under Signing &
Capabilities. The plugin requires keychain sharing, which cannot be used by an
unsigned macOS target. The entitlements are already present in the project.

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
