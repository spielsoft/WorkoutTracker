# GUI MVP Hardening Issues

This is the active vertical-slice plan for the remaining GUI/MVP hardening
work found through black-box macOS testing. Work through slices in dependency
order. Use TDD for each implementation slice: write or update one failing
behavior test through a public interface, implement the smallest fix, run
targeted tests, then update this checklist only after the slice is complete.

Do not run live Google integration tests or write to the development sheet
unless explicitly authorized for that slice. Rebuild the macOS release bundle
after GUI-facing changes.

## Checklist

- [x] Slice 1: Cleanly Integrate Current GUI Fixes
- [ ] Slice 2: Validate Multi-Set Logging Against Live GUI
- [ ] Slice 3: Make Row Actions Understandable
- [ ] Slice 4: Speed Up Multi-Exercise Plan Building
- [ ] Slice 5: Preserve Exercise Library Context After Save
- [ ] Slice 6: Repeat Black-Box GUI Regression Pass
- [ ] Slice 7: Clean Up Temporary GUI Tests

## Slice 1: Cleanly Integrate Current GUI Fixes

### Type

`AFK`

### What to build

Review and stabilize the GUI fixes already prototyped in the dirty worktree so
they become clean, reviewable vertical slices. The intended behavior is:

- New workbook creation starts with an empty active workout sheet and a seeded
  canonical exercise library.
- Add to workout and Create exercise are clearly distinguished.
- Stale logging saves do not clear inputs unless refreshed sheet data contains
  the saved set.
- Add to workout back navigation returns to workout setup.
- Newly created history blocks visibly become selected.
- Exercise placement includes search.
- Default exercise-authoring numeric fields replace selected text on focus.
- Return key behavior does not choose an unopened exercise picker item.

Keep the patch scoped to the MVP GUI hardening work and preserve unrelated
worktree changes.

### Acceptance criteria

- [x] The current GUI fixes are present in clean, understandable diffs.
- [x] The active workout template has only contract headers while `Exercises`
      keeps the seeded canonical library.
- [x] Logging write success is gated by refreshed public logging state.
- [x] Add to workout returns to workout setup on back.
- [x] History block selection refreshes after creation.
- [x] Exercise placement search filters by exercise name or description.
- [x] Authoring fields replace default numeric values on normal typing.
- [x] Targeted controller and widget tests pass.
- [x] The macOS release app bundle is rebuilt.

### Blocked by

None - can start immediately.

### User stories covered

- New sheet starts blank but useful.
- Add to workout is distinguishable from Create exercise.
- Logging does not silently discard data.
- Back navigation preserves user context.
- History block creation is immediately usable.
- Custom exercises can be found in the seeded library.
- Numeric defaults are easy to replace.

## Slice 2: Validate Multi-Set Logging Against Live GUI

### Type

`HITL`

### What to build

Run a GUI-only macOS validation pass focused on the previously blocking S2 save
workflow. The app must be logged in to a valid Google account, and the tester
must explicitly authorize live sheet writes for this validation. All app input
must use visible mouse and keyboard interactions only.

The goal is to determine whether the current stale-refresh guard is sufficient
or whether the live Google write/read adapter still fails to persist S2.

### Acceptance criteria

- [ ] The rebuilt macOS app creates or selects a test sheet through the GUI.
- [ ] A workout and history block are created or selected through the GUI.
- [ ] An exercise is added and S1 plus S2 are logged through the GUI.
- [ ] If S2 persists, the logged list and progress update visibly.
- [ ] If S2 does not persist, the input remains available or a visible error is
      shown; it must not silently disappear.
- [ ] The app is quit at the end of the pass.
- [ ] Findings are recorded with exact visible reproduction steps.

### Blocked by

- Slice 1: Cleanly Integrate Current GUI Fixes
- User must provide live Google login/authorization and permit test writes.

### User stories covered

- In-gym multi-set logging can be trusted.
- Failed writes are visible and recoverable.
- GUI testing reflects real app usage.

## Slice 3: Make Row Actions Understandable

### Type

`AFK`

### What to build

Improve the discoverability of row-level actions that black-box testing found
ambiguous: backup actions, reorder handles, and logging/open-row affordances.
Keep the layout compact, but make each action understandable through visible
labels where appropriate, tooltips, semantic labels, and tests.

### Acceptance criteria

- [ ] Backup actions are named clearly in tooltips and semantics.
- [ ] Reorder handles are named clearly per exercise.
- [ ] Opening/logging an exercise row is discoverable without relying only on
      trial-and-error icon interpretation.
- [ ] Compact desktop and narrow phone widget tests remain free of overflow.
- [ ] Widget tests verify the user-facing labels/tooltips for representative
      primary and backup rows.

### Blocked by

- Slice 1: Cleanly Integrate Current GUI Fixes

### User stories covered

- Row actions are understandable without guessing.
- Backup and reorder controls are safe to use in a gym context.

## Slice 4: Speed Up Multi-Exercise Plan Building

### Type

`AFK`

### What to build

Make adding several exercises to a workout less repetitive. After successfully
placing an exercise, provide an explicit path to add another exercise while
preserving the current workout and useful picker/search context. Keep the
default path simple for users who only wanted to add one exercise.

### Acceptance criteria

- [ ] After adding an exercise to a workout, the user can choose Add another
      without returning through awkward intermediate states.
- [ ] The selected workout is preserved.
- [ ] Search/filter context is either preserved or intentionally reset with
      predictable behavior.
- [ ] The existing single-add flow remains available.
- [ ] Widget tests cover adding at least two exercises to one workout using the
      improved flow.

### Blocked by

- Slice 1: Cleanly Integrate Current GUI Fixes

### User stories covered

- Building a workout plan with multiple exercises is fast.
- The user does not lose context between repeated additions.

## Slice 5: Preserve Exercise Library Context After Save

### Type

`AFK`

### What to build

After creating or editing a canonical exercise, preserve or restore useful
context in the exercise library. A user should be able to see the saved item
without manually scrolling back through the seeded library.

### Acceptance criteria

- [ ] Saving a new exercise returns to the exercise library with the saved item
      visible or clearly highlighted.
- [ ] Editing an existing exercise returns with that row visible.
- [ ] Long seeded-library lists do not jump to an unhelpful top position after
      save.
- [ ] Widget tests use a long exercise library and verify the saved/edited row
      is visible after returning.

### Blocked by

- Slice 1: Cleanly Integrate Current GUI Fixes

### User stories covered

- Exercise authoring gives clear confirmation.
- Custom exercise creation does not feel lost in the seeded library.

## Slice 6: Repeat Black-Box GUI Regression Pass

### Type

`HITL`

### What to build

Repeat the macOS GUI-only stress test after the AFK fixes are integrated and
the release bundle is rebuilt. The pass should create a new sheet, add custom
exercises, build at least two workouts, log multiple sets as if in the gym, and
try plausible random interactions. The tester must not use accessibility
setters, direct APIs, source inspection, or direct sheet edits.

### Acceptance criteria

- [ ] The pass uses only visible mouse and keyboard interactions.
- [ ] A new Google-backed sheet is created through the GUI.
- [ ] Several canonical exercises are added through the GUI.
- [ ] At least two workouts are built through the GUI.
- [ ] Multiple sets, including S2 or later, are logged through the GUI.
- [ ] The app is quit when the pass is complete or when a blocker is hit.
- [ ] Pain points and blockers are reported with reproduction steps.

### Blocked by

- Slice 1: Cleanly Integrate Current GUI Fixes
- Slice 2: Validate Multi-Set Logging Against Live GUI
- Slice 3: Make Row Actions Understandable
- Slice 4: Speed Up Multi-Exercise Plan Building
- Slice 5: Preserve Exercise Library Context After Save
- User must provide live Google login/authorization and permit test writes.

### User stories covered

- The MVP flow works under realistic gym use.
- GUI validation reflects actual user interactions.

## Slice 7: Clean Up Temporary GUI Tests

### Type

`AFK`

### What to build

Use the `test-cleanup` skill to review tests added during the GUI hardening
work. Keep durable behavior tests that protect user-facing contracts and remove
or rewrite tests that only pin temporary implementation details.

### Acceptance criteria

- [ ] Tests assert observable behavior through public app/controller/widget
      interfaces.
- [ ] Tests do not over-constrain private helper structure or incidental widget
      shape.
- [ ] The focused GUI/controller tests still cover stale logging saves,
      Add-to-workout navigation, history selection, search, authoring field
      replacement, row-action labels, Add another, and library context.
- [ ] Relevant targeted tests pass.
- [ ] The macOS release bundle is rebuilt if any GUI-facing code changes.

### Blocked by

- Slice 6: Repeat Black-Box GUI Regression Pass

### User stories covered

- Future refactors keep the MVP GUI path reliable.
- The test suite stays maintainable.
- `WORKOUT_TRACKER_RUN_LIVE_GOOGLE_TESTS=1 flutter test integration_test/live_logging_flow_test.dart`
  not run 2026-06-28; live Google sheet writes still require explicit
  authorization.
