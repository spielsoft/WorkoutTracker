# Remaining GUI MVP Reliability Issues

This is the active vertical-slice plan for the remaining GUI/MVP reliability
work. `ISSUES_PRD.md` is the product source; this file is the implementation
checklist.

Work through slices in dependency order. Use TDD for implementation slices:
write or update one failing behavior test through a public interface, implement
the smallest fix, run targeted tests, then update this checklist only after the
slice is complete.

Do not run live Google integration tests or write to live test spreadsheets
unless explicitly authorized for that slice. Rebuild the macOS release bundle
after GUI-facing changes and before live GUI validation.

## Checklist

- [x] Slice 1: Confirm Logged Sets Across Stale Post-Write Reads
- [ ] Slice 2: Preserve Recoverable Logging State On True Save Failure
- [ ] Slice 3: Repair Add-To-Workout Back Navigation Regression
- [ ] Slice 4: Run Live Multi-Set Confirmation Validation
- [ ] Slice 5: Repeat Black-Box GUI Regression Pass
- [ ] Slice 6: Clean Up Temporary GUI Tests

## Slice 1: Confirm Logged Sets Across Stale Post-Write Reads

### Type

`AFK`

### What to build

Make logged-set save confirmation resilient when Google Sheets accepts a write
but the first immediate reread does not yet show the written value. The app
should keep rereading within a small bounded confirmation window and report
success once the parsed logging context contains the expected set value.

This slice must keep the existing safety rule: success is only reported after
the saved set is visible through the public parsed logging context. The fix
must not introduce an app-owned workout history cache.

### Acceptance criteria

- [x] A stale first post-write refresh followed by a fresh refresh reports the
      set save as successful.
- [x] The refreshed controller/report state contains the saved set after
      confirmation succeeds.
- [x] The implementation uses a bounded retry policy with deterministic test
      behavior.
- [x] The write is not repeated just because the first read was stale.
- [x] A targeted controller or validation-service test covers the stale-read
      success path.
- [x] Relevant targeted Flutter tests pass.

### Blocked by

None - can start immediately.

### User stories covered

- Saved S2 appears after Google accepts the write.
- Brief Google Sheets read-after-write lag does not create a false failure.
- Future refactors preserve the confirmation behavior.

## Slice 2: Preserve Recoverable Logging State On True Save Failure

### Type

`AFK`

### What to build

Keep true save failures visibly recoverable after the retrying confirmation
path exists. If confirmation expires, the target row disappears, or a
conflicting value appears in the target set position, the app should show a
clear error and keep the attempted input available without falsely advancing
the current set.

This slice protects against the opposite failure mode from Slice 1: retrying
must not hide real write conflicts, schema drift, or manual sheet edits.

### Acceptance criteria

- [ ] A confirmation timeout still shows a visible logging error.
- [ ] A conflicting refreshed set value remains a failure rather than being
      treated as success.
- [ ] The attempted values remain visible and editable after true failure.
- [ ] The current-set indicator and progress do not advance on true failure.
- [ ] Retrying after a recoverable failure does not create duplicate or
      out-of-order set entries.
- [ ] Targeted controller and/or widget tests cover the true-failure path.
- [ ] Relevant targeted Flutter tests pass.

### Blocked by

- Slice 1: Confirm Logged Sets Across Stale Post-Write Reads

### User stories covered

- Real failed saves leave input visible.
- Conflicting sheet values are not hidden.
- Retrying a set save keeps workout history clean.

## Slice 3: Repair Add-To-Workout Back Navigation Regression

### Type

`AFK`

### What to build

Recheck and repair the live-observed navigation path where Back from Add to
workout returned to the account/sheet screen instead of workout setup. The user
should return to the selected workout and history block after leaving exercise
placement, including after placing an exercise and after using search.

Keep this slice narrow: it is a navigation/context repair, not a redesign of
sheet selection, exercise authoring, or workout setup.

### Acceptance criteria

- [ ] Back from Add to workout returns to workout setup for the selected sheet.
- [ ] Back after placing an exercise returns to the same workout and history
      block.
- [ ] Back after using exercise search does not route to the account/sheet
      screen.
- [ ] Existing account/sheet selection navigation remains available through
      its explicit controls.
- [ ] A focused widget test covers the observed live navigation path.
- [ ] Relevant targeted Flutter tests pass.
- [ ] The macOS release bundle is rebuilt if GUI-facing code changes.

### Blocked by

None - can start immediately.

### User stories covered

- Add to workout preserves user context.
- Building a plan does not require recovery from the sheet-selection screen.

## Slice 4: Run Live Multi-Set Confirmation Validation

### Type

`HITL`

### What to build

Run a GUI-only macOS validation pass after the stale-read confirmation fix and
release rebuild. The app must be logged in to a valid Google account, and the
tester must explicitly authorize live test workbook creation and writes. All
app input must use visible mouse and keyboard interactions.

The validation must compare app behavior with actual Google Sheet contents. The
goal is to prove that S1 and S2 both appear in the app after save and both
exist in the created workbook.

### Acceptance criteria

- [ ] The rebuilt macOS release app creates or selects a fresh test sheet
      through the GUI.
- [ ] A workout and history block are created or selected through the GUI.
- [ ] An exercise is added and S1 plus S2 are logged through the GUI.
- [ ] The app visibly shows the S2 save as successful after confirmation.
- [ ] The logged list and progress update visibly after S2.
- [ ] The created Google Sheet is inspected and contains the same S1 and S2
      values that the app displayed.
- [ ] The app is quit at the end of the pass.
- [ ] Findings are recorded with exact visible reproduction steps and the
      created sheet ID.

### Current live findings and uncertainty

- 2026-06-29: A GUI-only live pass created workbook
  `1x-qr7mNUqXwZNf54PnlCMCrS6WpRKyg6NakYL1OkEZ0`, built workout
  `Slice4 Test`, history block `Slice4 Block`, added Bench Press, and wrote
  `S1=135x6@8` and `S2=140x6@8.5` to the Google Sheet. The app still reported
  `saved set was not visible after refresh` for S2 in that pass, proving the
  stale read-after-write confirmation failure mode. A follow-up AFK fix extended
  bounded confirmation rereads, but the full Slice 4 live pass still needs to be
  rerun end to end before this slice can be marked complete.
- 2026-06-29 user HITL clarification: after clicking `Create sheet`, the app
  reached the expected setup screen with Workout and History block selectors
  visible. This means the earlier Computer Use failure to activate `Create
  sheet` should be treated as a live-validation tooling/click-target ambiguity,
  not as confirmed app product behavior.
- 2026-06-29 user HITL clarification: using the workout dropdown arrow and
  choosing `Add workout...` allowed a human tester to create workout `Test`,
  after which the workout dropdown showed `Test (0/0 done)`. This reduces
  confidence that the earlier Computer Use text-entry failures in the Add
  workout prompt represent an app bug. Keep the prompt-focus test coverage, but
  do not treat the human Add workout path as blocked without a fresh observed
  failure.
- 2026-06-29 user HITL observation: after `Add history block` and entering a
  label such as `S1` or `S2`, the history dropdown did not refresh immediately;
  it showed the new item after roughly one second. This is not yet known to be a
  correctness failure because history-block creation writes to Google and then
  revalidates the workbook, but it is a UX/reliability ambiguity. The next live
  pass should record whether a busy/disabled state is visible during this delay
  and whether the dropdown consistently lands on the new history block after the
  refresh completes.

### Blocked by

- Slice 1: Confirm Logged Sets Across Stale Post-Write Reads
- Slice 2: Preserve Recoverable Logging State On True Save Failure
- User must provide live Google login/authorization and permit test writes.

### User stories covered

- In-gym multi-set logging can be trusted.
- Live validation compares app state with the sheet source of truth.

## Slice 5: Repeat Black-Box GUI Regression Pass

### Type

`HITL`

### What to build

Repeat the macOS GUI-only stress pass after implementation fixes, targeted
tests, release rebuild, and Slice 4 live confirmation validation. The pass should
create a new sheet, add custom canonical exercises, build at least two workouts,
log multiple sets including S2 or later, and try plausible gym-use
interactions.

The tester must not use accessibility setters, direct APIs, source inspection,
or direct sheet edits to drive the app. Spreadsheet inspection is allowed only
as validation evidence after GUI actions.

### Acceptance criteria

- [ ] The pass uses only visible mouse and keyboard interactions to operate the
      app.
- [ ] A new Google-backed sheet is created through the GUI.
- [ ] Several custom canonical exercises are added through the GUI.
- [ ] At least two workouts are built through the GUI.
- [ ] Multiple sets, including S2 or later, are logged through the GUI.
- [ ] Add-to-workout back navigation preserves workout setup context during the
      pass.
- [ ] The created Google Sheet is inspected after the pass and matches the
      visible logged app state.
- [ ] The app is quit when the pass is complete or when a blocker is hit.
- [ ] Pain points and blockers are reported with reproduction steps.

### Blocked by

- Slice 3: Repair Add-To-Workout Back Navigation Regression
- Slice 4: Run Live Multi-Set Confirmation Validation
- User must provide live Google login/authorization and permit test writes.

### Carry-forward notes from Slice 4

- Do not classify Computer Use-only failures to click `Create sheet` or type in
  the Add workout prompt as product blockers unless they are reproduced by a
  human tester or by a macOS-specific app-level test. User HITL evidence shows
  the sheet-creation and Add workout paths can work through normal visible UI.
- Treat the delayed history-block dropdown refresh as a live UX item to observe
  during this stress pass. If the app gives no visible pending state or the
  delay causes plausible duplicate submissions/confusion, convert that finding
  into a narrow AFK implementation slice before completing Slice 5.

### User stories covered

- The MVP flow works under realistic gym use.
- GUI validation reflects actual user interactions and sheet contents.

## Slice 6: Clean Up Temporary GUI Tests

### Type

`AFK`

### What to build

Use the `test-cleanup` skill to review tests added during the remaining
reliability work. Keep durable behavior tests that protect user-facing
contracts and remove or rewrite tests that only pin temporary implementation
details.

This slice should preserve focused coverage for stale read-after-write
confirmation, true failure recovery, Add-to-workout navigation, and the public
MVP logging flow.

### Acceptance criteria

- [ ] Tests assert observable behavior through public app, controller, widget,
      or adapter interfaces.
- [ ] Tests do not over-constrain private helper structure, retry internals, or
      incidental widget shape.
- [ ] Durable tests still cover stale post-write confirmation success, true
      save-failure recovery, and Add-to-workout navigation.
- [ ] Relevant targeted tests pass.
- [ ] The macOS release bundle is rebuilt if any GUI-facing code changes.

### Blocked by

- Slice 5: Repeat Black-Box GUI Regression Pass

### User stories covered

- Future refactors keep the MVP GUI path reliable.
- The test suite stays maintainable after TDD.
