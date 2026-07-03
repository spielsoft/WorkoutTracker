# Google Sheets Consolidation And Exercise Delete PRD

## Problem Statement

WorkoutTracker relies on a user-owned Google Sheet as the source of truth, but
the Google-facing implementation is split across account authorization, Picker
selection, workbook initialization, sheet reads, sheet writes, and
WorkoutTracker-specific validation services. The current shape is workable, but
it makes upcoming spreadsheet operations harder than they should be. In
particular, generic row and column operations such as delete and move are not
available through one reusable sheet interface.

The next product feature exposes that gap directly. A user needs to delete a
primary exercise from a workout from the same tap-and-hold or right-click menu
that currently only offers Add backup. Deleting that primary exercise must also
delete all of its associated backup rows and all logged history on those rows.
Because this permanently removes sheet rows and history, the app must require
an explicit confirmation before applying the delete.

The desired refactor is not a broad rewrite. The goal is to deepen the existing
Google seams so Google account/picker concerns and generic Sheets workbook
operations live in one or two clear locations, while WorkoutTracker domain
behavior remains in the sheet-contract and controller/service modules.

## Solution

Create a deeper generic Google Sheets workbook module that owns low-level sheet
operations: sheet metadata, grid reads, cell writes, cell clears, row and column
insertions, row and column deletions, and row and column moves. Existing
WorkoutTracker-specific read/write adapters and workbook initialization should
use this generic module instead of each owning raw Google request construction.

Create a small authenticated Google access module that owns the repeated
pattern of requesting scoped authorization, creating authenticated clients or
Google API objects, and closing resources. Picker and account session behavior
should remain conceptually separate from generic Sheets workbook operations, but
callers should no longer need to recreate the same authorization/client
lifecycle by hand.

After those seams exist, add a domain delete plan for workout exercise rows. The
delete plan should remove a primary active-sheet row and every backup row
attached to it by the current sheet contract. It must preserve the rule that the
Google Sheet is the source of truth, and it must not delete the canonical
exercise definition from the Exercises tab.

Expose the delete plan through the existing workout overview action menu. The
primary exercise menu should contain Add backup exercise and Delete exercise.
Selecting Delete exercise should show a confirmation dialog that names the
exercise, explains that associated backups and logged history will be deleted,
and requires the user to confirm before any sheet write occurs. After a
successful delete, the workout overview should refresh from the sheet and no
longer show the deleted primary or its backups.

## User Stories

1. As a lifter, I want the exercise row action menu to include Delete exercise,
   so that I can remove an exercise I no longer want in a workout.
2. As a lifter, I want deleting a primary exercise to also remove its backup
   exercises, so that the workout does not keep orphaned backup rows.
3. As a lifter, I want the app to warn me before deleting an exercise row and
   history, so that I do not accidentally lose workout data.
4. As a lifter, I want the confirmation message to mention associated backups
   and history, so that I understand the consequence before confirming.
5. As a lifter, I want cancelling the confirmation dialog to leave the sheet
   unchanged, so that accidental menu taps are harmless.
6. As a lifter, I want the workout overview to refresh after delete, so that I
   can immediately see the remaining exercises.
7. As a lifter, I want deleting one primary exercise to leave unrelated primary
   exercises and their backups untouched, so that the rest of my workout remains
   intact.
8. As a lifter, I want canonical exercise definitions to remain in the exercise
   library after deleting a workout placement, so that I can add the exercise to
   another workout later.
9. As a maintainer, I want generic row and column delete operations in the
   Sheets library, so that future sheet features do not duplicate Google request
   construction.
10. As a maintainer, I want generic row and column move operations in the Sheets
    library, so that reorder and future structure features have a single
    implementation path.
11. As a maintainer, I want workbook initialization to use the same generic
    Sheets module as normal writes, so that structure and value request behavior
    is localized.
12. As a maintainer, I want Google API authorization/client lifecycle code in
    one place, so that Picker, validation, creation, and integration tests do
    not each reinvent it.
13. As a maintainer, I want the delete plan tested through public sheet-contract
    behavior, so that backup attachment rules are protected without testing
    private helpers.
14. As a maintainer, I want the service to reread and reject stale delete plans
    when sheet order changes, so that manual sheet edits cannot delete the wrong
    rows.
15. As a maintainer, I want widget tests for the menu and confirmation flow, so
    that the irreversible UI path stays reachable and guarded.
16. As a maintainer, I want temporary TDD scaffolding cleaned up at the end, so
    that the suite remains behavior-focused after the refactor.

## Implementation Decisions

- Keep two Google-facing locations rather than one large module: one for
  Google account, authorization, Picker, and authenticated client lifecycle;
  one for generic Google Sheets workbook operations.
- The generic Sheets workbook interface should be deeper than the current
  plan-specific write client. It should expose a workbook operation vocabulary
  that can represent cell writes, cell clears, row and column insertions, row
  and column deletions, and row and column moves.
- Row and column operations should use one-based sheet coordinates at the app
  interface and hide Google API zero-based index conversion inside the Google
  adapter.
- Deletion and movement should support rows and columns, even though the first
  product consumer is deleting active-sheet rows.
- Existing WorkoutTracker-specific plan application should translate domain
  write plans into generic workbook operations rather than building Google
  request details directly.
- Workbook initialization should reuse generic workbook operations where
  practical. Any remaining initialization-only formatting operations should live
  near the generic Sheets adapter, not in app workflow code.
- The authenticated Google access module should own scoped authorization,
  authenticated HTTP client creation, Sheets or Drive API construction, and
  cleanup. It should not own WorkoutTracker domain parsing or write planning.
- The delete feature deletes workout placements from the active sheet only. It
  does not delete canonical exercise rows from Exercises.
- The delete plan removes the selected primary row plus the backup rows that are
  attached to that primary by the current parsed sheet model.
- The delete plan should carry enough expectations to reject the write if the
  target row identity, workout, backup state, or attached backup rows no longer
  match the parsed sheet used to plan the delete.
- The UI should add Delete exercise to the existing primary exercise action
  menu used by overflow, right-click, and long-press actions.
- Delete exercise must show a confirmation dialog before any controller or
  service write method runs.
- The confirmation dialog should use clear, direct language: deleting removes
  the exercise from the workout, deletes associated backups, and deletes logged
  history for those rows.
- The delete operation should use the existing validation/report refresh
  behavior after write so the visible overview reflects the sheet source of
  truth.
- Keep the refactor incremental and test-driven. Each implementation slice
  should leave the app compiling and the relevant targeted tests green.

## Testing Decisions

- Use TDD for implementation slices. Start each behavior change with a failing
  test through a public sheet-contract, adapter, service, controller, or widget
  interface.
- Add generic Sheets workbook tests that verify row/column delete and move
  operations are represented correctly through the app-owned interface. These
  tests should not claim to prove Google behavior.
- Preserve or adapt existing read/write adapter tests so they verify the app's
  request intent without requiring Google credentials.
- Add sheet-contract tests showing that deleting a primary exercise plans
  removal of the primary row and attached backups, leaves unrelated rows alone,
  and rejects stale row/order changes.
- Add service/controller tests showing that a delete plan rereads the sheet,
  applies structural row deletion only when expectations still match, and
  returns a refreshed report.
- Add widget tests showing that the primary exercise action menu includes both
  Add backup exercise and Delete exercise, that the delete confirmation is
  required, that cancel does not call delete, and that confirm calls the delete
  path.
- Use targeted Flutter tests for backend, adapter, controller, and widget
  behavior. These tests must not require Google credentials or write to the
  development sheet.
- Do not run opt-in live Google integration unless a later slice explicitly
  asks for live validation and the user authorizes Google login and sheet
  writes.
- Include a final test-cleanup slice to remove or rewrite TDD scaffolding that
  pins private implementation details while preserving durable behavior tests.

## Out of Scope

- Deleting canonical exercise definitions from the Exercises tab.
- Bulk deleting multiple primary exercises at once.
- Undo or restore for deleted rows.
- A recycle bin, archive tab, or backup export.
- Changing the sheet contract's backup attachment rule.
- Replacing Google Sheets as the source of truth.
- Building an app-owned workout database.
- Broad visual redesign of the workout overview.
- Live Google validation unless separately authorized.
- Reworking unrelated GUI reliability issues from the previous superseded root
  plan.

## Further Notes

This PRD replaces the previous root-level GUI MVP reliability plan at the
user's request. The previous plan is no longer the active root issue plan.

The current code already has useful seams: app-level validation services, a
Google account/session abstraction, a Picker abstraction, read/write adapters,
and sheet-contract write plans. The refactor should deepen those seams instead
of replacing them wholesale.

The current primary exercise action menu already has both visible overflow and
right-click/long-press entry points. Adding Delete exercise should reuse that
single menu path so desktop and touch behavior remain consistent.
