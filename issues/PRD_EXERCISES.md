# Exercise Management PRD

## Problem Statement

WorkoutTracker already has a way to create canonical exercises, but the app does not yet provide a complete place to manage the exercise library. A user can add an exercise, but there is no obvious mobile-first view where they can see all current canonical exercises, choose one to edit, or control the order in which exercises appear.

This creates friction for real use on an iPhone. A user should not need to discover exercise management indirectly from workout setup. They should be able to open one clear exercise management view, scan their current exercises, add a new one, edit an existing one, and reorder the list in a way that feels natural on touch devices.

The feature also needs to respect the sheet as the source of truth. The app must not create a separate exercise database, and it must not offer destructive exercise deletion in the MVP. Canonical exercises may be referenced by workout placements and formulas, so delete behavior is intentionally out of scope until the project has a safe reference-management design.

## Solution

Add a mobile-first Edit Exercises view for managing canonical exercises from the user-owned Google Sheet.

The view lists all current canonical exercises in their sheet-backed order. It provides a clear add action that opens the existing exercise authoring flow with blank/default values. It also allows a user to edit an existing exercise by selecting it and opening the same authoring flow pre-populated with the selected exercise data.

The view supports reordering exercises by direct manipulation. On mobile, the user can press and hold an exercise row and drag it to a new position. On desktop-class pointer input, the same behavior should work with click and drag. Reordering canonical exercises means safely planning and writing row order changes against the exercise sheet while preserving the sheet as the source of truth.

The reorder behavior should be designed as a generic ordering seam, not as one-off code for the exercise library. The same mechanism should later be used to reorder exercises within a workout. Workout-level reordering must respect backup attachment rules, so a primary exercise and its backup rows can move as a group when needed.

The MVP explicitly does not include deleting exercises. The Edit Exercises view should not present delete as a supported action.

## User Stories

1. As an iPhone user, I want one obvious Edit Exercises view, so that I can manage my exercise library without hunting through setup flows.
2. As a lifter, I want to see all current canonical exercises in one list, so that I know what is already available.
3. As a lifter, I want the exercise list to reflect the order stored in my sheet, so that the app and sheet remain consistent.
4. As a lifter, I want an empty exercise library state to explain how to add the first exercise, so that setup does not feel broken.
5. As a lifter, I want a visible Add Exercise action from the exercise list, so that creating a new exercise is easy.
6. As a lifter, I want Add Exercise to use the existing exercise authoring form, so that creation behavior stays consistent.
7. As a lifter, I want new exercise authoring to keep sensible defaults, so that common exercises are quick to create.
8. As a lifter, I want to return to the exercise list after adding an exercise, so that I can confirm it was added.
9. As a lifter, I want newly added exercises to appear in the canonical exercise list, so that I can immediately use or reorder them.
10. As a lifter, I want to tap an existing exercise to edit it, so that correcting metadata is straightforward.
11. As a lifter, I want the edit form to be pre-populated with the selected exercise data, so that I can make small corrections without retyping everything.
12. As a lifter, I want saving an edited exercise to update the existing canonical exercise instead of appending a duplicate, so that the sheet remains clean.
13. As a lifter, I want canceling an edit to leave the exercise unchanged, so that accidental navigation is safe.
14. As a lifter, I want exercise names, default targets, notes, and log format to remain editable through the canonical exercise flow, so that the exercise library remains complete.
15. As a lifter, I want to reorder canonical exercises with press-and-hold drag on iPhone, so that organizing the list feels natural.
16. As a desktop user, I want to reorder canonical exercises with click and drag, so that the same feature works with pointer input.
17. As a lifter, I want the reordered exercise list to persist back to the sheet, so that the order is durable.
18. As a sheet-backed app user, I want exercise reordering to preserve exercise metadata, formulas, and workout references, so that reordering does not corrupt the workbook.
19. As a sheet-backed app user, I want the app to detect or avoid unsafe reorder writes when the sheet has changed underneath it, so that stale UI state does not overwrite newer sheet edits.
20. As a future implementer, I want exercise reordering to use a generic ordering seam, so that workout exercise reordering can reuse the same behavior.
21. As a lifter, I want to reorder exercises inside a workout using the same interaction model, so that workout organization is consistent with library organization.
22. As a lifter, I want workout reordering to preserve backup attachment, so that backup exercises stay attached to the correct primary exercise.
23. As a lifter, I want a primary exercise and its backups to move together when the primary is reordered, so that sheet order still represents the intended workout structure.
24. As a lifter, I want reordering to be reversible before it is saved when practical, so that accidental drags are not punishing.
25. As a mobile user, I want exercise rows to have clear touch targets and readable labels, so that the list is usable one-handed.
26. As a mobile user, I want drag handles or equivalent affordances to make reordering discoverable, so that I do not need to guess hidden gestures.
27. As a user who edits the Google Sheet directly, I want the app to continue treating the sheet as the source of truth, so that manual sheet edits remain respected.
28. As an MVP user, I do not want delete controls for exercises, so that the app does not offer a dangerous action before safe reference handling exists.
29. As a future implementer, I want this work split into behavior-oriented slices, so that add, edit, reorder, and cleanup can be implemented and reviewed independently.
30. As a future maintainer, I want tests to protect behavior and seams rather than widget internals, so that the UI can keep improving without brittle test failures.

## Implementation Decisions

- Add a dedicated Edit Exercises view that lists canonical exercise definitions from the sheet-backed exercise library.
- The exercise manager is mobile-first. It should be comfortable on iPhone while still accepting desktop pointer input where the platform supports it.
- The existing exercise authoring experience should be reused for both adding and editing canonical exercises.
- Add mode opens the authoring flow with blank/default values.
- Edit mode opens the authoring flow pre-populated from the selected canonical exercise.
- Saving in edit mode updates the selected canonical exercise row. It must not append a duplicate exercise.
- Canceling from add or edit leaves sheet data unchanged.
- The MVP does not offer exercise deletion. No delete button, swipe delete action, overflow delete item, or disabled placeholder delete control should be included.
- Canonical exercise ordering is sheet-backed. Reordering exercises must produce a safe sheet write plan rather than maintaining app-only order state.
- Reorder writes must preserve all canonical exercise metadata.
- Reorder writes must preserve active workout references and formula integrity. The implementation should use sheet operations or repair planning that keep formulas pointed at the intended canonical exercises.
- Reorder behavior should be expressed through a generic ordering seam that can accept ordered items, a movement intent, and enough context to produce a safe write plan.
- The generic ordering seam should support at least two domains: canonical exercise rows and workout placement rows.
- Workout placement reordering should reuse the generic seam and preserve backup attachment rules.
- When moving a primary workout exercise, its attached backup rows should move with it unless a later design explicitly introduces more granular backup reordering.
- The UI should make drag reordering discoverable with an appropriate handle or affordance.
- On touch platforms, press-and-hold followed by drag is the expected reorder interaction.
- On pointer platforms, click-and-drag is the expected reorder interaction.
- The feature must continue to use the Google Sheet as the source of truth. It must not introduce an app-owned exercise database.
- The implementation should prefer deep, testable modules for reorder planning and sheet write planning instead of scattering row-order logic through UI code.
- The exercise manager should use existing sheet parsing, validation, formula healing, authoring, and adapter boundaries where they already exist.

## Testing Decisions

- Tests should verify observable behavior, public interfaces, and intentional seams. They should not pin private widget hierarchy, helper names, or incidental Flutter layout structure.
- Exercise manager tests should verify that the canonical exercise list is visible, ordered, and reachable through the app's public UI flow.
- Add-flow tests should verify that the exercise manager opens the existing authoring flow in add mode and shows the added exercise after save.
- Edit-flow tests should verify that selecting an existing exercise opens a pre-populated authoring flow and that saving updates the existing exercise rather than appending a duplicate.
- Cancel-flow tests should verify that canceling add or edit does not change sheet-backed exercise data.
- Reorder planner tests should cover canonical exercise movement, no-op movement, boundary movement, stale input detection, and metadata preservation.
- Canonical reorder tests should verify that persisted order changes survive a reload from the sheet-backed source.
- Formula and reference safety should be tested through behavior: after reorder, workout placements should still resolve to the intended canonical exercises.
- Workout reorder tests should verify that moving primary exercises preserves backup attachment and moves backup groups appropriately.
- Widget tests should cover mobile reorder affordance availability and successful drag behavior at phone widths where practical.
- Adapter tests should use fake or in-memory sheet data unless a slice explicitly requires live Google validation.
- Live Google integration is not required for the normal development loop. It may be used only when a slice deliberately validates real sheet row movement behavior and the development-sheet write risk is acceptable.
- Any tests created during TDD should be reviewed near the end with the test-cleanup skill. The retained suite should enforce behavior, interfaces, and seams, not temporary implementation details.

## Out of Scope

- Deleting canonical exercises.
- Archiving or hiding canonical exercises.
- Bulk editing exercises.
- Importing exercise libraries from external sources.
- Adding exercise categories, tags, media, coaching instructions, analytics, or progression recommendations.
- Replacing the sheet as the source of truth.
- Introducing an app-owned exercise database.
- Changing the workbook contract beyond what is necessary to safely update existing canonical rows and row order.
- Making workout programming or template design a broader feature.
- Building a desktop-specific management experience separate from the mobile-first flow.
- Implementing unsafe reorder behavior that rewrites rows without preserving formulas, references, and metadata.

## Further Notes

- The key product goal is easy yet complete exercise management for a real iPhone user.
- Delete is intentionally absent because canonical exercises may be referenced by workout placements and formulas. A future delete or archive design should start from reference safety, not from a simple row removal action.
- Reordering canonical exercise rows is more sensitive than it looks because active workout rows may point into the exercise library. The implementation should treat reorder as a sheet-contract operation, not only as a UI list gesture.
- The generic reorder seam is important. It should keep row-order behavior consistent across the exercise library and workout exercise lists while allowing each domain to enforce its own sheet-safety rules.
- The exercise manager should remain compact and practical. It is a working tool for a gym logger, not a spreadsheet administration console.
