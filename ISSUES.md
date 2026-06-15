# Literal Log Format Implementation Plan

- [x] Slice 0: Define the Literal Log Format Contract
- [x] Slice 1: Parse and Render Literal Log Formats
- [ ] Slice 2: Read Log Format Metadata From the Sheet Contract
- [ ] Slice 3: Heal and Reset Log Format Formula Columns
- [ ] Slice 4: Parse Existing History Cells With Row-Local Formats
- [ ] Slice 5: Plan Set Writes From Formatted Field Values
- [ ] Slice 6: Render Dynamic Logging Fields in the GUI
- [ ] Slice 7: Validate the End-to-End Logging Flow
- [ ] Slice 8: Architecture and Test Cleanup

## Slice 0: Define the Literal Log Format Contract

### Type

`AFK`

### What to build

Record the new sheet contract for row-local literal log formats. The `Exercises` tab gains a human-readable log format metadata column, and the active workout sheet mirrors it by formula so each exercise row can define the app fields and compact sheet notation used for logging.

The agreed format language is literal:

```text
{Weight}[x]{Reps}[@]{RPE}
{Height}[x]{Reps}[@]{RPE}[,]{Pain}
{Reps}[@]{RPE}
{Seconds}[s@]{RPE}
```

Text inside `{}` is an app field label. Text inside `[]` is literal sheet text. Literal text is always rendered, even when an adjacent field value is blank. Blank format means the default format `{Weight}[x]{Reps}[@]{RPE}`. The initial app supports up to four fields per format.

### Acceptance criteria

- [x] The project documentation describes the literal log format language and its default.
- [x] The sheet contract names the new metadata column consistently as `Log Format`.
- [x] The active sheet fixed metadata order is documented as `Exercise`, `Sets`, `Reps`, `RPE`, `Rest`, `Tempo`, `Notes`, `Log Format`, `Workout`, and `is_backup`, followed by history blocks.
- [x] The contract states that `is_backup` remains the last metadata column before history blocks.
- [x] The contract states that literal text inside `[]` is never automatically omitted for blank field values.
- [x] The contract states that unparseable existing cells remain raw and editable.
- [x] No production behavior changes are made beyond documentation and tests needed to pin the contract.

### Blocked by

None - can start immediately.

### User stories covered

- MVP PRD user stories 12, 13, 14, 47, 48, 49, 51, 52.
- Conversation decision: literal `{Field Label}` and `[sheet literal]` syntax with no semantic field mapping.

## Slice 1: Parse and Render Literal Log Formats

### Type

`AFK`

### What to build

Add a backend Module that parses a `Log Format` string into an ordered logging template and renders compact sheet text from entered field values. The Module should be independent of Google access and GUI code. It should treat field labels as exact user-authored strings, not app-owned semantic names.

### Acceptance criteria

- [x] A behavior test fails first for parsing `{Weight}[x]{Reps}[@]{RPE}` into three fields and two literal segments.
- [x] Blank format parses as the default `{Weight}[x]{Reps}[@]{RPE}`.
- [x] Formats with one to four fields are accepted.
- [x] Empty or malformed field labels are rejected through an observable validation result.
- [x] Formats with more than four fields are rejected through an observable validation result.
- [x] Rendering concatenates field values and literal segments exactly in format order.
- [x] Rendering preserves delimiters when field values are blank, such as `{Weight}[x]{Reps}[@]{RPE}[,]{Pain}` rendering `150x10@8,` when `Pain` is blank.
- [x] Tests cover repeated literal delimiters such as `{A}[,]{B}[,]{C}` so blank middle values are not ambiguous by omission.
- [x] The existing raw text preservation behavior is not removed.

### Blocked by

- Slice 0: Define the Literal Log Format Contract

### User stories covered

- MVP PRD user stories 47, 48, 49, 51, 52.
- Conversation decision: literal delimiters are preserved even when data is missing.

## Slice 2: Read Log Format Metadata From the Sheet Contract

### Type

`AFK`

### What to build

Extend the active sheet parser and read models so every parsed workout slot carries its row-local `Log Format`. The active sheet receives this value by formula from `Exercises`, just like the other exercise metadata fields. Existing sheets with a blank `Log Format` value use the default format.

### Acceptance criteria

- [ ] A behavior test fails first for parsing a valid active sheet containing a `Log Format` column.
- [ ] The parser recognizes `Log Format` between `Notes` and `Workout`.
- [ ] `Workout` remains visible near the end of the fixed metadata area.
- [ ] `is_backup` remains the final metadata column before history blocks.
- [ ] Parsed primary and backup rows expose their row-local log format through the public sheet-contract Interface.
- [ ] Blank `Log Format` values are interpreted as the default format.
- [ ] Invalid `Log Format` values produce schema violations that prevent unsafe structured logging for that row.
- [ ] Workout overview behavior, backup grouping, history block discovery, and set counts continue to work with the added metadata column.

### Blocked by

- Slice 1: Parse and Render Literal Log Formats

### User stories covered

- MVP PRD user stories 11, 12, 13, 15, 17, 19, 24, 25, 47, 48.

## Slice 3: Heal and Reset Log Format Formula Columns

### Type

`AFK`

### What to build

Update formula healing and development sheet reset behavior so the active sheet's `Log Format` cells are direct formulas into `Exercises`. The `Exercises` tab fixture should include representative formats for weighted lifts, bodyweight reps, height-based drills, timed drills, and optional pain. After the parser and reset fixture understand the new column, update the live development/example Google Sheet through the reset harness so the app has a compatible sheet for testing.

### Acceptance criteria

- [ ] A behavior test fails first for a missing active-sheet `Log Format` formula.
- [ ] Formula healing regenerates the `Log Format` formula for exact, ambiguous, and selected exercise repairs using the same user-choice rules as other exercise metadata.
- [ ] The development reset fixture adds `Log Format` to `Exercises`.
- [ ] Active workout rows in the reset fixture link `Log Format` by direct formula.
- [ ] The live development/example Google Sheet is reset or migrated to include the `Log Format` column after app support for the new sheet shape exists.
- [ ] The live sheet update is not performed before Slice 2 support lands, so the currently working app is not broken by a premature schema change.
- [ ] The reset writer continues to write formulas as formulas and non-formula literals as plain text.
- [ ] Fixture tests include at least one weighted format, one bodyweight format, one height-based format, one timed format, and one optional-pain format.
- [ ] Existing Google read/write adapter behavior remains compatible with the expanded fixed metadata area.

### Blocked by

- Slice 2: Read Log Format Metadata From the Sheet Contract

### User stories covered

- MVP PRD user stories 7, 8, 9, 10, 13, 14, 47, 48, 49.

## Slice 4: Parse Existing History Cells With Row-Local Formats

### Type

`AFK`

### What to build

Use each row's `Log Format` to parse existing selected-history cells into editable field values for the exercise logging context. Parsing should use the literal segments as separators. If a cell cannot be parsed by the row-local format, preserve it as raw text exactly as the app does today.

### Acceptance criteria

- [ ] A behavior test fails first for parsing `150x10@8,` using `{Weight}[x]{Reps}[@]{RPE}[,]{Pain}` into field values with blank `Pain`.
- [ ] Repeated delimiter formats such as `{A}[,]{B}[,]{C}` parse cells with blank middle fields without dropping delimiters.
- [ ] Existing history entries expose the row-local field labels and parsed field values through the public read model.
- [ ] Existing unparseable cells remain `Raw` entries and preserve their original text.
- [ ] Row-local parsing is used for primary and backup rows independently.
- [ ] Recent history still shows the last three non-empty history blocks for the selected row.
- [ ] Tests cover blank format defaulting during history parsing.

### Blocked by

- Slice 3: Heal and Reset Log Format Formula Columns

### User stories covered

- MVP PRD user stories 35, 39, 40, 41, 44, 47, 48, 51, 52.

## Slice 5: Plan Set Writes From Formatted Field Values

### Type

`AFK`

### What to build

Change structured set write planning so callers provide field values for the selected row's `Log Format`, and the backend renders the compact sheet cell from that format. This keeps write planning row-local and avoids GUI code assembling compact notation itself.

### Acceptance criteria

- [ ] A behavior test fails first for logging field values through `{Weight}[x]{Reps}[@]{RPE}` and planning the cell value `150x10@8`.
- [ ] A blank optional-looking field still renders surrounding literals, such as `150x10@8,`.
- [ ] Primary and backup row writes use the selected row's own format.
- [ ] Logging into the first empty selected-row cell still works.
- [ ] Logging beyond existing set columns still plans history block growth.
- [ ] Editing an existing set cell can use structured field values when the cell parses successfully.
- [ ] Raw edit and clear behavior remain available for unparseable cells.
- [ ] The write planner remains testable without Google access.

### Blocked by

- Slice 4: Parse Existing History Cells With Row-Local Formats

### User stories covered

- MVP PRD user stories 44, 45, 47, 48, 51, 52, 53, 55.

## Slice 6: Render Dynamic Logging Fields in the GUI

### Type

`AFK`

### What to build

Replace the hard-coded Weight/Reps/RPE logging editor with a dynamic editor driven by the selected row's `Log Format`. The GUI should render one plain text input per `{Field Label}` in order, with labels exactly matching the sheet-authored format.

### Acceptance criteria

- [ ] A widget test fails first for an exercise whose format is `{Reps}[@]{RPE}` and verifies that only `Reps` and `RPE` fields appear.
- [ ] Weighted exercises render `Weight`, `Reps`, and `RPE` fields from the format.
- [ ] Height-based and timed exercises render their sheet-authored labels exactly.
- [ ] Switching from a primary to a backup row refreshes the visible field labels and parsed values using the backup row's format.
- [ ] Saving a structured entry sends field values to the backend write planner rather than assembling notation in the GUI.
- [ ] Unparseable existing cells still provide raw edit controls.
- [ ] The current exercise screen continues to show description, notes, rest, targets, current set rows, prior selected-block rows, and recent history.

### Blocked by

- Slice 5: Plan Set Writes From Formatted Field Values

### User stories covered

- MVP PRD user stories 36, 37, 39, 42, 43, 44, 47, 48, 51, 52, 56, 57.

## Slice 7: Validate the End-to-End Logging Flow

### Type

`AFK`

### What to build

Update the focused GUI and backend integration validation so the app can read a sheet with row-local log formats, render the matching dynamic fields, log structured values, and write compact human-readable notation back to the selected history block.

### Acceptance criteria

- [ ] The default local test suite passes.
- [ ] A focused GUI flow test logs a weighted exercise through dynamic fields.
- [ ] A focused GUI flow test logs a bodyweight or timed exercise without a weight field.
- [ ] A backend integration-style test verifies primary and backup rows can use different formats.
- [ ] The opt-in live Google test is updated to use the development fixture's `Log Format` column but remains skipped unless `WORKOUT_TRACKER_RUN_LIVE_GOOGLE_TESTS=1` is set.
- [ ] The live test reset/cleanup path still leaves the development sheet in a known state.
- [ ] A manual or opt-in validation confirms the example sheet opens in the app and shows exercises after the live sheet has been updated.
- [ ] No app-owned exercise metadata database or hidden mapping is introduced.

### Blocked by

- Slice 6: Render Dynamic Logging Fields in the GUI

### User stories covered

- MVP PRD user stories 1, 2, 5, 22, 29, 35, 42, 43, 44, 47, 48, 49, 51, 55.

## Slice 8: Architecture and Test Cleanup

### Type

`AFK`

### What to build

Run a cleanup pass after the feature lands. Review whether the literal log format Module is deep enough, whether the sheet-contract Interface remains the test surface, and whether GUI tests are still smoke-level rather than duplicating backend format parsing.

### Acceptance criteria

- [ ] Run an `improve-codebase-architecture` review focused on the new log format Module, sheet-contract read/write planning, and GUI dynamic field rendering.
- [ ] Remove or consolidate duplicate tests left behind by TDD.
- [ ] Ensure format parsing/rendering tests stay local to the format Module.
- [ ] Ensure sheet-contract tests cover row-local behavior through public Interfaces.
- [ ] Ensure widget tests cover only GUI rendering and interaction smoke behavior.
- [ ] Run the relevant local test tier after cleanup.
- [ ] Commit the cleanup separately from implementation slices.

### Blocked by

- Slice 7: Validate the End-to-End Logging Flow

### User stories covered

- MVP PRD user story 66.
- Project testing guidance in `AGENTS.md`.
