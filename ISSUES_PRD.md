# WorkoutTracker Reliability and Architecture Cleanup PRD

## Problem Statement

WorkoutTracker currently lets the macOS app look connected to Google Sheets while write operations can still fail with Google `401` errors. The user can read and navigate the selected sheet, including the workout contents, but writes such as creating an exercise or adding an exercise to a workout can fail. Disconnecting and reconnecting through the app reportedly does not fix the failure, so the problem is not proven to be only a stale restored token.

The verified code path shows a likely read/write authorization mismatch. Production wires `GooglePickerAuthorizationGateway` into all Google API access. Validation and writes request Sheets write scope from `GoogleScopedApiAccess`, but the Picker gateway ignores the requested scopes and returns whatever bearer token was most recently received from the Picker callback. The Picker authorization URL currently requests `drive.file`, not the Sheets write scope that the workbook client says it needs. That makes reconnect insufficient if reconnect simply obtains another token with the same insufficient scope. Persisted short-lived Picker tokens are still a risk after restart, but scope alignment and write authorization must be tested first rather than assumed.

The auth bug sits next to broader maintainability issues found in review: startup restore and command execution can race, GUI flow state is spread through a large shell and callback graph, Google Picker selection mixes multiple responsibilities, the active-sheet write-plan interface exposes too much internal machinery, and widget tests remain large and coupled to private UI keys. These issues make the auth bug harder to fix safely and make future sheet-contract changes more expensive.

## Solution

WorkoutTracker should make Google authorization explicit and verifiable for the operation being attempted. Read access, metadata resolution, and write access must not be conflated. Before any Sheets write, the app must either hold authorization that was requested for the required Sheets write scopes or route the user through the single chosen authorization path to obtain it. The app should treat Google Picker access tokens as short-lived credentials, not durable app state, but stale-token handling must be implemented alongside scope-correct authorization rather than as the only explanation.

The implementation should preserve the product decision that Google Picker is the single user-facing sheet selection and authorization path unless a later explicit decision replaces it with a single Google Sign-In-backed path that does not require a second prompt. The immediate plan should use the Picker-oriented architecture and remove misleading naming that implies durable native Google Sign-In ownership.

When Google returns an auth failure, the app should distinguish expired credentials from insufficient scopes where possible. It should clear or invalidate unusable authorization, keep selected spreadsheet metadata where useful, show an actionable reconnect or reauthorize state, and avoid making write failures appear silent. The add-to-workout form should remain recoverable after failures but should show the failure near the action that failed.

In parallel, the app should deepen the relevant modules: centralize authorization/session handling, centralize command serialization and stale-result protection, narrow GUI flow ownership, split Google Picker selection responsibilities, hide low-level write-plan machinery, and continue test cleanup so tests assert public behavior rather than private widget structure.

## User Stories

1. As a returning macOS user, I want reopening the app to show whether my Google session can perform the needed write operations, so that I do not discover an unusable session only after a failed write.
2. As a returning macOS user, I want my selected spreadsheet to remain remembered after restart, so that reconnecting does not require finding the sheet again.
3. As a returning macOS user, I want expired Google authorization to produce a clear reconnect action, so that I know how to fix the problem.
4. As a workout logger, I want adding an exercise to a workout to visibly report write failures on the same form, so that the action does not feel like it did nothing.
5. As a workout logger, I want add-to-workout submit controls disabled while a write is in flight, so that duplicate writes are not launched.
6. As a workout logger, I want failed add-to-workout attempts to preserve my selected exercise and edited metadata, so that I can reconnect or retry without re-entering work.
7. As a workout logger, I want Google auth failures to identify expired credentials or insufficient scopes when possible, so that the next action fixes the real authorization problem.
8. As a user choosing a spreadsheet, I want Google Picker authorization to request the scopes needed for later Sheets write operations, so that reading a sheet does not mask a write-scope failure.
9. As a user choosing a spreadsheet, I want only one Google-facing auth path, so that I am not asked to sign in twice.
10. As a developer, I want authorization interfaces named around generic Google authorization rather than Google Sign-In if Picker is the chosen path, so that the code matches the product architecture.
11. As a developer, I want startup restore operations to ignore stale async results, so that slow saved-state restore cannot overwrite a newer user selection.
12. As a developer, I want app service actions serialized or guarded, so that overlapping validation/write results cannot overwrite newer state.
13. As a developer, I want GUI screen transitions owned by a small flow module or controller interface, so that adding a flow does not require threading state and callbacks through a large shell.
14. As a developer, I want Google Picker selection, callback parsing, selected-sheet resolving, and workbook creation separated into focused modules, so that each behavior can be tested and changed locally.
15. As a developer, I want active-sheet write plans to expose domain-level behavior rather than low-level expectation classes, so that callers cannot couple to internal write mechanics.
16. As a developer, I want widget tests split by behavior area with shared helper libraries, so that GUI cleanup can continue without one giant test file.
17. As a developer, I want tests to assert visible behavior, public controller outcomes, and documented adapter contracts, so that tests survive internal widget and module refactors.
18. As a release owner, I want opt-in live Google validation to remain separate from local tests, so that local cleanup stays fast and deterministic while real Google behavior is validated deliberately.

## Implementation Decisions

- First prove the actual auth failure mode through local tests around the app-owned authorization interfaces. Do not assume stale-token-only behavior when read succeeds and reconnect does not fix writes.
- Treat Google Picker access tokens as operation-scoped and ephemeral. Persist selected spreadsheet metadata and account display metadata, but do not restore a persisted bearer token as valid write authorization.
- Make requested scopes meaningful for Picker-backed authorization. The Picker gateway must not ignore the scopes requested by Google API access when later writes depend on those scopes.
- Keep Google Picker as the immediate single user-facing path. Do not revert to a second native Google Sign-In prompt unless a later explicit architecture decision integrates it behind the same user-facing session.
- Introduce a neutral authorization vocabulary. Interfaces and local variables should describe Google authorization/session ownership without implying native Google Sign-In if Picker remains the path.
- Centralize Google authorization state transitions. A single module should decide whether authorization is usable, expired, missing, or requires reconnect.
- Centralize handling for Google auth failures. The app should clear or invalidate unusable authorization, preserve selected spreadsheet metadata where useful, and expose an actionable reconnect or reauthorize state.
- Align Picker authorization scopes with the scopes required by workbook validation, workbook creation, exercise creation, workout placement, formula repair, and set logging.
- Preserve selected spreadsheet state independently from authorization state. A user should be able to reconnect to the same sheet after session expiry.
- Make write failure UX local to the active write surface when possible. The add-to-workout form should show failures inline or through an immediately visible snackbar while preserving form state.
- Guard startup restore and command execution with stale-result protection or command serialization. Older async results must not overwrite newer user choices.
- Move GUI flow state toward a small explicit flow module or controller-owned read model. Avoid expanding the callback bag in the shell.
- Split Google Picker-related responsibilities into focused modules: app config parsing, callback validation, Picker authorization launch, selected-spreadsheet resolving, and spreadsheet creation.
- Hide low-level active-sheet write-plan operation and expectation classes from the public sheet-contract interface where practical. Preserve public domain planning behavior.
- Continue test cleanup from the extracted widget-test support library. Split tests by behavior area and prefer user-visible queries over private `ValueKey` strings unless a key is intentionally public test surface.

## Testing Decisions

- Fast local tests should cover read/write authorization differences without Google credentials. A token obtained with only read/file selection scope must not be treated as valid for Sheets writes.
- Fast local tests should cover authorization state restoration without Google credentials. Restored persisted Picker metadata must not imply valid write authorization.
- Local adapter/controller tests should simulate Google auth failures at the app-owned interface and assert that unusable authorization is invalidated, selected sheet metadata is preserved, and reconnect or reauthorize state is visible.
- Local widget tests should assert add-to-workout failure behavior through visible text, disabled submit state, form preservation, and retry/reconnect affordances.
- Scope tests should assert the app requests the scopes required for its own Google API calls. These tests verify the app-owned request contract, not Google behavior.
- Startup race tests should use controllable futures to prove stale restore/validation/write results do not overwrite newer selections.
- GUI flow tests should assert user-visible navigation and controller outcomes rather than private widget structure.
- Sheet-contract write-plan tests should remain focused on public domain behavior: planned writes, previews, rejections, and preservation of sheet data.
- Live Google integration remains opt-in and should only be used when real Google behavior must be validated with user/HITL readiness.

## Out of Scope

- Replacing the Google Sheet as the source of truth.
- Adding an app-owned backend or workout database.
- Broad redesign of workout programming, coaching, or progression behavior.
- Making the app a general spreadsheet editor.
- Running live Google integration by default.
- Rewriting all GUI code before fixing the auth-expired user path.
- Deleting native Google Sign-In code before confirming it is not used by any current runnable platform path.

## Further Notes

- The concrete user-visible failure was reported against a spreadsheet at `https://docs.google.com/spreadsheets/d/11rdY4Xi75FlISC9MD3fRu1_hxwlOZvHAGQyE-79L2ZI/edit?gid=437507741#gid=437507741`.
- The reported error was `DetailedApiRequestError(status: 401, message: Request had invalid authentication credentials...)`.
- The user reported that the app could read and navigate the sheet contents, and that disconnecting/reconnecting through the app did not fix the write failure. The plan must therefore test scope/write authorization behavior rather than trusting a stale-token-only diagnosis.
- Prior cleanup commit `0a50ac5` extracted shared widget-test support helpers; further test cleanup should build on that support library.
- Existing local docs and issue files may have unrelated worktree changes. Agents implementing this plan must preserve unrelated changes and stage only files belonging to each slice.
