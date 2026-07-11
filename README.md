# WorkoutTracker

WorkoutTracker is a focused gym logging app backed by a user-owned Google
Sheet. It presents spreadsheet workouts as a fast phone and desktop workflow
while keeping the Sheet readable and editable without the app.

The app can:

- sign in with Google and choose or create a workout Sheet;
- validate damaged workbook structure before allowing writes;
- organize exercises by workout, including attached backup exercises;
- create and edit canonical exercises;
- create visible history blocks and log compact set notation; and
- preserve manually entered set text it cannot parse.

It is not a coaching, progression, or program-generation service. Workout data
is not copied to an application backend.

## Current Status

The MVP is implemented in Flutter/Dart. macOS is the primary development and
front-line testing target; iOS is the intended mobile target. Android, Linux,
and Windows retain Flutter scaffolding but are not release-ready or validated.

The current source-MVP uses native Google Sign-In plus an in-app Flutter chooser
that lists Sheets through the Drive API. Each public source builder is expected
to supply a separate Google Cloud project and OAuth configuration. A future,
separately gated migration will evaluate Google Picker with per-file access.

## Build and Test

Install Flutter and Xcode, then from the repository root run:

```sh
flutter pub get
flutter analyze
flutter test
```

Google login requires local configuration described in
[`docs/google_sheets_development_auth.md`](docs/google_sheets_development_auth.md).
Apple release commands and artifact locations are in
[`COMPILE.md`](COMPILE.md).

## Documentation

| Topic | Document |
| --- | --- |
| Workbook schema and write invariants | [`docs/domain_contract.md`](docs/domain_contract.md) |
| Test tiers and live integration | [`docs/testing.md`](docs/testing.md) |
| Google account and chooser architecture | [`docs/google_sheets_development_auth.md`](docs/google_sheets_development_auth.md) |
| UI accessibility contract | [`docs/accessibility.md`](docs/accessibility.md) |
| Apple release builds | [`COMPILE.md`](COMPILE.md) |
