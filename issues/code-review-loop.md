# Code Review Loop Issues

- [x] Slice 0: Compact Spreadsheet Validation Write Interface
- [x] Slice 1: Use Read-Only Scope For Spreadsheet Validation
- [x] Slice 2: Hide Exercise Logging Flow From Public App Exports
- [x] Slice 3: Decompose Workout Tracker Shell File
- [ ] Slice 4: Keep Account Switching Scope-Free
- [ ] Slice 5: Evaluate Controller-Level GUI View Model

## Slice 0: Compact Spreadsheet Validation Write Interface

### Type

`AFK`

### What to build

Remove the shallow history-block write method from the spreadsheet validation Interface. The controller should plan a new history block through the parsed active sheet and apply that write plan through the existing generic write-plan path.

### Acceptance criteria

- [x] `SpreadsheetValidationService` no longer exposes a dedicated create-history-block method.
- [x] Creating a history block still updates the selected history block and active sheet report.
- [x] Tests cover history block creation through the controller public Interface.
- [x] Relevant controller, validation-service, and widget tests pass.

### Blocked by

None - can start immediately.

### User stories covered

- Architecture review finding: shallow history-block write Interface.
- MVP PRD stories 29-34.

## Slice 1: Use Read-Only Scope For Spreadsheet Validation

### Type

`AFK`

### What to build

Use the read-only Google Sheets scope for validation-only spreadsheet loading, while keeping write scope for operations that apply write plans.

### Acceptance criteria

- [x] Validation requests read-only spreadsheet scope.
- [x] History-block creation and write-plan application still request write-capable spreadsheet scope.
- [x] Spreadsheet validation tests pass.

### Blocked by

None - can start immediately.

### User stories covered

- Architecture review finding: validation/auth seam is wider than needed.
- MVP PRD stories 1, 2, 5.

## Slice 2: Hide Exercise Logging Flow From Public App Exports

### Type

`AFK`

### What to build

Stop exporting the internal exercise logging flow Module from the public app barrel unless an external caller depends on it. Keep the logging screen behavior unchanged.

### Acceptance criteria

- [x] Public app exports no longer expose `ExerciseLoggingFlow`.
- [x] Internal app code and focused logging-flow tests still compile.
- [x] Relevant logging-flow and widget tests pass.

### Blocked by

None - can start immediately.

### User stories covered

- Architecture review finding: internal logging-flow Module leaks through public app exports.

## Slice 3: Decompose Workout Tracker Shell File

### Type

`AFK`

### What to build

Split the oversized workout tracker shell library into focused GUI part files without changing behavior. Keep app shell orchestration, account menu, workout setup/overview, exercise logging, and validation panels easier to scan independently.

### Acceptance criteria

- [x] `workout_tracker_shell.dart` drops back below 1000 lines.
- [x] Behavior stays unchanged.
- [x] Widget tests pass.
- [x] Focused analyzer on touched GUI files passes.

### Blocked by

None - can start immediately.

### User stories covered

- Thermo-nuclear review finding: GUI shell file crossed 1000 lines and now owns too many responsibilities.

## Slice 4: Keep Account Switching Scope-Free

### Type

`AFK`

### What to build

Make the generic account switch UI avoid requesting Google Sheets scopes. Validation and write operations should request their own scopes at the point of use.

### Acceptance criteria

- [ ] Account switching requests no scopes from the account menu.
- [ ] Validation still requests read-only Sheets scope.
- [ ] Write operations still request write-capable Sheets scope.
- [ ] Relevant widget and spreadsheet-validation tests pass.

### Blocked by

None - can start immediately.

### User stories covered

- Thermo-nuclear review finding: scope policy leaked into account menu.

## Slice 5: Evaluate Controller-Level GUI View Model

### Type

`HITL`

### What to build

Evaluate whether a controller-level app view model should own valid workout/history selection repair, legal screen state, current overview, and per-workout progress counts. Implement only if it demonstrably removes widget-side fallback/progress logic without inflating the Interface.

### Acceptance criteria

- [ ] Decision recorded in this issue plan or implemented as a narrow cleanup slice.
- [ ] If implemented, controller tests cover the view model through the controller public Interface.
- [ ] If deferred, the reason is documented with the remaining risk.

### Blocked by

- Slice 0: Compact Spreadsheet Validation Write Interface
- Slice 3: Decompose Workout Tracker Shell File

### User stories covered

- Architecture review finding: GUI state policy split between controller and widget tree.

### Review note

The duplicate setup-preview and exercise-picker entry paths are intentionally preserved for now. The user clarified that selecting an exercise from setup should jump forward to the same logging destination as selecting from the exercise-picker screen.
