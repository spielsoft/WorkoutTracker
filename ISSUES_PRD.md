# Fast Gym Set Entry PRD

## Problem Statement

WorkoutTracker's set-entry screen presents the right underlying workout data
through a slow and confusing hierarchy. The active set number appears as a
detached `Next set S1` heading instead of on the save action where it matters.
The selected exercise is repeated in the screen header, exercise selector, and
again above the form. A bordered `Training details` panel consumes scarce phone
space while exposing compact sheet notation such as `x10-12@8,` that is useful
for storage but awkward for a person entering a set in the gym.

Configured target values are already available to prefill format-driven fields,
but the screen does not clearly explain those values. The user needs to see the
row-local suggestions chosen when the exercise was added to the workout, such
as `Reps (10-12)` and `RPE (8)`, next to the fields they describe. Blank targets
must remain blank rather than being displayed as zero, while an explicit zero
must remain visible as `0`.

The current iOS keyboard request asks for signed decimal input. Flutter maps
that request to iOS's numbers-and-punctuation keyboard, producing a large
punctuation layout with an alphabetic switch. A pure number or decimal pad is
faster, but stock iOS numeric pads do not reliably expose a Next key. The entry
flow therefore needs both a numeric-focused keyboard and an app-owned forward
action that preserves fast field traversal.

## Solution

Turn the logging screen into a compact, task-first set-entry flow. Keep the
sheet and selected exercise context at the top, but remove the repeated
standalone exercise heading and detached next-set heading. Replace the training
details card with an unframed summary such as `3 sets | 120 s Rest`, followed by
the exercise's coaching note as quiet secondary text. Do not render the encoded
Targets string or Tempo in this summary.

Keep the configured row-local target values beside the fields they describe.
For each new-set field, append a nonblank configured target in parentheses:
`Reps (10-12)`, `RPE (8)`, `Weight (240)`, or `Pain (0)`. A field with no
configured target keeps its plain label, such as `Weight` or `Pain`. These
parenthetical values always come from the active workout row's Targets cell;
they do not change when a previous logged result is used to prefill the input.
The existing prefill precedence remains unchanged.

Move the active set identity onto the primary action. The button reads
`Save set S1`, advances to `Save set S2` after a successful write, and continues
to use the existing safe workbook command path.

Request an unsigned decimal numeric keyboard for structured set fields so the
software keyboard does not present signed punctuation or alphabetic keys.
Provide an app-owned input accessory with a right-arrow action. The arrow moves
through fields in Log Format declaration order; from the final field it saves
the current set using the same guarded action as the visible save button. Do not
add an input formatter that rejects arbitrary characters, because Log Format
field values remain user-authored strings and must still accept paste or
hardware-keyboard input.

## User Stories

1. As a gym user, I want the active set number on the save button, so that I know exactly which set I am recording at the moment of action.
2. As a gym user, I want `Save set S1` to become `Save set S2` after a successful save, so that progress is clear without a separate status heading.
3. As a gym user, I want the selected exercise shown without redundant repeated headings, so that more of the entry form fits above the keyboard.
4. As a gym user, I want a compact `3 sets | 120 s Rest` summary, so that I can see the two planning facts I need quickly.
5. As a gym user, I do not want to see encoded target notation such as `x10-12@8,`, so that sheet storage syntax does not distract from entry.
6. As a gym user, I do not want a `Training details` heading and border around a few facts, so that the screen uses vertical space efficiently.
7. As a gym user, I want the exercise coaching note retained as secondary text, so that important form or safety cues remain available.
8. As a gym user, I want each configured target shown with its field, so that I can interpret `Reps (10-12)` without decoding another summary.
9. As a gym user, I want an explicit zero suggestion shown as `(0)`, so that zero is not confused with missing data.
10. As a gym user, I want fields with no configured target to keep a plain label, so that the app does not pretend a blank is a suggestion.
11. As a gym user, I want configured suggestions to remain visible even when prior history prefills a different value, so that I can compare the plan with my latest performance.
12. As a gym user, I want the suggestion label to reflect the active workout row, so that backup exercises and duplicate placements show their own targets.
13. As a gym user, I want a numeric-focused keyboard without alphabetic keys, so that common set values are faster to enter.
14. As a gym user, I want decimal entry available, so that fractional weights and other decimal values remain practical.
15. As a gym user, I want a large right-arrow control near the keyboard, so that I can advance without reaching back into the form.
16. As a gym user, I want the arrow to follow the declared field order, so that Weight, Reps, RPE, Pain, and custom formats remain predictable.
17. As a gym user, I want the final arrow to save the current set, so that set entry can be completed with one continuous keyboard workflow.
18. As a screen-reader user, I want stable contextual names such as `New set Weight`, so that visual suggestion text does not make field navigation verbose or unstable.
19. As a large-text user, I want suggestion-bearing labels and controls to fit a narrow phone, so that the optimized flow remains usable with accessibility scaling.
20. As a user editing structured values with paste or a hardware keyboard, I want literal text to remain accepted, so that the UI does not narrow the workbook's Log Format contract.
21. As a user, I want failed saves to leave my typed values visible, so that faster entry does not weaken existing error recovery.
22. As a user, I want busy-state protection to prevent duplicate saves from either the button or keyboard arrow, so that a fast interaction cannot create duplicate writes.
23. As a workbook owner, I want this redesign to change presentation only, so that Targets, history notation, validation, and write safety remain intact.
24. As the project owner, I want to inspect the real iOS keyboard and entry flow before release, so that native keyboard behavior is not inferred from widget fakes.

## Implementation Decisions

- This is a presentation and input-interaction change. It does not change the
  workbook schema, Targets encoding, Log Format parsing, history cells, or set
  write planning.
- The screen header and exercise selector remain. The repeated standalone
  selected-exercise heading below the selector is removed.
- The detached `Next set Sn` text is removed. The existing computed next-set
  number supplies the dynamic `Save set Sn` button label.
- The primary action advances only after the existing reread, guarded write,
  and refreshed-report workflow succeeds. Failed input remains visible.
- The bordered training-details panel is replaced with an unframed compact
  summary. The summary contains nonblank Sets and Rest only and never contains
  rendered Targets or Tempo.
- Seconds receive presentation-only spacing, so `120s` is displayed as
  `120 s Rest`. Other existing Rest units remain recognizable and are not
  rewritten in the workbook.
- A nonblank exercise note remains directly below the compact summary without
  the redundant `Notes:` prefix. Blank notes consume no space.
- New-set visual field labels append the active row's nonblank configured target
  value in parentheses. Parentheses contain the value itself, never the word
  `suggestion`.
- Blank targets produce no parenthetical suffix. Explicit zero is nonblank and
  displays as `(0)`. The app never synthesizes zero from a blank.
- Suggestion labels are derived from the active row's Targets map and remain
  independent of controller prefill. The existing prefill rule remains: use the
  latest formatted result when available, otherwise use configured Targets.
- Suggestion suffixes apply to new-set entry only. Editing an already logged set
  retains ordinary field labels because those values are no longer suggestions.
- Accessibility names remain stable and contextual, for example
  `New set Weight`; the visual `Weight (240)` label is not allowed to replace
  that semantic contract.
- Structured set fields request unsigned decimal numeric input. Signed input is
  not requested, which avoids iOS's numbers-and-punctuation layout. No filtering
  rule rejects pasted, hardware-keyboard, or otherwise valid literal text.
- A small app-owned keyboard accessory provides the forward action instead of a
  custom replacement keyboard or a new third-party keyboard dependency.
- The accessory follows Log Format declaration order. Intermediate arrows move
  focus to the next field; the final arrow invokes the same save workflow as
  `Save set Sn` and respects busy-state protection.
- The accessory has an accessible name that describes its current action, a
  compliant tap target, and clear focus/disabled state not conveyed by color
  alone.
- Field widths and wrapping are adjusted where necessary so parenthetical
  suggestions remain usable on narrow phones, large text, and the existing
  compact desktop layout.
- The generated mockups are directional design references. This PRD's clarified
  dynamic labels are authoritative over mockup text that literally says
  `(suggestion)`.

## Testing Decisions

- Use TDD through visible logging-screen and public logging-flow behavior. Do
  not test private string helpers or exact incidental widget nesting.
- Cover the compact summary with representative rest values and verify that
  Targets notation, Tempo, `Training details`, and the detached next-set label
  are absent.
- Cover the retained coaching note as visible secondary text and the blank-note
  state as absent content.
- Verify `Save set S1` emits the existing save command, advances to
  `Save set S2` only after a successful refreshed state, remains unchanged on
  failure, and is disabled while a command is pending.
- Cover suggestion labels for nonblank text, explicit zero, blank values,
  placement-specific targets, and a controller prefilled from more recent
  history. Tests should prove that labels come from Targets, not controller
  text.
- Preserve focused semantics coverage for stable `New set <field>` labels and
  declaration-order traversal.
- Verify the requested unsigned decimal keyboard configuration and the
  accessory's observable Next/final-save behavior. Widget tests establish the
  app contract but do not claim to prove the native iOS keyboard renderer.
- Retain tests showing decimal values, arbitrary pasted or hardware-entered
  literal values, failed-save input preservation, and duplicate-action
  suppression.
- Run narrow-phone and large-text layout checks plus Flutter's labeled-target,
  Android-target, iOS-target, and contrast guidelines for the revised state.
- Use the existing logging UI and integrated logging-flow tests as prior art.
  Keep assertions centered on copy, action behavior, focus order, commands, and
  accessible semantics.
- After TDD, use the test-cleanup skill to remove scaffolding and duplicated
  assertions while retaining the smallest durable public behavior suite.
- Finish with a human iOS review using the software keyboard. A simulator with
  the software keyboard forced visible is sufficient for layout review; a
  physical device is preferred for one-handed interaction. Use a disposable
  workbook copy or another explicitly approved sheet for any save action.

## Out of Scope

- Changing blank Weight or Pain targets to zero.
- Editing the shared reference workbook or running opt-in live Google tests.
- Changing canonical exercise defaults, active-row Targets, Log Format syntax,
  or history notation.
- Replacing the native keyboard with a custom keypad.
- Adding a third-party keyboard package solely for the accessory action.
- Rejecting letters or other literal characters with input formatters.
- Redesigning logged-set history, raw-set editing, exercise selection, recent
  history, workout setup, startup, account, sheet selection, or the sheet
  picker.
- Android release-readiness work or app-store packaging.
- Broad visual theming outside the logging entry screen.

## Further Notes

The shared workbook was inspected read-only to clarify the photographed row.
That Leg Press placement stores Targets as `x10-12@8,`, so Weight and Pain are
blank. Another placement stores `240x10-12@8,0`, demonstrating that configured
values and explicit zeroes are already preserved. The UI must present this
distinction rather than trying to repair or reinterpret it.

The native keyboard layout cannot be proven by Flutter widget tests or by an
adapter fake. Human acceptance must inspect the actual iOS software keyboard,
the app-owned arrow, focus movement, keyboard avoidance, and final-field save
behavior.
