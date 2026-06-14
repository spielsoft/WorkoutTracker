# WorkoutTracker

WorkoutTracker is a planned lightweight cross-platform gym logging app backed by a user-owned Google Sheet. The app is designed to make workout logging fast on a phone or desktop while keeping the spreadsheet human-readable and directly editable when the app is unavailable.

The first implementation target is a standard Flutter/Dart app with a macOS `.app` bundle available from day one. The long-term platform direction is iOS, macOS, Android, Linux, and Windows from one codebase.

## Project Goal

The app should let a user:

1. Sign in with Google.
2. Select their workout spreadsheet.
3. Validate and repair the active workout sheet when needed.
4. Select a workout such as Legs, Upper, or a default workout.
5. Select or create a visible history block such as `Week 1`.
6. Open an exercise, see recent row-local history, and log sets quickly.
7. Choose a backup exercise when the gym is busy.
8. Write compact set notation back to the sheet.

WorkoutTracker is not a coaching app, progression engine, or workout program editor. It is a focused logging interface over a spreadsheet the user controls.

## Source of Truth

The Google Sheet is the durable data artifact. There is no app-owned workout database and no app-owned backend.

The spreadsheet must remain useful without the app. This drives the core design:

- The first tab is the active workout/log sheet.
- The active sheet is canonical for workout rows and visible history.
- The `Exercises` tab stores canonical exercise metadata.
- Active sheet display cells use direct spreadsheet formulas into `Exercises`.
- The app can heal missing or broken formulas, but the initial app does not edit `Exercises`.
- Workout history is stored horizontally in visible set columns such as `S1`, `S2`, and `S3`.
- The app presents that horizontal sheet data in a phone-friendly vertical logging flow.

## Active Sheet Contract

The active sheet uses fixed columns followed by history blocks:

```text
Exercise | Sets | Reps | RPE | Rest | Tempo | Notes | Workout | is_backup | history blocks...
```

Important rules:

- Blank `Workout` means the default workout.
- Blank `is_backup` means not a backup.
- Rows with a blank or merged first display cell are ignored as human-only section/header rows.
- Backup rows belong to the nearest preceding non-backup row within the same workout.
- The first app-readable row in a workout cannot be a backup.
- History block labels are human labels, not date metadata.
- New history blocks start with `S1` and grow as more sets are logged.

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

Planning artifacts:

- [MVP PRD](issues/MVP_prd.md)
- [MVP implementation slices](ISSUES_MVP.md)
- [Agent prompts](PROMPTS.md)
- [Agent guidance](AGENTS.md)

Implementation will use TDD with vertical slices. Backend sheet-contract behavior comes first. GUI work starts only after backend parsing, validation, healing, write planning, Google integration, reset/cleanup, and backend architecture validation are complete.

Each completed slice should be committed separately.

## Current Status

This repository now contains the standard Flutter/Dart scaffold generated for Slice 0, with iOS, macOS, Android, Linux, and Windows platform targets present. Backend sheet-contract implementation has not started yet.

## Development Sheet

The writable development Google Sheet for integration work is:

https://docs.google.com/spreadsheets/d/1zQrmCYelrNqRMv4WtJcOrtezSxoaVniXzXi4XgKva_E/edit?gid=0#gid=0

Integration slices may write to this sheet, but they must include reset and cleanup behavior so tests leave it in a known state.
