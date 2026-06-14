# MVP Implementation Plan

- [x] Slice 0: Standard Flutter/Dart Scaffold and Git Repo
- [x] Slice 1: Capture Domain Contract and Backend Test Fixtures
- [x] Slice 2: Parse Active Sheet Rows Into Workout Slots
- [x] Slice 3: Validate Backup Grouping Rules
- [x] Slice 4: Architecture Review: Sheet Contract Module Depth
- [x] Slice 5: Discover and Select History Blocks
- [x] Slice 6: Plan New History Block Creation and Growth
- [x] Slice 7: Parse and Render Set Notation
- [x] Slice 8: Plan Set Logging Writes
- [x] Slice 9: Build Read Models for Workout Overview and Exercise Logging
- [ ] Slice 10: Formula Healing Planner
- [ ] Slice 11: Architecture Cleanup: Backend Module Seams
- [ ] Slice 12: Google Sheet Read Adapter
- [ ] Slice 13: Google Sheet Write Adapter
- [ ] Slice 14: Development Sheet Reset and Cleanup Harness
- [ ] Slice 15: Backend Integration Validation Gate
- [ ] Slice 16: Architecture Review: Backend Completion Gate
- [ ] Slice 17: App Store Readiness Validation
- [ ] Slice 18: GUI Shell: Spreadsheet Selection and Backend Validation
- [ ] Slice 19: GUI Workout and History Block Selection
- [ ] Slice 20: GUI Exercise Logging Screen
- [ ] Slice 21: GUI End-to-End Logging Validation
- [ ] Slice 22: Final Architecture and Test Cleanup

## Slice 0: Standard Flutter/Dart Scaffold and Git Repo

### Type

`AFK`

### What to build

Create a completely standard Flutter/Dart project layout for the workout tracker and initialize the workspace as a local git repository. The scaffold must support the agreed platform direction: iOS, macOS, Android, Linux, and Windows from one Flutter codebase, with a runnable macOS `.app` bundle as the day-one desktop requirement. Establish the baseline test command and make the first commit.

### Acceptance criteria

- [x] A standard Flutter project exists at the repository root.
- [x] iOS, macOS, Android, Linux, and Windows platform targets are present unless the local Flutter toolchain requires enabling them in a later setup step.
- [x] A baseline test command runs successfully.
- [x] A local git repository exists.
- [x] The scaffold is committed as the first slice commit.
- [x] No app-specific behavior is implemented beyond the standard scaffold.

### Blocked by

None - can start immediately.

### User stories covered

- PRD implementation decision: use Flutter/Dart as the cross-platform stack.
- PRD implementation decision: local/dev install only for MVP.
- PRD implementation decision: macOS `.app` bundle is required on day one.
- PRD user story 64.
- PRD user story 65.
- PRD user story 66.

## Slice 1: Capture Domain Contract and Backend Test Fixtures

### Type

`AFK`

### What to build

Record the domain contract in the repository and create backend test fixtures that model the active workout sheet and `Exercises` tab without requiring Google access. Include the development Google Sheet as a named writable integration fixture for later slices, but keep early tests local and deterministic.

### Acceptance criteria

- [x] The project has a concise domain contract describing active sheet, workout, history block, exercise row, primary row, backup row, and formula healing vocabulary.
- [x] Local in-memory fixtures represent a valid active sheet and a valid `Exercises` tab.
- [x] Local in-memory fixtures include at least one workout with primary rows and backup rows.
- [x] Local in-memory fixtures include ignored human section/header rows.
- [x] The development Google Sheet URL is documented as a writable integration fixture.
- [x] Tests verify that fixture loading itself is stable and deterministic.
- [x] All changes are committed after tests pass.

### Blocked by

- Slice 0: Standard Flutter/Dart Scaffold and Git Repo

### User stories covered

- PRD problem statement.
- PRD solution.
- PRD implementation decisions about strict schema and human-readable sheet contract.
- PRD testing decisions about in-memory sheet data.

## Slice 2: Parse Active Sheet Rows Into Workout Slots

### Type

`AFK`

### What to build

Build the first backend tracer bullet: parse an in-memory active sheet with fixed columns into workout slots. The parser must apply blank metadata defaults and ignore blank or merged first-column rows so callers get a clean workout model from a human-readable sheet.

### Acceptance criteria

- [x] A behavior test fails first for parsing a valid active sheet into workout slots.
- [x] The parser recognizes the fixed columns: `Exercise`, `Sets`, `Reps`, `RPE`, `Rest`, `Tempo`, `Notes`, `Workout`, and `is_backup`.
- [x] Blank `Workout` values are interpreted as the default workout.
- [x] Blank `is_backup` values are interpreted as false.
- [x] Rows whose first display column is blank or merged are ignored as human-only rows.
- [x] Parsed slots preserve active sheet row order.
- [x] Tests exercise the public backend interface rather than private helpers.
- [x] All changes are committed after tests pass.

### Blocked by

- Slice 1: Capture Domain Contract and Backend Test Fixtures

### User stories covered

- PRD user stories 11, 12, 15, 16, 17, 18, 21, 26.
- PRD testing decision: first tracer bullet.

## Slice 3: Validate Backup Grouping Rules

### Type

`AFK`

### What to build

Extend the active sheet parser/validator so backup rows are grouped under the nearest preceding primary row within the same workout. Detect contract violations that would make backup ownership ambiguous.

### Acceptance criteria

- [x] A behavior test fails first for backup grouping within a workout.
- [x] Backup rows attach to the nearest preceding non-backup row within the same `Workout` group.
- [x] Backup rows do not cross workout groups.
- [x] A workout whose first app-readable row is a backup produces a schema violation.
- [x] The parsed workout overview can distinguish primary rows from nested backup rows.
- [x] Validation errors are observable through the public backend interface.
- [x] All changes are committed after tests pass.

### Blocked by

- Slice 2: Parse Active Sheet Rows Into Workout Slots

### User stories covered

- PRD user stories 19, 20, 24, 25, 42, 43, 44.

## Slice 4: Architecture Review: Sheet Contract Module Depth

### Type

`AFK`

### What to build

Run an explicit architecture review using the `improve-codebase-architecture` skill vocabulary. Review the sheet contract module interface for depth, leverage, and locality before more behavior accumulates behind it. Apply cleanup only where it improves the interface or concentrates behavior behind a better module.

### Acceptance criteria

- [x] The review identifies whether the sheet contract module is deep or shallow.
- [x] Any shallow pass-through module discovered by the deletion test is removed or deepened.
- [x] Public tests continue to cross the same sheet contract interface used by callers.
- [x] Refactors happen only while tests are green.
- [x] The review result is documented briefly in the relevant commit message or project notes.
- [x] All changes are committed after tests pass.

### Blocked by

- Slice 3: Validate Backup Grouping Rules

### User stories covered

- PRD testing decisions about behavior-focused tests.
- PRD implementation decision: sheet contract parser/validator as a deep module.

## Slice 5: Discover and Select History Blocks

### Type

`AFK`

### What to build

Add backend behavior for discovering visible history blocks and selecting an existing block. A history block is identified by its visible label, not by date metadata, and contains set columns such as `S1`, `S2`, and `S3`.

### Acceptance criteria

- [x] A behavior test fails first for discovering visible history blocks.
- [x] The backend lists selectable history block labels in sheet order.
- [x] History block labels are treated as plain visible labels.
- [x] The backend does not require or infer date metadata.
- [x] Selecting an existing history block exposes its set columns.
- [x] The newest block closest to fixed metadata columns is represented correctly.
- [x] All changes are committed after tests pass.

### Blocked by

- Slice 4: Architecture Review: Sheet Contract Module Depth

### User stories covered

- PRD user stories 29, 34, 35.

## Slice 6: Plan New History Block Creation and Growth

### Type

`AFK`

### What to build

Add backend write planning for creating a new history block and growing a selected block as more sets are logged. A new history block starts with `S1` only and is inserted near the fixed metadata columns with newest history closest to the left.

### Acceptance criteria

- [x] A behavior test fails first for planning creation of a new `S1` history block.
- [x] A new block is planned near the fixed metadata columns.
- [x] The new block starts with only `S1`.
- [x] Adding a set beyond existing set columns plans extension to `S2`, `S3`, and later columns as needed.
- [x] Planned writes are represented without requiring immediate Google access.
- [x] Existing history block labels and data are preserved by the plan.
- [x] All changes are committed after tests pass.

### Blocked by

- Slice 5: Discover and Select History Blocks

### User stories covered

- PRD user stories 30, 31, 32, 33.

## Slice 7: Parse and Render Set Notation

### Type

`AFK`

### What to build

Build the backend module that parses and renders compact human-readable set notation while preserving unparseable values as raw text. The app will use structured fields in the UI later, but this slice owns the notation contract.

### Acceptance criteria

- [x] Behavior tests fail first for each supported notation category.
- [x] Weighted reps such as `150x10@8` parse and render.
- [x] Optional pain such as `150x10@8,1` parses and renders.
- [x] Bodyweight reps such as `15@8` parse and render.
- [x] Timed entries such as `45s@8` parse and render.
- [x] Height/platform-style entries parse and render for the agreed MVP direction.
- [x] Optional notes are preserved.
- [x] Unparseable cells are preserved as raw text and render back without data loss.
- [x] All changes are committed after tests pass.

### Blocked by

- Slice 2: Parse Active Sheet Rows Into Workout Slots

### User stories covered

- PRD user stories 47, 48, 49, 50, 51, 52.

## Slice 8: Plan Set Logging Writes

### Type

`AFK`

### What to build

Add backend behavior for planning set writes, edits, clears, and auto-advance within the selected row and selected history block. Writes are row-local: switching from a primary row to a backup row starts at that row's first empty set cell.

### Acceptance criteria

- [x] A behavior test fails first for logging a new set into the first empty set cell.
- [x] New set logging targets the selected row only.
- [x] Primary and backup rows can each receive their own row-local set entries.
- [x] Editing an existing set cell produces the expected planned write.
- [x] Clearing an existing set cell produces the expected planned write.
- [x] Logging beyond existing columns depends on the history block growth plan from Slice 6.
- [x] The next set position auto-advances after a successful planned write.
- [x] Raw unparseable existing data is preserved unless explicitly edited or cleared.
- [x] All changes are committed after tests pass.

### Blocked by

- Slice 6: Plan New History Block Creation and Growth
- Slice 7: Parse and Render Set Notation

### User stories covered

- PRD user stories 35, 44, 45, 47, 48, 51, 52, 53, 54, 55.

## Slice 9: Build Read Models for Workout Overview and Exercise Logging

### Type

`AFK`

### What to build

Build backend read models that provide exactly what the future GUI needs without requiring GUI code: workout selection, primary-only overview with nested backups, per-slot set counts, exercise logging context, and last-three row-local history blocks.

### Acceptance criteria

- [x] A behavior test fails first for building a primary-only workout overview.
- [x] Overview rows preserve active sheet order.
- [x] Backup rows are nested under their primary row and not shown as equal top-level exercises.
- [x] Per-slot set counts include primary and backup rows for that slot.
- [x] Exercise logging context includes read-only notes, rest, targets, selected row history, and available primary/backup choices.
- [x] History shown for an exercise is current-row only.
- [x] The default history view includes the last three non-empty history blocks for the selected row.
- [x] All changes are committed after tests pass.

### Blocked by

- Slice 8: Plan Set Logging Writes

### User stories covered

- PRD user stories 22, 23, 24, 25, 26, 27, 36, 37, 39, 40, 41, 46, 56, 57, 60.

## Slice 10: Formula Healing Planner

### Type

`AFK`

### What to build

Add backend behavior for detecting and planning repair of missing or broken direct formulas from the active sheet into the `Exercises` tab. The planner must support exact-name preselection and must require user choice when matches are ambiguous or missing. The initial app does not edit the `Exercises` tab.

### Acceptance criteria

- [ ] A behavior test fails first for detecting a missing formula-driven display cell.
- [ ] Missing or broken formulas in formula-driven columns are reported as healable issues.
- [ ] Exact displayed-name matches in `Exercises` are preselected where possible.
- [ ] Ambiguous displayed-name matches require a user selection.
- [ ] Missing displayed-name matches require a user selection.
- [ ] Healing plans produce direct formulas into the selected `Exercises` row.
- [ ] No healing plan writes to the `Exercises` tab.
- [ ] All changes are committed after tests pass.

### Blocked by

- Slice 9: Build Read Models for Workout Overview and Exercise Logging

### User stories covered

- PRD user stories 7, 8, 9, 10, 13, 14.

## Slice 11: Architecture Cleanup: Backend Module Seams

### Type

`AFK`

### What to build

Run an explicit architecture cleanup using the `improve-codebase-architecture` skill. Review the seams between sheet contract parsing, formula healing, set notation, history block planning, and set write planning. Tighten interfaces where it improves depth, leverage, and locality.

### Acceptance criteria

- [ ] The review applies the deletion test to backend modules that look shallow.
- [ ] The review identifies whether each seam has a real adapter need or is hypothetical.
- [ ] Cleanup reduces caller knowledge where possible.
- [ ] Behavior tests remain focused on public interfaces.
- [ ] No GUI work is introduced.
- [ ] All changes are committed after tests pass.

### Blocked by

- Slice 10: Formula Healing Planner

### User stories covered

- PRD implementation decision: backend sheet logic should be conceptually separated from Google API and UI.
- PRD testing decisions about behavior-focused tests.

## Slice 12: Google Sheet Read Adapter

### Type

`HITL`

### What to build

Build the Google Sheets read adapter for the backend seam. It must read the active first tab and the `Exercises` tab from the selected spreadsheet and translate live Google data into the same backend interface used by in-memory tests. This slice may require the user to complete Google login or authorize local credentials.

### Acceptance criteria

- [ ] The adapter can read from the writable `development` spreadsheet.
- [ ] The adapter identifies the first tab as the active workout sheet.
- [ ] The adapter reads the `Exercises` tab when present.
- [ ] Live read data can be passed through existing parser, validator, history block, and read model behavior.
- [ ] Auth setup is documented with the minimum practical permissions for development.
- [ ] If user-assisted login is required, the step is documented and repeatable.
- [ ] Local tests that do not require Google still run without credentials.
- [ ] All changes are committed after tests pass.

### Blocked by

- Slice 11: Architecture Cleanup: Backend Module Seams

### User stories covered

- PRD user stories 1, 2, 5, 6, 11, 12, 62.

## Slice 13: Google Sheet Write Adapter

### Type

`HITL`

### What to build

Build the Google Sheets write adapter for applying backend write plans to the development spreadsheet. It must apply planned updates for formula healing, history block creation/growth, set logging, editing, and clearing without bypassing the backend contract. This slice may require user-assisted Google authorization.

### Acceptance criteria

- [ ] Planned writes from backend tests can be applied to the `development` spreadsheet.
- [ ] The adapter can create a new `S1` history block in the live sheet.
- [ ] The adapter can grow a selected history block with additional set columns.
- [ ] The adapter can log a set to a primary row.
- [ ] The adapter can log a set to a backup row.
- [ ] The adapter can edit and clear existing set cells.
- [ ] The adapter can apply formula healing plans to the active sheet without editing `Exercises`.
- [ ] Existing unrelated sheet data is preserved.
- [ ] Local tests that do not require Google still run without credentials.
- [ ] All changes are committed after tests pass.

### Blocked by

- Slice 12: Google Sheet Read Adapter

### User stories covered

- PRD user stories 7, 30, 31, 32, 33, 44, 48, 53, 54.

## Slice 14: Development Sheet Reset and Cleanup Harness

### Type

`AFK`

### What to build

Create a repeatable reset and cleanup harness for the writable development spreadsheet so integration tests can safely write to it and return it to a known fixture state. This is required because the development sheet is intended to be used during backend development.

### Acceptance criteria

- [ ] The harness can reset the development spreadsheet to a known active sheet and `Exercises` tab fixture.
- [ ] Integration tests can call the reset path before or after live write tests.
- [ ] Cleanup preserves the workbook as a usable human-readable sheet.
- [ ] The reset fixture includes primary rows, backup rows, at least one workout name, blank default workout rows, and at least one history block.
- [ ] The reset fixture includes formula-driven active sheet fields pointing into `Exercises`.
- [ ] The harness avoids touching unrelated spreadsheets.
- [ ] All changes are committed after tests pass.

### Blocked by

- Slice 13: Google Sheet Write Adapter

### User stories covered

- PRD testing decisions about controlled test spreadsheets.
- User instruction: development sheet may be written to and should support cleanup.

## Slice 15: Backend Integration Validation Gate

### Type

`HITL`

### What to build

Validate the full backend flow against the live development spreadsheet: reset fixture, read, validate, heal formulas, select workout, select or create history block, log set, edit set, clear set, and reset again. This is the backend completion gate before GUI work.

### Acceptance criteria

- [ ] The live development sheet can be reset to known state.
- [ ] Backend validation passes on the reset sheet.
- [ ] Formula healing can be planned and applied to the live sheet.
- [ ] Existing and new history blocks can be selected or created.
- [ ] A primary row set can be logged, read back, edited, cleared, and read back again.
- [ ] A backup row set can be logged and included in slot set counts.
- [ ] The final cleanup returns the sheet to known state.
- [ ] Any required user login step is documented.
- [ ] All non-Google local tests continue to pass.
- [ ] All changes are committed after tests pass.

### Blocked by

- Slice 14: Development Sheet Reset and Cleanup Harness

### User stories covered

- PRD critical backend flow.
- PRD user stories 1, 2, 5, 6, 7, 22, 29, 30, 35, 44, 48, 53, 54, 60.

## Slice 16: Architecture Review: Backend Completion Gate

### Type

`AFK`

### What to build

Run the required backend-complete architecture review before GUI work starts. Use the `improve-codebase-architecture` skill to find deepening opportunities, shallow modules, leaky seams, and tests that overfit implementation. Apply cleanup where it improves locality and leverage.

### Acceptance criteria

- [ ] The review covers the sheet contract module, notation module, formula healing module, write planning module, and Google adapters.
- [ ] Any shallow module that fails the deletion test is removed or deepened.
- [ ] Any adapter seam with only one adapter is justified or collapsed.
- [ ] Backend tests still verify behavior through public interfaces.
- [ ] Backend integration validation still passes after cleanup.
- [ ] No GUI work starts before this slice is complete.
- [ ] All changes are committed after tests pass.

### Blocked by

- Slice 15: Backend Integration Validation Gate

### User stories covered

- User instruction: all backend should be complete before GUI begins.
- User instruction: include explicit test, validation, and cleanup slices using `improve-codebase-architecture`.

## Slice 17: App Store Readiness Validation

### Type

`AFK`

### What to build

Validate that the selected Flutter/Dart project setup does not block future submission to iOS App Store, macOS App Store, or Android Play Store. This is not store submission work; it is a planning and configuration sanity check.

### Acceptance criteria

- [ ] The project can build or is structurally prepared for iOS app packaging.
- [ ] The project can build or is structurally prepared for macOS `.app` packaging.
- [ ] The project can build or is structurally prepared for Android app packaging.
- [ ] Known future needs are documented: bundle identifiers, signing, entitlements, OAuth consent/configuration, privacy disclosures, and store metadata.
- [ ] No framework choice or package dependency is identified as blocking future iOS, macOS, or Android store submission.
- [ ] Any discovered blocker is recorded as an issue before GUI work proceeds.
- [ ] All changes are committed after validation.

### Blocked by

- Slice 0: Standard Flutter/Dart Scaffold and Git Repo

### User stories covered

- User requirement: easy future submission to app stores.
- PRD out-of-scope decision: no actual store distribution in MVP.

## Slice 18: GUI Shell: Spreadsheet Selection and Backend Validation

### Type

`HITL`

### What to build

Build the first GUI slice after backend completion. The app shell must support Google sign-in or the selected development auth path, spreadsheet selection, backend validation, and display of blocking schema/healing issues. It should use the completed backend modules rather than reimplementing sheet logic in UI code.

### Acceptance criteria

- [ ] The GUI can start on macOS during development.
- [ ] The user can connect or select a spreadsheet through the available development auth path.
- [ ] The GUI runs backend validation on the selected spreadsheet.
- [ ] Blocking schema errors are shown clearly.
- [ ] Healable formula issues are shown clearly.
- [ ] The GUI does not implement duplicate parser, validator, or healing logic.
- [ ] All backend tests continue to pass.
- [ ] All changes are committed after tests pass.

### Blocked by

- Slice 16: Architecture Review: Backend Completion Gate

### User stories covered

- PRD user stories 1, 2, 3, 4, 5, 6, 7.

## Slice 19: GUI Workout and History Block Selection

### Type

`AFK`

### What to build

Build the GUI flow for selecting a workout and selecting or creating a visible history block. The overview should show primary rows only, preserve sheet order, nest backups, and show per-slot logged set counts.

### Acceptance criteria

- [ ] The user can select a workout from human-readable workout names.
- [ ] Blank workout values appear under the default workout.
- [ ] The user can select an existing visible history block.
- [ ] The user can create a new history block.
- [ ] The overview shows primary exercises only.
- [ ] Backups are available as nested alternatives.
- [ ] The overview preserves active sheet order.
- [ ] Per-slot set counts include primary and backup row data.
- [ ] All backend tests continue to pass.
- [ ] All changes are committed after tests pass.

### Blocked by

- Slice 18: GUI Shell: Spreadsheet Selection and Backend Validation

### User stories covered

- PRD user stories 22, 23, 24, 25, 26, 27, 29, 30, 35, 46, 60.

## Slice 20: GUI Exercise Logging Screen

### Type

`AFK`

### What to build

Build the exercise logging screen. It should display read-only exercise context, show current/newest sets first, offer a primary/backup selector with primary selected by default, provide structured set entry fields, preserve raw text when needed, and write through backend planning modules.

### Acceptance criteria

- [ ] Opening a primary slot shows the primary row selected by default.
- [ ] The user can switch to a backup row from a selector.
- [ ] Switching rows changes the row-local history and next set target.
- [ ] Notes, targets, and rest are shown read-only.
- [ ] Current/newest set rows appear above prior sets and history.
- [ ] Structured fields can log a supported set notation value.
- [ ] Unparseable cells can be viewed and edited as raw text.
- [ ] The user can edit and clear set cells.
- [ ] Saving a set auto-advances to the next empty set for that selected row.
- [ ] All backend tests continue to pass.
- [ ] All changes are committed after tests pass.

### Blocked by

- Slice 19: GUI Workout and History Block Selection

### User stories covered

- PRD user stories 36, 37, 39, 40, 41, 42, 43, 44, 45, 47, 48, 49, 50, 51, 52, 53, 54, 55, 56, 57.

## Slice 21: GUI End-to-End Logging Validation

### Type

`HITL`

### What to build

Validate the full app flow on macOS as a local `.app` or development-run equivalent, using the live development spreadsheet. This validates GUI plus backend together and confirms the MVP workflow is usable before final cleanup.

### Acceptance criteria

- [ ] The app runs on macOS.
- [ ] The user can complete any required Google login step.
- [ ] The user can select the development spreadsheet.
- [ ] The app validates the sheet and handles any healing workflow.
- [ ] The user can select a workout and history block.
- [ ] The user can log a primary set and see it in the sheet.
- [ ] The user can log a backup set and see it in the sheet.
- [ ] The user can edit and clear a set and see the sheet update.
- [ ] The development sheet can be reset/cleaned after validation.
- [ ] All backend and UI tests pass.
- [ ] All changes are committed after tests pass.

### Blocked by

- Slice 20: GUI Exercise Logging Screen

### User stories covered

- Full MVP user flow from the PRD.

## Slice 22: Final Architecture and Test Cleanup

### Type

`AFK`

### What to build

Run the final explicit architecture and test cleanup slice using the `improve-codebase-architecture` skill. Remove accidental shallow modules, tighten public interfaces, improve test locality, and ensure the implementation remains easy for future agents to navigate.

### Acceptance criteria

- [ ] The review covers backend modules, Google adapters, and GUI-facing modules.
- [ ] Tests are checked for behavior focus and implementation coupling.
- [ ] Shallow modules are removed or deepened where doing so improves locality and leverage.
- [ ] Public interfaces are documented where callers need invariants or ordering rules.
- [ ] The development sheet cleanup harness still works.
- [ ] The macOS app still runs after cleanup.
- [ ] All tests pass.
- [ ] Final cleanup changes are committed.

### Blocked by

- Slice 21: GUI End-to-End Logging Validation

### User stories covered

- User instruction: include explicit test, validation, and cleanup slices using `improve-codebase-architecture`.
- PRD testing decisions.
