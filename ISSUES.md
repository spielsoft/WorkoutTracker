# Fast Gym Set Entry Issues

This plan implements `ISSUES_PRD.md`. It is limited to the logging entry
experience and does not modify sheet data, the startup work already present in
the worktree, or the sheet picker.

## Progress

- [x] Slice 1: Make the set-entry hierarchy task-first
- [x] Slice 2: Put configured targets on their fields
- [ ] Slice 3: Add numeric keyboard traversal
- [ ] Slice 4: Clean the completed behavior tests
- [ ] Slice 5: Approve the real iOS entry experience

## Slice 1: Make the set-entry hierarchy task-first

### Type

`AFK`

### What to build

Deliver the compact logging path from selected exercise through one saved set.
Remove redundant exercise and next-set headings, replace the training-details
card with the agreed Sets/Rest summary and secondary coaching note, and move the
active set identity onto the primary save action. Preserve the existing guarded
workbook command, failure recovery, and post-save refresh behavior.

### Acceptance criteria

- [ ] The selected exercise remains available in the screen header and selector,
      but the repeated standalone exercise heading below the selector is absent.
- [ ] `Next set Sn` is absent and the primary action reads `Save set Sn` using
      the existing computed next-set number.
- [ ] A successful S1 save refreshes the screen with `Save set S2`; a failed save
      retains `Save set S1` and the typed values.
- [ ] Pending state disables the dynamic save action and preserves duplicate-save
      suppression.
- [ ] The bordered `Training details` card and title are absent.
- [ ] The compact summary shows nonblank Sets and Rest only; `3` plus `120s`
      renders as `3 sets | 120 s Rest`.
- [ ] Rendered Targets notation and Tempo are absent from the compact summary.
- [ ] A nonblank coaching note appears as secondary text without a `Notes:`
      prefix; a blank note consumes no space.
- [ ] Existing logged-set history, recent history, backup selection, write
      planning, and error presentation continue to behave through their public
      interfaces.
- [ ] Focused phone, desktop, narrow-width, and large-text behavior tests pass.

### Blocked by

None - can start immediately.

### User stories covered

- PRD user stories 1-7, 21-23.

## Slice 2: Put configured targets on their fields

### Type

`AFK`

### What to build

Present each active workout row's configured target beside its corresponding
new-set field while leaving the existing draft prefill workflow intact. The
visual label describes the planned target; the controller may still contain a
more recent logged result. Blank and explicit-zero targets remain distinct, and
screen-reader labels stay stable.

### Acceptance criteria

- [ ] Each new-set field with a nonblank configured target appends that exact
      target in parentheses, such as `Reps (10-12)`, `RPE (8)`, `Weight (240)`,
      or `Pain (0)`.
- [ ] A blank configured target produces a plain label such as `Weight` or
      `Pain`; the UI never synthesizes `(0)`.
- [ ] Suggestions come from the active placement row's Targets map, so primary,
      backup, and duplicate placements may show different labels.
- [ ] A field prefilled from recent history still displays the configured row
      target in its label rather than the controller value.
- [ ] Existing prefill precedence remains latest formatted result first and
      configured Targets second.
- [ ] Suggestion suffixes appear only on new-set fields; editing a logged set
      retains ordinary field labels.
- [ ] Screen-reader names remain `New set <field>` in Log Format declaration
      order and do not include volatile suggestion values.
- [ ] Parenthetical labels remain usable on narrow phones, at large text, and in
      the compact desktop layout without changing traversal order.
- [ ] Behavior tests cover text targets, explicit zero, blank values, history
      prefill, placement-specific targets, and stable semantics.

### Blocked by

- Slice 1: Make the set-entry hierarchy task-first.

### User stories covered

- PRD user stories 8-12, 18-20, 23.

## Slice 3: Add numeric keyboard traversal

### Type

`AFK`

### What to build

Replace the signed numbers-and-punctuation request with unsigned decimal numeric
input and add a small app-owned input accessory for fast forward traversal.
Intermediate arrows advance through the declared format fields; the final arrow
saves the current `Sn` through the same guarded workflow as the visible button.
Keep literal input compatibility and accessibility without building a custom
keyboard or adding a keyboard dependency.

### Acceptance criteria

- [ ] Structured set fields request unsigned decimal numeric input and no longer
      request signed input.
- [ ] The app does not add an input formatter that rejects pasted,
      hardware-keyboard, or otherwise accepted literal text.
- [ ] When a structured new-set field has focus, an app-owned accessory exposes
      a clearly labeled right-arrow control with a compliant tap target.
- [ ] Intermediate arrows move focus to the next field in Log Format declaration
      order without changing field values.
- [ ] The final arrow invokes `Save set Sn`, respects empty-input behavior, and
      cannot bypass busy-state or duplicate-action protection.
- [ ] Failed final-arrow saves preserve draft values and the current set number.
- [ ] Keyboard dismissal, screen navigation, exercise switching, and widget
      disposal leave no stale accessory or focus state.
- [ ] The accessory communicates Next versus Save behavior through semantics and
      disabled state rather than color alone.
- [ ] Narrow-phone and large-text tests show that the focused field and accessory
      remain reachable when keyboard insets are present.
- [ ] Public tests verify requested keyboard configuration, traversal, final-save
      command behavior, decimal entry, arbitrary literal entry through test
      input, and duplicate-save suppression without asserting native key pixels.

### Blocked by

- Slice 2: Put configured targets on their fields.

### User stories covered

- PRD user stories 13-24.

## Slice 4: Clean the completed behavior tests

### Type

`AFK`

### What to build

Use the test-cleanup skill after the three TDD implementation slices. Remove or
rewrite scaffolding tests that pin private formatting helpers, focus-node
internals, overlay structure, or incidental widget nesting. Preserve the
smallest durable safety net for the visible set-entry contract, public command
behavior, semantics, layout, and error recovery.

### Acceptance criteria

- [ ] The test-cleanup skill is read and applied before changing the completed
      test suite.
- [ ] Tests that exist only to drive private string, focus, or accessory
      implementation details are removed or rewritten through public behavior.
- [ ] Durable coverage remains for compact summary content, configured-target
      labels, blank versus zero, dynamic `Save set Sn`, traversal order,
      final-arrow save, failure recovery, and duplicate suppression.
- [ ] Semantics, narrow-width, large-text, tap-target, and contrast coverage
      remains focused and nonduplicative.
- [ ] Logging-flow tests do not pretend that Flutter fakes prove the native iOS
      keyboard renderer.
- [ ] Focused logging tests, the shell accessibility test, and static analysis
      pass; any architecture guard added or documented by the repository also
      passes.

### Blocked by

- Slice 1: Make the set-entry hierarchy task-first.
- Slice 2: Put configured targets on their fields.
- Slice 3: Add numeric keyboard traversal.

### User stories covered

- All PRD user stories, as durable regression coverage.

## Slice 5: Approve the real iOS entry experience

### Type

`HITL`

### What to build

Run the integrated logging flow with the iOS software keyboard visible and have
the owner review it against the agreed hierarchy and mockup intent. Validate
one-handed entry, numeric key availability, decimal entry, arrow placement,
focus movement, final-field saving, keyboard avoidance, and accessible sizing.
Use a disposable workbook copy, fake-backed diagnostic build, or another sheet
the owner explicitly approves before any save.

### Acceptance criteria

- [ ] Review uses an iOS simulator with the software keyboard forced visible or
      a physical iPhone; a hardware-only keyboard session is insufficient.
- [ ] The keyboard presents the intended numeric-focused layout without the
      prior signed numbers-and-punctuation keyboard.
- [ ] Decimal entry is available and the app-owned forward control is visible,
      reachable, and comfortably sized.
- [ ] Weight-to-final-field traversal follows the row's Log Format order and
      keeps each focused field visible above the keyboard.
- [ ] The final arrow saves the displayed `Sn`, advances the button after the
      refreshed result, and does not double-submit under rapid taps.
- [ ] The compact summary, coaching note, dynamic target labels, and
      `Save set Sn` hierarchy match the clarified PRD rather than the literal
      `(suggestion)` text in the early mockups.
- [ ] Explicit zero, blank target, and recent-history-prefill examples are
      visually distinguishable as specified.
- [ ] Large text and VoiceOver receive a representative smoke pass for field
      order, arrow action, and save action.
- [ ] No ordinary workout sheet is written without explicit owner approval;
      any disposable test data is identified before the review.
- [ ] The owner approves the result or records concrete revisions in
      `ISSUES_PRD.md` and reopens the relevant AFK slice.

### Blocked by

- Slice 4: Clean the completed behavior tests.

### User stories covered

- PRD user stories 1-20, 24.
