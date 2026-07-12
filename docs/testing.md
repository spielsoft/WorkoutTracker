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

For dynamic exercise fields, retain public coverage for unique Log Format
labels, Default Values and Targets round-trips, target prefill versus saved
history precedence, raw-history preservation, and stale-write rejection. The
temporary owner migration and its colocated tests are deleted together before
MVP release.

Workbook-version coverage verifies that new sheets and successful conversions
write `workouttracker.schema_version=0.9`, missing metadata selects only the
original legacy converter, and a declared version is never guessed from
headers.

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

This command targets the supported macOS app and destructively resets the
named development Sheet before and after its representative logged-set write.
Field-model acceptance also inspects a conventional Weight/Reps/RPE row and a
timed or custom-format row directly in the real Sheet.

Without the environment flag, it must skip before authentication. A live run
must reset the fixture after itself; report reset failures and skipped runs
explicitly.

## Temporary Owner Migration

The pre-MVP app recognizes an exact unversioned legacy workbook and offers a
confirmed **Convert old sheet** action. It dry-runs first, rereads before
writing, stamps version `0.9`, and revalidates the converted workbook. Other
damaged or versioned workbooks remain on the normal repair path.

Before migrating an owner workbook, make a disposable copy and run the
temporary field migrator in dry-run mode:

```sh
WORKOUT_TRACKER_RUN_LEGACY_FIELD_MIGRATION=1 \
WORKOUT_TRACKER_LEGACY_MIGRATION_SPREADSHEET_ID=<copied-sheet-id> \
  flutter test integration_test/legacy_field_migration_test.dart -d macos
```

Review its listed changes, counts, and blockers. To apply only after explicit
owner approval, rerun the same command with the exact spreadsheet ID repeated
as `WORKOUT_TRACKER_CONFIRM_LEGACY_FIELD_MIGRATION`. The allowlist and exact
confirmation prevent accidental writes to any other workbook. Inspect the copy
in Google Sheets and in the app before repeating the process for an original.
Delete the temporary migrator, integration harness, and migration tests after
all owner workbooks complete the combined field/layout migration.

## Release Validation

Run the full local suite plus the clean Apple builds required by
[`COMPILE.md`](../COMPILE.md). Accessibility work also follows
[`docs/accessibility.md`](accessibility.md).
