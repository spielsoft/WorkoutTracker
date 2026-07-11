# Remaining Review Issues

This plan closes the remaining workbook-safety, GUI architecture, and
latest-history verification gaps identified in the codebase review.

## Progress

- [ ] Slice 1: Eliminate inferred writable column positions
- [ ] Slice 2: Route setup and workout screens through narrow contracts
- [ ] Slice 3: Route logging and exercise screens through narrow contracts
- [ ] Slice 4: Reduce the application flow to a routing facade
- [ ] Slice 5: Harden latest-history behavior coverage
- [ ] Slice 6: Clean up tests after the architecture slices

## Slice 1: Eliminate inferred writable column positions

### Type

`AFK`

### What to build

Make exact workbook schema validation the prerequisite for deriving writable
column positions or producing write plans. A malformed active sheet or
`Exercises` tab must remain readable as a damage report, but it must not expose
guessed writable positions or allow any planner or workbook session to produce
an applicable write.

### Acceptance criteria

- [ ] Active-sheet and `Exercises` column indexes are constructed only after
      their headers pass exact schema validation.
- [ ] Missing, empty, reordered, duplicated, or unsupported required columns do
      not receive inferred writable positions.
- [ ] Every public planner returns an empty or explicitly rejected plan when the
      parsed workbook has schema damage.
- [ ] Workout, healing, exercise-authoring, and logging actions remain
      unavailable while schema damage is present.
- [ ] Behavior tests prove that malformed active and `Exercises` headers cannot
      produce or apply active-sheet or canonical-exercise writes.
- [ ] Valid workbooks retain all existing parsing, planning, and writing
      behavior.

### Blocked by

None - can start immediately.

### User stories covered

- Original review finding: invalid workbooks must never receive unsafe writes.
- Domain contract: the app must not infer writable column positions while
  schema damage is present.

## Slice 2: Route setup and workout screens through narrow contracts

### Type

`AFK`

### What to build

Make workout setup and workout execution independently importable screens. Each
screen should receive only the read model it renders and the commands it is
allowed to issue. The application shell should route their typed views directly
instead of sending both through a multipurpose workout-screen dispatcher.

### Acceptance criteria

- [ ] Workout setup and workout execution are separate importable screens.
- [ ] Each screen accepts a small typed read model and a screen-specific command
      interface.
- [ ] Neither screen can issue unrelated sheet, account, library, authoring, or
      logging commands through an unrestricted application command runner.
- [ ] The application shell routes setup and workout views directly to their
      owning screens.
- [ ] Existing selection, progress, reordering, backup, deletion, and navigation
      behavior remains available through the new contracts.
- [ ] Focused tests exercise each public screen contract without depending on
      private widget structure.

### Blocked by

None - can start immediately.

### User stories covered

- Original review finding: replace the large private GUI library with
  importable screens and small typed interfaces.
- MVP workout setup and workout logging navigation.

## Slice 3: Route logging and exercise screens through narrow contracts

### Type

`AFK`

### What to build

Complete direct routing for logging, exercise library, exercise creation,
exercise editing, and workout placement. Each screen should own its presentation
contract and expose only feature-specific commands, allowing removal of the
remaining multipurpose workout-screen dispatcher.

### Acceptance criteria

- [ ] Logging, exercise library, exercise creation, exercise editing, and
      workout placement are independently importable screens.
- [ ] Each screen accepts only its own typed read model and command interface.
- [ ] Screens cannot issue arbitrary application commands through a shared
      unrestricted runner.
- [ ] The application shell routes every loaded application view directly to
      its owning screen.
- [ ] The multipurpose workout-screen dispatcher is removed.
- [ ] Existing logging, authoring, editing, placement, backup, and return-route
      behavior remains covered through public screen contracts.

### Blocked by

- Slice 2: Route setup and workout screens through narrow contracts.

### User stories covered

- Original review finding: make the shell the screen router and narrow GUI
  interfaces.
- MVP logging, exercise-library, authoring, editing, and placement flows.

## Slice 4: Reduce the application flow to a routing facade

### Type

`AFK`

### What to build

Move feature-specific views, commands, and transitions into their owning
modules, leaving the application flow as a small facade for startup restoration,
top-level routing, and genuinely shared coordination. Remove duplicated state,
pass-through commands, and feature behavior that no longer belongs in the
top-level flow.

### Acceptance criteria

- [ ] Feature-specific view and command declarations live with their owning
      feature modules.
- [ ] Feature transitions that do not cross application routes are handled by
      the feature owner rather than the top-level flow.
- [ ] The top-level flow exposes only the current routed view, restoration, and
      the minimal commands required for cross-feature coordination.
- [ ] Duplicate routing, selection, return-route, and transient feature state is
      removed or assigned to one authoritative owner.
- [ ] The routing facade is substantially smaller than the current monolithic
      flow and no longer contains an application-wide feature command switch.
- [ ] Startup restoration, account mismatch handling, stale validation
      rejection, and navigation behavior remain covered through public
      interfaces.

### Blocked by

- Slice 2: Route setup and workout screens through narrow contracts.
- Slice 3: Route logging and exercise screens through narrow contracts.

### User stories covered

- Original review finding: make the application shell a router and eliminate
  split GUI state ownership.
- Architecture expectation: prefer deep modules with small public interfaces.

## Slice 5: Harden latest-history behavior coverage

### Type

`AFK`

### What to build

Lock the latest-history display to the intended user-visible rule: show the
newest non-empty set from the newest prior history block, while ignoring empty
set gaps and excluding the currently selected block.

### Acceptance criteria

- [ ] A history block with an empty middle or trailing set still displays its
      newest non-empty set.
- [ ] When multiple prior history blocks contain data, the newest prior block
      wins.
- [ ] The currently selected block is not presented as prior history.
- [ ] A row with no prior history omits the latest-history value cleanly.
- [ ] Tests exercise the public logging-screen behavior and do not pin the
      private helper implementation.

### Blocked by

None - can start immediately.

### User stories covered

- Original review finding: latest history must display the latest set rather
  than the oldest set.
- MVP logging flow: show useful recent row-local history while logging.

## Slice 6: Clean up tests after the architecture slices

### Type

`AFK`

### What to build

Use the `test-cleanup` skill to remove temporary TDD scaffolding and rewrite
tests that pin routing internals, private widget structure, helper names, or
transient command choreography. Preserve the smallest durable safety net around
workbook write safety, public screen contracts, routing behavior, and
latest-history behavior.

### Acceptance criteria

- [ ] The `test-cleanup` skill is used for this slice.
- [ ] Tests that exist only to pin private implementation details are removed or
      rewritten through public interfaces.
- [ ] Workbook safety tests prove damaged schemas cannot produce applied writes.
- [ ] GUI tests are organized around importable public screen contracts.
- [ ] Latest-history coverage retains the gap and multiple-prior-block cases.
- [ ] `flutter analyze` and the full local `flutter test` suite pass.
- [ ] Clean macOS and iOS release compilation and relevant bundle validation
      pass before the plan is marked complete.

### Blocked by

- Slice 1: Eliminate inferred writable column positions.
- Slice 2: Route setup and workout screens through narrow contracts.
- Slice 3: Route logging and exercise screens through narrow contracts.
- Slice 4: Reduce the application flow to a routing facade.
- Slice 5: Harden latest-history behavior coverage.

### User stories covered

- Original review finding: keep the checked-in suite green and behavior-focused.
- Repository testing expectation: tests should describe observable behavior,
  public interfaces, and intentional seams rather than implementation details.
