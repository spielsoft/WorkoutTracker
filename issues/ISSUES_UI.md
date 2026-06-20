# Mobile-First UI Issues

Source PRD: `issues/PRD_IU.md`

This issue plan intentionally references the PRD for full rationale and user-story detail. Each slice below is a narrow vertical step toward the mobile-first UI described there.

## Checklist

- [x] Slice 1: Establish mobile visual state language
- [ ] Slice 2: Make logging entry thumb-first
- [ ] Slice 3: Compress logging context and history
- [ ] Slice 4: Expose backup row actions
- [ ] Slice 5: Stabilize mobile form layouts
- [ ] Slice 6: Move creation actions out of selectors
- [ ] Slice 7: Simplify first-run sheet setup
- [ ] Slice 8: Make repair flows task-first
- [ ] Slice 9: Mobile UI review pass
- [ ] Slice 10: Clean up TDD-only UI tests

## Slice 1: Establish mobile visual state language

### Type

`AFK`

### What to build

Introduce a compact, data-first visual language for workout logging states. The app should consistently distinguish logged, current, backup, warning, and error states while keeping the UI utilitarian and phone-friendly. This slice should create the smallest shared presentation vocabulary needed for later slices without redesigning every screen at once.

### Acceptance criteria

- [x] Logged, current, backup, warning, and error states have distinct user-visible treatments.
- [x] Set progress can be represented compactly as a reusable visual pattern.
- [x] Common mobile action labels use concise sentence case.
- [x] Icons reinforce recurring concepts such as exercise, set progress, rest, backup, sheet, warning, and repair where appropriate.
- [x] Existing behavior is preserved.
- [x] Widget tests verify semantic state presentation without relying on private implementation details.

### Blocked by

None - can start immediately

### User stories covered

- PRD user stories 12, 13, 14, 34, 35, 36, 37
- PRD sections: Solution, Implementation Decisions, Testing Decisions

## Slice 2: Make logging entry thumb-first

### Type

`AFK`

### What to build

Rework the mobile logging screen so the active exercise, next set editor, save action, and logged progress are available before secondary context. Saving should remain reachable while editing values, including when the software keyboard is present. The slice should preserve raw-text editing for unparseable values and continue to use the existing set-notation behavior.

### Acceptance criteria

- [ ] On common narrow phone widths, the next set editor is visible before recent history and extended context.
- [ ] The current exercise and next set identity are visible near the editor.
- [ ] The save action remains reachable while entering set values.
- [ ] Logged set progress is visible before recent history.
- [ ] Unparseable set cells remain editable as raw text.
- [ ] Focused widget tests cover the mobile logging priority order and save availability through public UI behavior.

### Blocked by

- Slice 1: Establish mobile visual state language

### User stories covered

- PRD user stories 1, 2, 3, 4, 8, 9, 10, 11, 12, 13, 14
- PRD sections: Solution, Implementation Decisions, Testing Decisions

## Slice 3: Compress logging context and history

### Type

`AFK`

### What to build

Move target, rest, tempo, notes, and recent history into compact mobile-first summaries that can expand when needed. The default logging view should prioritize action, while preserving guidance and prior performance for users who need it.

### Acceptance criteria

- [ ] Target, rest, tempo, and notes are available without pushing the next set editor below the primary mobile viewport.
- [ ] Recent history appears as a compact summary by default.
- [ ] Users can expand or inspect deeper history without leaving the logging flow.
- [ ] Logged current-session sets remain visually higher priority than prior history.
- [ ] Widget tests verify default collapsed or compact presentation and expansion behavior.

### Blocked by

- Slice 2: Make logging entry thumb-first

### User stories covered

- PRD user stories 5, 6, 7, 11, 13
- PRD sections: Solution, Implementation Decisions, Testing Decisions

## Slice 4: Expose backup row actions

### Type

`AFK`

### What to build

Add visible tap affordances for adding, switching, or managing backup exercises from workout overview rows. Long press may remain as a shortcut, but backup workflows must be discoverable through visible controls. Rows should keep the primary exercise and set progress readable even when backups exist.

### Acceptance criteria

- [ ] Every primary exercise row has a visible path to add or manage backups.
- [ ] Backup actions are accessible by tap and do not require long press.
- [ ] Long press remains optional if retained.
- [ ] Backup names, counts, or indicators do not crowd out primary exercise names.
- [ ] Set progress remains visible on rows with backups.
- [ ] Widget tests verify visible backup actions and readable row state.

### Blocked by

- Slice 1: Establish mobile visual state language

### User stories covered

- PRD user stories 15, 16, 17, 18, 19, 20
- PRD sections: Solution, Implementation Decisions, Testing Decisions

## Slice 5: Stabilize mobile form layouts

### Type

`AFK`

### What to build

Replace fragile fixed-width wrapped form layouts with predictable mobile form layouts across logging fields, workout setup, workout placement, and exercise authoring. Use stacked fields, stable responsive grids, or grouped controls that fit common phone widths. Apply appropriate input types for numeric or constrained values.

### Acceptance criteria

- [ ] Logging fields fit predictably on common phone widths without awkward wrapping.
- [ ] Workout setup controls fit predictably on common phone widths.
- [ ] Workout placement controls fit predictably on common phone widths.
- [ ] Exercise authoring remains usable on a phone with a clear submit path.
- [ ] Numeric and constrained fields request appropriate input types where supported.
- [ ] Widget tests cover narrow-width behavior and user-visible overflow risk.

### Blocked by

- Slice 1: Establish mobile visual state language

### User stories covered

- PRD user stories 8, 9, 21, 24, 25, 26, 27, 36
- PRD sections: Solution, Implementation Decisions, Testing Decisions

## Slice 6: Move creation actions out of selectors

### Type

`AFK`

### What to build

Separate selection from creation for workouts, history blocks, and exercises. Dropdowns and pickers should choose existing values only. Add workout, add history, and add exercise actions should be visible and should return the user to a selected, ready-to-continue state after creation.

### Acceptance criteria

- [ ] Existing-value selectors no longer depend on sentinel create items.
- [ ] Add-workout and add-history actions are visible without opening a selector.
- [ ] Add-exercise or choose-exercise flows require explicit user selection where needed.
- [ ] Newly created values become selected when appropriate.
- [ ] Widget tests verify visible creation actions and post-creation selection behavior.

### Blocked by

- Slice 5: Stabilize mobile form layouts

### User stories covered

- PRD user stories 21, 22, 23, 24, 25, 26, 27
- PRD sections: Solution, Implementation Decisions, Testing Decisions

## Slice 7: Simplify first-run sheet setup

### Type

`AFK`

### What to build

Rework first-run and sheet-selection presentation so there is one dominant mobile next action to choose a workout sheet. Create-sheet and paste-link flows should remain available as secondary paths. Selected sheet and account state should stay clear but compact.

### Acceptance criteria

- [ ] First-run setup presents one dominant choose-sheet action.
- [ ] Create-sheet and paste-link paths are visible but secondary.
- [ ] Returning users can understand selected sheet and account state without setup details dominating normal use.
- [ ] Existing sheet selection, creation, persistence, and fallback behavior is preserved.
- [ ] Widget tests verify the primary and secondary setup actions through public UI behavior.

### Blocked by

- Slice 1: Establish mobile visual state language

### User stories covered

- PRD user stories 28, 29, 30
- PRD sections: Solution, Implementation Decisions, Testing Decisions

## Slice 8: Make repair flows task-first

### Type

`AFK`

### What to build

Revise validation and repair presentation so panels lead with user task language while preserving spreadsheet diagnostics as secondary detail. Repair choices should help the user understand what action they are taking before exposing row-level sheet details.

### Acceptance criteria

- [ ] Repair panels lead with task-first language.
- [ ] Spreadsheet row numbers and diagnostic details remain available but visually secondary.
- [ ] Formula repair choices identify the affected task or exercise where possible.
- [ ] Warning and error states use the shared mobile visual state language.
- [ ] Widget tests verify task-first labels and preserved diagnostic availability.

### Blocked by

- Slice 1: Establish mobile visual state language

### User stories covered

- PRD user stories 31, 32, 33, 38
- PRD sections: Solution, Implementation Decisions, Testing Decisions

## Slice 9: Mobile UI review pass

### Type

`HITL`

### What to build

Perform a final mobile-first review of the completed UI slices against the PRD. This is a human-in-the-loop design review, not a broad refactor. The goal is to verify that the implemented flows feel coherent as a phone-first workout logger and that any remaining gaps are captured as follow-up issues.

### Acceptance criteria

- [ ] The logging flow can be reviewed on a phone-sized viewport from setup through set entry.
- [ ] Backup management is discoverable without hidden gestures.
- [ ] Form layouts remain predictable at common phone widths.
- [ ] Sheet setup and repair flows preserve task-first hierarchy.
- [ ] Visual states are consistent across logging, overview, setup, and repair surfaces.
- [ ] Any remaining design gaps are recorded as follow-up issues instead of being folded into this pass.

### Blocked by

- Slice 2: Make logging entry thumb-first
- Slice 3: Compress logging context and history
- Slice 4: Expose backup row actions
- Slice 5: Stabilize mobile form layouts
- Slice 6: Move creation actions out of selectors
- Slice 7: Simplify first-run sheet setup
- Slice 8: Make repair flows task-first

### User stories covered

- PRD user stories 1-40
- PRD sections: Solution, Implementation Decisions, Testing Decisions, Further Notes

## Slice 10: Clean up TDD-only UI tests

### Type

`AFK`

### What to build

Use the `test-cleanup` skill to review the tests created during the UI implementation slices and remove or rewrite TDD leftovers that over-constrain implementation details. The goal is to keep durable tests that protect user-facing behavior, public UI/controller interfaces, and intentional seams, while deleting almost all tests that only existed to drive intermediate TDD steps.

This slice should leave future UI work easier, not more fragile. Tests should describe the desired mobile behavior from the PRD: logging priority, discoverable backup actions, predictable mobile forms, visible creation actions, task-first setup and repair flows, and semantic visual states. Tests should not pin private widget structure, exact helper decomposition, incidental layout widgets, or temporary implementation paths.

### Acceptance criteria

- [ ] The `test-cleanup` skill is used before editing the test suite.
- [ ] TDD-only tests that assert implementation details, private widget structure, call ordering, or temporary helper behavior are removed or rewritten.
- [ ] Remaining tests enforce desired behavior through public UI, controller interfaces, or intentional seams.
- [ ] Mobile behavior from the PRD remains covered at the smallest useful test tier.
- [ ] Tests that remain for visual state semantics avoid exact color or pixel-perfect assertions unless those values are part of a deliberate public design contract.
- [ ] The final retained test set is documented in the slice report, including why each category remains.
- [ ] Relevant focused Flutter tests pass after cleanup.

### Blocked by

- Slice 9: Mobile UI review pass

### User stories covered

- PRD user stories 39, 40
- PRD sections: Testing Decisions, Further Notes
