# Architecture Cleanup Implementation Plan

- [x] Slice 0: Create a Shared Test Validation Harness
- [x] Slice 1: Retire the Dual Set Parsing Interface
- [x] Slice 2: Deepen the Exercise Logging Flow Module
- [x] Slice 3: Split Google Validation and Authorization Internals
- [x] Slice 4: Separate Development Reset Fixtures From Reset Writing
- [x] Slice 5: Final Architecture and Test Cleanup Gate

## Slice 0: Create a Shared Test Validation Harness

### Type

`AFK`

### What to build

Create a test-only validation Adapter that can drive controller and GUI-flow tests through the same public validation Interface used by the app. The harness should own the repeated behavior of parsing representative sheet rows, applying write-plan previews, and reparsing updated rows after simulated writes.

This slice is first because it makes later refactors safer: GUI logging-flow and controller tests should stop carrying their own sheet mutation Implementation before the production Modules are reshaped.

### Acceptance criteria

- [x] Controller tests and widget tests use a shared test validation Adapter instead of duplicating sheet parsing, write-plan preview, and reparse behavior.
- [x] The test Adapter still crosses the public validation Interface used by the GUI and controller.
- [x] Existing controller behavior remains covered: validation, workout selection, history selection, write-plan application, and error reporting.
- [x] Existing GUI smoke behavior remains covered: render, select workout/history, open logging screen, save a structured set, and account menu behavior.
- [x] Duplicate fake validation code is removed from individual test files.
- [x] Relevant controller and widget tests pass.

### Blocked by

None - can start immediately.

### User stories covered

- Architecture finding: duplicated fake validation Adapter behavior in controller and widget tests.
- Project testing guidance: tests should exercise public Interfaces and keep setup local to the right Module.

## Slice 1: Retire the Dual Set Parsing Interface

### Type

`AFK`

### What to build

Remove the need for callers to understand both the older fixed set-notation model and the newer row-local literal log-format model. Row history should expose one logging entry representation for app use: formatted values when the row-local `Log Format` parses the cell, or raw text when it does not. Any legacy parser that remains should be internal and justified by a specific compatibility need.

### Acceptance criteria

- [x] Row-history read models expose a single app-facing entry representation for formatted-vs-raw log cells.
- [x] GUI code no longer depends on the older fixed set-notation Interface.
- [x] Sheet-contract tests continue to cover row-local log-format parsing for weighted, bodyweight, timed, height-based, blank-field, and raw cells.
- [x] Public exports no longer expose the older set-notation Module unless a retained compatibility reason is documented.
- [x] Obsolete set-notation tests are removed or moved to the retained internal compatibility surface.
- [x] Relevant log-format, sheet-contract, controller, and widget tests pass.

### Blocked by

- Slice 0: Create a Shared Test Validation Harness

### User stories covered

- Architecture finding: `RowHistoryEntry` exposes both `SetNotation` and `LogEntry`.
- Literal log format plan: row-local log formats are the active sheet-contract Interface.

## Slice 2: Deepen the Exercise Logging Flow Module

### Type

`AFK`

### What to build

Deepen the GUI exercise logging flow so the shell primarily renders logging state and dispatches user intent. Controller synchronization, field-controller lifecycle, raw-vs-formatted branching, row switching, and write-plan creation should be concentrated behind a smaller logging-flow Module rather than spread across the widget Implementation.

The existing sheet-contract Seam should remain authoritative for parsing history, rendering structured entries, and planning writes. The GUI must not duplicate row-local log-format or write-planning rules.

### Acceptance criteria

- [x] The exercise logging screen renders from a logging-flow view model or equivalent deep Module instead of assembling all logging behavior directly in the widget state.
- [x] Structured new-set save, structured edit, raw edit, clear, and backup-row switching still use backend write plans.
- [x] Field-controller lifecycle is localized and does not leak sheet-contract details across unrelated widgets.
- [x] Widget tests stay smoke-level and verify visible behavior, not backend parsing choreography.
- [x] Existing uncommitted segmented-button styling work is preserved and not reverted.
- [x] Relevant widget, controller, and sheet-contract tests pass.

### Blocked by

- Slice 1: Retire the Dual Set Parsing Interface

### User stories covered

- Architecture finding: `_ExerciseLoggingScreenState` is too wide and owns too much logging behavior.
- MVP PRD user stories 42, 43, 44, 47, 48, 51, 52, 53, 55, 56, 57.

## Slice 3: Split Google Validation and Authorization Internals

### Type

`AFK`

### What to build

Keep the app-facing spreadsheet validation Seam stable while separating its internal responsibilities. Validation orchestration, Google account/session state, authorization header creation, and Google read/write Adapter wiring should become distinct internal Modules with focused tests.

This is an internal cleanup: user-visible spreadsheet validation, sign-in restoration, account switching, history block creation, and write-plan application should behave the same.

### Acceptance criteria

- [x] The public validation Interface used by the controller remains stable or changes only through a narrow compatibility update.
- [x] Google account/session behavior is localized behind a focused internal Module.
- [x] Authorization header wrapping is localized behind a focused internal Module or Adapter.
- [x] Google read/write Adapter wiring is separated from validation flow orchestration.
- [x] Existing validation tests are preserved or narrowed to the correct internal seams.
- [x] Controller and spreadsheet-validation tests pass.

### Blocked by

- Slice 0: Create a Shared Test Validation Harness

### User stories covered

- Architecture finding: validation, native Google sign-in, authorization, and Adapter wiring share one Implementation.
- MVP PRD user stories 1, 2, 3, 4, 5, 7, 30, 53.

## Slice 4: Separate Development Reset Fixtures From Reset Writing

### Type

`AFK`

### What to build

Separate deterministic development sheet fixture construction from Google Sheets reset writing. The reset harness should keep a small public Interface, while fixture data, reset safety checks, reset request planning, and Google request execution have clearer Locality.

This should preserve the existing live-development-sheet safety rule: only the known development spreadsheet may be reset by default.

### Acceptance criteria

- [x] Development fixture data lives in a fixture-focused Module rather than inside the Google reset writer Implementation.
- [x] Reset request planning remains locally testable without live Google access.
- [x] Typed-cell reset behavior remains covered: formulas as formulas, non-empty literals as strings, empty cells blank, and reset range formatted as text.
- [x] Reset safety still rejects unrelated spreadsheet IDs by default.
- [x] Fixture tests still verify representative workouts, backups, direct formulas, and representative `Log Format` values.
- [x] Relevant fixture and Google reset tests pass.

### Blocked by

- Slice 0: Create a Shared Test Validation Harness

### User stories covered

- Architecture finding: reset fixture data and Google rewrite planning share one large Module.
- Project Google Sheet integration guidance: integration tests that write to the development sheet must reset or clean up after themselves.

## Slice 5: Final Architecture and Test Cleanup Gate

### Type

`AFK`

### What to build

Run a final cleanup gate after the architecture slices land. Re-run the architecture review against the changed codebase, remove duplicate tests left behind by refactoring, and verify that the remaining Modules are deep enough for the next feature work.

### Acceptance criteria

- [x] Re-run an `improve-codebase-architecture` review focused on GUI logging flow, sheet-contract read models, validation/auth internals, reset fixtures, and test harnesses.
- [x] Remove or consolidate duplicate tests introduced during cleanup.
- [x] Confirm widget tests remain GUI smoke tests rather than backend behavior tests.
- [x] Confirm backend behavior tests still cross public sheet-contract and log-format Interfaces.
- [x] Run the default local test suite.
- [x] Document any remaining low-priority architecture findings for later work.
- [x] Commit the final cleanup separately from implementation slices.

### Architecture review notes

- GUI logging flow: `ExerciseLoggingFlow` is the deep Module behind the logging screen; it owns row switching, field-controller lifecycle, raw-vs-formatted entry editing, and backend write-plan creation. The view model now returns an immutable logged-entry snapshot so widget code cannot mutate flow state accidentally.
- Sheet-contract read models: `ExerciseLoggingContext`, `WorkoutOverview`, and row-history entries continue to expose one app-facing log entry representation, with parsing and raw preservation behind the public sheet-contract Interface.
- Validation/auth internals: spreadsheet validation orchestration, Google account/session state, authorization header wrapping, and Google Sheets Adapter wiring are separated behind focused Modules.
- Reset fixtures: deterministic fixture construction is separate from reset planning and Google request execution; reset planning remains locally testable without live Google access.
- Test harnesses: controller and widget tests use `TestSpreadsheetValidationService` through the public validation Interface. Widget coverage is now smoke-level for visible GUI flow, while row-local parsing and write planning stay in sheet-contract/log-format/logging-flow tests.
- Remaining low-priority finding: the local workbook fixture and the development reset fixture still duplicate representative workout-library content. Consolidating that fixture source would improve Locality, but it is outside this cleanup gate because both fixtures currently serve different Interfaces and the duplication is stable test data.

### Blocked by

- Slice 2: Deepen the Exercise Logging Flow Module
- Slice 3: Split Google Validation and Authorization Internals
- Slice 4: Separate Development Reset Fixtures From Reset Writing

### User stories covered

- Architecture review process requested by the user.
- Project testing guidance in `AGENTS.md`.
