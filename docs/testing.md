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
history precedence, raw-history preservation, and stale-write rejection.

Workbook-version coverage verifies that new sheets write
`workouttracker.schema_version=1.1`, that every other declared version and
missing metadata is rejected as unsupported schema damage with no in-app
upgrade offered, and that a declared version is never guessed from headers.

Schema 1.1 coverage verifies the nine-column Exercises header, blank
`Timer Fields` reading as empty, populated cells round-tripping exact labels in
Log Format declaration order, and malformed, repeated, or undeclared labels
blocking every write. The round-trip is covered for every awkward label the Log
Format grammar admits, including apostrophes, backslashes, commas, brackets,
leading and trailing spaces, and non-ASCII text, so an ordinary label still
renders as a plain `['Seconds']` while a malformed escape stays blocked.
Exercise create and update plans are covered as writing `Timer Fields` while
leaving active rows, Targets, and history untouched.
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

The writable development fixture is:

```text
https://docs.google.com/spreadsheets/d/1zQrmCYelrNqRMv4WtJcOrtezSxoaVniXzXi4XgKva_E/edit?gid=0#gid=0
```

No live Google test currently exists. The former live logging flow was built
around a declared `0.9` workbook and its in-app conversion, both of which are
gone, so it was deleted rather than left unrunnable. Rebuild it against a
schema `1.1` fixture when real Google validation is next required.

The fixture identity, `LiveLoggingEntry`, and the reset harness in
`test/support/reset.dart` remain and are covered by the local suite. The reset
harness is allowlisted to the Sheet above and to no other workbook.

A live test may reset and write that Sheet, so any rebuilt flow stays opt-in:
it must skip before authentication without its explicit environment flag, must
reset the fixture after itself, and must fail distinctly when that reset fails.
Never enable such a test implicitly.

## Release Validation

Run the full local suite plus the clean Apple builds required by
[`BUILDING.md`](../BUILDING.md). Accessibility work also follows
[`docs/accessibility.md`](accessibility.md).
