# Slice 4 Sheet Contract Architecture Review

## Finding

The sheet contract Module is deep for the behavior accumulated through Slice 3.
Its public Interface is `parseActiveSheet(ActiveSheetInput)`, returning a
`ParsedActiveSheet` with ordered slots, primary slots with nested backups, and
schema violations. Behind that small seam, the Implementation owns active sheet
fixed-column lookup, blank `Workout` and `is_backup` defaults, human section row
filtering, backup ownership by nearest preceding primary row, and ambiguous
backup validation.

The deletion test says this Module is earning its keep: deleting it would move
sheet contract knowledge into callers and tests instead of removing complexity.
The Interface gives callers leverage by letting them work with workout slots
instead of raw sheet grids, and it preserves locality by keeping current sheet
parsing and validation rules in one place.

`lib/sheet_contract.dart` is intentionally thin because it is the public seam.
Deleting it would make callers import from `src/` and learn the Implementation
layout. It is not a behavioral pass-through Module that needs removal.

## Cleanup

`WorkoutSlot.withBackups` was an exposed Implementation helper used only while
building grouped primary slots. Making it private reduces caller knowledge and
keeps backup grouping construction local to the parser Implementation.

## Test Surface

The sheet contract tests continue to cross the same public Interface used by
callers: `package:workout_tracker/sheet_contract.dart`. No tests reach private
helpers.
