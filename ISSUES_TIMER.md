# Timed Exercise Countdown Issues

This plan implements `ISSUES_TIMER_PRD.md` on the `timed-exercises` branch.
Treat the PRD as the product source and these slices as the dependency-ordered
implementation checklist.

No slice in this plan reads or writes a real workout Sheet. Slices 1-8 use local
models, fixtures, and the in-memory `dev/gym_preview.dart` harness only. Slice 9
is owner acceptance on a physical iPhone, and it also runs the in-memory
harness, so it needs no upgraded workbook and no Google access. Do not enable
live Google tests or write to any workout workbook at any point.

Upgrading an existing workbook to schema 1.1 is owner-performed work after this
plan completes. It is deliberately not a slice here.

## Progress

- [x] Slice 1: Persist canonical Timer Fields in schema 1.1
- [x] Slice 2: Author Timer Fields on canonical exercises
- [x] Slice 3: Share an exact labeled countdown with full vibration
- [ ] Slice 4: Remove unused next-field arrow buttons
- [ ] Slice 5: Run a modal exercise countdown from a timed set field
- [ ] Slice 6: Record the measured duration when a countdown ends
- [ ] Slice 7: Clean the timer test suite
- [ ] Slice 8: Run the complete local timer guard
- [ ] Slice 9: Accept the physical iOS timer flow

## Slice 1: Persist canonical Timer Fields in schema 1.1

### Type

`AFK`

### What to build

Move the workbook contract directly to version 1.1 and add the required
`Timer Fields` column to canonical Exercises. A blank cell means no timers; a
populated cell names exact Log Format labels in a visible list such as
`['Seconds']`. Carry that state through canonical reads, exercise write plans,
and new-workbook creation without adding a corresponding active-workout column
or changing targets and history.

Extend the bundled exercise catalog contract with an optional timer-field
array whose omission means empty. Make all 42 maintained definitions explicit,
enabling `Seconds` only for Side Plank and Copenhagen Side Plank. The catalog
continues to seed new workbooks once and never synchronizes into existing
workbooks.

Do not add a migration command, and do not upgrade any existing workbook.
Version 1.0 workbooks remain unsupported until the owner upgrades them after
this plan completes.

### Acceptance criteria

- [x] A public workbook-contract test first demonstrates a schema 1.1
      Exercises row with a timed field available in the canonical read model.
- [x] Schema 1.1 requires `Timer Fields` after `Default Values`; the active
      workout's fixed columns remain unchanged.
- [x] Blank Timer Fields parses as an empty immutable collection.
- [x] A populated Timer Fields cell round-trips exact labels in Log Format
      declaration order.
- [x] Malformed syntax, duplicate labels, or a label absent from that row's Log
      Format produces blocking schema damage.
- [x] Exercise create and update plans write Timer Fields while leaving active
      rows, Targets, and all history cells unchanged.
- [x] Newly created workbooks write schema metadata `1.1` and nine Exercises
      columns.
- [x] Catalog parsing treats a missing `timerFields` property as empty and
      rejects non-list or non-string values.
- [x] All 42 maintained catalog exercises declare `timerFields` explicitly;
      Side Plank and Copenhagen Side Plank contain `Seconds`, and the other 40
      arrays are empty.
- [x] Loading catalog defaults proves every Timer Fields label exists in that
      definition's parsed Log Format.
- [x] A declared version 1.0 workbook is rejected and no in-app 1.0-to-1.1
      mutation is offered or applied.
- [x] The workbook domain and testing guidance describe schema 1.1, Timer
      Fields ownership, JSON seed-only behavior, and owner-performed upgrade
      outside this plan.
- [x] Focused contract, planning, template, and version tests pass.

### Blocked by

None - can start immediately.

### User stories covered

- PRD user stories 4-5 and 27-42.
- PRD workbook schema, catalog, and ownership decisions.

## Slice 2: Author Timer Fields on canonical exercises

### Type

`AFK`

### What to build

Let exercise creators and editors select canonical Timer Fields through the
generated default-value section. Present one shared `Timer` column heading and
one checkbox for each parsed Log Format field. Saving writes the selected exact
labels to the canonical exercise so every placement observes the same state;
it does not copy timer metadata into active rows or modify existing targets and
history.

### Acceptance criteria

- [x] A public exercise-authoring behavior test first demonstrates enabling a
      timer field and saving it with the canonical exercise.
- [x] Create and edit forms show one shared Timer heading and one checkbox per
      parsed Log Format field in declaration order.
- [x] Each checkbox has an accessible name that includes its field label and a
      state available without relying on color, icon, or position.
- [x] Existing timer selections load checked; untimed fields load unchecked.
- [x] Saving create or edit state writes only exact labels still declared by
      the current valid Log Format.
- [x] A Log Format change cannot retain a stale Timer Fields label that no
      longer exists.
- [x] Changing Timer Fields alone does not enter the format-impact flow or
      rewrite placed Targets and history.
- [x] Busy forms disable the timer checkboxes consistently with other inputs.
- [x] The checkbox column remains usable at narrow widths and large text.
- [x] Focused authoring, application-command, write-plan, and accessibility
      tests pass.

### Blocked by

- Slice 1: Persist canonical Timer Fields in schema 1.1.

### User stories covered

- PRD user stories 26-33 and 41-42.

## Slice 3: Share an exact labeled countdown with full vibration

### Type

`AFK`

### What to build

Deepen the existing rest timer into one countdown module that owns an exact
deadline, pause/resume, `+30 s`, replacement, lifecycle correction, Done, and
one completion signal. Give the presentation an explicit heading above the
existing symmetric controls: `REST` for rest and the full exercise name for an
exercise. Keep rest behavior nonmodal and unchanged apart from its new label
and replacing the impact thunk with a request for one full system vibration.

The timer retains fractional seconds internally and computes its visible value
with ordinary nearest-integer rounding. Foreground operation is the supported
MVP; an expiry discovered after resume signals once then, without adding local
notifications or background execution.

The module must expose the elapsed duration at the moment a countdown ends, so
Slice 6 can record it without reaching into countdown internals.

### Acceptance criteria

- [x] A public countdown behavior test first demonstrates a fractional
      duration expiring at its exact deadline while exposing a rounded integer
      for display.
- [x] Countdown state is derived from a deadline rather than accumulated
      whole-second subtraction, including after lifecycle suspension.
- [x] Pause preserves the exact remaining duration, resume continues it,
      `+30 s` adds exactly 30 seconds, and Done clears it without signaling.
- [x] Ending a countdown exposes the elapsed duration through the module's
      public surface, for both Done and expiry.
- [x] Starting a new countdown replaces the previous countdown and prevents
      the replaced countdown from signaling later.
- [x] Natural expiry requests exactly one full platform vibration and clears
      the active countdown.
- [x] Missing or failing platform haptics cannot crash or strand the countdown.
- [x] The timer bar has a full-width heading row above the unchanged symmetric
      control row.
- [x] Rest shows `REST`; an exercise mode can show its full supplied name
      without shifting the three controls below it.
- [x] The countdown button retains accessible pause/resume state, remaining
      time, and timer identity.
- [x] Existing saved-set rest timers still start at the same time, remain
      usable during writes, remain nonmodal, and survive navigation.
- [x] Foreground/resume behavior is tested without claiming that a fake proves
      physical vibration or suspended iOS execution.
- [x] Focused countdown, rest-bar, rest-flow, lifecycle, layout, and
      accessibility tests pass.

### Blocked by

None - can start immediately.

### User stories covered

- PRD user stories 6-10, 13-17, 25, 39-40, and 43.

## Slice 4: Remove unused next-field arrow buttons

### Type

`AFK`

### What to build

Remove the visible next-field arrow control from every data-entry surface, in
workout logging, exercise authoring, placement, and format-review forms. This
also frees the trailing icon slot that Slice 5 needs for the timer control.

Every field that currently shows an arrow uses a numeric keyboard, which on iOS
has no Return or Next key, so no soft-keyboard traversal is being given up.
Traversal in practice is a direct tap on the field, and hardware-keyboard Tab
traversal continues to work as it did before the arrows existed. Do not change
field order.

### Acceptance criteria

- [ ] A public UI behavior test first demonstrates that representative entry
      forms contain no visible next-field arrow button.
- [ ] No app screen renders the retired arrow icon, tooltip, semantics action,
      or tap target.
- [ ] The shared arrow component is deleted when it has no remaining callers.
- [ ] Field declaration order and screen-reader traversal order are unchanged.
- [ ] Directly tapping any field still focuses it, and focusing still selects
      the existing value for replacement.
- [ ] Hardware-keyboard Tab traversal moves focus through the fields in
      declaration order.
- [ ] Removing the control does not reduce spacing below accessibility tap
      targets or cause narrow/large-text overflow.
- [ ] Focused workout-entry, authoring, placement, format-review, and broad
      accessibility tests pass.

### Blocked by

None - can start immediately.

### User stories covered

- PRD user stories 21-22 and 25.

## Slice 5: Run a modal exercise countdown from a timed set field

### Type

`AFK`

### What to build

Complete the athlete-facing path. Resolve the selected placement's canonical
Timer Fields from the already loaded Exercises tab and put a timer icon beside
each enabled field in the new-set editor only. Pressing the icon reads that
field's current positive finite numeric value as seconds and starts the shared
countdown under the full exercise name. Starting does not change the field,
confirm a suggestion, save a set, or start rest.

Exercise timing replaces any active rest countdown and makes the rest of the
app modal: visibly dim it, block pointer and navigation actions, and remove it
from accessibility focus. The timer controls remain usable. Pause retains the
lock; Done or exact expiry restores the app. Rest timers continue to leave the
app interactive.

### Acceptance criteria

- [ ] A public logging-flow test first demonstrates a timer icon on a
      canonical timed field and no icon on an untimed field with the same or a
      different label.
- [ ] Timer availability comes only from the canonical Exercises Timer Fields;
      no active-workout Timer Fields column or label/unit inference is added.
- [ ] Timer icons appear only in new-set entry, never in logged-set editing,
      history, targets, placement, or unrelated numeric fields.
- [ ] Each icon's accessible label names the exercise and source field and
      exposes whether the current value can start a timer.
- [ ] Pressing an enabled icon reads the field's current value at that moment,
      accepts positive fractional seconds, and starts the exact duration.
- [ ] Blank, zero, negative, non-finite, range, or otherwise nonnumeric values
      cannot start a countdown and do not disturb an existing countdown.
- [ ] Starting exercise timing leaves the field text, value origin, unsaved
      set, and Sheet unchanged.
- [ ] Starting exercise timing replaces an active rest countdown; the displaced
      countdown cannot later vibrate.
- [ ] The full exercise name appears above the symmetric `+30 s`, rounded
      countdown/pause, and Done controls and can wrap at narrow widths.
- [ ] While exercise timing is active, underlying controls cannot receive
      pointer, keyboard, back-navigation, or accessibility actions and are
      visibly dimmed.
- [ ] Pausing keeps the modal lock; `+30 s` keeps it active; Done and natural
      expiry both restore interaction and accessibility focus.
- [ ] A rest timer still leaves the app interactive and displays `REST`.
- [ ] Lifecycle resume preserves the exact exercise deadline and signals once
      if expiry is first discovered on resume.
- [ ] Narrow-phone, large-text, contrast, Android tap-target, iOS tap-target,
      labeled-control, and semantics checks pass.
- [ ] Focused canonical-read, logging-flow, shell, countdown, navigation, and
      accessibility tests pass.

### Blocked by

- Slice 1: Persist canonical Timer Fields in schema 1.1.
- Slice 2: Author Timer Fields on canonical exercises.
- Slice 3: Share an exact labeled countdown with full vibration.
- Slice 4: Remove unused next-field arrow buttons.

### User stories covered

- PRD user stories 1-25, 27, 31, 39-43.

## Slice 6: Record the measured duration when a countdown ends

### Type

`AFK`

### What to build

When a countdown that a set field started ends, by expiry or by Done, write the
elapsed duration into that field and mark the value recorded. A hold stopped at
thirty seconds of a prescribed forty-five reports thirty rather than leaving the
prescription in place. A hold that runs to expiry reports its full duration,
which also stops a completed prescribed hold from still reading as an
unconfirmed suggestion.

This introduces the third value origin. A logging value currently carries a
boolean: prefilled and unconfirmed, or not. Replace it with one explicit origin
of suggested, entered, or recorded, so the states cannot drift into overlapping
flags. A recorded value must not read as a suggestion; sharing the entered
treatment is acceptable because it is real performed data.

Saving the set stays explicit. Recording a duration never writes to the Sheet.

### Acceptance criteria

- [ ] A public logging behavior test first demonstrates Done partway through a
      countdown writing the elapsed seconds into the field that started it.
- [ ] Expiry writes the full duration into that field.
- [ ] The written value uses the same rounding as the visible countdown.
- [ ] The value's origin becomes recorded, and a recorded value is neither
      styled nor announced as a suggestion.
- [ ] Suggested, entered, and recorded are one explicit origin rather than
      parallel booleans.
- [ ] Ending a countdown writes only the field that started it and leaves every
      other field's text and origin unchanged.
- [ ] Editing a recorded value by hand makes it entered.
- [ ] Recording never saves a set, starts rest, or writes to the workbook.
- [ ] A rest countdown ending writes no field.
- [ ] A countdown displaced by a new countdown records nothing.
- [ ] Semantics distinguish recorded from suggested and entered without relying
      on color alone.
- [ ] Focused logging-flow, countdown, and accessibility tests pass.

### Blocked by

- Slice 5: Run a modal exercise countdown from a timed set field.

### User stories covered

- PRD user stories 45-48.
- PRD value-origin and timer-completion decisions.

## Slice 7: Clean the timer test suite

### Type

`AFK`

### What to build

Use the `test-cleanup` skill to review the tests produced by timer TDD. Remove
or rewrite scaffolding that pins private controller mechanics, exact widget
trees, incidental tick order, or temporary seams. Preserve the smallest
durable safety net for schema ownership, exercise authoring, precise countdown
behavior, rest/exercise policy differences, modal locking, value origin,
accessibility, and catalog defaults.

### Acceptance criteria

- [ ] The `test-cleanup` skill is explicitly loaded and followed for this
      slice.
- [ ] Tests assert public contract results, application commands, visible user
      behavior, semantics, and intentional injected clock/signal seams.
- [ ] Tests that exist only to pin private names, internal maps, widget nesting,
      timer tick implementation, or callback ordering are removed or rewritten.
- [ ] Fractional deadline, replacement, one completion signal, canonical
      Timer Fields, authoring round-trip, new-set icon scope, modal lock,
      recorded duration, and rest nonmodal behavior retain durable coverage.
- [ ] Physical vibration remains assigned to HITL acceptance rather than being
      falsely claimed by a mocked platform channel.
- [ ] No broad coverage deletion hides an untested product acceptance
      criterion.
- [ ] Every focused suite affected by cleanup passes.

### Blocked by

- Slice 6: Record the measured duration when a countdown ends.

### User stories covered

- PRD user stories 39-44 and 48.
- PRD testing decisions.

## Slice 8: Run the complete local timer guard

### Type

`AFK`

### What to build

Validate the complete local feature after the scoped implementation slices.
Use the in-memory gym preview for visual review of Side Plank timing; do not
connect to Google or touch any workout workbook. Inspect the final diff for
schema, UI, accessibility, and architecture drift and record any behavior that
still requires the physical-device gate.

### Acceptance criteria

- [ ] `dart format --output=none --set-exit-if-changed lib test integration_test dev`
      reports no changes.
- [ ] `flutter analyze` reports no issues.
- [ ] `flutter test` passes in full.
- [ ] The broad Flutter accessibility guideline test passes.
- [ ] The macOS accessibility probe runs against a local preview, or its skip
      is recorded with a concrete reason.
- [ ] The in-memory gym preview demonstrates Side Plank's timer icon, full-name
      two-row bar, rest replacement, modal dim/lock, pause, `+30 s`, Done,
      expiry, unlock, recorded duration, and unchanged set text without any
      Google access.
- [ ] The preview fixture covers a timed exercise, so Slice 9 can be accepted
      on a physical device without a real workbook.
- [ ] A narrow large-text preview shows no clipped exercise identity,
      overlapping controls, unreachable Done action, or exposed locked
      semantics.
- [ ] Any repository-defined architecture guard runs successfully. If the
      repository still defines no dedicated architecture command, that absence
      is recorded rather than inventing one.
- [ ] `git diff --check` passes and the diff contains no migration UI, active
      Timer Fields column, background notification path, live-test enablement,
      workbook write, secrets, or unrelated worktree changes.
- [ ] Remaining physical-vibration risk is handed to Slice 9 without claiming
      local fakes resolved it.

### Blocked by

- Slice 7: Clean the timer test suite.

### User stories covered

- All PRD user stories that can be established locally.
- PRD testing and out-of-scope decisions.

## Slice 9: Accept the physical iOS timer flow

### Type

`HITL`

### What to build

Stop for owner review before this slice. Build and run the in-memory
`dev/gym_preview.dart` harness on a physical iPhone so the owner can accept
hardware behavior that a simulator cannot establish. The harness carries its own
timed-exercise fixture, so this needs no upgraded workbook, no Google account,
and no access to real workout data.

The owner observes the full system vibration and accepts the exercise
interaction, modal lock, two-row layout, rounding, recorded duration, and
restoration.

Upgrading a real workbook to schema 1.1 is owner-performed work after this plan
and is deliberately not part of this slice.

### Acceptance criteria

- [ ] The harness runs on a physical iPhone in release or profile mode, and the
      device and OS version are recorded.
- [ ] No Google account is used and no workout workbook is read or written.
- [ ] A fractional exercise duration expires at its exact time while the visible
      count uses ordinary rounding.
- [ ] Exercise timing shows the full exercise name, replaces rest, dims and
      locks every underlying app action, remains locked while paused, and
      unlocks on Done and expiry.
- [ ] Expiry produces one full system vibration rather than the old impact
      thunk; it does not repeat and adds no sound.
- [ ] Stopping a hold early records the elapsed time in the field, and running
      to expiry records the full duration.
- [ ] Rest timing displays `REST`, produces the same full vibration, and leaves
      the rest of the app interactive.
- [ ] Background/resume behavior is observed as best effort and is not treated
      as a guaranteed suspended-app alert.
- [ ] The final report records the physical device and OS, observed behavior,
      commits under test, and every unresolved risk.

### Blocked by

- Slice 8: Run the complete local timer guard.
- Explicit owner approval to begin a physical acceptance session.

### User stories covered

- PRD user stories 1-19, 23-25, 43, and 45-47.
- PRD physical-device testing decisions.
