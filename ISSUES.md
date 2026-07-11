# Remaining Workout UI and Interaction Issues

This plan implements the remaining non-simple work described in
`ISSUES_PRD.md`. Localized findings already fixed before the PRD was written are
intentionally excluded.

## Progress

- [x] Slice 1: Make exercise log-format authoring safe and understandable
- [x] Slice 2: Serialize loaded-workbook mutations
- [x] Slice 3: Unify workout home and native navigation
- [x] Slice 4: Streamline phone set entry
- [ ] Slice 5: Make logged-set editing compact and recoverable
- [ ] Slice 6: Add scalable exercise-library search
- [ ] Slice 7: Complete responsive light and dark visual polish
- [ ] Slice 8: Clean up tests and run the release gate

## Slice 1: Make exercise log-format authoring safe and understandable

### Type

`AFK`

### What to build

Turn the literal log-format field into a guided, workbook-safe authoring
experience. Users should see concise syntax help, immediate validation, and a
representative output preview. Invalid formats must remain local to the draft
and must also be rejected by the write-planning contract. Protect changed
exercise drafts from accidental dismissal.

### Acceptance criteria

- [x] Valid literal formats show a representative preview before submission.
- [x] Invalid formats show focused, human-readable feedback beside the field.
- [x] Create and edit actions cannot submit an invalid format.
- [x] The public planner rejects an invalid application-authored format without
      emitting a write.
- [x] Attempting to leave a changed create or edit draft requires explicit
      discard confirmation; unchanged forms close immediately.
- [x] Valid create and edit flows preserve current workbook behavior.
- [x] Behavior tests exercise the public parser/planner and visible form
      behavior without duplicating parser internals.

### Blocked by

None - can start immediately.

### User stories covered

- PRD user stories 7-11.

## Slice 2: Serialize loaded-workbook mutations

### Type

`AFK`

### What to build

Put every loaded-workbook mutation behind one authoritative single-flight
command owner. It should expose consistent pending and failure state, prevent
overlapping commands regardless of which screen launched them, and leave safe
read-only navigation available where appropriate.

### Acceptance criteria

- [x] All loaded-workbook mutations use one command gate.
- [x] A second mutation cannot begin while the first is pending.
- [x] Pending state is visible through the existing typed screen read models.
- [x] Relevant mutation controls disable consistently while pending.
- [x] Success and failure both release pending state exactly once.
- [x] Existing stale-write expectations and workbook-session behavior remain
      authoritative.
- [x] Tests assert the app-owned command contract rather than simulated Google
      behavior or private counter state.

### Blocked by

None - can start immediately.

### User stories covered

- PRD user stories 12-14.

## Slice 3: Unify workout home and native navigation

### Type

`AFK`

### What to build

Replace the duplicate setup/workout destinations with one workout home that
contains workout selection, history selection, progress, and the interactive
exercise list. Remove the generic Select transition. Represent feature
navigation with a typed native page stack so in-app Back, Android system Back,
and iOS back gestures return to the page that actually launched the feature.

### Acceptance criteria

- [x] Workout and history selectors update the exercise list immediately.
- [x] The duplicate workout-list destination and generic Select action are
      removed.
- [x] Logging, placement, library, create, and edit pages return to their actual
      origin through page history rather than origin flags.
- [x] Android-style back dispatch follows the page stack before allowing app
      exit.
- [x] iOS feature pages participate in normal back navigation.
- [x] Sheet selection remains the parent destination of workout home.
- [x] AppShell composes pages without interpreting feature or workbook
      commands.
- [x] Navigation tests assert visible destinations and back behavior rather
      than internal route enum values.

### Blocked by

- Slice 2: Serialize loaded-workbook mutations.

### User stories covered

- PRD user stories 1-6 and 14.

## Slice 4: Streamline phone set entry

### Type

`AFK`

### What to build

Make the active set the primary phone task. Keep target sets, reps, RPE, and
rest visible near the editor; order fields before Save; support efficient
next/done keyboard flow; and accept both decimal values and arbitrary literal
field text without inferring semantics from field labels.

### Acceptance criteria

- [x] At phone width, structured fields appear before the primary Save action.
- [x] Target and rest information stays visible near the active editor.
- [x] Keyboard Next advances through structured fields in format order.
- [x] The final keyboard action can submit a non-empty valid set.
- [x] Decimal values and non-numeric literal field values can both be entered.
- [x] Saving retains existing write planning, pending-state, error, and
      next-set behavior.
- [x] Desktop layout remains compact without introducing a separate execution
      path.
- [x] Focused widget tests cover task order and keyboard submission through the
      public logging action interface.

### Blocked by

- Slice 2: Serialize loaded-workbook mutations.
- Slice 3: Unify workout home and native navigation.

### User stories covered

- PRD user stories 15-20.

## Slice 5: Make logged-set editing compact and recoverable

### Type

`AFK`

### What to build

Render saved sets as compact summaries and expand only the set being edited.
Clearing a set should use the normal workbook command path and offer an undo
action that restores the exact previous raw value through existing stale-write
protections.

### Acceptance criteria

- [ ] Logged sets are compact summaries by default on phone and desktop.
- [ ] Tapping an edit action expands only the selected set.
- [ ] Saving or cancelling collapses the editor without changing other sets.
- [ ] Clearing a set provides a visible, time-limited Undo action.
- [ ] Undo restores the exact prior raw cell value through the normal command
      interface.
- [ ] Failed clear or undo operations preserve clear error feedback and do not
      claim success.
- [ ] Training details and the new-set editor are not pushed below multiple
      expanded saved-set forms.
- [ ] Behavior tests cover formatted and raw sets, clear, undo, stale rejection,
      and one-editor-at-a-time behavior.

### Blocked by

- Slice 2: Serialize loaded-workbook mutations.
- Slice 4: Streamline phone set entry.

### User stories covered

- PRD user stories 20-23.

## Slice 6: Add scalable exercise-library search

### Type

`AFK`

### What to build

Add local search by exercise display name and description while retaining
canonical sheet order. Searching must not create a second ordering model, and
reordering must be unavailable while a filter hides part of the library.

### Acceptance criteria

- [ ] Search matches display names and descriptions case-insensitively.
- [ ] Results remain in canonical sheet order.
- [ ] A clear empty-result state explains that no exercise matched.
- [ ] Clearing search restores the full list and canonical order.
- [ ] Reorder handles and reorder commands are unavailable while filtered.
- [ ] Newly created or edited highlighted exercises remain discoverable after
      returning to the library.
- [ ] Tests cover matching, empty results, clearing, order preservation, and
      filtered reorder protection through visible behavior.

### Blocked by

- Slice 3: Unify workout home and native navigation.

### User stories covered

- PRD user stories 24-26.

## Slice 7: Complete responsive light and dark visual polish

### Type

`AFK`

### What to build

Add a system-following dark theme and make custom workout state colors adapt to
the active color scheme. Review the completed workout home, logging,
authoring, placement, library, picker, and repair states at narrow phone, large
text, normal desktop, and wide desktop sizes. Correct hierarchy, wrapping,
clipping, and action placement without creating platform-specific screen
implementations.

### Acceptance criteria

- [ ] The app follows system light and dark appearance.
- [ ] Logged, current, backup, warning, and error states meet contrast guidance
      in both themes.
- [ ] Core screens remain usable at narrow phone width and with large text.
- [ ] Desktop content retains intentional density and maximum width.
- [ ] Primary actions remain visually ordered after responsive wrapping.
- [ ] No status relies on color alone.
- [ ] Accessibility guideline tests pass for representative light and dark
      states.
- [ ] A visual smoke pass covers the main macOS flow and representative phone
      widget sizes.

### Blocked by

- Slice 1: Make exercise log-format authoring safe and understandable.
- Slice 3: Unify workout home and native navigation.
- Slice 4: Streamline phone set entry.
- Slice 5: Make logged-set editing compact and recoverable.
- Slice 6: Add scalable exercise-library search.

### User stories covered

- PRD user stories 27-29.

## Slice 8: Clean up tests and run the release gate

### Type

`AFK`

### What to build

Use the `test-cleanup` skill to remove temporary TDD scaffolding and rewrite
tests that pin widget structure, private navigation state, or command-owner
implementation. Retain the smallest durable behavior suite, then run the full
static, test, accessibility, and clean release-build gate.

### Acceptance criteria

- [ ] The `test-cleanup` skill is used for this slice.
- [ ] Tests assert public screen behavior, command contracts, or workbook plans
      rather than private helpers and widget-tree trivia.
- [ ] Redundant TDD-only cases are removed or consolidated.
- [ ] Safety coverage remains for invalid-format rejection, command
      serialization, navigation/back behavior, set clear/undo, and filtered
      reorder protection.
- [ ] The complete Flutter test suite passes.
- [ ] Static analysis and diff checks pass.
- [ ] A clean macOS release build passes.
- [ ] A clean unsigned iOS release build passes.

### Blocked by

- Slice 1: Make exercise log-format authoring safe and understandable.
- Slice 2: Serialize loaded-workbook mutations.
- Slice 3: Unify workout home and native navigation.
- Slice 4: Streamline phone set entry.
- Slice 5: Make logged-set editing compact and recoverable.
- Slice 6: Add scalable exercise-library search.
- Slice 7: Complete responsive light and dark visual polish.

### User stories covered

- PRD user story 30 and the complete release-readiness goal.
