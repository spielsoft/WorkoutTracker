# Google Sheets Consolidation And Exercise Delete Issues

This is the vertical-slice plan for consolidating Google Sheets access,
centralizing authenticated Google client lifecycle, and adding delete exercise
from the workout exercise action menu. The source PRD is
`ISSUES_PRD.md`.

Work through slices in dependency order. Use TDD for implementation slices:
write or update one failing behavior test through a public interface, implement
the smallest fix, run targeted tests, then update this checklist only after the
slice is complete. Preserve unrelated worktree changes.

## Checklist

- [x] Slice 1: Create A Generic Sheets Workbook Operation Port
- [x] Slice 2: Route WorkoutTracker Sheet Reads, Writes, And Initialization Through The Workbook Port
- [x] Slice 3: Centralize Scoped Google Client Lifecycle
- [x] Slice 4: Plan Primary Workout Exercise Deletion With Attached Backups
- [x] Slice 5: Apply Workout Exercise Deletion Through Services And Sheets Row Deletes
- [ ] Slice 6: Add Delete Exercise To The Primary Exercise Menu With Confirmation
- [ ] Slice 7: Clean Up Refactor And Feature Tests

## Slice 1: Create A Generic Sheets Workbook Operation Port

### Type

`AFK`

### What to build

Introduce a generic Sheets workbook interface that represents sheet metadata,
grid reads, cell writes, cell clears, row and column insertions, row and column
deletions, and row and column moves behind one app-owned interface. The Google
adapter should hide Google API request construction and index conversion.

This slice is the foundation for the delete feature, but it should be useful on
its own: callers can express delete rows and delete columns without knowing
Google request details.

### Acceptance criteria

- [x] A public app-owned workbook operation interface can represent row
      insertion, row deletion, row move, column insertion, column deletion,
      column move, cell write, and cell clear.
- [x] The interface uses one-based sheet coordinates at the app boundary.
- [x] The Google adapter owns conversion to Google zero-based ranges and batch
      requests.
- [x] Empty operation batches are no-ops.
- [x] Operations can target a sheet by resolved sheet identity rather than
      requiring callers to construct raw Google request objects.
- [x] Focused adapter tests cover row/column delete and move request intent
      without Google credentials.
- [x] Relevant targeted Flutter tests pass.

### Blocked by

None - can start immediately.

### User stories covered

- Generic row and column delete operations exist in the Sheets library.
- Generic row and column move operations exist in the Sheets library.
- Future sheet features do not duplicate Google request construction.

## Slice 2: Route WorkoutTracker Sheet Reads, Writes, And Initialization Through The Workbook Port

### Type

`AFK`

### What to build

Migrate existing WorkoutTracker-specific sheet reads, write-plan application,
and workbook initialization to use the generic Sheets workbook port. This slice
should preserve existing user behavior while moving request construction and
sheet identity lookup behind the deeper interface.

The goal is consolidation, not product change. Existing validation, exercise
authoring, formula healing, history block creation, and workbook reset behavior
should continue to behave the same after the migration.

### Acceptance criteria

- [x] Active-sheet and Exercises reads still parse through the existing public
      sheet-contract input path.
- [x] Existing active-sheet write plans still apply history column insertions,
      row insertions, cell writes, and clears correctly.
- [x] Existing Exercises write plans still apply row appends, row updates, and
      active-sheet formula updates correctly.
- [x] Workbook initialization no longer owns broad duplicate raw Google Sheets
      request construction for operations covered by the workbook port.
- [x] Existing adapter and workbook initialization tests are preserved or
      rewritten around the deeper public interface.
- [x] Relevant targeted Flutter tests pass.

### Blocked by

- Slice 1: Create A Generic Sheets Workbook Operation Port

### User stories covered

- Workbook initialization uses the same generic Sheets module as normal writes.
- Request behavior is localized.
- Existing sheet-contract behavior is preserved.

## Slice 3: Centralize Scoped Google Client Lifecycle

### Type

`AFK`

### What to build

Introduce a small authenticated Google access module that owns requesting
scoped authorization, creating authenticated clients or Google API objects,
running an action, and closing resources. Replace repeated call-site lifecycle
plumbing in validation, selection/creation, and live integration wiring where it
can be done without broad behavior changes.

This slice should keep Picker/account responsibilities separate from generic
Sheets workbook operations. It only centralizes the lifecycle that is currently
repeated across Google-facing callers.

### Acceptance criteria

- [x] A public app-owned helper or interface runs scoped Google actions with
      authenticated resources and guaranteed cleanup.
- [x] Spreadsheet validation and write services use the centralized lifecycle.
- [x] Spreadsheet creation or selected-spreadsheet resolution uses the
      centralized lifecycle where practical.
- [x] Tests verify requested scopes and cleanup through fakes, without
      simulating third-party Google behavior as product behavior.
- [x] Existing Google account and Picker behavior remains unchanged.
- [x] Relevant targeted Flutter tests pass.

### Blocked by

None - can start immediately.

### User stories covered

- Google API authorization and client lifecycle live in one place.
- Picker, validation, creation, and integration wiring do not reinvent the same
  lifecycle.

## Slice 4: Plan Primary Workout Exercise Deletion With Attached Backups

### Type

`AFK`

### What to build

Add sheet-contract behavior for planning deletion of a primary workout
exercise placement from the active sheet. The plan should delete the selected
primary row and every backup row attached to it by the parsed sheet model. It
must leave unrelated primary rows, unrelated backups, history blocks, and
canonical Exercises rows intact.

The plan should include expectations that reject the delete if the target row
or attached backup group no longer matches the parsed sheet used to create the
plan.

### Acceptance criteria

- [x] Planning delete for a primary workout slot produces row deletion intent
      for the primary row and its attached backups.
- [x] The planned delete does not include canonical Exercises rows.
- [x] The planned delete leaves unrelated workout rows and backups untouched.
- [x] The planned delete preserves history block columns and unrelated history.
- [x] The plan rejects if the primary row identity, workout, or backup state
      changed before apply.
- [x] The plan rejects if the attached backup group changed before apply.
- [x] Public sheet-contract tests cover no-backup, one-backup, and
      multiple-backup cases.
- [x] Relevant targeted Flutter tests pass.

### Blocked by

None - can start immediately.

### User stories covered

- Deleting a primary exercise also removes its backup exercises.
- Deleting one primary leaves unrelated workout rows untouched.
- Canonical exercise definitions remain available.
- Stale delete plans do not delete the wrong rows.

## Slice 5: Apply Workout Exercise Deletion Through Services And Sheets Row Deletes

### Type

`AFK`

### What to build

Expose workout exercise deletion through the app's service/controller path.
The service should reread the spreadsheet, validate the delete plan against the
fresh parsed sheet, apply row deletions through the generic Sheets workbook
port, and return a refreshed report.

This slice provides a complete non-visual behavior path for deleting a workout
exercise placement and associated backups.

### Acceptance criteria

- [x] The app service/controller exposes a public delete-workout-exercise
      operation using a primary workout slot or sheet row selected from the
      current parsed report.
- [x] The operation rereads the sheet before applying delete.
- [x] The operation returns write rejections instead of deleting when
      expectations fail.
- [x] A successful delete applies structural row delete operations through the
      generic Sheets workbook port.
- [x] A successful delete returns a refreshed report without the primary or
      attached backups.
- [x] The selected workout and history block remain usable after refresh when
      they still exist.
- [x] Targeted service/controller tests cover success and stale rejection.
- [x] Relevant targeted Flutter tests pass.

### Blocked by

- Slice 1: Create A Generic Sheets Workbook Operation Port
- Slice 2: Route WorkoutTracker Sheet Reads, Writes, And Initialization
  Through The Workbook Port
- Slice 4: Plan Primary Workout Exercise Deletion With Attached Backups

### User stories covered

- The workout overview refreshes after delete.
- Manual sheet edits cannot cause the wrong rows to be deleted.
- Deleting a workout placement does not delete canonical exercise definitions.

## Slice 6: Add Delete Exercise To The Primary Exercise Menu With Confirmation

### Type

`AFK`

### What to build

Add Delete exercise to the existing primary exercise action menu that is opened
from the visible overflow button, right-click, and long-press. Selecting Delete
exercise must show a confirmation dialog before any write runs. Confirming the
dialog should call the service/controller delete path and refresh the workout
overview; cancelling should leave the sheet and app state unchanged.

Keep this slice focused on the existing workout overview menu. Do not redesign
the exercise manager or add canonical exercise deletion.

### Acceptance criteria

- [ ] The primary exercise action menu shows Add backup exercise and Delete
      exercise.
- [ ] The menu remains reachable from the visible overflow button.
- [ ] The menu remains reachable from right-click on desktop.
- [ ] The menu remains reachable from long-press on touch.
- [ ] Selecting Delete exercise opens a confirmation dialog before any delete
      operation runs.
- [ ] The confirmation dialog names the exercise and warns that associated
      backups and logged history will be deleted.
- [ ] Cancelling the dialog does not call the delete path and leaves the
      visible overview unchanged.
- [ ] Confirming the dialog calls the delete path and removes the primary plus
      attached backups after refresh.
- [ ] A failed or rejected delete leaves a visible error and does not hide the
      target row from the last confirmed report.
- [ ] Focused widget tests cover menu contents, cancel, and confirm behavior.
- [ ] Relevant targeted Flutter tests pass.

### Blocked by

- Slice 5: Apply Workout Exercise Deletion Through Services And Sheets Row
  Deletes

### User stories covered

- The action menu includes Delete exercise.
- The user must confirm an irreversible delete.
- Associated backups and history are explicitly called out.
- The workout overview updates after successful delete.

## Slice 7: Clean Up Refactor And Feature Tests

### Type

`AFK`

### What to build

Use the test-cleanup skill to review tests added during this refactor and
feature work. Preserve durable behavior tests and remove or rewrite tests that
only pin temporary TDD scaffolding, private helper structure, or incidental
widget composition.

This slice should leave a small, high-signal safety net around the generic
Sheets workbook port, authenticated Google lifecycle, delete planning,
service/controller application, and delete confirmation UI.

### Acceptance criteria

- [ ] Tests assert observable behavior through public sheet-contract, adapter,
      service, controller, or widget interfaces.
- [ ] Tests do not over-constrain private helper names, internal batching
      order beyond externally meaningful ordering, or incidental widget tree
      shape.
- [ ] Durable tests still cover row/column delete and move operations.
- [ ] Durable tests still cover primary-plus-backups delete planning and stale
      rejection.
- [ ] Durable tests still cover confirmation-required UI behavior.
- [ ] Relevant targeted Flutter tests pass.
- [ ] Any architecture guard or review step requested by the active slice is
      run and findings are resolved or documented.

### Blocked by

- Slice 6: Add Delete Exercise To The Primary Exercise Menu With Confirmation

### User stories covered

- Future refactors keep the generic Sheets and delete behavior reliable.
- The test suite remains maintainable after TDD.
