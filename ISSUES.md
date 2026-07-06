# Cleanup Implementation Plan

## Checklist

- [ ] Slice 1: Prove And Fix Read-Write Authorization Scope Handling
- [ ] Slice 2: Stop Restoring Picker Tokens As Durable Write Credentials
- [ ] Slice 3: Surface Google Auth Failures As Reconnectable State
- [ ] Slice 4: Make Add-To-Workout Write Failures Visible And Recoverable
- [ ] Slice 5: Guard Startup Restore And Service Actions Against Stale Results
- [ ] Slice 6: Split Google Picker Selection Responsibilities
- [ ] Slice 7: Neutralize Authorization Naming And Remove Dead Sign-In Paths
- [ ] Slice 8: Narrow GUI Flow Ownership Around Workout And Exercise Screens
- [ ] Slice 9: Hide Low-Level Active-Sheet Write-Plan Internals
- [ ] Slice 10: Continue Widget Test Cleanup By Behavior Area
- [ ] Slice 11: Run Auth And Architecture Validation Gate

## Slice 1: Prove And Fix Read-Write Authorization Scope Handling

### Type

`AFK`

### What to build

Create a focused local proof around the app-owned Google authorization contract: reading/navigating a selected sheet is not enough to prove write authorization. Fix the Picker-backed authorization path so the scopes requested by Sheets write operations are actually requested and represented in the authorization used for those writes.

### Acceptance criteria

- [ ] Local tests prove the Picker gateway does not ignore requested scopes for Sheets write operations.
- [ ] The Picker authorization URL or equivalent authorization path requests the scopes required by workbook validation and writes, not only file selection scope.
- [ ] Tests cover the reported shape: selected sheet can be present/readable while write authorization is missing or insufficient.
- [ ] Reconnecting through the app obtains authorization capable of the requested Sheets write operations, or clearly reports that write authorization was not granted.
- [ ] No live Google credentials are required for the default test.

### Blocked by

None - can start immediately

### User stories covered

- User stories 1, 7, 8, 9
- PRD sections: Solution, Implementation Decisions, Testing Decisions

## Slice 2: Stop Restoring Picker Tokens As Durable Write Credentials

### Type

`AFK`

### What to build

Change persisted Google workspace state so a restored Picker access token is not treated as durable write authorization after app restart. The app should still restore selected spreadsheet metadata and account display metadata, but write authorization should restart in a missing-or-needs-refresh state unless fresh operation-appropriate authorization is obtained.

### Acceptance criteria

- [ ] Local tests prove restored workspace state does not produce usable write authorization headers from an old Picker bearer token.
- [ ] Selected spreadsheet metadata still restores and remains visible after restart.
- [ ] Account display metadata may restore for UI display, but it is not enough to authorize Google write API calls.
- [ ] Existing saved states with an access token do not crash; they are interpreted as needing fresh write authorization.
- [ ] No live Google credentials are required for the test.

### Blocked by

- Slice 1: Prove And Fix Read-Write Authorization Scope Handling

### User stories covered

- User stories 1, 2, 3, 7
- PRD sections: Solution, Implementation Decisions, Testing Decisions

## Slice 3: Surface Google Auth Failures As Reconnectable State

### Type

`AFK`

### What to build

Add central handling for Google auth failures. When Google API calls return an auth failure such as invalid credentials or insufficient permission, invalidate unusable authorization, preserve useful selected spreadsheet metadata, and expose a clear reconnect or reauthorize state in the app instead of a generic validation failure.

### Acceptance criteria

- [ ] A simulated Google auth failure invalidates stored write authorization through the app-owned state interface.
- [ ] The selected spreadsheet remains available for reconnect after auth is invalidated.
- [ ] The UI shows copy equivalent to "Google authorization needs reconnect" with an actionable reconnect or reauthorize control.
- [ ] Non-auth failures still use the existing connection/validation failure path.
- [ ] Tests cover the controller/service contract and the visible reconnect or reauthorize state.

### Blocked by

- Slice 1: Prove And Fix Read-Write Authorization Scope Handling
- Slice 2: Stop Restoring Picker Tokens As Durable Write Credentials

### User stories covered

- User stories 1, 2, 3, 7
- PRD sections: Solution, Implementation Decisions, Testing Decisions

## Slice 4: Make Add-To-Workout Write Failures Visible And Recoverable

### Type

`AFK`

### What to build

Improve the add-to-workout flow so failed writes are visible on or near the form that launched the write. Preserve the selected exercise and edited placement metadata after failure, disable submit while busy, and make auth failures route to the reconnect or reauthorize action.

### Acceptance criteria

- [ ] A simulated add-to-workout write failure leaves the user on the form with the selected exercise and metadata intact.
- [ ] The submit action is disabled while the write is in flight.
- [ ] The failure is visible without navigating away from the form.
- [ ] Auth failures show the reconnect or reauthorize action from Slice 3.
- [ ] Widget tests assert visible behavior rather than private implementation structure where practical.

### Blocked by

- Slice 3: Surface Google Auth Failures As Reconnectable State

### User stories covered

- User stories 4, 5, 6, 7
- PRD sections: Problem Statement, Solution, Testing Decisions

## Slice 5: Guard Startup Restore And Service Actions Against Stale Results

### Type

`AFK`

### What to build

Prevent slow startup restore, validation, or write futures from overwriting newer user choices. Add a small command serialization or generation-token mechanism around restore and service actions so stale async results are ignored.

### Acceptance criteria

- [ ] A delayed startup restore cannot overwrite spreadsheet text or selection entered after startup.
- [ ] Overlapping validation or write operations cannot let an older result replace a newer report.
- [ ] Busy state remains accurate after success, failure, and ignored stale results.
- [ ] Tests use controllable futures and public app/controller behavior.
- [ ] Existing startup restore behavior still works when no newer user action occurs.

### Blocked by

- Slice 2: Stop Restoring Picker Tokens As Durable Write Credentials

### User stories covered

- User stories 11, 12
- PRD sections: Problem Statement, Implementation Decisions, Testing Decisions

## Slice 6: Split Google Picker Selection Responsibilities

### Type

`AFK`

### What to build

Reshape the Google Picker modules so config parsing, callback validation, Picker authorization launch, selected-spreadsheet resolving, and workbook creation are owned by focused modules with small interfaces. Preserve behavior while improving locality and testability.

### Acceptance criteria

- [ ] Picker callback validation can be tested without launching URLs or touching Google API clients.
- [ ] Selected-spreadsheet resolving is separated from Picker launch mechanics.
- [ ] Spreadsheet creation remains available through the selected single auth path.
- [ ] Existing local Picker and workspace tests pass after the split.
- [ ] No production behavior changes beyond those required by prior auth slices.

### Blocked by

- Slice 1: Prove And Fix Read-Write Authorization Scope Handling
- Slice 3: Surface Google Auth Failures As Reconnectable State

### User stories covered

- User stories 9, 14
- PRD sections: Implementation Decisions, Testing Decisions

## Slice 7: Neutralize Authorization Naming And Remove Dead Sign-In Paths

### Type

`AFK`

### What to build

Rename misleading Google Sign-In-specific interfaces and variables to neutral Google authorization/session names if Picker remains the chosen path. Remove unused native Google Sign-In implementations and dependency entries only after tests and platform wiring show they are not used.

### Acceptance criteria

- [ ] Core auth interfaces no longer imply native Google Sign-In when they are used by Picker authorization.
- [ ] Production wiring uses neutral names that reflect the selected architecture.
- [ ] Unused native Google Sign-In code is removed only if no current platform path depends on it.
- [ ] Dependency cleanup is covered by analysis/build checks appropriate to the changed platforms.
- [ ] Tests are updated to use the neutral auth vocabulary.

### Blocked by

- Slice 1: Prove And Fix Read-Write Authorization Scope Handling
- Slice 3: Surface Google Auth Failures As Reconnectable State
- Slice 6: Split Google Picker Selection Responsibilities

### User stories covered

- User stories 9, 10
- PRD sections: Solution, Implementation Decisions, Out of Scope

## Slice 8: Narrow GUI Flow Ownership Around Workout And Exercise Screens

### Type

`AFK`

### What to build

Move workout/exercise screen state and transitions out of the large shell callback graph into a smaller flow module or controller-owned read model. Keep the patch behavior-preserving while reducing the number of callbacks passed through the workout selection surface.

### Acceptance criteria

- [ ] The shell no longer owns all transient route intent state directly.
- [ ] Workout setup, exercise picker, exercise manager, add/edit exercise, and logging flows still navigate as before.
- [ ] Tests cover user-visible navigation outcomes rather than callback plumbing.
- [ ] The change reduces callback fan-out in the workout/exercise selection surface.
- [ ] No backend sheet-contract behavior is duplicated in GUI code.

### Blocked by

- Slice 4: Make Add-To-Workout Write Failures Visible And Recoverable
- Slice 5: Guard Startup Restore And Service Actions Against Stale Results

### User stories covered

- User stories 13, 17
- PRD sections: Implementation Decisions, Testing Decisions

## Slice 9: Hide Low-Level Active-Sheet Write-Plan Internals

### Type

`AFK`

### What to build

Reduce public exposure of low-level active-sheet write operations and expectation classes. Preserve domain planning behavior while moving internal expectations and operation details behind a smaller write-plan interface.

### Acceptance criteria

- [ ] Callers can still request domain write plans and apply/preview them through supported public behavior.
- [ ] Internal expectation classes are no longer part of the broad public sheet-contract surface where practical.
- [ ] Existing write-planning behavior tests continue to prove planned writes, rejections, and preview results.
- [ ] Tests avoid asserting private helper names or internal class taxonomy.
- [ ] Google write adapters still receive the operations they need.

### Blocked by

- Slice 5: Guard Startup Restore And Service Actions Against Stale Results

### User stories covered

- User stories 15, 17
- PRD sections: Implementation Decisions, Testing Decisions

## Slice 10: Continue Widget Test Cleanup By Behavior Area

### Type

`AFK`

### What to build

Use the `test-cleanup` skill to split the remaining large widget test into behavior-focused files that share the extracted support helpers. Replace fragile private-key navigation with visible text, semantics, or public outcomes where practical.

### Acceptance criteria

- [ ] Widget tests are split into behavior areas such as sheet selection/auth, validation/repair, workout placement, exercise authoring, logging, and account menu.
- [ ] Shared fake services and fixture builders live in support helpers rather than the main widget test file.
- [ ] Tests retain meaningful behavioral coverage while removing implementation-coupled assertions where they are not intentional public test surface.
- [ ] The focused widget suites pass individually and as a group.
- [ ] The cleanup does not change production behavior.

### Blocked by

- Slice 4: Make Add-To-Workout Write Failures Visible And Recoverable
- Slice 8: Narrow GUI Flow Ownership Around Workout And Exercise Screens

### User stories covered

- User stories 16, 17
- PRD sections: Testing Decisions, Further Notes

## Slice 11: Run Auth And Architecture Validation Gate

### Type

`AFK`

### What to build

Run the broad local validation needed after auth, GUI flow, write-plan, and test cleanup changes. Document any remaining live-Google assumptions and keep opt-in live validation separate unless the user confirms HITL readiness.

### Acceptance criteria

- [ ] Broad local Flutter tests pass.
- [ ] `flutter analyze` passes.
- [ ] Relevant platform build or smoke validation is run if changed auth/platform wiring requires it.
- [ ] Any remaining Google behavior assumptions are documented instead of represented as mock-proven facts.
- [ ] The issue checklist is updated and each completed slice has a commit hash.

### Blocked by

- Slice 7: Neutralize Authorization Naming And Remove Dead Sign-In Paths
- Slice 8: Narrow GUI Flow Ownership Around Workout And Exercise Screens
- Slice 9: Hide Low-Level Active-Sheet Write-Plan Internals
- Slice 10: Continue Widget Test Cleanup By Behavior Area

### User stories covered

- User stories 18
- PRD sections: Testing Decisions, Out of Scope, Further Notes
