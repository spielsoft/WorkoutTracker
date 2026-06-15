## Problem Statement

Gym workout logging currently depends on editing a Google Sheet directly. The sheet is flexible, human-readable, and remains usable without any app, but it is awkward on a phone during a workout. The user needs a lightweight cross-platform front end that signs into Google, connects to a user-selected Google Sheet, presents the active workout clearly, and writes set data back into the sheet without replacing the sheet as the source of truth.

The key constraint is that the Google Sheet must remain directly usable if the app is broken, unavailable, or not installed. The app must therefore respect a strict but human-readable sheet contract instead of moving workout history into an app-owned database or a purely normalized hidden data model.

## Solution

Build a single-user, bring-your-own-Google-Sheet workout logging app. The first tab of the selected spreadsheet is the active workout and canonical log. The app reads the active sheet, validates the strict schema, heals missing or broken formula-driven display fields, lets the user select a workout and a visible history block, and provides a gym-friendly logging interface for entering set results.

The app does not author workout programs, edit the exercise library, provide coaching recommendations, manage a backend, or maintain a separate workout database. It acts as a focused logging surface over the user-owned Google Sheet.

The active sheet remains human-readable. It uses fixed metadata/display columns followed by horizontal history blocks. Exercise metadata comes from a separate `Exercises` tab via direct spreadsheet formulas. Backup rows are defined contextually on the active workout sheet with `is_backup`, and backup ownership is inferred by row order within each workout.

## User Stories

1. As a lifter, I want to sign into my Google account, so that the app can access my workout spreadsheet.
2. As a lifter, I want to select the Google Sheet used for workout logging, so that I can keep my own spreadsheet as the source of truth.
3. As a lifter, I want the app to remember my selected spreadsheet on this device, so that I do not have to choose it every time.
4. As a lifter, I want to switch to a different spreadsheet from settings, so that I can move between workout sheets if needed.
5. As a lifter, I want the app to validate my sheet before logging, so that it does not write into the wrong structure.
6. As a lifter, I want the app to tell me when the active sheet violates the required contract, so that I know what must be fixed before logging.
7. As a lifter, I want the app to regenerate missing formula-driven display cells, so that the active sheet can be repaired after manual edits.
8. As a lifter, I want formula repair to use exercise choices from the `Exercises` tab, so that repaired rows point to canonical exercise metadata.
9. As a lifter, I want exact matching exercise names to be preselected during repair, so that common repair cases are quick.
10. As a lifter, I want ambiguous or missing exercise matches to require my selection, so that the app does not silently link to the wrong exercise.
11. As a lifter, I want the first spreadsheet tab to be treated as the active workout sheet, so that my current workflow stays simple.
12. As a lifter, I want the active workout sheet to remain readable in Google Sheets, so that I can use it manually if the app is unavailable.
13. As a lifter, I want the active workout sheet to use direct formulas into `Exercises`, so that exercise descriptions and targets are shared across workouts.
14. As a lifter, I want the app to treat the `Exercises` tab as read-only in the initial app, so that exercise library management remains spreadsheet-first.
15. As a lifter, I want the active sheet to support a visible `Workout` column, so that I can group exercise rows into workouts like Legs, Upper, or a default workout.
16. As a lifter, I want blank `Workout` values to mean the default workout, so that simple sheets do not require repeated labels.
17. As a lifter, I want the active sheet to support an `is_backup` column, so that backup choices can be defined in the workout context.
18. As a lifter, I want blank `is_backup` values to mean not a backup, so that the common case is easy to author.
19. As a lifter, I want backup rows to belong to the nearest preceding primary row in the same workout, so that backup definitions are simple and visible in sheet order.
20. As a lifter, I want the app to reject a workout whose first app-readable row is a backup, so that ambiguous backup ownership is prevented.
21. As a lifter, I want blank or merged first-column rows to be ignored as human section/header rows, so that I can keep headings and spacing in the sheet.
22. As a lifter, I want to select which workout I am doing, so that I can focus only on the relevant exercise rows.
23. As a lifter, I want the workout list to come from the active sheet's `Workout` values, so that the app reflects the sheet directly.
24. As a lifter, I want the app to show primary exercises only in the workout overview, so that the planned workout is not cluttered by backups.
25. As a lifter, I want backup exercises nested under their primary exercise, so that I can choose them only when needed.
26. As a lifter, I want exercises shown in sheet order, so that the app matches the workout layout I authored.
27. As a lifter, I want to open exercises in any order, so that I can adapt to gym availability.
28. As a lifter, I do not want the app to reorder exercises, so that program structure stays controlled by the sheet.
29. As a lifter, I want to select an existing visible history block such as `Week 1`, so that I can log into the intended group of set columns.
30. As a lifter, I want to create a new visible history block when starting a workout, so that I can begin a new week or session from the app.
31. As a lifter, I want new history blocks inserted near the fixed metadata columns, so that recent history stays closest to the left.
32. As a lifter, I want a new history block to start with only `S1`, so that the sheet grows only as I actually log sets.
33. As a lifter, I want the selected history block to grow with `S2`, `S3`, and later columns when needed, so that I can perform more sets than planned.
34. As a lifter, I want history block labels to be treated as plain visible labels, so that labels like `Week 1` do not need date metadata.
35. As a lifter, I want selecting an existing history block to show already logged cells, so that I can continue or correct prior entries.
36. As a lifter, I want the exercise logging screen to show the exercise description and notes read-only, so that cues are available while logging.
37. As a lifter, I want the exercise logging screen to show the requested rest time, so that I can see the prescription without needing a timer.
38. As a lifter, I want no countdown timer in the MVP, so that the first app remains focused on logging.
39. As a lifter, I want the exercise logging screen to show recent history for the current row, so that I can choose appropriate loads based on prior performance.
40. As a lifter, I want the default history view to show the last three non-empty history blocks for the current row, so that I have useful context without clutter.
41. As a lifter, I want history to be row-local, so that the same canonical exercise in another workout does not confuse this row's prescription.
42. As a lifter, I want the primary exercise preselected when I open a primary slot, so that normal logging is fast.
43. As a lifter, I want a selector for primary and backup choices, so that I can switch to a backup when the gym is busy.
44. As a lifter, I want selecting a backup to switch history and writes to that backup row, so that the visible sheet records what I actually did.
45. As a lifter, I want switching rows to start logging at that row's first empty set cell, so that each row's `S1`, `S2`, and later cells remain row-local.
46. As a lifter, I want the overview to show total set count for a primary slot including backup rows, so that rare mixed-row cases are summarized simply.
47. As a lifter, I want to enter set data through structured fields, so that logging is faster than typing compact notation manually.
48. As a lifter, I want the app to write compact human-readable set notation into the sheet cell, so that the sheet remains usable directly.
49. As a lifter, I want common notation such as `150x10@8`, `150x10@8,1`, `15@8`, and `45s@8` supported, so that existing logging patterns continue to work.
50. As a lifter, I want optional notes in set cells, so that I can record context like pain, equipment issues, or form notes.
51. As a lifter, I want unparseable cells preserved and shown as raw text, so that the app never discards manual sheet data.
52. As a lifter, I want to edit raw text for unparseable cells, so that I can still correct entries that do not match the strict parser.
53. As a lifter, I want to clear a logged set cell from the app, so that I can fix mistakes.
54. As a lifter, I want clearing non-empty data to be deliberate, so that accidental deletion is avoided.
55. As a lifter, I want the app to auto-advance to the next empty set after saving, so that repeated set entry is fast.
56. As a phone user, I want the current exercise screen to show newest/current set rows first, so that the next action is at the top.
57. As a phone user, I want prior sets and then history below the current set, so that the layout fits the gym workflow.
58. As a lifter, I want no required finish workout action, so that each cell write is immediately meaningful.
59. As a lifter, I want no workout progress count in MVP, so that the app does not imply a formal completion model.
60. As a lifter, I want per-exercise logged set counts in the overview, so that I can see what has been logged without opening every exercise.
61. As a lifter, I want no progression recommendations in MVP, so that the app does not act as a coach.
62. As a lifter, I want the app to require online access except for any Google-provided offline behavior, so that the app does not need its own sync conflict system.
63. As a developer, I want the first deliverable to support local/dev install only, so that store distribution work does not delay the MVP.
64. As a developer, I want the MVP to run as a `.app` bundle on the user's Mac, so that macOS is available on day one.
65. As a developer, I want the project to aim for one cross-platform codebase, so that iOS, macOS, Android, Linux, and Windows remain viable targets.
66. As a developer, I want the work developed with TDD vertical slices, so that the sheet contract is locked down behavior by behavior.

## Implementation Decisions

- The MVP is single-user and sheet-backed only.
- There is no app-owned backend.
- There is no app-owned workout database.
- Google Sheets remains the source of truth for workout definitions and workout history.
- The app uses Google sign-in and the narrowest practical access scope for the selected spreadsheet.
- The app stores one selected spreadsheet per device, with switching available from settings.
- The first spreadsheet tab is the active workout sheet.
- The active workout sheet is canonical for the active workout definition and visible workout history.
- The `Exercises` tab stores canonical exercise metadata.
- The initial app reads from `Exercises` but does not edit it.
- Active sheet display fields use direct spreadsheet formulas into `Exercises`, not app-visible IDs or lookup keys.
- The active sheet does not expose `exercise_id`.
- Formula healing is mandatory when formula-driven fields are missing or broken.
- Formula healing offers exercise choices from `Exercises`; exact displayed-name matches are preselected where possible.
- The active sheet fixed columns are `Exercise`, `Sets`, `Reps`, `RPE`, `Rest`, `Tempo`, `Notes`, `Log Format`, `Workout`, and `is_backup`, followed by history blocks.
- The `Exercises` tab owns a human-readable `Log Format` metadata column, and the active sheet mirrors it by direct formula for each exercise row.
- A blank `Log Format` means the default literal format `{Weight}[x]{Reps}[@]{RPE}`.
- Literal log formats use `{Field Label}` for app field labels and `[sheet literal]` for compact sheet text.
- Literal text inside `[]` is always rendered and is never automatically omitted for blank field values.
- Existing set cells that cannot be parsed by the row-local `Log Format` remain raw text and editable.
- `Workout` is human-readable and visible near the end of the fixed metadata area.
- Blank `Workout` means the default workout.
- `is_backup` is the last metadata column before history blocks.
- Blank `is_backup` means false.
- Rows whose first display column is blank or merged are ignored as human-only section/header rows.
- Backups are inferred by row order: a backup belongs to the nearest preceding non-backup row within the same workout.
- A workout whose first app-readable row is a backup is a schema violation.
- The user selects a workout before logging.
- The workout overview shows only primary rows, with backups nested under their primary row.
- The user can log exercises in any order.
- The app does not reorder workouts or exercises.
- The user selects an existing history block or creates a new one before logging.
- History blocks are identified by visible labels, not date metadata.
- New history blocks are inserted near the fixed metadata columns with newest history closest to the left.
- New history blocks start with `S1` only.
- History blocks grow by adding `S2`, `S3`, and later columns as needed when the user logs more sets.
- The app reads existing selected-block entries and displays them as editable logged sets.
- The exercise logging screen includes a selector for primary and backup rows, with the primary selected by default.
- Selecting a backup switches the active row for history and writes.
- Switching rows starts at that row's first empty set cell.
- If primary and backup rows both contain data in a selected block, the overview reports total sets across the slot.
- The app uses structured UI fields for set entry but writes compact notation to the sheet.
- The parser must support the agreed compact notation direction for weighted reps, bodyweight reps, timed drills, optional pain, and optional notes.
- Unparseable cells are preserved and editable as raw text.
- The app supports clearing and editing logged set cells.
- The exercise screen shows the last three non-empty history blocks for the current row by default.
- History is current-row only, even when the same canonical exercise appears elsewhere.
- The exercise screen shows notes/descriptions and rest targets read-only.
- The MVP has no rest timer.
- The MVP has no progression recommendation engine.
- The MVP has no required finish-workout action.
- The MVP has no workout-level progress count.
- The overview shows per-slot logged set counts.
- The MVP is online-first; app-owned offline sync is out of scope.
- The first deliverable is local/dev install only, not App Store or Play Store distribution.
- The MVP must run as a `.app` bundle on the user's Mac.
- The project should aim for a single cross-platform codebase suitable for iOS, macOS, Android, Linux, and Windows.
- Development should proceed via TDD vertical slices.
- The first vertical slice should be the active sheet contract parser/validator using in-memory sheet data, before Google API integration or UI polish.
- The sheet contract parser/validator should be treated as a deep module: a simple public interface hiding parsing, grouping, validation, history-block discovery, and write-planning complexity.
- Google API access, auth, UI, and sheet-contract logic should remain conceptually separated so the contract can be tested without network access.

## Testing Decisions

- Tests should verify behavior through public interfaces, not implementation details.
- Tests should be integration-style where practical: pass representative sheet data into the sheet contract layer and assert the observable workout model, validation errors, or planned writes.
- Tests should not depend on private helpers, call order, or internal parsing structure.
- Tests should be written one behavior at a time using red-green-refactor.
- The first tracer bullet should prove that the parser reads an active sheet with the required columns, applies blank `Workout` and `is_backup` defaults, ignores blank/merged first-column rows, and groups backups under the nearest preceding primary row within the same workout.
- Parser tests should cover contract violations, including a workout whose first app-readable row is a backup.
- Validation tests should cover required fixed columns and history block shape.
- Formula-healing tests should cover missing formulas, exact-name preselection, ambiguous matches requiring user choice, and regeneration of direct formulas.
- History-block tests should cover selecting an existing block, creating a new `S1` block, inserting newest blocks near the fixed columns, and extending a block with additional set columns.
- Set notation tests should cover parse and render behavior for weighted reps, optional pain, bodyweight reps, timed entries, height/platform-style entries, notes, and unparseable raw text.
- Logging tests should cover writing to primary rows, writing to backup rows, switching selected rows, preserving existing data, editing cells, clearing cells, and auto-advancing to the next empty set.
- Overview tests should cover primary-only display, nested backups, sheet-order preservation, selected-workout filtering, and total set counts across primary plus backup rows.
- Google integration tests should be added only after the core sheet contract behavior is stable, and should verify read/write behavior against controlled test spreadsheets rather than replacing core unit/integration tests.
- UI tests should focus on the critical user flow: sign in, select spreadsheet, validate/heal, choose workout, choose/create history block, select exercise, choose primary/backup, log/edit/clear sets.

## Out of Scope

- Multi-user accounts, trainer/client collaboration, or shared backend features.
- App-owned server database or app-owned workout history storage.
- Editing the canonical `Exercises` tab from inside the initial app.
- Full workout program authoring from inside the app.
- Reordering exercises from inside the app.
- Arbitrary spreadsheet interpretation outside the strict schema.
- Importing all possible legacy sheet formats in the MVP.
- Progression recommendations such as automatic load increases.
- Coaching logic, warmup management, cooldown management, or rule enforcement beyond displaying read-only context already present in the active sheet.
- Rest countdown timers, notifications, or background timer behavior.
- Required workout completion or finish-session workflow.
- Workout-level progress count.
- App-owned offline sync and conflict resolution.
- Store distribution, notarization, public release packaging, or OAuth verification work beyond what is needed for local/dev use.
- Separate polished desktop-specific UX beyond producing a runnable `.app` bundle for macOS.

## Further Notes

- The strongest product constraint is that the sheet must remain useful without the app. Every schema and write decision should preserve direct Google Sheets usability.
- The active sheet's horizontal history layout is intentional. The app may present it vertically on phone screens, but storage remains the human-readable horizontal block format.
- Direct formulas into `Exercises` are part of the sheet contract. The app should repair those formulas, not replace them with app-only identifiers.
- Metadata should stay minimal and human-understandable. `Workout` and `is_backup` are active-sheet context, not normalized database tables.
- The current example spreadsheet is inspiration for layout and notation, not an exact final schema.
- Future versions may add import helpers, richer history views, exercise library editing, recommendations, timers, broader packaging, or offline sync, but those should not dilute the MVP logging contract.
