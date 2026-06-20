# Mobile-First UI PRD

## Problem Statement

WorkoutTracker is intended to make gym logging fast on a phone while preserving a user-owned Google Sheet as the source of truth. The current UI is functional, but several mobile flows still feel like a direct presentation of app state rather than a thumb-first logging tool. Important actions can be visually delayed, hidden behind gestures, or embedded in controls whose primary purpose is selection.

The main user pain is friction during an active workout. Between sets, the user needs to see the current exercise, log the next set, save it reliably with the keyboard open, and move on. Secondary context such as targets, rest, tempo, notes, history, validation details, and spreadsheet diagnostics should remain available, but it should not dominate the first mobile viewport.

The app also needs a clearer workout-log visual identity. It should feel compact, data-first, and purpose-built for recording sets, not like an unstyled default form application. Logged, current, backup, warning, and error states should be visibly distinct and consistent across the app.

## Solution

Redesign the mobile UI around the actual workout moment: fast set entry, clear progress, and direct row actions.

The logging screen should become thumb-first. The next set editor should appear early, save should remain reachable when the keyboard is open, and contextual information should move into secondary or collapsible areas. The current exercise, current set target, logged progress, and save action should be the dominant mobile surface.

Workout overview rows should expose backup exercise actions directly. Long press can remain a shortcut, but adding, switching, or managing backups must be possible through visible tap targets. Backup indicators should not crowd out the primary exercise name, set progress, or row action.

Forms should use predictable mobile layouts rather than fixed-width wrapped controls. Logging fields, workout setup, placement forms, and exercise authoring should fit common phone widths without awkward wrapping or detached submit actions. Numeric fields should use appropriate mobile input types.

Creation actions should be visible instead of hidden as dropdown sentinel items. Selecting an existing workout, history block, or exercise should remain separate from creating a new one.

The app should establish a compact workout-log visual language. Set chips, progress counters, current-set highlighting, backup markers, status colors, consistent icons, and sentence-case labels should create a recognizable logging experience while staying quiet and utilitarian.

Sheet setup and repair flows should become task-first on mobile. First-run setup should present one dominant next action, with create and paste-link options clearly secondary. Repair flows should lead with what the user can do next, while keeping spreadsheet details available as secondary diagnostics.

## User Stories

1. As a lifter between sets, I want the next set editor to be visible immediately, so that I can log a set without scanning through secondary information.
2. As a lifter between sets, I want the save action to remain reachable when the keyboard is open, so that I can finish logging without dismissing the keyboard first.
3. As a lifter, I want to see which exercise I am logging and which set comes next, so that I do not accidentally enter data for the wrong row.
4. As a lifter, I want logged set progress to be visible before recent history, so that I can quickly tell how much of the exercise is complete.
5. As a lifter, I want target reps, RPE, rest, tempo, and notes to be available but not dominant, so that guidance does not slow down entry.
6. As a lifter, I want recent history summarized compactly, so that prior performance helps me choose values without taking over the screen.
7. As a lifter, I want to expand recent history when needed, so that deeper context is available without always consuming space.
8. As a lifter, I want structured set fields to fit predictably on my phone, so that values do not jump into awkward rows.
9. As a lifter, I want numeric fields to open numeric keyboards where appropriate, so that entry is faster during a workout.
10. As a lifter, I want raw unparseable set text to remain editable, so that manually entered sheet data is preserved.
11. As a lifter, I want saved sets to appear immediately in the logged set list, so that I trust the app recorded the entry.
12. As a lifter, I want the current set to be visually distinct from completed sets, so that I can orient myself quickly.
13. As a lifter, I want completed sets to read as compact chips or rows, so that progress is scannable at a glance.
14. As a lifter, I want clear warning and error states for invalid or unsaved entries, so that I know when action is required.
15. As a lifter in a busy gym, I want a visible way to add a backup exercise from a primary exercise row, so that I do not need to know a hidden gesture.
16. As a lifter in a busy gym, I want to switch to or manage a backup exercise through a tap target, so that I can adapt quickly when equipment is unavailable.
17. As a lifter, I want long press to remain an optional shortcut only, so that core backup workflows are discoverable.
18. As a lifter, I want backup indicators to show count or status compactly, so that long backup names do not crowd the row.
19. As a lifter, I want primary exercise names and set progress to remain readable even when backups exist, so that overview rows stay useful.
20. As a lifter, I want tapping an exercise row to open logging and tapping row actions to manage the row, so that navigation and management are distinct.
21. As a user setting up a workout, I want add-workout and add-history actions to be visible, so that I understand how to create new options.
22. As a user setting up a workout, I want dropdowns to contain only existing choices, so that selection and creation do not feel mixed together.
23. As a user setting up a workout, I want newly created workouts or history blocks to become selected, so that I can continue without repeating work.
24. As a user adding an exercise to a workout, I want to explicitly select an existing canonical exercise, so that I do not accidentally add the first available exercise.
25. As a user adding an exercise to a workout, I want row-local targets to be easy to review and adjust on a phone, so that placement metadata is correct.
26. As a user authoring a canonical exercise, I want a mobile-friendly form with sensible defaults, so that adding a new exercise is slower than logging but still understandable.
27. As a user authoring a canonical exercise, I want the submit action to remain easy to find after entering metadata, so that the form does not feel like a dead end.
28. As a first-time user, I want one dominant action to choose my workout sheet, so that setup starts with a clear next step.
29. As a first-time user, I want create-sheet and paste-link options to be available but secondary, so that alternative setup paths are discoverable without competing with the main path.
30. As a returning user, I want the selected sheet and account to be clear but compact, so that setup state does not dominate normal use.
31. As a sheet-backed app user, I want repair screens to describe the task in user language, so that I know what to fix.
32. As a sheet-backed app user, I want spreadsheet row details available as secondary diagnostics, so that I can inspect the source of truth when needed.
33. As a sheet-backed app user, I want formula repair choices to identify the affected exercise or task, so that I do not need to translate row numbers before acting.
34. As a mobile user, I want buttons and labels to use concise sentence-case language, so that the UI is easy to scan.
35. As a mobile user, I want icons to consistently reinforce common actions and states, so that repeated workflows become faster.
36. As a mobile user, I want the app to feel dense but not cramped, so that it supports repeated logging rather than occasional form completion.
37. As a mobile user, I want visual states for logged, current, backup, warning, and error items to be distinct, so that I can recognize them without reading every label.
38. As a user who still edits the Google Sheet directly, I want the UI to respect the sheet contract, so that app changes do not hide or reinterpret my data unexpectedly.
39. As a future implementer, I want UI work split into behavior-oriented slices, so that each change can be tested and reviewed independently.
40. As a future implementer, I want the UI to use existing backend sheet-contract behavior, so that presentation changes do not duplicate parsing, validation, formula healing, or write planning.

## Implementation Decisions

- The work is mobile-first. Phone ergonomics, keyboard behavior, thumb reach, dense scanning, and workflow speed are more important than desktop-specific layout optimization.
- The logging screen is the highest-priority surface. It should place the current exercise, next set editor, save action, and logged progress before secondary context.
- Target, rest, tempo, notes, and recent history remain part of the logging experience, but they should be compact, collapsible, or otherwise visually secondary on phones.
- Save behavior should be reachable while editing values. The implementation may use a sticky action, an editor-attached action, or another mobile-native pattern, as long as it does not obscure fields.
- Backup exercise workflows require visible row-level affordances. Long press may remain, but it cannot be the only path to add, switch, or manage backups.
- Workout overview rows should preserve primary exercise readability and set progress. Backup detail should use compact indicators, counts, chips, expansion, or menus rather than crowding the main row.
- Mobile forms should avoid hard-coded fixed-width wrapping as the primary layout strategy. Use stable stacked layouts, responsive grids, or field groups that behave predictably across common phone widths.
- Numeric or constrained values should request appropriate input types where the platform supports them.
- Dropdowns should only select existing values. Creating a workout, history block, or exercise should be represented by visible actions outside the dropdown menu.
- Adding a workout placement should require an explicit exercise selection rather than defaulting to the first available canonical exercise.
- The visual system should remain utilitarian and data-first. It should use compact density, set progress, current-set emphasis, status color, and consistent iconography instead of decorative fitness marketing patterns.
- The app should use sentence-case labels for actions and avoid phrase-heavy buttons where a shorter mobile label is clear.
- Sheet setup should prioritize a single dominant first-run action, with create and paste-link paths presented as secondary choices.
- Repair and validation screens should lead with task language and user action. Spreadsheet row numbers, sheet IDs, and diagnostic details should remain available but visually secondary.
- UI changes must continue to use completed backend modules for sheet parsing, validation, backup grouping, set notation, write planning, formula healing, and Google adapters.
- The implementation should prefer deep UI-facing helpers where they simplify state and behavior behind small testable interfaces, especially for mobile layout decisions, row state presentation, and logging editor behavior.

## Testing Decisions

- Tests should verify observable behavior, public interfaces, and user-facing state. They should not pin private widget structure, helper names, or implementation-only layout mechanics.
- Logging screen tests should cover the presence and ordering priority of the active exercise, next set editor, save action, logged progress, target summary, and recent history at mobile sizes.
- Keyboard-reach behavior should be tested where the widget test environment can represent it reliably. If platform keyboard behavior cannot be fully exercised locally, use focused widget tests for layout state and document any manual verification needed.
- Backup workflow tests should verify that visible tap actions exist for adding or managing backups and that long press is not the only discoverable path.
- Workout overview tests should verify that primary exercise identity and set progress remain visible when backups exist.
- Mobile form tests should cover narrow widths for logging fields, workout setup, workout placement, and exercise authoring, focusing on field availability, action availability, and absence of user-visible overflow.
- Creation-flow tests should verify that add actions are visible outside selectors and that newly created values become selected when appropriate.
- Sheet setup tests should verify that the first-run screen has one dominant choose-sheet path and that create and paste-link paths remain available as secondary actions.
- Repair-flow tests should verify task-first user-facing labels while preserving diagnostic details.
- Visual identity tests should focus on semantic states and accessible labels rather than exact colors or pixel-perfect styling.
- Golden tests may be useful after the mobile visual direction stabilizes, but the initial implementation should rely primarily on behavior-oriented widget tests.
- Live Google integration tests are out of scope for ordinary UI revisions unless a slice explicitly changes sheet creation, selection, validation, or repair behavior that requires live verification.

## Out of Scope

- Changing the Google Sheet contract.
- Creating an app-owned workout database or backend.
- Redesigning the canonical data model for workouts, exercises, backups, history blocks, set notation, or formula healing.
- Building desktop-specific layouts or optimizing for wide-screen workflows.
- Adding coaching, progression recommendations, program design, analytics, charts, social features, or workout templates beyond the current sheet-backed logging scope.
- Replacing Flutter or changing the project’s platform strategy.
- Rewriting backend modules that already own sheet parsing, validation, set notation, write planning, formula healing, or Google adapters.
- Pixel-perfect brand design, custom illustration, animation systems, or marketing-style landing experiences.

## Further Notes

- Sticky save actions improve speed but can obscure fields if keyboard handling is not deliberate.
- Collapsing target and history context saves space but may hide guidance some users rely on; summaries should make expansion obvious.
- More visible backup actions add row complexity; use one clear affordance rather than several competing controls.
- Compact density is valuable during a workout, but touch targets must remain large enough for sweaty, one-handed use.
- A stronger visual identity should stay quiet, durable, and data-first. The app should feel like a fast training log, not a fitness marketing product.
- Repair flows must balance user-friendly task language with the project’s commitment to a human-readable Google Sheet source of truth.
- The PRD intentionally avoids implementation file paths so future agents can apply it against the current code structure without stale references.
