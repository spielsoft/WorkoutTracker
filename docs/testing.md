# Testing

Use the smallest tier that can establish the behavior being changed.

## Local Tests

Target one public contract or flow during development:

```sh
flutter test test/fixtures/workbook_test.dart
flutter test test/app/workspace_test.dart
flutter test test/app/ui/logging_flow_test.dart
```

Choose the actual focused file or directory relevant to the patch. Before a
release or broad refactor, run:

```sh
flutter analyze
flutter test
```

Good local tests cover workbook parsing and validation, write plans, notation,
Google adapter inputs, application commands, and visible screen behavior.
Avoid private helpers, exact widget trees, documentation prose, and incidental
callback order.

Fakes may prove what WorkoutTracker requests or accepts. They do not prove the
behavior of Google Sign-In, Drive, Sheets, Firebase, OAuth, or Picker.

## Live Google Integration

The writable fixture is:

```text
https://docs.google.com/spreadsheets/d/1zQrmCYelrNqRMv4WtJcOrtezSxoaVniXzXi4XgKva_E/edit?gid=0#gid=0
```

The live test can reset and write this Sheet. Run it only when the active task
explicitly requires real Google validation and the user is ready for login and
fixture writes:

```sh
WORKOUT_TRACKER_RUN_LIVE_GOOGLE_TESTS=1 \
  flutter test integration_test/live_logging_flow_test.dart -d macos
```

Without the environment flag, it must skip before authentication. A live run
must reset the fixture after itself; report reset failures and skipped runs
explicitly.

## Release Validation

Run the full local suite plus the clean Apple builds required by
[`COMPILE.md`](../COMPILE.md). Accessibility work also follows
[`docs/accessibility.md`](accessibility.md).
