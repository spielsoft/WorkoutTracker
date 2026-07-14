# Python-Style Exercise Log Formats

- [x] Slice 1: Use Python-Style Formats in Version 1.0 Workbooks
- [x] Slice 2: Convert Version 0.9 Formats Safely
- [x] Slice 3: Log Five-Field DB Step-Ups in New Workbooks
- [ ] Slice 4: Safely Change Formats for Placed Exercises
- [ ] Slice 5: Normalize Every Provided Exercise Default
- [ ] Slice 6: Clean Up TDD Tests
- [ ] Slice 7: Run the Architecture and Full Local Guard
- [ ] Slice 8: Validate Conversion Against Google Sheets

## Slice 1: Use Python-Style Formats in Version 1.0 Workbooks

### Type

`AFK`

### What to build

Deliver the corrected notation contract end to end for new workbooks. A
version `1.0` workbook
uses exact `{Field}` placeholders with every character outside braces treated
as literal text, supports one through five fields, and can be authored,
validated, rendered, parsed, and logged through the public app flow. Convert
the repository's templates and fixtures to equivalent Python-style formats.
Keep declared `0.9` workbooks on their current explicitly selected semantics
until the next slice provides their converter; never reinterpret them as
`1.0` merely because headers happen to match.

### Acceptance criteria

- [x] A behavior test first demonstrates parsing and rendering a Python-style format whose literal punctuation appears directly outside field braces.
- [x] Formats with one through five exact, case-sensitive fields are accepted.
- [x] Empty fields, unmatched braces, duplicate fields, more than five fields, and adjacent fields without a literal extraction boundary are rejected with useful validation messages.
- [x] Rendering and parsing `({Height (in)}, {Weight (lbs)})x{Reps}@{RPE},{Pain}` round-trips `(12, 15)x8@8,0` into five ordered values with the exact declared keys.
- [x] Preview generation works for five fields and has no fixed four-value assumption.
- [x] Exercise authoring help, validation, preview, and accessible default-field names expose only the Python-style contract.
- [x] A structured five-field exercise can be logged through an in-memory version `1.0` workbook using the public command flow.
- [x] New workbook templates and repository fixtures contain Python-style formats and carry schema version `1.0`.
- [x] Declared `0.9` workbooks remain explicitly version-routed and are not parsed as `1.0` formats.
- [x] Focused notation, version routing, workbook parsing, authoring, and logging tests pass.

### Blocked by

None - can start immediately.

### User stories covered

- ISSUES_PRD.md user stories 3, 6, 11-16, 20, 28, 30-32.

## Slice 2: Convert Version 0.9 Formats Safely

### Type

`AFK`

### What to build

Add the deliberate `0.9`-to-`1.0` workbook conversion. Recognize the old
repository notation only inside the versioned converter, preview every change,
prove equivalent rendered data, preserve history cells, and stamp `1.0` only
after a confirmed stale-checked write. Preserve the existing unversioned
original-workbook conversion route without guessing versions from structure.

### Acceptance criteria

- [x] A declared version `0.9` workbook offers a dry-run conversion that lists every format change without writing.
- [x] Confirmed conversion rewrites notation-only brackets into equivalent literal text, preserves the rendered Default Values and Targets, leaves history cells unchanged, and stamps version `1.0`.
- [x] Conversion is idempotent, refuses damaged or stale workbooks, and never guesses a version from headers.
- [x] An unversioned original workbook still follows only its existing legacy conversion path and reaches the current contract deliberately.
- [x] Converter-specific recognition of the old notation does not leak into `1.0` authoring help or validation behavior.
- [x] Converted workbooks reopen through ordinary `1.0` validation with no format, Default Values, Targets, or history regression.
- [x] Focused migration planning, confirmation UI, adapter, version metadata, and reread tests pass.

### Blocked by

- Slice 1: Use Python-Style Formats in Version 1.0 Workbooks

### User stories covered

- ISSUES_PRD.md user stories 17-20, 26-27, 30-32.

## Slice 3: Log Five-Field DB Step-Ups in New Workbooks

### Type

`AFK`

### What to build

Make the provided DB Step-Up definition use the exact agreed five-field format
and numeric novice defaults. Prove that an app-created `1.0` workbook exposes
Height (in), Weight (lbs), Reps, RPE, and Pain in order, keeps numeric gym-entry
controls, displays the target context, writes compact notation, and reads it
back as structured history on mobile and desktop layouts.

### Acceptance criteria

- [x] A failing template behavior test first identifies the missing DB Step-Up Weight field.
- [x] DB Step-Up uses exactly `({Height (in)}, {Weight (lbs)})x{Reps}@{RPE},{Pain}`.
- [x] Its defaults are exactly `12`, `15`, `8`, `8`, and `0` in declaration order.
- [x] Its rendered default entry is exactly `(12, 15)x8@8,0`.
- [x] Placing DB Step-Up copies five valid numeric Targets into the active row.
- [x] The logging screen exposes five numeric-keyboard fields in declaration order with stable accessible names.
- [x] Saving edited values writes the exact compact notation produced by the format owner rather than UI string assembly.
- [x] Rereading the saved cell restores all five numeric field values.
- [x] The five-field editor and save action remain reachable without overlap at narrow width, large text, and the supported desktop width.
- [x] Existing raw-history preservation and stale-write rejection remain intact.
- [x] Focused template, placement, logging, semantics, and write-planning tests pass.

### Blocked by

- Slice 1: Use Python-Style Formats in Version 1.0 Workbooks

### User stories covered

- ISSUES_PRD.md user stories 1-8, 16, 23, 28-29.

## Slice 4: Safely Change Formats for Placed Exercises

### Type

`AFK`

### What to build

Close the existing safety gap in canonical exercise editing. When a format
change affects exercises already placed in workouts, show every affected
row-local Target under the proposed fields, preserve exact field matches, seed
new fields from canonical defaults, and require valid placement values before
confirmation. Apply the canonical exercise update and all affected active-sheet
Targets as one workflow-owned, stale-checked Google Sheets batch. Report the
history entries that will become raw and never rewrite them automatically.

### Acceptance criteria

- [ ] A failing public workflow test first proves that changing a placed exercise's format cannot update only the Exercises row and leave invalid Targets.
- [ ] A format change with no placements continues through the simple canonical update path.
- [ ] A format change with placements returns an impact model containing every affected row, its old Targets, proposed ordered fields, and count of history entries that will become raw.
- [ ] Exact matching fields retain their placement-specific values.
- [ ] New or renamed fields begin with canonical defaults and remain explicitly editable for each placement before confirmation.
- [ ] The update cannot proceed while any affected placement would render invalid Targets under the proposed format.
- [ ] The final plan owns the complete canonical-plus-placement workflow behind one public interface rather than exposing pass-through helpers.
- [ ] The workflow rereads schema-valid state, verifies canonical and placement expectations, and rejects concurrent edits.
- [ ] The Sheets adapter applies Exercises and active-sheet writes in one batch operation.
- [ ] A DB Step-Up upgrade can set Height (in), Weight (lbs), Reps, RPE, and Pain Targets without an intermediate invalid workbook.
- [ ] Existing DB Step-Up history lacking Weight is unchanged byte-for-byte and appears as editable raw history after the update.
- [ ] The confirmation UI identifies affected placements and raw-history impact with accessible, non-color-only state.
- [ ] Focused planning, orchestration, adapter, format-edit, logging, and accessibility tests pass.

### Blocked by

- Slice 1: Use Python-Style Formats in Version 1.0 Workbooks
- Slice 3: Log Five-Field DB Step-Ups in New Workbooks

### User stories covered

- ISSUES_PRD.md user stories 17-27, 30-31.

## Slice 5: Normalize Every Provided Exercise Default

### Type

`AFK`

### What to build

Audit the entire provided exercise catalog under the corrected contract. Every
declared field receives a nonblank default, all provided gym-entry values are
numeric, Pain is `0`, and measurement units or necessary context live in exact
field names rather than values. Preserve useful strength/hypertrophy range and
coaching guidance in human-readable descriptions or notes. Prove that every
definition seeds a valid `1.0` workbook and can round-trip through its format.

### Acceptance criteria

- [ ] A catalog behavior test fails for every blank, nonnumeric, missing, extra, or mismatched provided field value.
- [ ] Every provided format uses Python-style literal text and one through five unique fields.
- [ ] Every provided default map has exactly the format's fields in declaration order.
- [ ] Every provided default value is a numeric string suitable for the numeric gym-entry keyboard.
- [ ] Every declared Pain value is exactly `0`.
- [ ] Weight and height fields carry their units in names such as `Weight (lbs)` and `Height (in)` rather than in values.
- [ ] Stable measurement context needed for extraction is carried by the field name; exercise instructions and target ranges remain human-readable in descriptions or notes.
- [ ] Defaults remain conservative for an untrained male pursuing strength and hypertrophy.
- [ ] Each rendered default parses back to the exact default map.
- [ ] A newly created workbook contains every provided exercise as one valid eight-column Exercises row.
- [ ] DB Step-Up retains the exact five-field contract established in Slice 3.
- [ ] Focused catalog and workbook-template tests pass.

### Blocked by

- Slice 1: Use Python-Style Formats in Version 1.0 Workbooks
- Slice 3: Log Five-Field DB Step-Ups in New Workbooks

### User stories covered

- ISSUES_PRD.md user stories 4, 7-10, 28, 31.

## Slice 6: Clean Up TDD Tests

### Type

`AFK`

### What to build

Use the `test-cleanup` skill to remove or rewrite development-loop tests that
pin parser internals, exact widget trees, incidental callback order, or adapter
implementation details. Retain the smallest durable safety net for the public
Python-style grammar, versioned workbook conversion, atomic format evolution,
provided defaults, numeric five-field logging, accessibility, raw-history
preservation, and stale-write behavior.

### Acceptance criteria

- [ ] The `test-cleanup` skill is read and followed before changing tests.
- [ ] Tests that exist only to drive private helper implementation are removed or rewritten through public interfaces.
- [ ] Contract tests retain the exact DB Step-Up format, five-field extraction, and malformed-format boundaries.
- [ ] Workbook tests retain version selection, dry-run conversion, idempotence, raw preservation, and stale rejection.
- [ ] UI tests retain numeric keyboard behavior, stable semantics, responsive five-field layout, and the atomic-update confirmation contract without pinning widget structure.
- [ ] Catalog tests retain complete fields, numeric values, pain `0`, and round-trip coverage without enumerating irrelevant JSON formatting.
- [ ] Focused suites and the full local test suite pass after cleanup.

### Blocked by

- Slice 1: Use Python-Style Formats in Version 1.0 Workbooks
- Slice 2: Convert Version 0.9 Formats Safely
- Slice 3: Log Five-Field DB Step-Ups in New Workbooks
- Slice 4: Safely Change Formats for Placed Exercises
- Slice 5: Normalize Every Provided Exercise Default

### User stories covered

- ISSUES_PRD.md user stories 30-32 and Testing Decisions.

## Slice 7: Run the Architecture and Full Local Guard

### Type

`AFK`

### What to build

Run a strict maintainability review and the complete local validation gate.
Confirm that notation, version conversion, workflow planning, Google adapters,
application orchestration, and UI presentation remain separate concerns; that
one deep public workflow owns atomic format changes; and that no DB Step-Up
special case or app-owned exercise database entered production code. Resolve
all in-scope findings before declaring the plan locally complete.

### Acceptance criteria

- [ ] The `code-quality-review` skill is used for the final architecture review.
- [ ] The review finds no shallow pass-through layer, duplicated parser, DB Step-Up production special case, unsafe cross-tab seam, or public contract drift.
- [ ] All in-scope review findings are fixed and validated.
- [ ] Formatting and static analysis pass.
- [ ] The full local test suite passes without enabling live Google tests.
- [ ] The domain contract and user-facing format help agree on Python-style syntax, five fields, unit-bearing names, numeric entry, version conversion, and raw-history safety.
- [ ] Every completed slice has its own validated commit and checked plan item.

### Blocked by

- Slice 6: Clean Up TDD Tests

### User stories covered

- ISSUES_PRD.md user stories 30-32 and all implementation/testing decisions.

## Slice 8: Validate Conversion Against Google Sheets

### Type

`HITL`

### What to build

With explicit user approval, validate the complete workflow against the named
development Google Sheet or a disposable copy. Exercise the dry-run and
confirmed `0.9` conversion, verify a five-field DB Step-Up target and logged
set directly in Google Sheets, confirm old history preservation, and reset the
fixture afterward. Do not touch an owner workbook as part of automated
validation.

### Acceptance criteria

- [ ] The user explicitly approves the live test and target spreadsheet before authentication or writes.
- [ ] The test uses only the documented opt-in environment flag and allowlisted development fixture or disposable copy.
- [ ] Dry-run output is reviewed before confirmed conversion.
- [ ] The converted workbook is stamped `1.0`, validates in the app, and contains Python-style formats.
- [ ] DB Step-Up displays five numeric fields and writes a cell shaped like `(12, 15)x8@8,0`.
- [ ] Direct Sheet inspection confirms the format, numeric values, formula ownership, active Targets, and unchanged prior history.
- [ ] The fixture reset succeeds after validation; any reset failure is reported prominently.
- [ ] No owner workbook is changed without a separate explicit confirmation naming that workbook.

### Blocked by

- Slice 7: Run the Architecture and Full Local Guard

### User stories covered

- ISSUES_PRD.md user stories 1-5, 17-27, 32 and the live-testing decision.
