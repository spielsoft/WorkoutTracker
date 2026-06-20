# WorkoutTracker

WorkoutTracker is a planned lightweight cross-platform gym logging app backed by a user-owned Google Sheet. The app is designed to make workout logging fast on a phone or desktop while keeping the spreadsheet human-readable and directly editable when the app is unavailable.

The first implementation target is a standard Flutter/Dart app with a macOS `.app` bundle available from day one. The long-term platform direction is iOS, macOS, Android, Linux, and Windows from one codebase.

## Project Goal

The app should let a user:

1. Sign in with Google.
2. Select an existing workout spreadsheet or create a new app-initialized
   workout spreadsheet in Google Drive.
3. Validate and repair the active workout sheet when needed.
4. Select a workout such as Legs, Upper, or a default workout.
5. Select or create a visible history block such as `Week 1`.
6. Add canonical exercise definitions to the `Exercises` tab.
7. Add primary exercises to a workout from the workout exercise list.
8. Add backup exercises from an existing primary exercise when the gym is busy.
9. Open an exercise, see recent row-local history, and log sets quickly.
10. Write compact set notation back to the sheet.

WorkoutTracker is not a coaching app, progression engine, or workout program editor. It is a focused logging interface over a spreadsheet the user controls.

## Source of Truth

The Google Sheet is the durable data artifact. There is no app-owned workout database and no app-owned backend.

The spreadsheet must remain useful without the app. This drives the core design:

- The first tab is the active workout/log sheet.
- The active sheet is canonical for workout rows and visible history.
- The `Exercises` tab stores canonical exercise metadata.
- Active sheet display cells use direct spreadsheet formulas into `Exercises`.
- The app can heal missing or broken formulas, and the MVP app can append new
  canonical rows to `Exercises`.
- Workout history is stored horizontally in visible set columns such as `S1`, `S2`, and `S3`.
- The app presents that horizontal sheet data in a phone-friendly vertical logging flow.

## Active Sheet Contract

The active sheet uses fixed columns followed by history blocks:

```text
Exercise | Sets | Reps | RPE | Rest | Tempo | Notes | Log Format | Workout | is_backup | history blocks...
```

Important rules:

- Blank `Workout` means the default workout.
- Blank `is_backup` means not a backup.
- Rows with a blank or merged first display cell are ignored as human-only section/header rows.
- Backup rows belong to the nearest preceding non-backup row within the same workout.
- The first app-readable row in a workout cannot be a backup.
- History block labels are human labels, not date metadata.
- New history blocks start with `S1` and grow as more sets are logged.
- Adding from the workout exercise list creates a primary non-backup row.
- Adding a backup exercise starts from an existing primary row through a
  row-specific action such as right-click on macOS or long-press on mobile.

## Exercise Editing MVP

App-created spreadsheets make exercise authoring part of the MVP. The app must
provide a reusable add-exercise screen that can be opened from both the workout
setup context and the add-to-workout context.

The add-exercise screen captures canonical `Exercises` metadata:

- exercise name;
- default sets, reps, RPE, rest, and tempo;
- notes;
- literal log format.

The app should supply sensible defaults, including the default log format:

```text
{Weight}[x]{Reps}[@]{RPE}
```

Adding a primary exercise to a workout should let the user choose an existing
canonical exercise or create a new one through the same add-exercise screen,
then append a non-backup active-sheet row for the selected workout. Adding a
backup exercise should be launched from an existing primary row and should
append a backup row attached to that primary exercise by sheet order.

## Set Notation

The app uses structured fields in the UI but writes compact human-readable notation into sheet cells.

Initial notation examples:

- `150x10@8`
- `150x10@8,1`
- `15@8`
- `45s@8`
- `150x10@8,1; felt fast`

Unparseable cells must be preserved and editable as raw text. The app must not silently discard manual sheet data.

## Development Plan

Stable project artifacts:

- [Domain contract](docs/domain_contract.md)
- [Agent prompts](PROMPTS.md)
- [Agent guidance](AGENTS.md)

Transient issue plans may be created while coordinating work, but stable docs
and tests should not depend on those files being present.

Implementation uses TDD with vertical slices. Backend sheet-contract behavior
comes before GUI work: parsing, validation, healing, write planning, Google
integration, reset/cleanup, and backend architecture validation should be
complete before UI code depends on it.

## Testing

Use the narrowest test tier that matches the change:

- Fast default local tests: targeted `flutter test` commands for backend,
  adapter, controller, or notation behavior. These are the normal development
  loop and do not require Google credentials.
- Targeted GUI tests: focused widget tests such as
  `flutter test test/widget_test.dart` for app flow or layout behavior.
- Opt-in live Google integration:
  `integration_test/live_logging_flow_test.dart` validates the real development
  sheet flow. It skips by default; run it only when Google login/HITL is ready
  and development-sheet writes are acceptable by setting
  `WORKOUT_TRACKER_RUN_LIVE_GOOGLE_TESTS=1`.
- Release/full validation: run the broad local suite plus any relevant platform
  build or live validation before release, architecture gates, or final cleanup.

## Current Status

This repository contains a Flutter/Dart app with backend sheet-contract modules,
Google Sheets adapters, app flow controllers, widget tests, and an opt-in live
integration test for the development sheet. The broad local suite should remain
green before release candidates.

## Development Sheet

The writable development Google Sheet for integration work is:

https://docs.google.com/spreadsheets/d/1zQrmCYelrNqRMv4WtJcOrtezSxoaVniXzXi4XgKva_E/edit?gid=0#gid=0

Integration slices may write to this sheet, but they must include reset and cleanup behavior so tests leave it in a known state.

## Spreadsheet Selection

Native Google Sign-In remains wired for account access and Sheets API
authorization. Google Drive Picker is used for choosing an existing sheet.
Google-backed sheet creation creates a new spreadsheet, initializes it with the
WorkoutTracker contract, selects it, and persists that selection for later
launches.
