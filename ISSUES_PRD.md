# Workout UI and Interaction Reliability PRD

## Problem Statement

WorkoutTracker now covers the MVP feature set and presents a generally coherent
Material interface, but several important workflows still make users think
about the application's internal structure rather than the workout they are
performing.

Exercise authoring accepts a literal log format without explaining or validating
it before writing. An invalid value can therefore turn a valid workbook into a
blocking validation state. Workbook mutations also do not yet pass through one
authoritative command gate, leaving correctness dependent on individual screens
disabling the right controls at the right time.

Navigation has two nearly identical workout-list screens and no native page
history for most feature transitions. This adds a generic Select step, creates
multiple paths into logging, and prevents Android back and iOS back gestures
from behaving like users expect.

The phone logging layout is functional but not optimized for repeated use in a
gym. The primary save action can appear before the values it saves, keyboard
flow does not move efficiently between fields, existing sets remain as large
editable forms, training targets become harder to see as the workout grows, and
clearing a set has no recovery path. The exercise library similarly requires
long scrolling once a sheet contains many exercises.

The remaining work should make the shortest common path obvious and safe:
choose a workout, tap an exercise, enter a set, save it, and continue.

## Solution

Provide one workout home screen that owns workout and history selection as well
as the exercise list. Selecting either value updates the list immediately; no
separate Select step or duplicate workout-list page remains. Feature pages are
represented in a native page stack so back buttons, Android system back, and
iOS back gestures all return to the actual originating page.

Put all workbook mutations behind a single command owner that exposes pending
state and prevents overlapping writes. Screens consume this state rather than
each inventing a partial concurrency policy.

Turn exercise log-format authoring into a guided editor. The user keeps the
human-readable literal syntax, but sees immediate validation and an example
preview before saving. Invalid formats are rejected both by the form and by the
write-planning contract, so no application path can author workbook damage.
Dirty authoring forms protect entered work when the user navigates away.

Redesign logging around the active set. Training targets and rest remain visible
near the top, fields appear before their save action, focus advances through the
fields, and the final keyboard action saves. Input must support decimal values
and arbitrary literal field values without inferring meaning from a user-authored
field label. Previously logged sets render as compact summaries and expand only
when edited. Clearing a set provides an undo path.

Add local search to the exercise library while retaining canonical sheet order.
Reordering remains available only when the complete unfiltered order is visible.
Finish with responsive light/dark visual QA so the hierarchy, state colors, and
contrast remain coherent across phone and desktop layouts.

## User Stories

1. As a person starting a workout, I want workout and history choices on the same screen as my exercises, so that I do not pass through a redundant confirmation screen.
2. As a returning user, I want my saved workout and history choice restored on the workout home screen, so that I can resume with one tap.
3. As a user changing workouts, I want the exercise list to update immediately, so that the result of my selection is obvious.
4. As a user opening an exercise from workout home, I want Back to return to workout home, so that navigation is predictable.
5. As an Android user, I want system Back to follow the in-app page history, so that it does not unexpectedly exit the application.
6. As an iOS user, I want the standard back gesture to work on feature pages, so that the app behaves like other iOS applications.
7. As a user with unsaved exercise changes, I want a warning before leaving, so that an accidental back gesture does not erase my work.
8. As a user creating an exercise, I want the log-format syntax explained in place, so that I do not need documentation beside the form.
9. As a user creating an exercise, I want immediate format validation, so that I can correct mistakes before saving.
10. As a user creating an exercise, I want to see a representative rendered log example, so that I understand what will be written to the sheet.
11. As a workbook owner, I want every application write path to reject an invalid log format, so that the app cannot damage its own workbook contract.
12. As a user saving any workbook change, I want one clear pending state, so that I know the action is still running.
13. As a user who taps twice, I want only one workbook mutation to execute, so that latency cannot create duplicate or conflicting writes.
14. As a user navigating during a write, I want unsafe actions blocked consistently while safe viewing remains possible, so that the app does not enter an ambiguous state.
15. As a user logging a set on my phone, I want to enter values before reaching Save, so that the layout follows the order of the task.
16. As a user logging several fields, I want the keyboard action to advance to the next field, so that I do not tap every field manually.
17. As a user on the final field, I want the keyboard action to save the set, so that set entry can be completed without reaching for another control.
18. As a user logging fractional weight or RPE, I want decimal values to be accepted, so that the keyboard does not prevent valid workout data.
19. As a user with a custom literal field, I want to enter non-numeric text when needed, so that the UI does not reinterpret my sheet contract.
20. As a user between sets, I want target sets, reps, RPE, and rest visible near the active editor, so that I do not scroll to recall the plan.
21. As a user reviewing completed sets, I want each saved set summarized compactly, so that the current set remains the visual priority.
22. As a user correcting a saved set, I want to expand only that set for editing, so that the screen does not become a wall of fields.
23. As a user who accidentally clears a set, I want to undo the clear, so that a stray tap does not permanently erase logged data.
24. As a user with a large exercise library, I want to search by exercise name or description, so that editing an item does not require long scrolling.
25. As a user searching the exercise library, I want results to retain canonical sheet ordering, so that filtering does not imply a different persisted order.
26. As a user reordering exercises, I want reordering available only when the full order is visible, so that a filtered move cannot have a surprising result.
27. As a user with dark appearance enabled, I want the app to follow the system theme, so that it is comfortable in different environments.
28. As a user with large text or a narrow phone, I want controls and status information to remain readable without clipping, so that the app remains usable with accessibility settings.
29. As a desktop user, I want content density and width to remain intentional as the window grows, so that forms do not become visually disconnected.
30. As a maintainer, I want behavior-focused tests around the final public screen and command contracts, so that later layout refactors are not blocked by implementation-pinned tests.

## Implementation Decisions

- Keep the Google Sheet as the source of truth and preserve the existing workbook contract and literal log-format language.
- Use the existing log-format parser as the canonical validation rule. The form may present friendlier messages and a preview, but it must not implement a competing parser.
- Add a planner-level rejection for invalid application-authored log formats. UI validation improves feedback; the planner is the safety boundary.
- Keep authoring drafts local until submission. Track whether a draft differs from its initial normalized value and require confirmation before discarding a dirty draft.
- Introduce one authoritative single-flight command owner for loaded-workbook mutations. Busy state, failure reporting, and completion belong to that owner, not to individual buttons.
- Do not prove external Google behavior with fakes. Concurrency tests should assert this application's command interface and emitted plans only.
- Replace the separate setup and workout list destinations with one workout home experience. Workout and history selectors update the visible list immediately.
- Represent feature navigation as a page stack with typed page state. The stack must preserve origin naturally instead of adding more origin flags.
- AppShell remains a composition and top-level routing surface; it must not interpret domain commands.
- Preserve the current direct tap target for opening an exercise and the row-specific menu for backup and delete actions.
- Place training targets and rest near the new-set editor. Longer notes and deeper history may remain collapsible secondary information.
- Render logged sets as read-only summaries by default. At most one set editor should be expanded at a time on a phone.
- Undo for clearing a set must restore the exact prior raw value through the normal workbook command path and stale-write protections.
- Do not infer field semantics from labels such as Weight, Pain, or RPE. Input behavior must allow decimals and arbitrary literal values.
- Exercise-library search is local and case-insensitive across display name and description. It does not change persisted ordering.
- Disable reorder controls while a library filter is active. Clearing the filter restores the same canonical order and scroll behavior.
- Add a dark color scheme derived from the application seed, then make custom logged/current/backup/warning/error styles theme-aware rather than relying on fixed light colors.
- Preserve the existing accessibility semantics interfaces and verify phone, desktop, large-text, light, and dark representative states.
- Keep modules deep: navigation history, command serialization, log-format validation/preview, and recoverable set clearing should each have one clear owner rather than scattered widget flags.

## Testing Decisions

- Tests should assert observable behavior through screen action interfaces, the loaded-workbook command interface, and the public sheet-contract planner.
- Exercise-authoring tests should cover friendly invalid-format feedback, preview output, planner rejection, dirty-form cancellation, and successful valid submission.
- Command tests should prove that a second mutation cannot overlap the first and that busy/error state is released after both success and failure.
- Navigation tests should cover workout home, logging, exercise library, creation, editing, placement, Android-style back dispatch, and preservation of the actual origin page.
- Logging tests should cover field order at phone width, focus/submit behavior, decimal and text entry, visible training targets, compact set summaries, one expanded editor, clear, and undo.
- Exercise-library tests should cover name/description matching, canonical result order, empty results, clearing search, and reorder availability.
- Theme and accessibility tests should reuse the existing broad accessibility guideline test and add representative dark-theme, large-text, narrow-phone, and wide-desktop states.
- Do not assert private helper names, widget-tree trivia, internal route enum values, or exact implementation call order unless that order is an intentional command-interface contract.
- Use targeted widget and contract tests during each slice. Run the full Flutter suite, static analysis, and clean macOS and unsigned iOS release builds at the final gate.
- Finish with the `test-cleanup` skill to remove temporary TDD scaffolding and retain only the smallest durable behavioral safety net.

## Out of Scope

- Coaching, progression recommendations, timers, notifications, or program-generation features.
- Changes to the Google Sheet schema or literal log-format syntax.
- An application-owned workout database or synchronization backend.
- Deleting canonical exercises from the library.
- Arbitrary sorting of the canonical exercise library independent of sheet order.
- Proving Google Drive, Google Sheets, OAuth, or platform behavior with simulated third-party responses.
- Broad visual rebranding, custom illustration work, or a new design system beyond the existing Material direction.
- Live development-sheet writes unless a later implementation slice explicitly requires and prepares an opt-in integration run.

## Further Notes

The simple findings from the third review were completed before this PRD was
written. Current code now distinguishes create and edit forms, propagates busy
state into those forms, removes unused authoring UI, names placement context,
returns primary placement to the correct origin, uses truthful "started"
progress wording, explains signed-out account-menu login, replaces stale picker
results with retry guidance, and centers non-fullscreen content at its width
limit. These completed items must not be reopened by the issue plan.

The remaining work deliberately favors interaction simplification over adding
features. The strongest success metric is fewer decisions and taps on the path
from opening the app to saving the next set, without weakening workbook safety.
