# iPhone Live Testing Readiness Issues

This is the active vertical-slice plan for getting WorkoutTracker ready for
live iPhone testing. Work through slices in order. Use TDD for each slice:
write or update a failing behavior test through a public interface, implement
the smallest fix, run targeted tests, then update this checklist only after the
slice is complete.

Do not run live Google integration tests or write to the development sheet
unless explicitly authorized for that slice.

## Slice 1: Existing Sheet Selection Must Work On iPhone

Status: complete

Problem:

- A fresh build can hide the pasted Google Sheets URL/ID fallback whenever a
  `SpreadsheetPicker` is present, even if choosing an existing sheet is
  unavailable because `WORKOUT_TRACKER_GOOGLE_PICKER_CLIENT_ID` is not set.
- This can block testers from selecting the known development sheet.

Acceptance criteria:

- If Google Drive choosing is unavailable, the sheet selection screen exposes a
  pasted URL/ID path.
- The pasted URL/ID path remains compatible with native Google Sign-In
  validation.
- Existing picker/create controls still render their availability state.
- Widget tests cover picker-present/manual-fallback behavior.

Likely files:

- `lib/src/app/workout_tracker_shell.dart`
- `lib/src/app/spreadsheet_selection.dart`
- `test/widget_test.dart`
- `test/app/spreadsheet_selection_test.dart`

Suggested tests:

- `flutter test test/widget_test.dart --plain-name "exposes pasted sheet validation when picker choosing is unavailable"` - passed
- `flutter test test/app/spreadsheet_selection_test.dart` - passed
- `flutter test test/widget_test.dart --plain-name "spreadsheet"` - passed

## Slice 2: Keep The Local Readiness Suite Green

Status: complete

Problem:

- `flutter test` is red because readiness tests reference deleted transient docs
  and one restored-selected-sheet UI expectation no longer matches current
  startup behavior.

Acceptance criteria:

- Broad local `flutter test` passes, excluding live Google writes.
- Tests do not depend on deleted transient plan files.
- The restored selected-sheet behavior is either fixed or the test is updated
  to match the intended current flow.

Likely files:

- `test/platform_store_readiness_test.dart`
- `test/widget_test.dart`
- `APP_STORE.md`
- `README.md`
- `docs/google_sheets_development_auth.md`

Suggested tests:

- `flutter test test/platform_store_readiness_test.dart` - passed
- `flutter test test/widget_test.dart --plain-name "restores a selected Google Drive sheet label"` - passed
- `flutter test` - passed, 174 tests

## Slice 3: Prevent Duplicate Async Actions

Status: complete

Problem:

- Picker/create actions and logging save/edit actions can be tapped repeatedly
  while async work is pending.
- On phones this can launch multiple auth flows, create multiple sheets, or
  submit duplicate set writes.

Acceptance criteria:

- Picker/create actions enter a local busy state until the action completes.
- Logging save/edit/clear controls are disabled or visibly busy while a write
  is pending.
- Failed writes are visible near the logging action or otherwise discoverable
  without scrolling back to the top.
- Tests cover repeated taps during pending actions.

Likely files:

- `lib/src/app/workout_tracker_shell.dart`
- `lib/src/app/workout_tracker_shell_logging.dart`
- `lib/src/app/workout_tracker_controller.dart`
- `test/widget_test.dart`

Suggested tests:

- `flutter test test/widget_test.dart --plain-name "picker"` - passed
- `flutter test test/widget_test.dart --plain-name "Save set"` - passed
- `flutter test test/widget_test.dart` - passed, 51 tests

## Slice 4: Reject Stale Formula Repair Plans

Status: complete

Problem:

- Formula repair plans can write formulas to stale rows because they do not
  carry active-sheet row expectations.

Acceptance criteria:

- Formula healing write plans include enough expectations to reject if the
  target row identity changed after validation.
- Rejection explains that the sheet changed and must be revalidated.
- Tests cover stale-row formula repair rejection through the public sheet
  contract or validation-service interface.

Likely files:

- `lib/src/sheet_contract/active_sheet/formula_healing.dart`
- `lib/src/sheet_contract/active_sheet/write_plans.dart`
- `lib/src/app/spreadsheet_validation_core.dart`
- `test/sheet_contract/active_sheet_formula_healing_test.dart`
- `test/app/spreadsheet_validation_test.dart`

Suggested tests:

- `flutter test test/sheet_contract/active_sheet_formula_healing_test.dart` - passed
- `flutter test test/app/spreadsheet_validation_test.dart` - passed
- `git diff --check -- lib/src/sheet_contract/active_sheet/formula_healing.dart lib/src/sheet_contract/active_sheet/write_plans.dart test/sheet_contract/active_sheet_formula_healing_test.dart ISSUES.md` - passed

## Slice 5: Reject Stale Log Format Set Writes

Status: complete

Problem:

- Set writes render notation from the old row-local log format but do not reject
  if the sheet's `Log Format` changed before apply.

Acceptance criteria:

- New set saves, structured edits, raw edits, and clears reject stale row-local
  log-format changes when that format affects the planned write.
- Tests cover a format change between planning and applying a write.
- Raw preservation behavior remains intact.

Likely files:

- `lib/src/sheet_contract/active_sheet/write_plans.dart`
- `test/sheet_contract/active_sheet_write_planning_test.dart`
- `test/app/spreadsheet_validation_test.dart`

Suggested tests:

- `flutter test test/sheet_contract/active_sheet_write_planning_test.dart` - passed
- `flutter test test/app/spreadsheet_validation_test.dart --plain-name "Log Format"` - passed
- `git diff --check -- lib/src/sheet_contract/active_sheet/write_plans.dart test/sheet_contract/active_sheet_write_planning_test.dart test/app/spreadsheet_validation_test.dart` - passed

## Slice 6: iPhone Logging Usability Pass

Status: pending

Problem:

- iPhone-specific layout and keyboard behavior is thinly covered.
- Structured set fields do not request numeric-friendly keyboards.

Acceptance criteria:

- Structured set fields use a keyboard appropriate for numeric set entry while
  preserving arbitrary raw text edit paths.
- Narrow iPhone viewport tests cover workout setup, exercise picker, logging,
  keyboard/view-inset behavior, and backup selection.
- No text overflow or inaccessible primary actions in tested phone viewports.

Likely files:

- `lib/src/app/workout_tracker_shell_workout.dart`
- `lib/src/app/workout_tracker_shell_logging.dart`
- `test/widget_test.dart`

Suggested tests:

- `flutter test test/widget_test.dart --plain-name "phone"`
- `flutter test test/widget_test.dart --plain-name "backup"`

## Slice 7: Google Adapter Read/Write Robustness

Status: pending

Problem:

- Live reads fetch grid data for every tab.
- History block/column insertion writes are split across multiple calls, which
  can leave partial sheet changes on flaky mobile networks.

Acceptance criteria:

- Reads request only the active sheet and `Exercises` data needed by the app.
- History-block creation/growth write behavior is covered for failure modes or
  made more atomic through Sheets batch APIs where practical.
- Tests verify adapter requests and partial-failure behavior without live
  Google credentials.

Likely files:

- `lib/src/google_sheets/read_adapter.dart`
- `lib/src/google_sheets/write_adapter.dart`
- `test/google_sheets/google_sheets_read_adapter_test.dart`
- `test/google_sheets/google_sheets_write_adapter_test.dart`

Suggested tests:

- `flutter test test/google_sheets/google_sheets_read_adapter_test.dart`
- `flutter test test/google_sheets/google_sheets_write_adapter_test.dart`

## Slice 8: Device Validation Gate

Status: pending

Problem:

- Local builds pass, but no real iPhone was visible during review and live
  Google writes were not authorized.

Acceptance criteria:

- `flutter devices` sees the intended iPhone or simulator test target.
- Device signing/team setup is documented or configured for the tester machine.
- `flutter build ios --simulator` and `flutter build ios --no-codesign` pass.
- Live Google integration is run only after explicit authorization, with reset
  and cleanup behavior confirmed.

Likely files:

- `APP_STORE.md`
- `docs/google_sheets_development_auth.md`
- iOS project signing configuration if explicitly chosen

Suggested tests:

- `flutter analyze`
- `flutter test`
- `flutter build ios --simulator`
- `flutter build ios --no-codesign`
- `WORKOUT_TRACKER_RUN_LIVE_GOOGLE_TESTS=1 flutter test integration_test/live_logging_flow_test.dart`
  only with explicit authorization.
