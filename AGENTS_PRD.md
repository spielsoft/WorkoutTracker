## Problem Statement

WorkoutTracker has the right domain direction: a lightweight app over a
user-owned Google Sheet, with sheet-contract behavior kept separate from Google
adapters and GUI presentation. The remaining architecture problem is that
several app workflows still require callers to understand too much about
Google workspace state, selected spreadsheet persistence, scoped Google API
access, workbook validation, write retries, and shell navigation.

The recent shim cleanup removed old Picker marker interfaces and internal
legacy state migration. The deeper issue remains: Google-facing behavior and
workbook commands are still spread across small services, widget state, app
startup wiring, and tests that sometimes pin transitional seams. This makes the
code harder to navigate, harder to test through public behavior, and easier to
accidentally regress when Google login, Picker selection, sheet creation,
validation, or logging behavior changes.

## Solution

Create deeper app modules that hide the orchestration behind small, stable
interfaces. The Google workspace module should own account/session restore,
Picker authorization, selected spreadsheet restore and persistence, sheet
choice, sheet creation, scoped Google API access, and selected-sheet resolution.
The workbook command module should expose app-level workbook actions such as
validate, repair formulas, log sets, author exercises, reorder exercises, and
delete workout placements without forcing callers to juggle read adapters,
write adapters, active-sheet snapshots, or authoring-vs-validation service
splits.

The GUI should depend on these deeper modules rather than duplicating Google
workspace state transitions. Widget code should focus on rendering and local
form state. Controller code should retain user-facing workout and logging
state, but should stop carrying low-level Google and workbook execution
plumbing. Sheet-contract modules should continue to own parsing, validation,
formula healing, set notation, and write planning, while write-planning
internals should be easier to navigate and test without broadening their public
surface.

## User Stories

1. As a WorkoutTracker user, I want the app to restore my selected sheet and
   Google account state consistently, so that launch behavior is predictable.
2. As a WorkoutTracker user, I want choosing a sheet and creating a new sheet to
   follow one coherent account flow, so that I am not surprised by different
   authorization paths.
3. As a WorkoutTracker user, I want logout to disconnect the selected sheet and
   account state in one action, so that the app does not retain stale Google
   access.
4. As a WorkoutTracker user, I want pasted sheet IDs to remain available when
   Picker is unavailable, so that I can still use the app during setup or
   degraded builds.
5. As a WorkoutTracker user, I want validation, formula repair, logging,
   exercise authoring, reordering, and deletion to keep using the same selected
   spreadsheet, so that sheet actions feel like one app workflow.
6. As a WorkoutTracker user, I want failed Google, Picker, or Sheets operations
   to report clear task-focused errors, so that I know what action to take.
7. As a WorkoutTracker user, I want set logging to remain safe against stale
   sheet state, so that manual sheet edits are not overwritten silently.
8. As a WorkoutTracker user, I want exercise authoring and workout placement to
   preserve the human-readable sheet contract, so that the sheet remains useful
   outside the app.
9. As a WorkoutTracker user, I want formula repair to stay available when
   formulas are broken, so that the app can heal sheet structure without
   replacing the sheet contract.
10. As a developer, I want one Google workspace interface to own selected-sheet
    restore, choice, creation, account profile, and persistence, so that callers
    do not need runtime type checks or state-store choreography.
11. As a developer, I want scoped Google client lifetime hidden behind one
    module, so that every Google API action requests the correct scopes and
    closes clients reliably.
12. As a developer, I want Google-backed workbook validation and writes to be
    constructed in one place, so that app startup and tests do not duplicate
    adapter wiring.
13. As a developer, I want app-facing workbook commands to be unified, so that
    controllers do not split behavior between validation and authoring services.
14. As a developer, I want workbook command tests to verify behavior through
    public app actions, so that tests do not preserve old forwarding layers.
15. As a developer, I want widget tests to focus on visible workflows, so that
    UI tests do not pin internal Google workspace plumbing.
16. As a developer, I want shell navigation and Google workspace orchestration
    separated, so that widget state remains readable and localized.
17. As a developer, I want write-planning internals organized by domain, so that
    set logging, exercise authoring, reordering, placement, deletion, and formula
    healing are easier to change independently.
18. As a developer, I want the parsed active-sheet public interface to remain
    stable, so that backend callers keep using sheet-contract behavior rather
    than private helpers.
19. As a developer, I want stale transitional tests removed or rewritten, so
    that future refactors are constrained by desired behavior rather than old
    module boundaries.
20. As a maintainer, I want each architecture cleanup slice to be independently
    reviewable and committed, so that the repository can improve without a
    risky broad rewrite.

## Implementation Decisions

- Preserve the project rule that the Google Sheet is the source of truth and
  there is no app-owned workout database.
- Do not change sheet contract semantics as part of this architecture cleanup.
- Keep sheet-contract parsing, validation, formula healing, set notation,
  history block planning, set write planning, Google adapters, and GUI
  presentation conceptually separate.
- Introduce a deeper Google workspace module only if it hides real orchestration
  currently spread across startup wiring, shell state, app state storage, Picker
  selection, sheet creation, and scoped API access.
- Treat Google, Drive Picker, OAuth, and Sheets behavior as external. Local
  tests may verify this app's requested scopes, URLs, callback parsing,
  selected-sheet persistence, adapter calls, and write plans, but must not claim
  to prove third-party behavior.
- Fold auth-wrapped forwarding services into the deeper workspace/workbook
  construction path instead of preserving pass-through layers.
- Consolidate validation and exercise authoring behind one app-facing workbook
  command interface, while keeping sheet-contract planning behavior owned by
  backend modules.
- Move Google workspace restore, selected-sheet persistence, Picker selection,
  creation authorization, and sign-out cleanup out of widget state.
- Keep the parsed active-sheet facade as the stable backend public interface if
  it continues to prevent callers from reaching into private planning helpers.
- Refactor write-planning internals behind the existing public facade rather
  than changing user-visible sheet behavior.
- Change tests that lock old seams when those seams are removed. Tests should
  continue to verify observable workflows, public interfaces, and intentional
  contracts.
- Preserve the recent shim cleanup. Do not reintroduce Picker marker interfaces
  or legacy state migration.

## Testing Decisions

- Use TDD for each implementation slice.
- Start each slice with a failing behavior test through the public interface
  being deepened.
- Prefer fast local tests for workspace state, workbook commands, sheet
  planning, and controller behavior.
- Use widget tests only when visible shell behavior changes.
- Do not run live Google integration unless a slice explicitly needs it and the
  user confirms that authentication and development-sheet writes are acceptable.
- Add or preserve tests that verify selected-sheet restore, choose/create flows,
  logout cleanup, scoped access requests, client lifetime, optimistic write
  rejection, formula repair, exercise authoring, and logging behavior.
- Remove or rewrite tests that only verify forwarding through old service
  layers, old wiring factories, marker-interface discovery, or internal helper
  structure.
- Run `flutter analyze` for each completed slice.
- Run targeted `flutter test` commands for the modules touched by each slice.
- Include a final test-cleanup pass using the `test-cleanup` skill.

## Out of Scope

- Changing the spreadsheet schema or sheet contract.
- Adding an app-owned backend or local workout database.
- Replacing Google Drive Picker or native Google Sign-In with a different
  provider.
- Adding new end-user workout features beyond preserving existing validation,
  logging, authoring, reordering, deletion, and formula repair behavior.
- Running live Google integration by default.
- Broad visual redesign of the app.
- Reintroducing compatibility code for internal MFV-stage legacy formats.

## Further Notes

- Candidate 3 from the architecture review was partially addressed by removing
  separate Picker marker interfaces. The remaining work is to deepen the full
  Google workspace lifecycle rather than only its interface shape.
- The strongest remaining shim is the auth-wrapped validation forwarding layer.
  It is a strong case for removal, not a good abstraction.
- The shell currently remains the highest-risk locality issue because it mixes
  rendering, navigation, selected-sheet persistence, Google restore, Picker
  actions, create-sheet prompts, and sign-out cleanup.
- The write-planning public facade may be acceptable even though it contains
  one-line methods; the deeper work is internal organization and duplicated
  expectation mechanics, not exposing private planners to callers.
