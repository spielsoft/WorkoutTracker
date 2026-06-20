# Exercise Management Issues

Source PRD: `issues/PRD_EXERCISES.md`

This issue plan references the PRD for full rationale and user-story detail. Each slice is intended to be independently grabbable and to preserve the Google Sheet as the source of truth. The MVP intentionally does not include deleting exercises.

## Checklist

- [x] Slice 1: Add the exercise manager inventory
- [x] Slice 2: Launch add exercise from the manager
- [x] Slice 3: Edit existing canonical exercises
- [x] Slice 4: Reorder canonical exercises through a generic seam
- [ ] Slice 5: Reuse reorder behavior for workout exercise order
- [ ] Slice 6: Exercise management mobile review
- [ ] Slice 7: Clean up TDD-only exercise-management tests

## Slice 1: Add the exercise manager inventory

### Type

`AFK`

### What to build

Create the mobile-first Edit Exercises view as a read-oriented inventory of canonical exercises. The view should be reachable from the app, list current canonical exercises in sheet-backed order, handle empty/loading/error states, and make it clear that delete is not part of the MVP by simply not offering delete controls.

### Acceptance criteria

- [x] A user can reach an Edit Exercises view through a visible app flow.
- [x] The view lists canonical exercises in the order provided by the sheet-backed source.
- [x] Exercise rows are readable and usable at common iPhone widths.
- [x] Empty, loading, and error states are user-facing and actionable where appropriate.
- [x] The view does not expose delete, swipe-delete, disabled delete, or overflow delete actions.
- [x] Focused tests verify inventory visibility, ordering, empty state, and absence of delete controls through public UI behavior.

### Blocked by

None - can start immediately

### User stories covered

- PRD user stories 1, 2, 3, 4, 25, 27, 28
- PRD sections: Solution, Implementation Decisions, Testing Decisions, Out of Scope

## Slice 2: Launch add exercise from the manager

### Type

`AFK`

### What to build

Add a clear Add Exercise action to the exercise manager. It should open the existing exercise authoring flow in add mode with blank/default values, save a new canonical exercise through the existing sheet-backed behavior, then return the user to an updated exercise list.

### Acceptance criteria

- [x] The exercise manager exposes a visible Add Exercise action.
- [x] Add mode uses the existing exercise authoring experience rather than a duplicate form.
- [x] Add mode starts with blank/default authoring values.
- [x] Saving creates one new canonical exercise and returns to an updated exercise list.
- [x] Canceling add mode leaves canonical exercise data unchanged.
- [x] Tests verify the add flow through public UI/controller behavior without pinning private widget structure.

### Blocked by

- Slice 1: Add the exercise manager inventory

### User stories covered

- PRD user stories 5, 6, 7, 8, 9, 13, 14, 27
- PRD sections: Solution, Implementation Decisions, Testing Decisions

## Slice 3: Edit existing canonical exercises

### Type

`AFK`

### What to build

Allow a user to edit an existing canonical exercise from the exercise manager. Selecting an exercise should open the existing authoring flow in edit mode, pre-populated with that exercise's current metadata. Saving should update the existing canonical exercise row instead of appending a duplicate.

### Acceptance criteria

- [x] A user can open edit mode for an existing canonical exercise from the manager.
- [x] Edit mode pre-populates the authoring fields with the selected exercise data.
- [x] Saving edit mode updates the selected canonical exercise instead of appending a duplicate.
- [x] Canceling edit mode leaves the selected canonical exercise unchanged.
- [x] The updated exercise appears in the manager after save.
- [x] Existing workout placements continue to resolve to the intended canonical exercise after metadata edits.
- [x] Tests verify pre-population, save-as-update, cancel behavior, and no duplicate creation.

### Blocked by

- Slice 1: Add the exercise manager inventory
- Slice 2: Launch add exercise from the manager

### User stories covered

- PRD user stories 10, 11, 12, 13, 14, 18, 27
- PRD sections: Solution, Implementation Decisions, Testing Decisions

## Slice 4: Reorder canonical exercises through a generic seam

### Type

`AFK`

### What to build

Enable canonical exercise reordering from the exercise manager using a generic reorder seam. The user should be able to press and hold then drag on mobile, or click and drag on pointer platforms, and persist the new canonical order safely to the sheet-backed source. The underlying reorder behavior should be reusable for other ordered sheet-backed domains.

### Acceptance criteria

- [x] Exercise rows expose a discoverable reorder affordance.
- [x] Press-and-hold drag works for canonical exercise reorder on mobile-sized layouts where the platform supports it.
- [x] Click-and-drag works for canonical exercise reorder on pointer platforms where the platform supports it.
- [x] Reordered canonical exercise order persists after reloading from the sheet-backed source.
- [x] Reorder preserves canonical exercise metadata.
- [x] Reorder preserves workout references and formula integrity for existing workout placements.
- [x] Stale or unsafe reorder input is detected or avoided before writing over newer sheet state.
- [x] The reorder planning seam is generic enough to support workout placement ordering without copying canonical-only logic.
- [x] Tests cover reorder planning, persistence, metadata preservation, formula/reference safety, no-op moves, boundary moves, and public drag behavior where practical.

### Blocked by

- Slice 3: Edit existing canonical exercises

### User stories covered

- PRD user stories 15, 16, 17, 18, 19, 20, 24, 26, 27
- PRD sections: Solution, Implementation Decisions, Testing Decisions, Further Notes

## Slice 5: Reuse reorder behavior for workout exercise order

### Type

`AFK`

### What to build

Apply the generic reorder seam to exercises within a workout. Users should be able to reorder workout exercise rows with the same interaction model used by the exercise manager. Primary exercises with attached backups should move as a group so backup attachment remains correct according to sheet order.

### Acceptance criteria

- [ ] Workout exercise rows expose a discoverable reorder affordance consistent with the exercise manager.
- [ ] Workout exercise reorder uses the same generic reorder seam as canonical exercise reorder.
- [ ] Moving a primary exercise moves its attached backup rows with it.
- [ ] Backup attachment remains correct after reorder.
- [ ] Workout reorder persists to the active sheet-backed source.
- [ ] Existing set history and row-local target metadata are preserved.
- [ ] Tests verify primary movement, backup-group movement, metadata preservation, persistence, and no unsafe cross-workout attachment changes.

### Blocked by

- Slice 4: Reorder canonical exercises through a generic seam

### User stories covered

- PRD user stories 20, 21, 22, 23, 24, 27
- PRD sections: Solution, Implementation Decisions, Testing Decisions, Further Notes

## Slice 6: Exercise management mobile review

### Type

`HITL`

### What to build

Perform a focused mobile-first review of the completed exercise management flows. This is a human-in-the-loop product/design pass to verify that the manager is easy yet complete for an iPhone user and that delete remains intentionally absent from the MVP.

### Acceptance criteria

- [ ] The exercise manager can be reviewed on a phone-sized viewport from inventory through add, edit, and reorder.
- [ ] Add and edit flows feel like one consistent authoring experience.
- [ ] Reorder behavior is discoverable without written instructions.
- [ ] The absence of delete does not make the UI feel broken or unfinished.
- [ ] Canonical exercise reorder and workout exercise reorder feel consistent.
- [ ] Any remaining gaps are recorded as follow-up issues instead of being folded into this review pass.

### Blocked by

- Slice 5: Reuse reorder behavior for workout exercise order

### User stories covered

- PRD user stories 1, 15, 16, 21, 25, 26, 28, 29
- PRD sections: Solution, Implementation Decisions, Further Notes

## Slice 7: Clean up TDD-only exercise-management tests

### Type

`AFK`

### What to build

Use the `test-cleanup` skill to review tests created during exercise-management implementation and remove or rewrite TDD leftovers that over-constrain implementation details. The retained suite should protect the exercise-management behavior described in the PRD through public UI behavior, controller interfaces, sheet-planning seams, and the generic reorder seam.

This cleanup should remove almost all tests that only existed to drive intermediate TDD steps. It should keep the smallest useful behavioral safety net for future work on add, edit, canonical reorder, workout reorder, sheet-reference safety, and no-delete MVP behavior.

### Acceptance criteria

- [ ] The `test-cleanup` skill is used before editing the test suite.
- [ ] TDD-only tests that assert private widget hierarchy, helper decomposition, call ordering, temporary state shape, or incidental layout structure are removed or rewritten.
- [ ] Remaining tests enforce desired behavior through public UI, controller interfaces, sheet write-planning interfaces, or intentional reorder seams.
- [ ] Exercise add, edit, canonical reorder, workout reorder, reference safety, and no-delete MVP behavior remain covered at the smallest useful test tier.
- [ ] Tests do not over-specify exact drag implementation details beyond the public behavior and supported platform interactions.
- [ ] The final retained test set is documented in the slice report, including why each category remains.
- [ ] Relevant focused Flutter tests pass after cleanup.

### Blocked by

- Slice 6: Exercise management mobile review

### User stories covered

- PRD user stories 29, 30
- PRD sections: Testing Decisions, Further Notes
