# Slice 11 Backend Module Seams Architecture Review

## Finding

The public sheet contract Module remains deep. Its Interface is still
`parseActiveSheet(ActiveSheetInput)` plus behavior on the returned
`ParsedActiveSheet`: workout selection, history block selection and growth
planning, set write planning, formula healing planning, and read-model
construction. The interface is the test surface; behavior tests continue to
cross `package:workout_tracker/sheet_contract.dart`.

The deletion test says the public `lib/sheet_contract.dart` export is earning
its keep even though it is thin. Deleting it would force callers and tests to
import `src/` implementation files and learn the internal layout.

`lib/src/sheet_contract/active_sheet.dart` had become a large Implementation
file containing several distinct internal Modules. The public seam was still
right, but Locality inside the Implementation was poor: formula healing,
history block discovery, read models, set write planning, and row parsing were
interleaved. Splitting those into internal part files improves Locality without
adding new external seams or adapter Interfaces.

## Deletion Test

- `sheet_contract.dart`: keep. Deleting it moves implementation layout
  knowledge into callers.
- `set_notation.dart`: keep. Deleting it would spread compact notation parsing,
  rendering, and raw-text preservation into sheet read and write callers. It is
  a distinct notation Module with useful Depth.
- History block planning: keep as an internal sheet-contract Module. Deleting
  it would move newest-near-fixed-columns and growth rules back into callers.
- Set write planning: keep as an internal sheet-contract Module. Deleting it
  would spread row-local write targeting, auto-advance, and growth coordination
  into GUI or Google write code.
- Formula healing planning: keep as an internal sheet-contract Module. Deleting
  it would spread direct `Exercises` formula knowledge into future adapters and
  UI flows.
- `ParsedActiveSheet` public constructor: remove from the Interface. It exposed
  Implementation-only state such as raw rows and formula column maps, so the
  constructor failed the deletion test as caller knowledge.

## Adapter Seams

No new adapter Interface was added in Slice 11. The current in-memory
`ActiveSheetInput` path is not an Adapter seam by itself, and one adapter means
a hypothetical seam. The real Adapter need begins in Slice 12 and Slice 13,
where Google read and write adapters will translate spreadsheet data into the
existing sheet-contract Interface and apply `ActiveSheetWritePlan` values.

Set notation also has no Adapter need today. It remains a real domain seam
because multiple backend behaviors consume the same compact notation contract,
not because alternate adapters exist.

## Cleanup

- Split the active sheet Implementation into cohesive internal Modules:
  formula healing, history blocks, parsed sheet facade, row parsing, read
  models, workout rows, write plans, and shared helpers.
- Kept the public `package:workout_tracker/sheet_contract.dart` Interface
  stable.
- Made `ParsedActiveSheet` construction private so callers cannot construct
  parsed results with Implementation-only state.
- Added no GUI code, no Google adapter code, and no new feature behavior.
