# Agent Guidance

This file is the lightweight startup guide for agents working in WorkoutTracker.

## Read First

Before doing implementation work, read:

1. `AGENTS.md`
2. `ISSUES_MVP.md`
3. `issues/MVP_prd.md`
4. `PROMPTS.md` when using a prepared prompt flow

If future project guidance files are added, read them before choosing work.

## Project Summary

WorkoutTracker is a lightweight cross-platform gym logging app. The durable data artifact is a user-owned Google Sheet. The app should make logging ergonomic while preserving the sheet as the human-readable source of truth.

The selected implementation direction is Flutter/Dart with a standard package layout. The MVP must eventually run as a macOS `.app` bundle and should keep iOS, Android, Linux, and Windows viable.

## Development Discipline

- Follow `ISSUES_MVP.md` slice order.
- Use TDD for every implementation slice.
- Write one failing behavior test through a public interface, then implement the smallest code needed to pass.
- Refactor only after tests are green.
- Commit each completed slice separately.
- Update the `ISSUES_MVP.md` checklist only when the slice is actually complete.
- Preserve unrelated worktree changes.
- Stage only files that belong to the current slice.

## Backend Before GUI

All backend sheet-contract behavior must be complete before GUI work begins.

Do not start GUI slices until Slice 16 is complete:

- sheet parsing and validation
- backup grouping
- history block discovery and planning
- set notation parsing/rendering
- set write planning
- formula healing planning
- Google Sheet read/write adapters
- development sheet reset/cleanup
- backend integration validation
- backend architecture review

GUI code must use completed backend modules instead of duplicating sheet parsing, validation, formula healing, or write planning.

## Sheet Contract Principles

- The Google Sheet is the source of truth.
- There is no app-owned workout database.
- The first tab is the active workout/log sheet.
- `Exercises` stores canonical exercise metadata and is read-only in the initial app.
- Active sheet display cells use direct formulas into `Exercises`.
- The app may heal active-sheet formulas when they are missing or broken.
- `Workout` and `is_backup` live on the active sheet.
- Blank `Workout` means default workout.
- Blank `is_backup` means false.
- Backup rows attach to the nearest preceding primary row within the same workout.
- Unparseable set cells must be preserved as raw text.

## Testing Expectations

Tests should describe observable behavior, not implementation details.

Good test surfaces include:

- parsing an active sheet into workout slots
- validating schema violations
- grouping primary and backup rows
- discovering and creating history blocks
- parsing and rendering set notation
- planning writes without Google access
- healing formulas
- applying Google read/write adapters
- resetting the development sheet fixture

Do not test private helpers just because they exist. The public backend interface should be the test surface.

## Google Sheet Integration

Use this development sheet for integration slices:

https://docs.google.com/spreadsheets/d/1zQrmCYelrNqRMv4WtJcOrtezSxoaVniXzXi4XgKva_E/edit?gid=0#gid=0

First try to complete Google integration work AFK. If local app authentication requires user login or authorization, stop at the smallest necessary HITL point and explain the exact action needed.

Integration tests that write to the development sheet must reset or clean up after themselves.

## Architecture Expectations

Use the architecture review slices in `ISSUES_MVP.md` seriously. Prefer deep modules with small public interfaces and substantial behavior behind them.

Keep these seams conceptually separate:

- sheet contract parsing/validation
- set notation parsing/rendering
- history block planning
- set write planning
- formula healing
- Google Sheet adapters
- GUI presentation

Avoid shallow pass-through modules. If deleting a module would simply move the same complexity into callers, deepen it or remove it.

## Reporting

At the end of a slice, report:

- commit hash
- changed files
- tests run
- whether the slice checklist was updated
- risks or follow-up slices

If a slice cannot be committed, do not mark it complete. Explain the blocker.
