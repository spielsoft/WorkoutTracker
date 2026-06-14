# Slice 16 Backend Completion Architecture Review

## Finding

The backend is ready to serve as the hard pre-GUI seam after a small write
planning cleanup.

The public sheet contract Module remains deep. Its Interface is
`parseActiveSheet(ActiveSheetInput)` plus behavior on `ParsedActiveSheet` for
workout selection, history block selection and growth planning, set write
planning, formula healing planning, and read-model construction. The
Implementation hides fixed-column parsing, blank metadata defaults, ignored
human rows, backup grouping, history block discovery, row-local history,
formula repair planning, and write planning.

The deletion test still says `lib/sheet_contract.dart` is earning its keep.
Deleting it would make callers and tests import `src/` files and learn the
Implementation layout. Keeping that public seam gives callers Leverage over the
sheet contract while preserving Locality for backend changes.

The notation Module remains deep. Its Interface is `parseSetNotation` and
`renderSetNotation` over the public notation value objects. The Implementation
hides compact notation parsing for weighted reps, bodyweight reps, timed
entries, height/platform entries, pain, notes, and raw-text preservation.
Deleting it would spread notation parsing and rendering across read models,
write planning, and future GUI code.

Formula healing and history/write planning remain internal sheet-contract
Modules rather than separate public seams. They are deep because their
Implementation owns direct `Exercises` formulas, exact/ambiguous exercise
matching, newest-near-fixed-columns insertion, set-column growth, row-local
write targeting, edit/clear behavior, and next-set planning. Deleting them
would move that sheet contract knowledge into callers.

## Adapter Seams

The Google adapter seams are now real. Each client Interface has a production
Google APIs Adapter and a fake Adapter in behavior tests:

- `GoogleSheetsSpreadsheetClient`: `GoogleApisSheetsSpreadsheetClient` plus
  test fakes.
- `GoogleSheetsWriteClient`: `GoogleApisSheetsWriteClient` plus test fakes.
- `DevelopmentSheetResetClient`: `GoogleApisDevelopmentSheetResetClient` plus
  test fakes.

These seams no longer fail the one-adapter test. They keep Google API details
outside the sheet contract Module, and they let tests verify adapter behavior
without live network access.

## Cleanup

Set write planning accepted any sheet row number as long as the history block
existed. That leaked row-validity knowledge to future callers: a GUI could pass
an ignored human row, header row, or out-of-range row and receive a write plan.

The cleanup keeps row locality inside `_ActiveSheetWritePlanner`. Logging,
editing, and clearing now return an empty plan unless the target row is one of
the parsed exercise rows. This improves Locality by keeping active-sheet row
validity in the backend Implementation, and it gives future GUI callers
Leverage because they can rely on the write planner instead of duplicating the
parser's row filter.

## Test Surface

Backend tests still cross public package seams:

- `package:workout_tracker/sheet_contract.dart`
- `package:workout_tracker/set_notation.dart`
- `package:workout_tracker/google_sheets.dart`

No tests import private `src/` modules or private helpers. The new write
planning test verifies behavior through `ParsedActiveSheet.planSetLoggingWrite`,
`planSetEdit`, and `planSetClear`, matching the Interface future GUI code will
use.

## Gate

No GUI work was started in this slice. Existing Flutter scaffold files remain
unchanged from earlier slices.
