# Google Sheets Development Auth

Slice 12 only reads spreadsheet structure and cell display/formula data. Use the
minimum read-only Sheets scope:

```text
https://www.googleapis.com/auth/spreadsheets.readonly
```

The read adapter does not require Drive scopes and does not write to the sheet.
The live verification command uses Application Default Credentials:

```sh
/Users/ispielma/Dart/flutter/flutter/bin/dart run bin/verify_development_sheet_read.dart
```

Slice 13 writes planned active-sheet updates to the development spreadsheet.
Use the Sheets spreadsheet scope:

```text
https://www.googleapis.com/auth/spreadsheets
```

The write adapter still does not require Drive scopes. The live write
verification command uses Application Default Credentials:

```sh
/Users/ispielma/Dart/flutter/flutter/bin/dart run bin/verify_development_sheet_write.dart
```

Slice 14 resets the writable development spreadsheet to a deterministic active
sheet and `Exercises` fixture. It uses the same Sheets spreadsheet scope and
does not require Drive scopes. The live reset verification command uses
Application Default Credentials:

```sh
/Users/ispielma/Dart/flutter/flutter/bin/dart run bin/verify_development_sheet_reset.dart
```

Slice 15 validates the full backend integration gate against the same
development spreadsheet. It uses the same Sheets spreadsheet scope, resets the
sheet before validation, exercises live backend read/write behavior, and resets
the sheet again after validation:

```sh
/Users/ispielma/Dart/flutter/flutter/bin/dart run bin/verify_backend_integration_gate.dart
```

Slice 21 validates the GUI flow against the same development spreadsheet using
a live `integration_test`.

The runnable iOS and macOS apps use native Google Sign-In rather than ADC. To
enable the browser/account-picker flow, create iOS and macOS OAuth client
configuration in Firebase/Google Cloud, then copy the `CLIENT_ID` and
`REVERSED_CLIENT_ID` values from each platform's `GoogleService-Info.plist` to:

```text
ios/Flutter/GoogleSignIn.xcconfig
macos/Runner/Configs/AppInfo.xcconfig
```

The platform `Info.plist` files already expose those values to the
`google_sign_in` plugin as `GIDClientID` and `CFBundleURLTypes`. The app
requests the Sheets scopes through native Google Sign-In when the user taps
Validate, creates a history block, or saves a set.

For macOS native Google Sign-In, open `macos/Runner.xcworkspace` in Xcode,
select the `Runner` target, and choose a development team under Signing &
Capabilities. The plugin requires keychain sharing, which cannot be used by an
unsigned macOS target. The entitlements are already present in the project.

For macOS, the debug/profile entitlement is left unsandboxed so the local
development-run app can access ADC during the integration-test validation path.
The release bundle keeps the sandbox enabled with outbound network access and
Google Sign-In keychain sharing. It does not read local gcloud ADC credentials.

Run the macOS GUI validation with an explicit ADC file path when using
`flutter test`:

```sh
GOOGLE_APPLICATION_CREDENTIALS="$HOME/.config/gcloud/application_default_credentials.json" \
flutter test integration_test/live_logging_flow_test.dart -d macos
```

For iOS simulator validation, boot an available simulator first. The simulator
app process does not inherit the host `HOME` environment reliably, so pass the
same ADC file path through Flutter's compile-time development define:

```sh
xcrun simctl boot B924969D-19D1-4BE0-A128-E6C8630B4FA9
flutter devices
flutter test integration_test/live_logging_flow_test.dart \
  -d B924969D-19D1-4BE0-A128-E6C8630B4FA9 \
  --dart-define=WORKOUT_TRACKER_GOOGLE_APPLICATION_CREDENTIALS="$HOME/.config/gcloud/application_default_credentials.json"
```

The iOS simulator build can be checked without live Google access:

```sh
flutter build ios --simulator
```

For AFK verification, provide credentials before running the command:

1. Create or choose a Google Cloud project with the Google Sheets API enabled.
2. Create a service account or Application Default Credentials that can read
   Google Sheets with the needed scope above.
3. Share the development spreadsheet with the service account email if using a
   service account JSON file.
4. Set `GOOGLE_APPLICATION_CREDENTIALS` to the service account JSON path, or
   use an existing ADC setup.

If no ADC credentials are available, the smallest repeatable user-assisted step
is to install the Google Cloud CLI and create user ADC credentials:

```sh
gcloud auth application-default login \
  --scopes=https://www.googleapis.com/auth/cloud-platform,https://www.googleapis.com/auth/spreadsheets
```

Google Sheets API calls made with local user ADC also require a quota project.
Choose a Google Cloud project where you can enable services, then run:

```sh
gcloud auth application-default set-quota-project YOUR_PROJECT_ID
gcloud services enable sheets.googleapis.com --project=YOUR_PROJECT_ID
```

Then rerun the relevant live verifier:

```sh
/Users/ispielma/Dart/flutter/flutter/bin/dart run bin/verify_development_sheet_read.dart
/Users/ispielma/Dart/flutter/flutter/bin/dart run bin/verify_development_sheet_write.dart
/Users/ispielma/Dart/flutter/flutter/bin/dart run bin/verify_development_sheet_reset.dart
/Users/ispielma/Dart/flutter/flutter/bin/dart run bin/verify_backend_integration_gate.dart
```

The development spreadsheet for Google integration slices is:

```text
https://docs.google.com/spreadsheets/d/1zQrmCYelrNqRMv4WtJcOrtezSxoaVniXzXi4XgKva_E/edit?gid=0#gid=0
```
