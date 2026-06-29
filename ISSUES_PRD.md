# Remaining GUI MVP Reliability PRD

## Problem Statement

WorkoutTracker's remaining MVP risk is not that Google failed to save the
second logged set. Live evidence shows the second set was written to the
Google-backed sheet. The problem is that the app's immediate post-write refresh
can fail to observe that just-written set, report a save failure, and leave the
user unsure whether the sheet contains the set.

That false failure is serious in a gym context. A lifter may retry the same set,
change values unnecessarily, or stop trusting the app. The app must report set
save outcomes based on a reliable post-write confirmation path, not on a single
possibly stale read immediately after the Sheets API write returns.

The remaining GUI hardening work also needs one observed navigation regression
to be revalidated and fixed if present: returning from Add to workout sometimes
lands on the account/sheet screen rather than workout setup. Final black-box
validation cannot complete until multi-set logging and navigation are reliable
in the rebuilt macOS release app.

## Solution

Make set-save confirmation resilient to Google Sheets read-after-write
staleness while preserving the app's existing safety rule: do not clear user
input or advance the visible logging state unless the refreshed public logging
context contains the saved value.

The implementation should confirm a logged-set write by rereading the selected
spreadsheet until either:

- the expected saved set appears in the parsed logging context;
- a real conflicting value appears in the target set cell;
- a real schema/write rejection blocks the target; or
- a bounded retry window expires.

When confirmation succeeds after a stale read, the user should see the normal
logged-set progression with no false error. When confirmation truly fails, the
user should still see a visible error and retain the attempted input.

After the confirmation path is fixed, rebuild the macOS release app and run
live GUI validation through visible mouse and keyboard interactions. Use the
connected Google Sheet itself as evidence: inspect the created workbook after
the GUI run to verify what the app wrote and what the app displayed.

## User Stories

1. As a lifter, I want a saved second set to appear in the app after Google
   accepts the write, so that I can continue logging without second-guessing
   the sheet.
2. As a lifter, I want the app to tolerate brief Google Sheets read-after-write
   lag, so that a successful save is not reported as a failure.
3. As a lifter, I want a real failed save to leave my input visible, so that I
   can retry or correct it without retyping from memory.
4. As a lifter, I want the app to distinguish stale reads from conflicting
   sheet values, so that the app does not hide real data races or manual edits.
5. As a lifter, I want retrying a set save to avoid duplicate or out-of-order
   set entries, so that my workout history stays clean.
6. As a lifter, I want Add to workout back navigation to return to workout
   setup, so that I do not lose context while building a plan.
7. As a tester, I want live validation to inspect the Google-backed sheet after
   the GUI run, so that apparent app failures can be compared with actual sheet
   contents.
8. As a tester, I want the macOS black-box pass to create a fresh sheet, add
   custom exercises, build multiple workouts, and log multiple sets, so that
   the MVP flow is validated end to end.
9. As a maintainer, I want the stale-read behavior covered by focused tests, so
   that future refactors do not reintroduce false save failures.
10. As a maintainer, I want temporary TDD scaffolding cleaned up after the fix,
    so that the test suite protects behavior without pinning incidental
    implementation details.

## Implementation Decisions

- Keep the Google Sheet as the source of truth. Do not add an app-owned workout
  database or optimistic local workout history store.
- Preserve the current safety invariant: the logging UI may only report a save
  as successful when the parsed public logging context contains the saved set
  value.
- Treat one stale refresh after a Sheets write as an expected live-service
  condition. Confirmation should allow a bounded number of additional reads
  before reporting failure.
- Keep retry policy explicit and small. It should be deterministic under test
  and should not produce unbounded waits in the GUI.
- Do not blindly accept any later sheet state. A conflicting value in the
  target set position should remain a visible failure rather than being treated
  as success.
- Keep post-write confirmation behind the existing spreadsheet validation and
  controller boundaries so widget code does not duplicate sheet parsing or set
  matching logic.
- Keep live Google validation opt-in and HITL. The release app must be logged
  in and the tester must authorize test workbook creation and writes.
- Use the connected spreadsheet contents as part of live validation evidence.
  The prior live sheet showed `S2 = 140x6@8.5` even though the app displayed a
  stale-refresh error, which is the core evidence for this PRD.
- Preserve unrelated worktree changes. Stage and commit only files that belong
  to the active slice.
- Rebuild the macOS release bundle after GUI-facing changes and before live
  GUI validation.

## Testing Decisions

- Use TDD for implementation slices. Start with a failing behavior test through
  a public controller, validation-service, or widget interface.
- Add a focused stale-read confirmation test: the first post-write refresh does
  not contain the saved set, a later refresh does, and the user-facing save
  result is success.
- Keep an explicit true-failure test: if the refreshed sheet never contains the
  expected set or contains a conflicting value, the save reports a visible
  error and preserves input.
- Add or update a navigation behavior test for Add to workout back behavior
  only if the current test suite does not already catch the observed live path.
- Use targeted Flutter tests for controller and widget behavior. These tests
  must not require Google credentials.
- Use live Google GUI validation only after local tests and release rebuild
  pass. The live validation should create a fresh test workbook, log S1 and S2,
  verify visible app state, then inspect the created sheet contents.
- After the implementation and validation slices, use the `test-cleanup` skill
  to remove or rewrite tests that only served the TDD loop while preserving
  durable behavior coverage.

## Out of Scope

- Replacing Google Sheets as the durable data artifact.
- Building an offline workout database or sync engine.
- Broad visual redesign.
- Coaching, progression, or programming logic.
- Directly editing live spreadsheets to make validation pass.
- Treating Computer Use or accessibility-tool failures as product bugs unless
  the app itself visibly crashes or reproduces the behavior outside the
  automation tool.
- Reworking unrelated GUI areas except where they are needed to fix the
  remaining navigation or validation failures.

## Further Notes

Live evidence from the recent GUI pass:

- The app created a Google-backed sheet named `WorkoutTracker 2026-06-28`.
- The GUI logged S1 for Bench Press and advanced to S2.
- The GUI attempted S2 as `140 / 6 / 8.5` and showed
  `saved set was not visible after refresh`.
- Later spreadsheet inspection showed the active sheet contained
  `S1 = 135x6@8` and `S2 = 140x6@8.5`.

This means the likely cause is read-after-write confirmation staleness, not a
missing write and not obvious workbook corruption.
