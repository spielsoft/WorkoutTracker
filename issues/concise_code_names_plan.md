# Concise Code Names Plan

Transient planning file for the repo-wide concise-name cleanup.

## Goal

Shorten identifiers that restate repository, module, or enclosing-type context,
while preserving domain distinctions from the sheet contract.

This pass should primarily remove repeated prefixes such as:

- `WorkoutTracker`
- `GoogleSpreadsheet`
- `GoogleWorkspace`
- `GooglePicker`
- `CanonicalExercise` where the enclosing module already provides that context
- `ActiveSheet` where the enclosing module already provides that context

## Guardrails

- Keep domain words that separate real concepts: `workout`, `backup`,
  `history`, `formula`, `placement`, `exercise`, `spreadsheet`.
- Do not rename Flutter/Dart SDK symbols or third-party API types.
- Prefer readable short names over aggressive abbreviations for public types.
- Use more compact abbreviations for local variables only after public names and
  filenames are stable.
- Apply broad search-replace only from an explicit symbol map and only with
  whole-identifier matches.

## Hotspots

High-value production files:

- `lib/src/sheets/init_plan.dart`
- `lib/src/sheets/init.dart`
- `lib/src/sheets/template.dart`
- `lib/src/app/validation_service.dart`
- `lib/src/app/access.dart`
- `lib/src/app/shell.dart`
- `lib/src/app/logging.dart`
- `lib/src/app/workout.dart`
- `lib/src/app/repair.dart`
- `lib/src/app/exercise_form.dart`

High-value test mirrors:

- `test/widget_test.dart`
- `test/app/controller_test.dart`
- `test/app/validation_test.dart`
- `test/app/test_validation_service.dart`
- `test/sheets/workout_tracker_workbook_template_test.dart`

## Proposed Rename Map

These are the first-pass replacements worth doing mechanically. Final names can
still be adjusted during implementation if collisions appear.

| Old name | Proposed name | Main locations |
| --- | --- | --- |
| `init_plan.dart` | `init_plan.dart` | `lib/src/sheets/` |
| `init.dart` | `init.dart` | `lib/src/sheets/` |
| `template.dart` | `template.dart` | `lib/src/sheets/` |
| `logging.dart` | `logging.dart` | `lib/src/app/` |
| `workout.dart` | `workout.dart` | `lib/src/app/` |
| `repair.dart` | `repair.dart` | `lib/src/app/` |
| `account.dart` | `account.dart` | `lib/src/app/` |
| `a11y.dart` | `a11y.dart` | `lib/src/app/` |
| `states.dart` | `states.dart` | `lib/src/app/` |
| `exercise_form.dart` | `exercise_form.dart` | `lib/src/app/` |
| `exercise_library.dart` | `exercise_library.dart` | `lib/src/app/` |
| `validation_service.dart` | `validation_service.dart` | `lib/src/app/` |
| `access.dart` | `access.dart` | `lib/src/app/` |
| `GoogleApisWorkbookInit` | `GoogleApisWorkbookInit` | `lib/src/sheets/init.dart` |
| `WorkbookInitFactory` | `WorkbookInitFactory` | `lib/src/app/selection.dart` |
| `WorkbookTabPlan` | `WorkbookTabPlan` | `lib/src/sheets/init_plan.dart` |
| `WorkbookTab` | `WorkbookTab` | `lib/src/sheets/template.dart` |
| `SpreadsheetValidationService` | `SpreadsheetValidationService` | `lib/src/app/validation_service.dart` |
| `SpreadsheetAccess` | `SpreadsheetAccess` | `lib/src/app/access.dart` |
| `WorkspaceAccessState` | `WorkspaceAccessState` | `lib/src/app/state_store.dart` |
| `WorkspaceStateController` | `WorkspaceStateController` | `lib/src/app/state_store.dart` |
| `WorkspaceController` | `WorkspaceController` | `lib/src/app/workspace.dart` |
| `PickerAuth` | `PickerAuthSnapshot` | `lib/src/app/account_session.dart` |
| `PickerAuthGateway` | `PickerAuthGateway` | `lib/src/app/account_session.dart` |
| `PickerCallbackReceiverFactory` | `PickerCallbackReceiverFactory` | `lib/src/app/selection.dart` |
| `NativePickerCallbackReceiver` | `NativePickerCallbackReceiver` | `lib/src/app/selection.dart` |
| `MobileSpreadsheetPicker` | `MobileSpreadsheetPicker` | `lib/src/app/selection.dart` |
| `PickerCallbackResult` | `PickerCallbackResult` | `lib/src/app/selection.dart` |
| `ValidationReport` | `ValidationReport` | `lib/src/app/validation_core.dart` |
| `AppController` | `AppController` | `lib/src/app/controller.dart` |
| `AppScrollBehavior` | `AppScrollBehavior` | `lib/src/app/shell.dart` |
| `validateSelection` | `validateSelection` | `lib/src/app/controller.dart` |
| `reportSelectionFailure` | `reportSelectionFailure` | `lib/src/app/controller.dart` |
| `authorizeSheetCreation` | `authorizeSheetCreation` | `lib/src/app/workspace.dart`, `lib/src/app/selection.dart` |
| `resolveSelection` | `resolveSelection` | `lib/src/app/workspace.dart`, `lib/src/app/selection.dart` |
| `addExerciseToWorkout` | `addExerciseToWorkout` | `lib/src/app/validation_service.dart`, wiring, controller |
| `buildLoggingContext` | `buildLoggingContext` | `lib/src/contract/active/` |
| `loadWorkbookTemplate` | `loadWorkbookTemplate` | `lib/src/sheets/template.dart` |
| `restorePickerAuth` | `restorePickerAuth` | `lib/src/app/account_session.dart` |
| `updatePickerAuth` | `updatePickerAuth` | `lib/src/app/account_session.dart` |
| `readWorkspaceState` | `readWorkspaceState` | `lib/src/app/state_store.dart` |
| `writeWorkspaceState` | `writeWorkspaceState` | `lib/src/app/state_store.dart` |
| `clearWorkspaceState` | `clearWorkspaceState` | `lib/src/app/state_store.dart` |
| `planPrimaryPlacement` | `planPrimaryPlacement` | `lib/src/contract/active/` |
| `planBackupPlacement` | `planBackupPlacement` | `lib/src/contract/active/` |
| `planExerciseReorder` | `planExerciseReorder` | `lib/src/contract/active/` |
| `planPrimaryExerciseDeletion` | `planPrimaryExerciseDeletion` | `lib/src/contract/active/` |
| `planCanonicalAppend` | `planCanonicalAppend` | `lib/src/contract/active/` |
| `planCanonicalUpdate` | `planCanonicalUpdate` | `lib/src/contract/active/` |
| `planCanonicalReorder` | `planCanonicalReorder` | `lib/src/contract/active/` |

## Local-name Cleanup Targets

Do these after filenames and public API names settle:

- `sheetColumnNumber` -> `col`
- `selectedSpreadsheet` -> `selection` or `sheet`
- `selectedSheetRowNumber` -> `row`
- `primarySheetRowNumber` -> `primaryRow`
- `historyBlockLabel` -> `blockLabel`
- `currentActiveSheet` -> `sheet`
- `workoutSelection` -> `workout`
- `googleAuthorization` -> `auth`

Keep local renames file-scoped and only where the shorter name is obvious from
surrounding code.

## Execution Plan

1. Freeze the rename map.
   Record every intended rename in this file before running replacements.

2. Rename files and imports first.
   Drop repeated file prefixes so later symbol edits happen in shorter module
   contexts.

3. Rename public production symbols in slices.
   Start with `lib/src/sheets/`, then `lib/src/app/`, then
   `lib/src/contract/active/`.

4. Update mirrored test symbols and helper filenames.
   Keep tests in lockstep with the production slice they cover.

5. Run targeted tests after each slice.
   Prefer file- or area-specific `flutter test` commands over the whole suite
   until the final pass.

6. Finish with local-variable cleanup.
   Only shorten locals in files already touched by the slice.

## Automation Strategy

Use a generated rename map plus whole-word replacements, not ad hoc manual
searches. Recommended flow:

1. Export the approved rename map into a simple script input format.
2. For each slice, replace exact identifiers with word boundaries.
3. Rename affected files.
4. Run formatter plus targeted tests.
5. Fix any collision, import, or casing fallout before moving to the next slice.

Avoid one-shot repo-wide substring replacement. It is too risky for nearby
identifiers such as expectation/helper types in the sheet-contract tests.

## Verification Gates

- `dart format` on touched files
- targeted `flutter test` for the changed slice
- broad `flutter test` after the final rename pass
- `rg` checks for stale old identifiers after each slice

## Open Decisions

- `AppController` may want `Controller` or `ShellController` instead
  of `AppController`; decide after checking call sites.
- `ValidationReport` may be short enough as `ValidationReport`, but
  confirm that nearby modules do not introduce ambiguous `Report` types.
- `ActiveSheet*Expectation` classes may merit a second dedicated pass because
  they are numerous and tightly related; do not collapse their domain words too
  early.
