# Agent Guidance

This file is the lightweight startup guide for agents working in WorkoutTracker.

## Read First

Before doing implementation work, read:

1. `AGENTS.md`
2. `README.md`
3. `docs/domain_contract.md`
4. `PROMPTS.md` when using a prepared prompt flow
5. Any active transient plan file explicitly named by the user or task

If future project guidance files are added, read them before choosing work.

## Project Summary

WorkoutTracker is a lightweight cross-platform gym logging app. The durable data artifact is a user-owned Google Sheet. The app should make logging ergonomic while preserving the sheet as the human-readable source of truth.

The selected implementation direction is Flutter/Dart with a standard package layout. The MVP must eventually run as a macOS `.app` bundle and should keep iOS, Android, Linux, and Windows viable.

## Development Discipline

- Follow the active task plan when one is provided.
- Use TDD for every implementation slice.
- Write one failing behavior test through a public interface, then implement the smallest code needed to pass.
- Refactor only after tests are green.
- Commit each completed slice separately.
- Update transient plan checklists only when the slice is actually complete.
- Preserve unrelated worktree changes.
- Stage only files that belong to the current slice.

## Backend Before GUI

All backend sheet-contract behavior must be complete before GUI work begins.

Do not start GUI slices until Slice 16 is complete:

- sheet parsing and validation
- backup grouping
- history block discovery and planning
- set notation parsing/rendering
- set write planning
- formula healing planning
- Google Sheet read/write adapters
- development sheet reset/cleanup
- backend integration validation
- backend architecture review

GUI code must use completed backend modules instead of duplicating sheet parsing, validation, formula healing, or write planning.

## Sheet Contract Principles

- The Google Sheet is the source of truth.
- There is no app-owned workout database.
- The first tab is the active workout/log sheet.
- `Exercises` stores canonical exercise metadata and is read-only in the initial app.
- Active sheet display cells use direct formulas into `Exercises`.
- The app may heal active-sheet formulas when they are missing or broken.
- `Workout` and `is_backup` live on the active sheet.
- Blank `Workout` means default workout.
- Blank `is_backup` means false.
- Backup rows attach to the nearest preceding primary row within the same workout.
- Unparseable set cells must be preserved as raw text.

## Testing Expectations

Tests should describe observable behavior, not implementation details.

Do not treat mocks, fakes, canned HTTP responses, or simulated third-party
callbacks as behavior tests for systems outside this repository. They may only
verify this app's own interface contracts: which adapter method is called, which
scope or URL is requested, which callback shape the app accepts, or which write
plan the app emits. They do not prove Google, Firebase, OAuth, Picker, or app
store behavior. If the external system's behavior matters, use an opt-in live
integration test or document the assumption instead of inventing the answer in a
mock.

Use the smallest test tier that gives useful signal for the work in front of
you:

- Fast default local tests: run targeted `flutter test` commands for the
  backend, adapter, or controller behavior you changed. These tests must not
  require Google credentials or write to the development sheet.
- Targeted GUI tests: run focused widget tests such as
  `flutter test test/widget_test.dart` when app presentation or interaction
  behavior changes.
- Opt-in live Google integration: run
  `integration_test/live_logging_flow_test.dart` only when explicitly needed,
  Google login is ready, and it is acceptable to reset/write the development
  sheet. Set `WORKOUT_TRACKER_RUN_LIVE_GOOGLE_TESTS=1` for that run; without
  it, the live test must skip before authentication.
- Release/full validation: run the broad local suite and any platform build or
  live validation called for by a release, architecture gate, or final cleanup.
  Do this deliberately rather than as a reflex for small changes.

Good test surfaces include:

- parsing an active sheet into workout slots
- validating schema violations
- grouping primary and backup rows
- discovering and creating history blocks
- parsing and rendering set notation
- planning writes without Google access
- healing formulas
- applying Google read/write adapters
- resetting the development sheet fixture

Do not test private helpers just because they exist. The public backend interface should be the test surface.

## Google Sheet Integration

Use this development sheet for integration slices:

https://docs.google.com/spreadsheets/d/1zQrmCYelrNqRMv4WtJcOrtezSxoaVniXzXi4XgKva_E/edit?gid=0#gid=0

First try to complete Google integration work AFK. If local app authentication requires user login or authorization, stop at the smallest necessary HITL point and explain the exact action needed.

Integration tests that write to the development sheet must reset or clean up after themselves.

Live Google integration tests are opt-in. Do not set
`WORKOUT_TRACKER_RUN_LIVE_GOOGLE_TESTS=1` unless the current task explicitly
requires live validation and the user/HITL state is ready for Google
authorization and development-sheet writes.

## Architecture Expectations

Use architecture review tasks seriously when they are part of the active plan.
Prefer deep modules with small public interfaces and substantial behavior behind
them.

Keep these seams conceptually separate:

- sheet contract parsing/validation
- set notation parsing/rendering
- history block planning
- set write planning
- formula healing
- Google Sheet adapters
- GUI presentation

Avoid shallow pass-through modules. If deleting a module would simply move the same complexity into callers, deepen it or remove it.

## Reporting

At the end of a slice, report:

- commit hash
- changed files
- tests run
- whether the slice checklist was updated
- risks or follow-up slices

If a slice cannot be committed, do not mark it complete. Explain the blocker.

## Active Architecture Deepening Plan

This section is a transient implementation plan generated from
`AGENTS_PRD.md`. Preserve the standing guidance above. Work through these
slices in dependency order, using TDD, preserving unrelated worktree changes,
and committing each completed slice separately.

### Checklist

- [x] Slice 1: Introduce Google workspace lifecycle state
- [x] Slice 2: Move selected-sheet restore and persistence behind workspace
- [x] Slice 3: Route choose/create/logout through workspace commands
- [x] Slice 4: Fold scoped Google validation forwarding into workbook access
- [x] Slice 5: Consolidate app-facing workbook commands
- [x] Slice 6: Move shell workspace orchestration out of widget state
- [ ] Slice 7: Deepen write-planning internals without changing the facade
- [ ] Slice 8: Run architecture and test cleanup

## Slice 1: Introduce Google Workspace Lifecycle State

### Type

`AFK`

### What to build

Create the first thin Google workspace lifecycle interface for restoring the
current account profile, current selected spreadsheet, Picker authorization
snapshot, and availability state. This slice should not move all Picker or
Sheets behavior yet; it should establish a single app-facing state model that
callers can observe instead of separately reading account session, app state,
and selected spreadsheet fields.

### Acceptance criteria

- [ ] A public workspace state exposes selected spreadsheet, account profile,
      Picker availability, and whether pasted-sheet fallback is available.
- [ ] Existing startup behavior is preserved for saved selected sheets and
      pasted sheet text.
- [ ] Existing Google account menu behavior remains visible through the shell.
- [ ] Tests verify restored workspace state through a public workspace
      interface, not by inspecting old shell-private choreography.
- [ ] `flutter analyze` and targeted workspace/shell tests pass.

### Blocked by

None - can start immediately.

### User stories covered

- User stories 1, 4, 10, 15, 20 from `AGENTS_PRD.md`.

## Slice 2: Move Selected-Sheet Restore And Persistence Behind Workspace

### Type

`AFK`

### What to build

Move selected-sheet restore, selected-sheet resolution, pasted sheet text
persistence, Picker authorization persistence, and workout-selection
persistence behind the Google workspace module. The shell should no longer
manually coordinate state-store updates for these concepts.

### Acceptance criteria

- [ ] Restoring a saved selected spreadsheet still validates the selected sheet
      and opens the workout setup when the sheet is usable.
- [ ] Restoring pasted sheet text still supports manual validation when no
      selected sheet exists.
- [ ] Picker authorization remains persisted after a successful Picker
      selection.
- [ ] Workout and history selection persistence still follows the selected
      spreadsheet.
- [ ] Widget tests assert visible restore and persistence behavior without
      depending on shell-private state-store calls.
- [ ] `flutter analyze` and targeted app-state/widget tests pass.

### Blocked by

- Slice 1: Introduce Google workspace lifecycle state

### User stories covered

- User stories 1, 3, 4, 10, 15, 16 from `AGENTS_PRD.md`.

## Slice 3: Route Choose/Create/Logout Through Workspace Commands

### Type

`AFK`

### What to build

Move spreadsheet choosing, create-sheet authorization, create-sheet execution,
selected-sheet adoption, and logout cleanup behind workspace commands. The GUI
may still own the create-sheet name prompt, but it should invoke one workspace
command for the resulting action and receive updated workspace state.

### Acceptance criteria

- [ ] Choosing a spreadsheet still launches the existing Picker path and adopts
      the selected spreadsheet.
- [ ] Creating a spreadsheet still authorizes through the folder Picker path,
      prompts for a name, creates and initializes the workbook, and adopts it.
- [ ] Logout still clears account, selected sheet, pasted sheet text, workout
      selection, and loaded validation state.
- [ ] Duplicate choose/create actions remain blocked while an action is in
      flight.
- [ ] Tests verify visible choose/create/logout behavior through workspace
      commands.
- [ ] `flutter analyze` and targeted Picker/widget tests pass.

### Blocked by

- Slice 2: Move selected-sheet restore and persistence behind workspace

### User stories covered

- User stories 2, 3, 4, 6, 10, 16 from `AGENTS_PRD.md`.

## Slice 4: Fold Scoped Google Validation Forwarding Into Workbook Access

### Type

`AFK`

### What to build

Remove the auth-wrapped validation forwarding layer by moving scoped Google API
client lifetime and Google-backed workbook service construction into one deeper
workbook access module. Preserve scope requests, authenticated client closing,
read adapter behavior, write adapter behavior, validation, and write refresh
semantics.

### Acceptance criteria

- [ ] Google-backed validation requests the writable Sheets scope through the
      workspace/account authorization path.
- [ ] Authenticated clients remain open for the full Google action and are
      closed afterward.
- [ ] Validation, active-sheet writes, formula repairs, exercise authoring,
      reordering, and deletion still return refreshed validation reports.
- [ ] The old forwarding service and factory wiring are removed or reduced to a
      non-public construction detail.
- [ ] Tests that previously pinned forwarding are rewritten to verify scoped
      workbook behavior through the deeper module.
- [ ] `flutter analyze` and targeted validation/Google adapter tests pass.

### Blocked by

- Slice 1: Introduce Google workspace lifecycle state

### User stories covered

- User stories 5, 6, 7, 11, 12, 14, 19 from `AGENTS_PRD.md`.

## Slice 5: Consolidate App-Facing Workbook Commands

### Type

`AFK`

### What to build

Replace the split app-facing validation and exercise-authoring service shape
with one workbook command interface. The controller should call a single
workbook command module for validate, write-plan application, formula repair,
canonical exercise create/update/reorder, workout placement, workout reorder,
and workout exercise deletion.

### Acceptance criteria

- [ ] The controller no longer needs separate validation and authoring
      collaborators for one selected spreadsheet workflow.
- [ ] Existing user-visible validation, repair, logging, exercise authoring,
      reordering, and deletion behavior is preserved.
- [ ] The "authoring is not connected yet" path disappears unless there is a
      real unsupported build mode.
- [ ] Optimistic write rejection and refreshed-report behavior remain covered.
- [ ] Tests are rewritten around public workbook commands and controller
      behavior rather than the old service split.
- [ ] `flutter analyze` and targeted controller/workbook tests pass.

### Blocked by

- Slice 4: Fold scoped Google validation forwarding into workbook access

### User stories covered

- User stories 5, 7, 8, 9, 13, 14, 19 from `AGENTS_PRD.md`.

## Slice 6: Move Shell Workspace Orchestration Out Of Widget State

### Type

`AFK`

### What to build

Reduce shell widget state to rendering, navigation, and local form state by
moving workspace restore, selected-sheet adoption, create/choose busy state,
sign-out cleanup, and persistence side effects into app controllers or
workspace state owners. Keep visual behavior unchanged.

### Acceptance criteria

- [ ] The main shell no longer manually coordinates Google workspace restore,
      Picker authorization restore, selected-sheet persistence, or sign-out
      persistence cleanup.
- [ ] The shell still renders the same first-run, selected-sheet, fallback,
      validation, workout setup, exercise manager, placement, and logging
      states.
- [ ] Existing widget behavior remains covered by focused tests.
- [ ] Tests no longer pin shell-private Google workspace plumbing.
- [ ] `flutter analyze` and targeted widget tests pass.

### Blocked by

- Slice 3: Route choose/create/logout through workspace commands
- Slice 5: Consolidate app-facing workbook commands

### User stories covered

- User stories 1, 2, 3, 4, 5, 15, 16, 20 from `AGENTS_PRD.md`.

## Slice 7: Deepen Write-Planning Internals Without Changing The Facade

### Type

`AFK`

### What to build

Refactor active-sheet write-planning internals so set logging, set editing,
history block growth, canonical exercise authoring, canonical reorder, workout
placement, workout reorder, deletion, and expectation generation are organized
by domain behind the existing parsed active-sheet facade. Preserve public
sheet-contract behavior.

### Acceptance criteria

- [ ] Public parsed active-sheet planning methods remain available to callers.
- [ ] Existing write plans for history blocks, set logging, set editing, raw
      edits, clears, exercise authoring, workout placement, reordering,
      deletion, and formula-related updates are unchanged in observable
      behavior.
- [ ] Repeated expectation and stale-sheet rejection mechanics are centralized
      or made easier to reason about.
- [ ] Tests continue to validate write-plan behavior through public
      sheet-contract methods.
- [ ] `flutter analyze` and targeted sheet-contract/write-planning tests pass.

### Blocked by

- Slice 5: Consolidate app-facing workbook commands

### User stories covered

- User stories 7, 8, 9, 17, 18, 20 from `AGENTS_PRD.md`.

## Slice 8: Run Architecture And Test Cleanup

### Type

`AFK`

### What to build

Run a final architecture review and test cleanup pass after the deepening
slices. Use the `architecture-deepening`, `code-quality-review`, and
`test-cleanup` skills as appropriate. Remove or rewrite tests that only pin
temporary seams introduced during TDD while preserving durable behavior tests.

### Acceptance criteria

- [ ] No removed forwarding services, marker interfaces, or internal legacy
      compatibility paths are reintroduced.
- [ ] Tests focus on public behavior, public contracts, intentional external
      adapter boundaries, and visible GUI workflows.
- [ ] Remaining architecture risks are documented or converted into follow-up
      issues.
- [ ] Broad local tests and `flutter analyze` pass.
- [ ] This checklist is fully updated, and each completed slice has a separate
      commit.

### Blocked by

- Slice 6: Move shell workspace orchestration out of widget state
- Slice 7: Deepen write-planning internals without changing the facade

### User stories covered

- User stories 14, 15, 19, 20 from `AGENTS_PRD.md`.
