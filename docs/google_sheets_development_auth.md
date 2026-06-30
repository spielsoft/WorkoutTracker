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

Google Drive Picker is used for choosing an existing spreadsheet and for the
OAuth authorization that backs later Google Sheets API calls. Google-backed
sheet creation also uses this Picker authorization path to choose a destination
folder before it asks for a sheet name and initializes a new WorkoutTracker
spreadsheet in Drive. The Picker callback forwards the access token and Google
account profile used by the app's account menu and persisted launch state.
Picker selection uses the checked-in web OAuth client ID for the
`workouttracker-16285` Google Cloud project:

```text
657151291920-la859t7i7i8b0kjs1f4cn6c09kd72376.apps.googleusercontent.com
```

## Firebase Hosting Picker Callback

Firebase Hosting is a durable release dependency for support/privacy pages and
for the Google Picker browser-to-native handoff. It is a static site, not an
app backend, and it does not store workout data. The durable data artifact
remains the user-owned Google Sheet.

The repo-root Firebase config points at the existing Firebase project:

```text
workouttracker-16285
```

The configured production Hosting origins, after live deploy, are:

```text
https://workouttracker-16285.web.app
https://workouttracker-16285.firebaseapp.com
```

The Google Picker OAuth redirect/callback URL to deploy and register is:

```text
https://workouttracker-16285.firebaseapp.com/google-picker-callback/
```

This URI must match the Web OAuth client's Authorized redirect URI exactly.
Using the alternate `web.app` hosting origin for this OAuth redirect causes
Google to return `Error 400: redirect_uri_mismatch`.

The hosted callback page preserves Google Picker result parameters and returns
them to the native Flutter app through this app-owned URL scheme:

```text
workouttracker://google-picker-callback
```

Before relying on the hosted callback, deploy Firebase Hosting to the live
channel and confirm the callback URL returns HTTP 200. The Web OAuth client must
then list the exact hosted callback URL above under Authorized redirect URIs.
The OAuth consent screen should also use the hosted support and privacy URLs:

```text
https://workouttracker-16285.web.app/
https://workouttracker-16285.web.app/privacy.html
```

Production app startup injects the native callback receiver, so Picker
authorization always uses the hosted HTTPS callback. The app no longer supports
a local loopback Picker callback path.

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

## Test Boundaries

Default local tests may use fake Google-facing collaborators only to verify this
app's interface contracts, such as requested scopes, generated OAuth URLs,
accepted callback parameters, and adapter write plans. Those tests do not prove
Google Sign-In, OAuth, Picker, Sheets, Drive, or Firebase Hosting behavior. Do
not add canned Google HTTP responses or simulated Picker success flows as
behavior tests. When real Google behavior matters, use explicit opt-in live
validation against the development sheet and report any required user
authorization or sheet writes.

## macOS GUI validation

For macOS native Google Sign-In, open `macos/Runner.xcworkspace` in Xcode,
select the `Runner` target, and choose a development team under Signing &
Capabilities. The plugin requires keychain sharing, which cannot be used by an
unsigned macOS target. Picker selection should use the hosted HTTPS callback
and app-owned URL scheme above for release validation.

Build the macOS bundle:

```sh
flutter build macos
```

Run the app and use Choose workout sheet or Create sheet. A browser Picker flow
should appear when Google authorization is needed:

```sh
open build/macos/Build/Products/Release/workout_tracker.app
```

## iOS device and simulator validation

Use a physical iPhone or iPad for release-facing validation:

```sh
flutter devices
flutter run --release -d <device-id>
```

Use profile mode only when you need limited runtime observability:

```sh
flutter run --profile -d <device-id>
```

Boot an available simulator and run the app through Flutter so the simulator
installs and launches the bundle. Simulator runs are layout/basic-flow checks,
not release-equivalent validation:

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
