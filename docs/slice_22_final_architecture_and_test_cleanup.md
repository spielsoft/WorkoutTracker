# Slice 22 Final Architecture and Test Cleanup

## Scope

This review covered three areas:

- backend sheet-contract Modules under `lib/src/sheet_contract/active_sheet/`
- Google adapter Modules under `lib/src/google_sheets/`
- the GUI-facing Module that had accumulated in `lib/main.dart`

The review used the required vocabulary: Module, Interface, Implementation,
Depth, Seam, Adapter, Leverage, Locality, and deletion test.

## Backend Modules

The backend sheet-contract Module remains deep.

Its public Interface is still `parseActiveSheet(ActiveSheetInput)` plus
behavior on `ParsedActiveSheet` for workout selection, history-block selection,
logging-context construction, formula-healing planning, and write planning. The
Implementation still hides fixed-column parsing, ignored human rows, blank
metadata defaults, backup ownership, history-block discovery, row-local
history, and set-write growth.

The deletion test still says this Module is earning its keep. Deleting the
sheet-contract Seam would force callers and tests to learn the Implementation
layout inside `src/`, which would lower Leverage and spread contract knowledge
across the GUI and Google Adapters.

Slice 22 only tightened the Interface documentation where callers need ordering
rules: the `ParsedActiveSheet` read-model builders now say which row numbers are
valid to feed back into the write-planning Interface.

## Google Adapters

The Google adapter Modules remain real seams with multiple Adapters:

- read: `GoogleApisSheetsSpreadsheetClient` plus test fakes
- write: `GoogleApisSheetsWriteClient` plus test fakes
- reset: `GoogleApisDevelopmentSheetResetClient` plus test fakes

Those seams are still deep enough to hide Google API shape, batch-update
details, sheet-title quoting, and reset mechanics behind small Interfaces.
Nothing in Slice 22 justified reopening them.

The deletion test still favors keeping these Modules. Deleting them would move
Google-specific request structure into callers and destroy Locality for live
integration changes.

## GUI-facing Module

The GUI-facing Module needed cleanup.

Before this slice, `lib/main.dart` mixed three concerns in one place:

- the app entrypoint
- the spreadsheet validation Adapter wiring
- the stateful workout/history/logging flow

That made the GUI-facing Interface shallow. Callers and tests only crossed the
widget seam, but the Implementation details for validation, report adoption,
selection resets, busy-state handling, and error formatting were all embedded
inside one large state class. The deletion test failed: deleting the stateful
shell logic would not remove complexity, it would just reappear across the
widget tree and the tests.

The cleanup deepened this Module in two ways:

1. `WorkoutTrackerController` is now the GUI-facing Module for app flow state.
   Its Interface is a small set of observable properties plus mutation methods
   for validation, history-block creation, write-plan application, and
   workout/history/row selection. Its Implementation now owns the ordering
   rules for adopting a report and clearing stale row selections.
2. `lib/main.dart` is now a true entrypoint again. The spreadsheet validation
   Adapter wiring moved behind `spreadsheet_validation.dart`, and the widget
   Implementation moved behind `workout_tracker_shell.dart`.

This increases Leverage because the shell can ask one Module to manage report
state instead of hand-editing several fields. It increases Locality because
future flow changes now land in one controller instead of inside multiple
widgets.

## Test Surface

The tests were checked for behavior focus and implementation coupling.

Backend and adapter tests still cross public package seams:

- `package:workout_tracker/sheet_contract.dart`
- `package:workout_tracker/google_sheets.dart`
- `package:workout_tracker/set_notation.dart`

For the GUI-facing Module, Slice 22 added controller tests that cross the new
controller Interface directly. That keeps flow-state behavior focused on the
Module that owns it instead of overfitting widget structure.

The widget tests still cross `WorkoutTrackerApp`, but one brittle assertion was
improved by adding a key for the new-history-block field. That removes one
piece of widget-order coupling without broadening the MVP scope.

## Result

No backend Module or Google Adapter failed the deletion test strongly enough to
justify more surgery. The final cleanup therefore focused on the shallow part
of the codebase: the GUI-facing Module and its test surface.
