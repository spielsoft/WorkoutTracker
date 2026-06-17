# Code Review Loop Issues

- [x] Slice 0: Compact Spreadsheet Validation Write Interface
- [x] Slice 1: Use Read-Only Scope For Spreadsheet Validation
- [x] Slice 2: Hide Exercise Logging Flow From Public App Exports
- [x] Slice 3: Decompose Workout Tracker Shell File
- [x] Slice 4: Keep Account Switching Scope-Free
- [x] Slice 5: Add Controller Setup Read Model

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

- [x] Account switching requests no scopes from the account menu.
- [x] Validation still requests read-only Sheets scope.
- [x] Write operations still request write-capable Sheets scope.
- [x] Relevant widget and spreadsheet-validation tests pass.

### Blocked by

None - can start immediately.

### User stories covered

- Thermo-nuclear review finding: scope policy leaked into account menu.

## Slice 5: Add Controller Setup Read Model

### Type

`HITL`

### What to build

Add a compact controller-owned workout setup/read model for valid workout/history selection repair, current overview, per-workout progress counts, and safe logging target rows. Do not build a broad controller-level app view model; keep navigation state, text controllers, account restore, spreadsheet text persistence, and `ExerciseLoggingFlow` in the shell or their existing modules.

### Acceptance criteria

- [x] Decision recorded in this issue plan as a setup/read-model-only cleanup.
- [x] Controller tests cover setup selection repair, progress counts, overview, and safe logging targets through the controller public Interface.
- [x] Widget-side fallback and progress derivation removed from `workout_tracker_shell_workout.dart`.

### Blocked by

- Slice 0: Compact Spreadsheet Validation Write Interface
- Slice 3: Decompose Workout Tracker Shell File

### User stories covered

- Architecture review finding: GUI state policy split between controller and widget tree.

### Review note

Implemented the narrow accepted direction as a controller-owned workout setup read model only, not a broad app view model. The duplicate setup-preview and exercise-picker entry paths are intentionally preserved for now. The user clarified that selecting an exercise from setup should jump forward to the same logging destination as selecting from the exercise-picker screen.
