# Workout Logging Interface Refinements

These slices come from a review of the logging flow against real gym use. They
refine feedback, progress reporting, and rest behavior inside the current
navigation; none of them begins the view split described in
`docs/workout_ui_direction.md`.

- [ ] Slice 1: Distinguish Target Values From Entered Values
- [x] Slice 2: Replace Prefilled Set Values by Typing
- [x] Slice 3: Rest After Every Set With a Rest Value
- [x] Slice 4: Signal Rest Completion by Haptic
- [x] Slice 5: Draw the Rest Bar From the App Palette
- [x] Slice 6: Show Logged Sets Against Prescribed Sets
- [x] Slice 7: Remove the Duplicate Exercise Library Heading
- [x] Slice 8: Remove the Unused Light Theme
- [x] Slice 9: Start Rest Before the Sheet Write Completes
- [x] Slice 10: Run the Full Local Guard

## Slice 1: Distinguish Target Values From Entered Values

### Type

`HITL`

### What to build

Make a set-entry value say whether the athlete actually entered it. Fields
arrive prefilled from the most recent logged set or, failing that, from the
row's targets, and nothing currently separates a number the athlete confirmed
from one the app suggested. A value that has not been edited for the current
set renders in a high-visibility amber; once edited it renders as ordinary
entered text. The amber is deliberately louder than entered text rather than
dimmer, because dimmed text is unreadable under gym lighting, and it derives
from the warning seed already used for `VisualSt.warning` so the app keeps one
warm accent rather than two. It must stay distinguishable from the error color,
which already means something is wrong.

Provisional state resets with each set: after a save, values carried into the
next set are suggestions again until the athlete edits them.

The target reference also moves out of its colliding parenthetical. A field
whose name already carries a unit currently reads `Height (in) (12)`; it
becomes `Height (in) → 12`, which stays legible and keeps the target visible
after the athlete overwrites the value.

### Acceptance criteria

- [x] A behavior test first demonstrates that an untouched prefilled field renders its value in the provisional style while an edited field does not.
- [x] Editing a field clears its provisional state for the current set.
- [x] Saving a set returns the values carried into the next set to the provisional style until they are edited.
- [x] The provisional color derives from the existing warning seed rather than a new literal, and is distinct from the error color.
- [x] A field with a target renders `Height (in) → 12`; a field without one renders the bare label.
- [x] Semantics announce the provisional state, so the distinction is never carried by color alone.
- [x] `textContrastGuideline` passes for provisional and entered values.
- [x] Three-field and five-field formats are checked on an iPhone 13 mini sized viewport.
- [ ] The owner confirms the provisional color is legible under gym lighting.

### Blocked by

None - can start immediately.

### User stories covered

- Review decision: prefill is kept, but a suggested value must never be mistaken for a recorded one.
- `docs/accessibility.md`: state conveyed by color is also present in semantics.

## Slice 2: Replace Prefilled Set Values by Typing

### Type

`AFK`

### What to build

Focusing a set-entry field selects its whole contents, so the first keystroke
replaces the value instead of appending to it. The caret currently lands after
the existing text, so changing a prefilled `8` to `10` yields `810` unless the
field is cleared first. Recording a deviation from the target is the ordinary
case rather than the exception, so the common path should cost one tap and one
entry.

The same behavior applies wherever a set is edited, including the formatted
fields and the raw text field behind a logged set's edit control.

### Acceptance criteria

- [x] A behavior test first demonstrates that focusing a prefilled field and typing replaces its value rather than appending to it.
- [x] Selection covers the full value on focus for every field in a format, including the last.
- [x] Advancing with the in-field next arrow selects the destination field's contents the same way.
- [x] Re-focusing a field the athlete already edited also selects its contents.
- [x] Editing a logged set through its edit control behaves identically for formatted and raw fields.
- [x] Existing logging, keyboard traversal, and set-entry tests pass unchanged.

### Blocked by

- Distinguish Target Values From Entered Values

### User stories covered

- Review decision: prefill stays, and correcting a prefilled value must be cheap.

## Slice 3: Rest After Every Set With a Rest Value

### Type

`AFK`

### What to build

A saved set starts the rest timer whenever its exercise declares a usable Rest
value, whatever the Sets cell contains. The timer is currently suppressed
unless Sets parses as a plain integer, which lets the app decide not to rest
after the final set — but it also means an exercise written as `3-4`, `AMRAP`,
or `3 x 8` silently never rests at all, for any set, with no indication why.
The workbook is human-authored free text, so those spellings are reachable.

Replace the conditional with one predictable rule: rest after every saved set.
The final timer of an exercise is dismissed with Done, which is cheaper than a
timer that never appears and is never noticed.

### Acceptance criteria

- [x] A behavior test first demonstrates a rest timer starting after a saved set whose Sets cell is not a plain integer.
- [x] A rest timer starts after every saved set for an exercise with a usable Rest value, including the last prescribed set.
- [x] An exercise with a blank or unparseable Rest value starts no timer.
- [x] Every supported Rest spelling still resolves, including `3 min`, `90s`, `1.5 min`, and `3:00`.
- [x] Tests asserting suppression after the final set are removed or rewritten to the new rule.

### Blocked by

None - can start immediately.

### User stories covered

- Review decision: always rest, never suppress.

## Slice 4: Signal Rest Completion by Haptic

### Type

`AFK`

### What to build

When the countdown reaches zero the phone gives a haptic pulse. The app has no
feedback of any kind today: the bar simply disappears, so a countdown watched
from across a bench ends silently and unnoticed. The signal is haptic only —
an audible alert is intrusive in a shared gym. A configurable sound is possible
later and is out of scope here.

The signal is injected the way the wake-lock setter is, so behavior is
verifiable without a device and a missing platform channel leaves the timer
usable.

### Acceptance criteria

- [x] A behavior test first demonstrates a completion signal firing exactly once when the countdown reaches zero.
- [x] Ending the timer with Done, or starting a new timer over a running one, fires no signal.
- [x] A timer whose remaining time elapsed while the app was backgrounded fires the signal once on resume.
- [x] The signal is a haptic only; no sound is played.
- [x] The signal is injectable, and an absent platform channel neither throws nor stops the timer.

### Blocked by

None - can start immediately.

### User stories covered

- Review decision: haptic on completion, no sound, no notification.

## Slice 5: Draw the Rest Bar From the App Palette

### Type

`AFK`

### What to build

The rest bar takes its surface, countdown, and control colors from the app's
color scheme instead of three hardcoded browns that sit outside the palette
entirely. It remains a strongly contrasting surface, because rest state should
be unmistakable at a glance from across the room, but that contrast is chosen
from the palette rather than from outside it.

The countdown continues to display whole remaining seconds. Minutes and seconds
were considered and rejected: the athlete reasons in seconds, so a `1:57`
readout would add a conversion rather than remove one.

### Acceptance criteria

- [x] The rest bar declares no hardcoded color literals.
- [x] Surface, countdown text, and both controls derive from color scheme roles.
- [x] The bar remains visually distinct from the ordinary page surface and from the provisional value color.
- [x] `textContrastGuideline` passes for the countdown and both control labels.
- [x] The countdown still displays whole remaining seconds.
- [x] Rest timer tests pass unchanged.

### Blocked by

- Signal Rest Completion by Haptic

### User stories covered

- Review decision: re-derive the rest bar from the theme; keep the seconds readout.

## Slice 6: Show Logged Sets Against Prescribed Sets

### Type

`AFK`

### What to build

An exercise tile reports progress as logged against prescribed, `1 of 3 sets`,
so the list the athlete returns to between exercises says what is left without
opening anything. A tile currently shows a logged count worded identically to a
prescription, so `1 set` on a three-set exercise reads as though one set were
programmed.

The workout selector has a related defect. It appends progress inside the same
ellipsized text as the workout name, so a name long enough to truncate loses
its progress entirely while shorter names keep theirs. Progress becomes its own
element that survives truncation of the name.

### Acceptance criteria

- [x] A behavior test first demonstrates a tile reporting both its logged and prescribed set counts.
- [x] A tile with no logged sets and a tile with every prescribed set logged both read unambiguously.
- [x] An exercise whose Sets cell is not a plain integer reports its logged count without inventing a total.
- [x] The workout selector shows progress for a workout name long enough to truncate.
- [x] Truncation still applies to the name itself and the selector stays single-line on a narrow phone.
- [x] Semantics convey the same progress the visual conveys, for both the tile and the selector.
- [x] History block and workout selector order is unchanged.

### Blocked by

None - can start immediately.

### User stories covered

- Review decision: report logged against prescribed, and stop truncation from swallowing progress.

## Slice 7: Remove the Duplicate Exercise Library Heading

### Type

`AFK`

### What to build

The exercise library renders `Edit exercises` twice, once as the screen
header's subtitle and again as a heading immediately beneath it. One is
removed so the screen opens on its search field and list rather than on a
repeated title.

### Acceptance criteria

- [x] The phrase appears once on the screen.
- [x] The screen keeps an accessible heading and its screen label is unchanged.
- [x] Vertical space above the search field is recovered on a narrow phone.
- [x] Library and search tests pass unchanged.

### Blocked by

None - can start immediately.

### User stories covered

- Review decision: remove the duplicate heading.

## Slice 8: Remove the Unused Light Theme

### Type

`AFK`

### What to build

The app pins its theme mode to dark, so the light `ThemeData` constructed
alongside it is never used. Dark-only is permanent, so that configuration is
removed and a single theme is built for the dark brightness.

The input decoration theme carrying the always-floating label behavior lives in
the same builder and must survive the removal.

### Acceptance criteria

- [x] A single `ThemeData` is constructed, for dark brightness.
- [x] The app presents dark regardless of the system appearance setting.
- [x] The always-floating label behavior remains in effect app-wide.
- [x] Shell tests pass unchanged.

### Blocked by

None - can start immediately.

### User stories covered

- Review decision: dark-only is permanent.

## Slice 9: Start Rest Before the Sheet Write Completes

### Type

`AFK`

### What to build

Saving a set starts the rest timer as soon as the set is known to be savable,
rather than after the spreadsheet write returns. Rest is a physical clock that
begins when the athlete racks the bar, so on a slow connection the countdown
currently starts late by the full network latency: the remaining time shown is
wrong for the whole set, and the tap produces no feedback until the write
lands.

The timer must not start when there is nothing to save. Planning a set returns
no plan when every field is blank, and that case saves nothing today. Start the
timer only once a plan exists, then await the write as before. Reporting a
failed write is unchanged.

One consequence is accepted deliberately: if a write fails and the athlete
retries, the countdown restarts. A failed save already interrupts the set, and
the alternative is per-set bookkeeping about whether a timer is already
running.

This does not make logging work on a poor connection. Saving stays blocked
until the write completes, and a single save costs at least three sequential
round trips — a re-read to validate the plan against current state, the write,
and a confirming read that retries while the change is not yet visible.
Reducing those round trips, and entering data while offline, are deliberately
out of scope here.

### Acceptance criteria

- [x] A behavior test first demonstrates the rest timer running while a set write is still in flight.
- [x] Tapping save with every field blank saves nothing and starts no timer.
- [x] A write that ultimately fails leaves the started timer running and still reports the failure.
- [x] Retrying a failed save restarts the countdown, asserted rather than left incidental.
- [x] An exercise with no usable Rest value starts no timer, whatever the write does.
- [x] Existing logging and rest timer tests pass unchanged.

### Blocked by

- Rest After Every Set With a Rest Value

### User stories covered

- Review decision: start rest on the intent to save, not on write acknowledgment.
- Deferred: entering data on a poor connection, and reducing the round trips a save costs.

## Slice 10: Run the Full Local Guard

### Type

`AFK`

### What to build

Run the repository's broad validation gates once every preceding slice has
landed, since each slice runs only the focused tests its change requires.

No live Google validation is required. No slice in this plan changes workbook
writes, schema validation, or format routing, and the progress work reads the
active sheet without writing to it.

### Acceptance criteria

- [x] `dart format --output=none --set-exit-if-changed lib test integration_test dev` reports no changes.
- [x] `flutter analyze` reports no issues.
- [x] `flutter test` passes in full.
- [x] The macOS accessibility probe was skipped: the unsigned local preview
  launched, but this Codex host exposed only shallow `AXGroup`/`AXTextField`
  roles rather than Flutter's semantic labels.

### Blocked by

- Every preceding slice

### User stories covered

- `docs/testing.md`: run the broad gates before a release or after a broad refactor.
