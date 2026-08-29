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

Workbook-version coverage verifies that new sheets write
`workouttracker.schema_version=1.1`, declared `0.9` sheets retain their routed
syntax until conversion, declared `1.0` sheets are rejected as unsupported and
offered no in-app upgrade, missing metadata selects only the original legacy
converter, and a declared version is never guessed from headers. The `0.9`
conversion is covered as producing the `1.0` it always produced, whose result
is then rejected rather than falsely claiming `1.1` compatibility.

Schema 1.1 coverage verifies the nine-column Exercises header, blank
`Timer Fields` reading as empty, populated cells round-tripping exact labels in
Log Format declaration order, and malformed, repeated, or undeclared labels
blocking every write. Exercise create and update plans are covered as writing
`Timer Fields` while leaving active rows, Targets, and history untouched.
Template coverage verifies that a missing catalog `timerFields` property parses
as empty, that non-list and non-string values are rejected, that all maintained
catalog records declare the property explicitly, and that every declared label
exists in that record's parsed Log Format. The catalog only seeds new
workbooks; upgrading an existing workbook to schema 1.1 is owner-performed work
outside this repository's automation, so no test performs it.

Fakes may prove what WorkoutTracker requests or accepts. They do not prove the
behavior of Google Sign-In, Drive, Sheets, Firebase, OAuth, or Picker.

## Local App Preview

`dev/gym_preview.dart` runs the real application against an in-memory workbook.
It requires no Google account, writes nothing outside the process, and opens on
the workout home with several weeks of history already logged. Use it to judge
screen behavior that is faster to see than to assert, such as keyboard
avoidance, rest-timer presentation, or how a five-field log format lays out on
a small phone.

```sh
flutter run -t dev/gym_preview.dart -d <device-id>
```

`flutter devices` lists the identifiers. The fixture covers three workouts,
three history blocks, a backup exercise, a deliberately long workout name, and
two-, three-, and five-field log formats. Its Legs workout also carries the
timed exercises: Side Plank and a deliberately long-named Copenhagen variation
both declare `Timer Fields` of `['Seconds']`, while Front Plank leaves the same
`Seconds` label untimed. Edit its rows to reproduce a specific workbook shape;
active-sheet and `Exercises` writes both round-trip in memory, so logging,
reordering, and authoring all behave as they do against a real Sheet.

This harness is a preview, not a validation tier. It proves nothing about
Google, the schema contract, or any real workbook, and it never substitutes for
`flutter test`. `test/dev/gym_preview_test.dart` keeps the fixture honest by
loading it through the real screens; it does not make the harness a tier.

### Simulator Keyboard

A simulator attached to the Mac keyboard never raises the on-screen numeric
keypad, which hides the layout that matters most while logging a set.
Disconnect the hardware keyboard once:

```sh
defaults write com.apple.iphonesimulator ConnectHardwareKeyboard -bool false
```

Restart the Simulator application for the change to take effect. Set it back to
`true` to restore typing from the Mac keyboard.

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

This command targets the supported macOS app and only the allowlisted
development Sheet. It resets that fixture to a declared `0.9` workbook,
reviews the format-conversion dry run, confirms conversion to `1.0`, upgrades
the placed DB Step-Up to its five-field format, and logs
`(12, 15)x8@8,0`. It then reads the Sheet directly to verify version metadata,
the Exercises definition, formula ownership, active Targets, the new set, and
unchanged pre-conversion history. The teardown resets the fixture to its
ordinary deterministic state even when an assertion fails.

That live flow predates schema 1.1 and cannot pass as written: the `0.9`
conversion still produces `1.0`, which the app now rejects, so nothing after
the conversion can log a set. Rebuild the flow around a schema 1.1 fixture
before running it again. Nothing in the timed-exercise plan needs it.

Without the environment flag, it must skip before authentication. A live run
must reset the fixture after itself; reset failures fail the test distinctly.

## Temporary Owner Migration

The pre-MVP app recognizes an exact unversioned legacy workbook and offers a
confirmed **Convert old sheet** action. It dry-runs first, rereads before
writing, stamps version `0.9`, and revalidates the converted workbook. Other
damaged or versioned workbooks remain on the normal repair path.
The v1 converter preserves legacy Reps text under `Reps`, or under the explicit
`Seconds` alias used by timed exercises; it does not guess arbitrary fields.

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
[`BUILDING.md`](../BUILDING.md). Accessibility work also follows
[`docs/accessibility.md`](accessibility.md).
