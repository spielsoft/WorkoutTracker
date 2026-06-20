# WorkoutTracker Agent Prompts

Use these prompts to start development with one agent or coordinate slices with subagents. Replace bracketed text as needed.

## 1. Kick Off Development

```text
You are working in the WorkoutTracker repository.

WorkoutTracker is a lightweight cross-platform gym workout logging app. The durable data artifact is a user-owned Google Sheet. The implementation should preserve a standard Flutter/Dart package layout and keep the backend sheet-contract logic complete before GUI work begins.

Read `AGENTS.md`, `ISSUES_MVP.md`, and `issues/MVP_prd.md` first. If additional project guidance files exist, read them before choosing work.

In what follows [N] = ...

Perform the work described in Slice [N].

Favor existing Flutter, Dart, Google API, and testing packages over custom implementations. Add custom code only when a package does not fit or when a thin domain-specific layer is needed. Keep the sheet-contract backend testable without Google access wherever possible.

Use TDD for the slice:

1. Identify the public behavior the slice must provide.
2. Write one failing behavior test through the public interface.
3. Implement the smallest code needed to pass.
4. Repeat until the slice acceptance criteria are met.
5. Refactor only after tests are green.
6. Run the relevant targeted tests for the changed behavior. Do not run the
   whole suite reflexively unless this is a release/full-validation task or the
   slice acceptance criteria require it.
7. Update the `ISSUES_MVP.md` checklist if the slice is complete.
8. Commit the completed slice with a message like `Complete slice [N]: [slice title]`.

For backend slices, keep tests focused on observable sheet behavior: parsing, validation, formula healing, history block planning, set notation, write planning, Google adapter behavior, and cleanup/reset behavior. Do not couple tests to private helpers or implementation choreography.

For Google Sheets integration slices, first try to complete the work AFK using the provided development sheet:

https://docs.google.com/spreadsheets/d/1zQrmCYelrNqRMv4WtJcOrtezSxoaVniXzXi4XgKva_E/edit?gid=0#gid=0

If local app authentication requires user interaction, stop at the smallest necessary HITL point and explain exactly what login/authorization action is needed. Do not mark the slice complete until the live read/write behavior required by the acceptance criteria is verified.

Live Google integration tests are opt-in. Do not run
`integration_test/live_logging_flow_test.dart` against Google unless the user or
task explicitly requires live validation, Google login/HITL is ready, and
development-sheet writes are acceptable. Set
`WORKOUT_TRACKER_RUN_LIVE_GOOGLE_TESTS=1` for that run; without it, the live
test should skip before authentication.

Do not begin GUI slices until Slice 16 is complete. For GUI slices, use the completed backend modules rather than duplicating sheet parsing, validation, formula healing, or write planning in UI code.

Do not broaden scope beyond this slice unless required by its acceptance criteria. Preserve unrelated worktree changes. Stage only files that belong to the slice. At the end, report the commit hash, changed files, tests run, and any risks or follow-up slices. If you cannot commit, do not mark the slice complete; explain the blocker.
```

## 2. Kick Off Development of Several Slices

```text
You are working in the WorkoutTracker repository.

WorkoutTracker is a lightweight cross-platform gym workout logging app. The durable data artifact is a user-owned Google Sheet. The implementation should preserve a standard Flutter/Dart package layout and keep the backend sheet-contract logic complete before GUI work begins.

Read `AGENTS.md`, `ISSUES_MVP.md`, and `issues/MVP_prd.md` first. If additional project guidance files exist, read them before choosing work.

In what follows you will be working on several slices with [N] = ... to ... . For each slice:

Perform the work described in Slice [N].

Favor existing Flutter, Dart, Google API, and testing packages over custom implementations. Add custom code only when a package does not fit or when a thin domain-specific layer is needed. Keep the sheet-contract backend testable without Google access wherever possible.

Use TDD for the slice:

1. Identify the public behavior the slice must provide.
2. Write one failing behavior test through the public interface.
3. Implement the smallest code needed to pass.
4. Repeat until the slice acceptance criteria are met.
5. Refactor only after tests are green.
6. Run the relevant targeted tests for the changed behavior. Do not run the
   whole suite reflexively unless this is a release/full-validation task or the
   slice acceptance criteria require it.
7. Update the `ISSUES_MVP.md` checklist if the slice is complete.
8. Commit the completed slice with a message like `Complete slice [N]: [slice title]`.

For backend slices, keep tests focused on observable sheet behavior: parsing, validation, formula healing, history block planning, set notation, write planning, Google adapter behavior, and cleanup/reset behavior. Do not couple tests to private helpers or implementation choreography.

For Google Sheets integration slices, first try to complete the work AFK using the provided development sheet:

https://docs.google.com/spreadsheets/d/1zQrmCYelrNqRMv4WtJcOrtezSxoaVniXzXi4XgKva_E/edit?gid=0#gid=0

If local app authentication requires user interaction, stop at the smallest necessary HITL point and explain exactly what login/authorization action is needed. Do not mark the slice complete until the live read/write behavior required by the acceptance criteria is verified.

Live Google integration tests are opt-in. Do not run
`integration_test/live_logging_flow_test.dart` against Google unless the user or
task explicitly requires live validation, Google login/HITL is ready, and
development-sheet writes are acceptable. Set
`WORKOUT_TRACKER_RUN_LIVE_GOOGLE_TESTS=1` for that run; without it, the live
test should skip before authentication.

Respect dependencies in `ISSUES_MVP.md`. Do not run dependent slices out of order. Do not begin GUI slices until Slice 16 is complete. For GUI slices, use the completed backend modules rather than duplicating sheet parsing, validation, formula healing, or write planning in UI code.

Do not broaden scope beyond the requested slices unless required by their acceptance criteria. Preserve unrelated worktree changes. Stage only files that belong to the current slice. Commit after each completed slice, not only at the end. At the end, report each commit hash, changed files, tests run, and any risks or follow-up slices. If you cannot commit a slice, do not mark it complete; explain the blocker.
```

## 3. Kick Off Development With Subagents

```text
You are coordinating work in the WorkoutTracker repository.

Use subagents for all slices in `ISSUES.md`. Read `AGENTS.md` and `ISSUES.md` first. If a cleanup slice explicitly references another project document, read only that referenced document before dispatching that slice.

The active plan is `ISSUES.md`. Dispatch work in dependency order. Do not run dependent slices concurrently.  If multiple subagents will touch the same checkout, serialize them; only run slices concurrently when they are independent and isolated in separate worktrees. Each completed slice must pass its relevant tests, update the `ISSUES.md` checklist, and commit its own changes before the next dependent slice starts.

Favor deeper Modules with smaller Interfaces and better Locality over moving code sideways. 

Continue until the requested work is complete, but stop if any blockers are encountered. Report the final summary from each subagent, especially any concerns or risks they identified.

Send each subagent this prompt with [N] replaced by the assigned slice:

You are working in the WorkoutTracker repository as a subagent.

WorkoutTracker is a lightweight cross-platform gym workout logging app. The durable data artifact is a user-owned Google Sheet. The implementation should preserve a standard Flutter/Dart package layout and keep the backend sheet-contract logic complete before GUI work begins.

Read `AGENTS.md` and `ISSUES.md` first. If cleanup Slice [N] explicitly references another project document, read only that referenced document before starting work.

Perform the work described in cleanup Slice [N] in `ISSUES.md`.

Favor demand Flutter, Dart, Google API, and testing packages over custom implementations. Add custom code only when a package does not fit or when a thin domain-specific layer is needed. Keep the sheet-contract backend testable without Google access wherever possible.

Use TDD for the slice:

1. Identify the public behavior the slice must provide.
2. Write one failing behavior test through the public interface.
3. Implement the smallest code needed to pass.
4. Repeat until the slice acceptance criteria are met.
5. Refactor only after tests are green.
6. Run the relevant targeted tests for the changed behavior. Do not run the
   whole suite reflexively unless this is a release/full-validation task or the
   slice acceptance criteria require it.
7. Update the `ISSUES.md` checklist if the slice is complete.
8. Commit the completed slice with a message like `Complete slice [N]: [slice title]`.

For cleanup slices, keep tests focused on observable behavior through public Interfaces. Do not couple tests to private helpers or implementation choreography. Preserve the intended seams: sheet-contract parsing/read models/write planning, log-format parsing/rendering, GUI presentation, validation/auth orchestration, Google Sheets adapters, and development reset behavior.

For Google Sheets integration slices, first try to complete the work AFK using the provided development sheet:

https://docs.google.com/spreadsheets/d/1zQrmCYelrNqRMv4WtJcOrtezSxoaVniXzXi4XgKva_E/edit?gid=0#gid=0

If local app authentication requires user interaction, stop at the smallest necessary HITL point and explain exactly what login/authorization action is needed. Do not mark the slice complete until the live read/write behavior required by the acceptance criteria is verified.

Live Google integration tests are opt-in. Do not run
`integration_test/live_logging_flow_test.dart` against Google unless the user or
task explicitly requires live validation, Google login/HITL is ready, and
development-sheet writes are acceptable. Set
`WORKOUT_TRACKER_RUN_LIVE_GOOGLE_TESTS=1` for that run; without it, the live
test should skip before authentication.

For GUI cleanup slices, use the completed backend Modules rather than duplicating sheet parsing, validation, formula healing, log-format parsing, or write planning in UI code. For GUI validation slices, build or run the macOS app and report the `.app` path when a bundle is produced, unless the slice is explicitly documentation-only.

Do not broaden scope beyond this slice unless required by its acceptance criteria. Preserve unrelated worktree changes. Stage only files that belong to the slice. At the end, report the commit hash, changed files, tests run, app bundle status for GUI work, whether the `ISSUES.md` checklist was updated, and any risks or follow-up slices. If you cannot commit, do not mark the slice complete; explain the blocker.
```
