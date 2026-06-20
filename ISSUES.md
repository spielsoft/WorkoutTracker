# MVP Repair and Sheet Interaction Plan

This is the active transient implementation plan for the next MVP pass.

The goal is app-level MVP usefulness and sheet safety, not App Store submission
process work. Store distribution tasks, signing, TestFlight, and store metadata
are intentionally out of scope here.

Every validation or repair slice must create broken sheet fixtures that expose
the proposed issue and prove the app catches it before writing.

- [x] Slice 0: Repair-Damage Test Fixtures
- [x] Slice 1: Block Damaged Sheets on the Validation Screen
- [x] Slice 2: One-Click Unambiguous Formula Repair
- [x] Slice 3: Choice-Based Ambiguous Formula Repair
- [x] Slice 4: Manual Repair Items for Structural Damage
- [x] Slice 5: Literal Writes for User and History Text
- [x] Slice 6: Narrow Write Sanity Checks and Duplicate Block Prevention
- [x] Slice 7: MVP Repair and Interaction Validation Gate

## Slice 0: Repair-Damage Test Fixtures

### Type

`AFK`

### What to build

Create reusable local sheet fixtures for the damaged-sheet cases in this plan.
The fixtures should be small, deterministic, and usable by backend tests,
controller tests, and widget tests without Google credentials.

This slice should not add product behavior by itself. It creates the test
surface that later slices use to prove damaged sheets are caught and routed
correctly.

### Acceptance criteria

- [x] Local fixtures include missing or renamed fixed columns.
- [x] Local fixtures include malformed history blocks: duplicate labels, stray
      set columns, skipped set labels, and empty history blocks.
- [x] Local fixtures include invalid `Log Format` values.
- [x] Local fixtures include backup grouping violations.
- [x] Local fixtures include missing formula-driven cells.
- [x] Local fixtures include broken formula-driven cells pointing at the wrong
      `Exercises` row or column.
- [x] Local fixtures include ambiguous formula repair cases with duplicate
      `Exercises` matches.
- [x] Local fixtures include no-exact-match formula repair cases.
- [x] Fixture tests verify each broken fixture is stable and exposes the
      intended damaged-sheet condition.
- [x] No fixture requires Google credentials or writes to the development
      spreadsheet.

### Blocked by

None - can start immediately.

### User stories covered

- Sheet contract validation and repair reliability.
- MVP testing requirement: broken sheets must expose each proposed issue.

## Slice 1: Block Damaged Sheets on the Validation Screen

### Type

`AFK`

### What to build

Route every damaged selected sheet to the main validation/repair screen and
prevent workout logging until the sheet is valid enough to use. If damage is
detected after an app action, discard transient typed logging input and return
to the validation/repair screen.

The validation screen should show all known current issues and update after
revalidation. This slice establishes the damaged-sheet gate before adding
specific repair actions.

### Acceptance criteria

- [x] A behavior test fails first with a broken fixed-column fixture and proves
      the app does not enter workout logging.
- [x] A behavior test fails first with a broken history-block fixture and proves
      the app does not enter workout logging.
- [x] A behavior test fails first with an invalid `Log Format` fixture and
      proves the app does not enter workout logging.
- [x] A behavior test fails first with a backup grouping violation fixture and
      proves the app does not enter workout logging.
- [x] The validation/repair screen lists all currently known issues for the
      selected sheet.
- [x] If a later app action produces a validation report with damage, the app
      returns to the validation/repair screen and no longer exposes logging
      controls.
- [x] Transient typed logging input is not preserved when routing back to repair.
- [x] Tests cross public backend/controller/widget interfaces rather than
      private helpers.

### Blocked by

- Slice 0: Repair-Damage Test Fixtures

### User stories covered

- No app editing of a damaged sheet.
- Repair screen owns sheet validation state.

## Slice 2: One-Click Unambiguous Formula Repair

### Type

`AFK`

### What to build

Add MVP click-to-fix behavior for formula repair cases where the correct
`Exercises` row is unambiguous. The validation/repair screen should group all
unambiguous formula issues into one action, apply repairs for only the flagged
cells, re-read the sheet, and shrink the issue list.

This slice only repairs formulas. It must not attempt structural repairs.

### Acceptance criteria

- [x] A behavior test fails first using a broken sheet with missing formula
      cells that have exact `Exercises` matches.
- [x] A behavior test fails first using a broken sheet with wrong direct
      formulas that have exact `Exercises` matches.
- [x] The repair screen shows one grouped action for all unambiguous formula
      issues.
- [x] Applying the grouped action writes direct formulas only into flagged
      cells.
- [x] Applying the grouped action does not overwrite unflagged formula-driven
      cells.
- [x] Applying the grouped action does not edit the `Exercises` tab.
- [x] After repair, the app re-reads/revalidates and the repaired issues
      disappear from the list.
- [x] Logging remains blocked while any blocking issue remains.

### Blocked by

- Slice 0: Repair-Damage Test Fixtures
- Slice 1: Block Damaged Sheets on the Validation Screen

### User stories covered

- Click-to-fix common formula damage.
- Formula repair writes only flagged cells.

## Slice 3: Choice-Based Ambiguous Formula Repair

### Type

`AFK`

### What to build

Add individual repair items for formula issues where the app cannot infer the
correct `Exercises` row. Each ambiguous or no-exact-match item should include a
searchable/filterable `Exercises` row picker and a fix action enabled only after
the user chooses a row.

This slice only repairs formulas. It must not create exercises or perform
structural sheet repairs.

### Acceptance criteria

- [x] A behavior test fails first using a broken sheet where a formula repair
      row has duplicate exact `Exercises` name matches.
- [x] A behavior test fails first using a broken sheet where a formula repair
      row has no exact `Exercises` name match.
- [x] Ambiguous and no-match formula rows appear as individual repair items, not
      in the unambiguous grouped action.
- [x] Each individual item exposes a searchable/filterable picker containing
      all `Exercises` rows.
- [x] The fix action is disabled until a row is selected.
- [x] Applying the fix writes direct formulas only into flagged cells for that
      active-sheet row.
- [x] Applying the fix does not overwrite unflagged formula-driven cells.
- [x] After repair, the app re-reads/revalidates and the fixed item disappears
      or changes according to the new sheet state.

### Blocked by

- Slice 2: One-Click Unambiguous Formula Repair

### User stories covered

- User-selected formula repair when the correct exercise row is ambiguous.
- User-selected formula repair when no exact exercise-name match exists.

## Slice 4: Manual Repair Items for Structural Damage

### Type

`AFK`

### What to build

For structural sheet damage that is easy for users to fix directly in the
spreadsheet, provide clear manual repair items on the validation/repair screen
with an Open in Google Sheets action. Do not build complex structural
auto-repair in MVP.

Manual repair items should be concise and actionable: what is wrong, where it
is, and what the user should change in the sheet.

### Acceptance criteria

- [x] A broken fixed-column fixture produces a manual repair item with no
      app-side fix action.
- [x] A malformed history-block fixture produces a manual repair item with no
      app-side fix action.
- [x] An invalid `Log Format` fixture produces a manual repair item with no
      app-side fix action.
- [x] A backup grouping violation fixture produces a manual repair item with no
      app-side fix action.
- [x] Manual repair items include an Open in Google Sheets action.
- [x] Opening behavior is abstracted so tests can verify the target spreadsheet
      URL without launching a real app or browser.
- [x] Revalidating after the user fixes the sheet externally updates the issue
      list and can unlock logging.

### Blocked by

- Slice 1: Block Damaged Sheets on the Validation Screen

### User stories covered

- Structural damage is blocked and explained.
- Users can jump to the source-of-truth sheet for manual repair.

## Slice 5: Literal Writes for User and History Text

### Type

`AFK`

### What to build

Separate formula writes from literal user/history writes. Formula repair writes
must continue to enter formulas. User set logs, raw edits, clears, history block
labels, and set labels must be written as literal text so formula-looking user
values are not executed by Google Sheets.

### Acceptance criteria

- [x] A write-adapter behavior test fails first when a structured set renders a
      formula-looking value such as `=1+1`.
- [x] A write-adapter behavior test fails first when raw set text starts with
      `=`.
- [x] A write-adapter behavior test fails first when a new history block label
      starts with `=`.
- [x] User log values and history labels/set labels are sent through a literal
      value path.
- [x] Formula repair cells are sent through a formula-entered path.
- [x] Mixed write plans split formula and literal writes if the Google Sheets
      adapter cannot safely apply both in one request.
- [x] Clearing a cell still clears the cell rather than writing visible escape
      text.
- [x] Existing local write-adapter tests continue to pass.

### Blocked by

- Slice 2: One-Click Unambiguous Formula Repair

### User stories covered

- User-entered workout text is preserved as text.
- Formula repair still writes formulas.

## Slice 6: Narrow Write Sanity Checks and Duplicate Block Prevention

### Type

`AFK`

### What to build

Add MVP action-local write safety checks without adding full validation before
every write and without re-planning to a different visible set target behind the
user's back.

Before applying a write, the app should check only the target facts needed for
that action: expected row identity, workout/backup selection, selected history
block or set column, target cell expectation, and insertion point expectation.
If the target no longer makes sense, return to validation/repair.

Also prevent app-created duplicate history block labels before writing.

### Acceptance criteria

- [x] A broken/changed sheet fixture proves a set write is rejected when the
      target row no longer has the expected exercise display value.
- [x] A broken/changed sheet fixture proves a set write is rejected when the
      target row no longer matches the expected workout or backup state.
- [x] A broken/changed sheet fixture proves an edit/clear is rejected when the
      target set column no longer exists.
- [x] A broken/changed sheet fixture proves a new-set save is rejected when the
      target cell is no longer the value/empty state shown in the UI.
- [x] A broken/changed sheet fixture proves history block insertion is rejected
      when the fixed-column/header insertion point no longer matches the plan.
- [x] Rejected writes route the app to the validation/repair screen.
- [x] Save behavior trusts the visible UI target and does not silently re-plan
      to another set cell.
- [x] Creating a history block with an existing label is blocked inline before
      any write plan is applied.
- [x] Duplicate labels already present in the sheet remain a validation/repair
      issue, not an auto-repair.

### Blocked by

- Slice 1: Block Damaged Sheets on the Validation Screen
- Slice 5: Literal Writes for User and History Text

### User stories covered

- Avoid obvious bad writes without full validation on every write.
- Prevent app-created duplicate history block damage.

## Slice 7: MVP Repair and Interaction Validation Gate

### Type

`HITL`

### What to build

Validate the complete MVP repair and sheet interaction flow. This is the gate
for the pass: all local tests must pass, the skipped-by-default live integration
test must still compile/skip without Google credentials, and a HITL live run may
be performed only when Google login and development-sheet writes are explicitly
approved.

### Acceptance criteria

- [x] Every broken-sheet fixture introduced in this plan is covered by a
      behavior test that proves the issue is caught before writing.
- [x] Formula repair tests cover grouped unambiguous repair and individual
      choice-based repair.
- [x] Manual repair tests cover structural issues and Open in Google Sheets
      action routing.
- [x] Literal write tests prove formula-looking user/history text is preserved
      as text.
- [x] Narrow write sanity tests prove rejected writes route to validation/repair.
- [x] `flutter test` passes.
- [x] `flutter analyze` passes.
- [x] `flutter test integration_test/live_logging_flow_test.dart` builds and
      skips cleanly without `WORKOUT_TRACKER_RUN_LIVE_GOOGLE_TESTS=1`.
- [x] If a live run is explicitly approved, the development sheet is reset
      before and after the run.
- [x] README or domain docs are updated only if behavior or user-facing repair
      semantics changed.

### Blocked by

- Slice 3: Choice-Based Ambiguous Formula Repair
- Slice 4: Manual Repair Items for Structural Damage
- Slice 6: Narrow Write Sanity Checks and Duplicate Block Prevention

### User stories covered

- MVP validation and repair flow.
- MVP sheet interaction safety.
- Development discipline for broken-sheet coverage.
