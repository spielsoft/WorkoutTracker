# Timed Exercise Countdown PRD

## Problem Statement

WorkoutTracker can prescribe and log fixed-duration exercises such as a
20-second Side Plank, but it cannot time them. The athlete must leave the app,
open a separate timer, enter the duration again, wait for it to finish, and
return to log the set. That interruption is especially awkward during an
exercise when the athlete cannot safely interact with the phone.

The existing rest timer already supplies most of the countdown mechanics, but
field labels cannot determine whether a timer should appear. A field named
`Seconds` may intentionally remain an ordinary numeric value, while a timer may
be wanted for a differently named field. Inferring behavior from the field
label or its displayed unit would violate the existing rule that Log Format
labels are exact user-authored data rather than application-owned semantics.

The workbook and bundled exercise catalog also serve different purposes. The
catalog seeds a new workbook once; it is never synchronized into an existing
workbook. The selected workbook's `Exercises` tab must therefore own timer
configuration at runtime, while the catalog must carry the same configuration
only so future workbooks begin with the intended defaults.

## Solution

Add an explicit per-field timer capability to canonical exercises. Each Log
Format field has one of two MVP states: no timer or a countdown interpreted in
seconds. Store the enabled field labels in a new human-visible `Timer Fields`
column on the workbook's `Exercises` tab. A blank cell means no fields are
timed; a populated cell uses an exact list such as `['Seconds']`. Timer labels
must be unique fields declared by the same row's Log Format.

Move the workbook contract directly to schema version 1.1. Do not build an
in-app migration. New workbooks receive the new column and version from the
start. Upgrading an existing workbook is owner-performed work outside this
plan; version 1.0 workbooks remain rejected until the owner completes it. No
slice in this plan reads, writes, or requires a real workout Sheet.

Extend exercise authoring with a single `Timer` checkbox column beside the
generated default-value rows. In workout logging, show a timer icon only beside
timer-enabled fields in the new-set editor. Pressing it reads the field's
current positive numeric value as seconds and starts an exercise countdown.
Starting does not edit, confirm, or save the field. When the countdown ends, by
expiry or by Done, the app writes the elapsed duration into that field and
marks the value recorded, so a hold stopped early reports what was performed
rather than what was prescribed. Saving the set stays a separate explicit
action. Fractional seconds remain exact in the countdown deadline, while the
visible remaining time and the recorded value use ordinary nearest-integer
rounding.

Generalize the existing global countdown presentation without carrying rest
behavior into exercise timing. The bar has a heading row above its existing
symmetric controls. Rest shows `REST`; exercise timing shows the full exercise
name. Starting an exercise countdown replaces any current rest countdown and
locks the rest of the app until the exercise expires or the athlete presses
Done. Pause and `+30 s` remain available, and pausing does not unlock the app.
Rest countdowns remain nonmodal.

Replace the existing completion impact thunk with one full system vibration
for both rest and exercise countdowns. Foreground timing is sufficient for the
MVP. The app keeps the workout screen awake and preserves the exact deadline
across lifecycle changes, but it does not request notification permission or
promise an alert while iOS has suspended the process.

## User Stories

1. As an athlete, I want to time a fixed-duration exercise without leaving WorkoutTracker, so that my workout flow is uninterrupted.
2. As an athlete, I want the timer to start from the value already in the set field, so that I do not enter the duration twice.
3. As an athlete, I want a timer icon only on fields configured for timing, so that ordinary numeric fields remain uncluttered.
4. As an athlete, I want a `Seconds` field to remain untimed when configured that way, so that labels never force application behavior.
5. As an athlete, I want a differently named numeric field to be timeable, so that my exercise vocabulary is not constrained by the app.
6. As an athlete, I want fractional seconds to affect the actual deadline, so that precise prescriptions are honored.
7. As an athlete, I want the displayed countdown rounded to an integer, so that it remains quick to read during an exercise.
8. As an athlete, I want the full exercise name above the countdown controls, so that I can distinguish exercise timing from rest.
9. As an athlete, I want rest timers labeled `REST`, so that the shared countdown presentation is unambiguous.
10. As an athlete, I want an exercise timer to replace an active rest timer, so that only one global countdown competes for attention.
11. As an athlete, I want the rest of the app locked while an exercise countdown is active, so that accidental taps cannot alter my workout while I am exercising.
12. As an athlete, I want pausing the exercise countdown to keep the app locked, so that pause is not an accidental escape from exercise mode.
13. As an athlete, I want Done to end exercise timing and restore the app, so that I can stop early when necessary.
14. As an athlete, I want `+30 s` to remain available, so that I can extend a countdown without recreating it.
15. As an athlete, I want an expired exercise timer to unlock the app automatically, so that I can immediately log the completed set.
16. As an athlete, I want one full vibration when a countdown expires, so that completion feels like an alert rather than a button impact.
17. As an athlete, I want rest timers to remain nonmodal, so that I can enter or review workout information while resting.
18. As an athlete, I want timer controls only on new-set entry, so that editing historical sets cannot unexpectedly start an exercise.
19. As an athlete, I want starting a timer to leave my field value unchanged, so that timing does not silently confirm or save workout data.
20. As an athlete, I want blank, zero, negative, or nonnumeric timed fields not to start a countdown, so that invalid durations fail safely.
21. As an athlete, I want visible next-field arrows removed, so that each entry row has only controls I use in the gym.
22. As an athlete, I want to reach the next field by tapping it, and by Tab on a hardware keyboard as I could before the arrows existed, so that removing the visible arrows costs no traversal I actually use.
23. As a screen-reader user, I want the timer icon named for its exercise and field, so that its action and source value are clear.
24. As a screen-reader user, I want exercise mode to hide locked controls from accessibility focus, so that unavailable actions are not announced as usable.
25. As a user with large text or a narrow phone, I want the full exercise heading and timer controls to remain readable and tappable, so that timing is usable on supported layouts.
26. As an exercise author, I want one shared Timer heading over a column of field checkboxes, so that timer configuration is compact and explicit.
27. As an exercise author, I want timer selections to save with the canonical exercise, so that every placement of that exercise behaves consistently.
28. As an exercise author, I want Timer Fields validated against Log Format, so that stale or misspelled timer labels cannot create ambiguous behavior.
29. As a workbook owner, I want Timer Fields stored visibly in my Sheet, so that the app does not hide workout configuration in a backend.
30. As a workbook owner, I want no Timer Fields active when the cell is blank, so that untimed exercises remain easy to inspect and edit directly.
31. As a workbook owner, I want all placements to use their canonical exercise's timer configuration, so that I do not maintain repeated row-local copies.
32. As a workbook owner, I want existing history and active workout values unchanged by the schema update, so that adding timers cannot rewrite workout data.
33. As a workbook owner, I want to upgrade my own workbooks myself after this work ships, so that no automated step in this plan ever touches my real workout data.
34. As a user creating a new workbook, I want the bundled exercise catalog to seed Timer Fields correctly, so that timed exercises work immediately.
35. As a catalog maintainer, I want every bundled exercise to declare `timerFields` explicitly, so that intended defaults are reviewable in source.
36. As a catalog maintainer, I want a missing `timerFields` property interpreted as empty, so that external or older catalog entries remain safely untimed.
37. As a Side Plank user, I want its Seconds field timed by default in a newly created workbook, so that the primary MVP example works without editing the exercise.
38. As a Copenhagen Side Plank or Plank user, I want each remaining duration-based catalog exercise timed by default in a newly created workbook, so that they behave consistently with Side Plank.
39. As a maintainer, I want one countdown engine to own deadlines, lifecycle correction, pause, extension, completion, and signaling, so that rest and exercise timers cannot drift apart.
40. As a maintainer, I want rest and exercise policies supplied explicitly to the shared countdown, so that sharing a widget does not accidentally share modal behavior.
41. As a maintainer, I want timer metadata parsed and rendered behind a small contract, so that Sheet syntax does not leak throughout UI code.
42. As a maintainer, I want public behavior tests rather than private widget-tree tests, so that timer internals can be refactored safely.
43. As a project owner, I want the full vibration and modal exercise flow verified on physical iOS, so that simulator-only evidence does not approve hardware behavior.
44. As a project owner, I want no ordinary workout Sheet or live Google fixture changed without explicit approval, so that validation cannot damage real data.
45. As an athlete, I want a timer I stop early to record the time I actually held, so that a shortened set reports what I did rather than what was prescribed.
46. As an athlete, I want a countdown that runs to expiry to record its full duration, so that finishing a prescribed hold does not leave the value still reading as an unconfirmed suggestion.
47. As an athlete, I want a recorded value to read as real performed data rather than a suggestion, so that I can tell at a glance which numbers the timer measured.
48. As a maintainer, I want suggested, entered, and recorded to be one explicit value-origin concept, so that logging state cannot drift into overlapping boolean flags.

## Implementation Decisions

- Timer capability is explicit metadata and is never inferred from `Seconds`,
  `Minutes`, punctuation, defaults, targets, notes, or any other field content.
- The MVP has only two states per Log Format field: no timer or timer in
  seconds. A list of enabled labels is sufficient; do not introduce a general
  unit/type system.
- The workbook's canonical `Exercises` tab is the runtime source of truth.
  Timer metadata is not copied to the active workout tab and has no
  placement-level override.
- Add `Timer Fields` as a required Exercises column in schema 1.1. Its value is
  blank for no timers or a human-visible exact list of field labels such as
  `['Hold']`.
- Timer Fields parsing rejects malformed lists, duplicates, and labels absent
  from that exercise's parsed Log Format. Rendering follows Log Format
  declaration order so direct Sheet edits remain stable and reviewable.
- Existing schema versions do not gain an automatic or confirmed timer
  migration. Version 1.0 workbooks are rejected until manually upgraded, and
  legacy conversion code must not produce or accept a workbook that falsely
  claims 1.1 compatibility. Performing that manual upgrade is outside this
  plan.
- The bundled JSON catalog remains a one-time new-workbook seed. It does not
  update or merge into an existing Exercises tab.
- Catalog `timerFields` is an array of exact labels. A missing property parses
  as an empty array, although all maintained catalog records declare it
  explicitly.
- The maintained catalog enables `Seconds` for every duration-based exercise -
  Side Plank, Copenhagen Side Plank, and Plank - and leaves every other current
  exercise empty. Plank was seeded after Slice 1 landed.
- Exercise creation and editing show generated default-value rows with one
  shared `Timer` column heading and one accessible checkbox per Log Format
  field.
- Changing a canonical exercise's Timer Fields affects every current and
  future placement because all placements resolve the same canonical exercise.
- Timer configuration changes do not rewrite targets, history, or active rows.
- Timer start controls appear only in the new-set editor. Logged-set editing,
  history summaries, targets, and exercise placement screens do not start
  timers.
- The timer icon reads the field controller at the moment it is pressed.
  Starting does not mutate the field, mark a suggestion confirmed, save a set,
  or start rest.
- Ending a countdown that a field started writes that field's elapsed duration
  and marks the value recorded. Expiry writes the full duration; Done writes
  the time actually elapsed. Rounding matches the countdown display, and saving
  the set stays explicit.
- A logging value has exactly three origins: suggested when prefilled and not
  yet confirmed, entered when the athlete typed it, and recorded when a timer
  measured it. A recorded value must not be styled as a suggestion. Sharing the
  entered treatment is acceptable because it is real performed data; any
  distinct treatment must not rely on color alone.
- A countdown starts only from a positive finite numeric seconds value.
  Fractional seconds are accepted and retained in the actual deadline.
- Remaining time is computed from a deadline rather than by subtracting whole
  ticks. The visible number uses ordinary nearest-integer rounding.
- The shell owns one global countdown. Starting any new countdown replaces the
  current one.
- Countdown presentation has a full-width heading row above the symmetric
  `+30 s`, countdown/pause, and Done controls. The heading is `REST` for rest
  or the complete exercise name for exercise timing; it may wrap rather than
  truncate away identity.
- Exercise timing is modal. The underlying app is visibly dimmed, cannot
  receive pointer or navigation actions, and is removed from accessibility
  focus until Done or expiry. Pausing does not remove the lock.
- Rest timing retains its current nonmodal workflow, including starting from a
  saved set and surviving navigation.
- The visible next-field arrow control is removed app-wide. Framework keyboard
  traversal may remain, but no separate arrow button is shown.
- Completion calls the platform's full vibration once for both countdown
  kinds. It does not loop until dismissal and does not add sound.
- Foreground timing is the supported MVP. Keep the screen awake and preserve
  elapsed-time correctness across lifecycle changes, but do not add local
  notifications, background execution, or notification permission.
- Prefer one deep countdown module that owns precise deadlines, pause/resume,
  extension, lifecycle correction, completion, and signal dispatch behind a
  small public state/action surface. Keep workbook notation and validation in
  the contract layer, exercise authoring in presentation/application code, and
  timer policy in the shell rather than coupling those concerns.

## Testing Decisions

- Follow TDD through public workbook, application, and visible UI behavior.
  Tests should not assert private helper names, exact widget nesting, timer
  implementation classes, or incidental callback order.
- Workbook contract tests cover the schema 1.1 header, version rejection,
  Timer Fields parsing, empty values, exact-label validation, duplicate and
  unknown labels, canonical read models, and stable rendering order.
- Write-plan tests cover creation and editing of Timer Fields while proving
  that active rows, targets, and history remain unchanged.
- Template tests cover JSON omission as empty, explicit arrays on all current
  records, the three default timed exercises, nine-column Exercises rows, and
  version 1.1 metadata for new workbooks.
- Exercise authoring tests cover the shared Timer heading, declaration-order
  checkboxes, create/edit round trips, disabled busy state, and accessible
  checkbox names without pinning the exact responsive layout tree.
- Countdown tests use an injected clock and completion signal to prove exact
  fractional deadlines, rounded display, pause/resume, `+30 s`, replacement,
  lifecycle correction, one completion signal, and Done. Fakes prove the app's
  signaling request, not the physical vibration.
- Existing rest-timer behavior tests remain the prior art and must demonstrate
  that rest remains nonmodal, starts on set save, survives navigation, and is
  labeled distinctly after the shared presentation change.
- Logging UI tests cover icon presence only for canonical Timer Fields,
  current-value reads, positive fractional durations, invalid disabled states,
  new-set-only scope, replacement of rest, modal locking, pause, Done, expiry,
  and unchanged field/save behavior.
- Accessibility tests cover descriptive timer actions, explicit rest/exercise
  identity, locked content excluded from semantics, tap-target guidelines,
  contrast, narrow widths, and large text.
- App-wide UI tests confirm visible next-field arrows are absent while ordinary
  tapping and keyboard Next traversal remain usable.
- Use the `test-cleanup` skill after TDD implementation to remove tests that
  pin temporary seams or widget structure while retaining the smallest durable
  public behavior safety net.
- Run focused tests per slice, formatting checks, static analysis, the complete
  local suite, the repository accessibility guard, and any architecture guard
  defined by the repository at execution time.
- Physical iOS owner acceptance is required for the full system vibration,
  exercise-mode lock, full-name two-row layout, rounded fractional countdown,
  recorded duration, and unlock behavior. Simulator tests cannot establish
  hardware vibration. That acceptance runs the in-memory `dev/gym_preview.dart`
  harness on a physical device, so it needs no upgraded workbook and no Google
  access.
- No slice in this plan reads or writes a real workout Sheet. Do not enable
  live Google tests and do not write to any workout workbook. Upgrading a
  workbook to schema 1.1 is owner-performed work after this plan completes.

## Out of Scope

- Inferring timer behavior from a field named Seconds, Minutes, Time, Hold, or
  any other user-authored label.
- Timer units other than seconds, including minute-mode configuration.
- A general field type, unit, validation, or plugin system.
- Per-workout, per-placement, per-set, or backup-specific timer overrides.
- Automatically starting a timer from a target without the athlete pressing
  the icon.
- Automatically saving a set or starting rest when an exercise timer starts
  or expires. Writing the measured duration into its own field is in scope;
  committing that set to the Sheet is not.
- Timer controls while editing logged history.
- Multiple simultaneous countdowns or preserving a displaced rest timer.
- Unlocking the app merely because the exercise countdown is paused.
- Repeating vibration until dismissal, audible alarms, music ducking, or custom
  haptic patterns.
- Guaranteed alerts while the app is suspended, background execution, local
  notifications, notification permissions, Lock Screen widgets, or Live
  Activities.
- An in-app schema 1.0-to-1.1 migration, automatic workbook mutation, or JSON
  synchronization into existing workbooks.
- Adding Timer Fields to the active workout tab.
- Counting up, open-ended holds, or any max-effort timing mode. A
  hold-as-long-as-you-can option is separate future work.
- Upgrading either owner workbook, or touching any real workout Sheet or live
  Google fixture, at any point in this plan.
- Android readiness or Android hardware acceptance.

## Further Notes

The existing timer is named and presented as a rest timer, but its controller
already owns useful countdown behavior: pause, resume, time extension,
lifecycle correction, Done, and completion signaling. Reusing those mechanics
should mean extracting explicit countdown state and policy rather than making
exercise timing call rest-specific application callbacks.

The present medium-impact haptic is the source of the reported completion
defect. The prepared Flutter SDK exposes a default platform vibration distinct
from impact feedback; the physical iOS gate verifies that this produces the
intended full buzz.

The two current duration-based catalog definitions both use the exact field
label `Seconds`, even though one Log Format also emits a literal `s`. Timer
configuration still remains explicit so future exercises and owner-authored
fields are not coupled to those examples.
