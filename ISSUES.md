# Human-Friendly Workout Sheet Issues

This plan implements `ISSUES_PRD.md`. It does not modify or begin the separate
Picker plan.

## Progress

- [ ] Slice 1: Prototype and approve the real sheet layout
- [ ] Slice 2: Upgrade legacy workbooks to explicit exercise rows
- [ ] Slice 3: Create a styled human-readable workbook
- [ ] Slice 4: Persist and style workout sections
- [ ] Slice 5: Preserve annotations through exercise mutation
- [ ] Slice 6: Keep history blocks readable as they grow
- [ ] Slice 7: Enforce workbook and formatting isolation
- [ ] Slice 8: Clean the completed behavior test suite
- [ ] Slice 9: Validate the integrated layout in live Google Sheets

## Slice 1: Prototype and approve the real sheet layout

### Type

`HITL`

### What to build

Use isolated prototype code to create a disposable Google Sheet that renders
the proposed schema and presentation before those choices are integrated into
production. Populate it with at least two workout headings, primary and backup
exercises, short and long names, wrapped notes, an empty annotation row, and
multiple history blocks with several sets. The owner reviews the actual Sheets
UI and either approves the design or records revised constants in the PRD and
issue plan. Production formatting slices remain blocked until this review is
accepted.

### Acceptance criteria

- [ ] The prototype creates only an owner-approved disposable workbook or copy
      and cannot target an ordinary workout sheet accidentally.
- [ ] The prototype uses the proposed fixed-column order, final narrow
      `is_exercise` column, clean backup names, and no Starting point column.
- [ ] The rendered sheet includes two frozen header rows, the frozen metadata
      band, hidden or de-emphasized machine fields, vertical fixed-header
      grouping, merged history labels, and grey workout headings.
- [ ] The initial width trial uses Exercise 250 px, Sets 80 px, Rest 96 px,
      Tempo 96 px, Targets 128 px, Notes 330 px, `is_exercise` 28 px, and
      128 px history columns.
- [ ] Representative long exercise names, wrapped notes, at least two workouts,
      a backup, an empty workout, and multi-set history are visible during the
      review.
- [ ] The owner explicitly approves or revises widths, wrapping, merges,
      freezes, hidden-column treatment, colors, borders, and row heights in the
      real Google Sheets renderer.
- [ ] Approved constants and any changed behavior are recorded in
      `ISSUES_PRD.md` and the remaining acceptance criteria before production
      integration begins.
- [ ] The prototype is identified as visual evidence only and is not treated as
      proof of production parsing, migration, or write safety.

### Blocked by

None - can start immediately.

### User stories covered

- PRD user stories 1-8, 11-14, 30-31.

## Slice 2: Migrate owner workbooks to explicit exercise rows

### Type

`AFK`

### What to build

Introduce the active-sheet contract whose final fixed metadata column is
`is_exercise`. Normal parsing treats only literal `x` rows as exercises,
treats blank rows as non-exercise annotations, and rejects unknown markers.
Extend `lib/src/migration/legacy_fields.dart` to insert and populate the marker,
create durable workout declarations, and apply the layout for allowlisted
owner workbooks or approved copies. Keep every legacy rule in that one file;
keep its temporary confirmed owner UI separate from normal parsing, and delete
the file and UI before MVP.

### Acceptance criteria

- [ ] The required fixed columns end with `is_backup`, `is_exercise`, followed
      immediately by history columns.
- [ ] Only rows containing the literal `x` marker are parsed as exercises;
      non-empty visible text on an unmarked row is ignored.
- [ ] Blank markers are accepted and unknown non-empty markers are blocking
      schema damage that prevents workout writes.
- [ ] Workout heading rows carry Workout identity without being parsed as
      exercises, so a workout with no exercises remains selectable after a
      reread.
- [ ] The temporary migrator accepts only allowlisted owner workbooks or
      approved copies and produces a dry-run report before mutation.
- [ ] Upgrade inserts the marker before existing history, tags only rows
      accepted by the legacy parser, and preserves formulas, raw history text,
      unrecognized rows, and history labels.
- [ ] The upgrade uses the loaded-session reread and expectation checks; stale
      source rows or headers reject the operation without partial follow-up
      writes.
- [ ] After a successful refreshed report, the ordinary parser and UI proceed
      through the new schema without a fallback path.
- [ ] Public behavior tests cover new parsing, damage, migration success, and
      stale rejection; there is no visible upgrade flow to test.
- [ ] The migration file and its tests are explicitly marked for deletion
      after all owner sheets complete the combined field/layout migration.

### Blocked by

- Slice 1: Prototype and approve the real sheet layout.

### User stories covered

- PRD user stories 7, 9-10, 15-16, 23-27.

## Slice 3: Create a styled human-readable workbook

### Type

`AFK`

### What to build

Make the existing Create sheet path initialize the new schema and its default
presentation in one complete workflow. The generated active tab should expose
two clear frozen header rows, a frozen metadata band before history, the
reference sheet's deliberate width proportions and wrapping, de-emphasized
machine columns, and a narrow centered exercise marker. Fixed headers and
future history columns must have a coherent two-level layout without
introducing Starting point or visible backup prose.

### Acceptance criteria

- [ ] A newly created workbook validates immediately under the explicit-marker
      schema and contains a compatible Exercises tab.
- [ ] The active tab freezes both header rows and the complete fixed metadata
      band before history.
- [ ] Initial visible widths closely match the agreed reference proportions:
      Exercise 250 px, Sets 80 px, Rest 96 px, Tempo 96 px, Targets 128 px,
      Notes 330 px, `is_exercise` 28 px, and each history set 128 px.
- [ ] Exercise and Notes use appropriate wrapping/overflow behavior; machine
      fields are hidden or de-emphasized and `is_exercise` is the final narrow,
      centered metadata column.
- [ ] Fixed headers occupy a coherent two-row presentation and remain readable
      through the value parser after merges are applied.
- [ ] Header emphasis, borders, text treatment, and contrast produce a sane
      default rather than attempting to copy every detail of the reference
      workbook.
- [ ] The template does not add Starting point or prepend `Backup:` to exercise
      names.
- [ ] Workbook initialization applies presentation only to the two owned tabs
      and never deletes or formats unrelated tabs.
- [ ] Adapter tests verify the intentional pixel-width requests plus essential
      freeze, merge, hidden-state, and format boundaries without pinning
      incidental request order.
- [ ] The ordinary Create sheet UI returns the refreshed, usable workbook after
      initialization succeeds and reports a distinct failure if styling or
      initialization cannot complete.

### Blocked by

- Slice 2: Upgrade legacy workbooks to explicit exercise rows.

### User stories covered

- PRD user stories 1, 3, 5-8, 12, 28-29.

## Slice 4: Persist and style workout sections

### Type

`AFK`

### What to build

Make workout creation a durable workbook command rather than session-only
state. Creating a workout inserts a heading that stores its identity in the
Workout metadata, leaves the exercise marker blank, and receives the default
grey section treatment. Primary placement writes an `x` row inside the chosen
section; backup placement remains adjacent to its parent. The resulting sheet
and refreshed UI should retain an empty workout and group later additions under
the correct visible heading.

### Acceptance criteria

- [ ] Creating a workout writes a durable heading and returns a refreshed
      report before the command is considered successful.
- [ ] The heading shows the workout name, carries the same identity in Workout,
      has a blank exercise marker, and is ignored as an exercise.
- [ ] New headings use a restrained grey, emphasized style and a merge across a
      stable visible metadata range rather than the changing history width.
- [ ] A newly created empty workout remains selectable after a full reread or
      application restart.
- [ ] Adding a primary inserts it into the selected workout section, marks it
      `x`, and does not append it after a later workout section.
- [ ] Adding a backup marks it `x`, sets `is_backup`, keeps its canonical name
      free of visible backup prose, and preserves adjacency to its parent.
- [ ] Adding rows formats only the new heading or exercise row and does not
      broadly restyle existing workout rows.
- [ ] Existing pending-workout fallback state is removed or reduced so the
      durable sheet, not a controller-only list, owns empty workouts.
- [ ] Public controller and screen tests demonstrate create, reload, placement,
      and empty-workout behavior through the normal commands.

### Blocked by

- Slice 2: Upgrade legacy workbooks to explicit exercise rows.
- Slice 3: Create a styled human-readable workbook.

### User stories covered

- PRD user stories 2, 9-12, 15-16.

## Slice 5: Preserve annotations through exercise mutation

### Type

`AFK`

### What to build

Update deletion and reordering to use explicit row ownership. Exercise and
backup rows move or disappear without consuming unmarked empty rows, notes, or
workout headings. Prefer dimension moves where they safely carry row formatting
with the exercise; limit value updates and formatting requests to the rows that
must change. Deleting the final exercise leaves its durable workout heading and
the selected empty workout intact.

### Acceptance criteria

- [ ] Deletion targets only the selected marked primary and its marked backups,
      even when unmarked rows occur between them.
- [ ] Empty rows and visible annotation rows survive exercise deletion with
      their values intact.
- [ ] Deleting the last exercise leaves the workout heading, selection, and
      empty exercise list intact after reread.
- [ ] Reordering uses structural row movement where practical so existing row
      formatting travels with owned exercise data.
- [ ] Reordering never turns an unmarked annotation into an exercise or clears
      it as a side effect.
- [ ] Stale marker, workout, backup, formula, or row expectations reject the
      mutation before writes proceed.
- [ ] Unaffected rows receive no formatting normalization request during delete
      or reorder operations.
- [ ] Public planning, session, and UI tests cover annotations around primaries
      and backups, formatted-row moves, final-exercise deletion, and stale
      rejection.

### Blocked by

- Slice 4: Persist and style workout sections.

### User stories covered

- PRD user stories 10, 15-20, 28.

## Slice 6: Keep history blocks readable as they grow

### Type

`AFK`

### What to build

Extend the existing history creation and next-set growth commands so new
history columns receive the default width, header treatment, and grouping.
Each block label occupies the first header row and is merged over its S columns;
set labels remain in the second row. Formatting changes must stay inside the
new columns and the directly affected block-header merge, while workout heading
fill extends into newly inserted history columns.

### Acceptance criteria

- [ ] Creating a history block inserts S1 at the fixed-metadata boundary and
      applies the default history header, 128 px width, alignment, and text
      format.
- [ ] Adding S2 or later extends the selected block's header merge and preserves
      the correct set-label sequence.
- [ ] The semantic history parser still discovers unique block labels and
      consecutive set columns from the two header rows.
- [ ] New history cells remain text-formatted so literal workout notation is
      not coerced by Sheets.
- [ ] New columns receive workout-heading background treatment without
      rebuilding full-width merges or restyling existing exercise values.
- [ ] Unrelated history blocks, annotations, and retired tabs receive no format
      or merge requests.
- [ ] If the target header changed since planning, expectation checks reject
      the structural write rather than merging the wrong columns.
- [ ] Public command and adapter tests cover first-block creation, multiple
      blocks, set growth, reread, stale rejection, and request scope.

### Blocked by

- Slice 3: Create a styled human-readable workbook.
- Slice 4: Persist and style workout sections.

### User stories covered

- PRD user stories 3-4, 13-14, 17-18, 29.

## Slice 7: Enforce workbook and formatting isolation

### Type

`AFK`

### What to build

Close the preservation boundary across all completed workflows. Extra retired
tabs remain visible in Google Sheets but are absent from workout parsing and
never become write or formatting targets. Formatting remains presentation
output, not parser input. Add a small request-scope guard so ordinary value
writes cannot accidentally acquire workbook-wide unmerge, clear, or repeat
format behavior.

### Acceptance criteria

- [ ] The first tab is the active workout, Exercises is located by exact title,
      and all other tabs are ignored for parsing and mutation.
- [ ] Selecting, validating, logging, authoring, migrating, and formatting an
      active workout never deletes, renames, clears, reorders, or formats a
      retired tab.
- [ ] Fonts, colors, borders, widths, frozen panes, hidden state, and formatting
      changes cannot change which rows parse as exercises.
- [ ] Ordinary set logging and cell repair send only value/formula operations
      and no broad presentation requests.
- [ ] Structural presentation requests are limited to new or directly affected
      active-tab ranges.
- [ ] Workbook initialization is the only path allowed to apply the complete
      default format, and only for app-created owned tabs.
- [ ] Tests use multiple-tab snapshots and observable operation targets rather
      than asserting private filtering helpers.
- [ ] The domain and testing guidance documents the explicit marker, ignored
      annotations, best-effort formatting guarantee, and retired-tab rule once,
      without duplicating implementation instructions.

### Blocked by

- Slices 1-6.

### User stories covered

- PRD user stories 15-18, 21-22, 28-29.

## Slice 8: Clean the completed behavior test suite

### Type

`AFK`

### What to build

Use the `test-cleanup` skill to remove temporary TDD scaffolding and rewrite
tests that pin request order, private planners, exact widget trees, or cosmetic
constants without protecting behavior. Retain the smallest durable suite for
schema upgrade, explicit exercise ownership, preserved annotations, generated
layout contracts, workout grouping, history growth, and tab isolation.

### Acceptance criteria

- [ ] Almost all tests that existed only to drive internal implementation are
      removed or replaced by public parser, session, adapter, or screen
      behavior tests.
- [ ] Essential formatting tests assert semantic request ranges and outcomes,
      not every request object or exact operation order.
- [ ] Exact colors and dimensions are tested only where they are intentional
      public presentation constants.
- [ ] Schema damage, unsafe write prevention, raw history preservation, and
      stale expectation coverage remain intact.
- [ ] Annotation, empty-workout, history grouping, and retired-tab behavior
      retain focused regression coverage.
- [ ] The default test suite remains credential-free and passes with static
      analysis.

### Blocked by

- Slice 7: Enforce workbook and formatting isolation.

### User stories covered

- PRD user stories 28-29.

## Slice 9: Validate the integrated layout in live Google Sheets

### Type

`HITL`

### What to build

Run the final opt-in acceptance pass against Google Sheets with the owner
present. Create a new workbook, upgrade a copy of a representative legacy
WorkoutTracker workbook, add workouts and history, delete and reorder
exercises, and visually compare the result with the agreed reference style.
Confirm that annotations and retired tabs survive before declaring the plan
complete.

### Acceptance criteria

- [ ] The owner approves the generated sheet's hierarchy, widths, wrapping,
      frozen panes, history grouping, and workout headings on desktop Sheets.
- [ ] The owner compares the visible proportions with the reference and
      confirms the wide Exercise and Notes columns, compact target columns,
      28 px marker, and uniform 128 px history columns are comfortable.
- [ ] A newly created sheet remains usable through WorkoutTracker after visual
      inspection or harmless manual formatting changes.
- [ ] A copied legacy workbook upgrades without losing formulas, raw history,
      annotations, empty rows, or unrelated tabs.
- [ ] Adding a workout, primary, backup, history block, and later set produces
      coherent formatting in the real Sheets UI.
- [ ] Deleting the final exercise leaves a visible, selected empty workout;
      deleting and reordering other exercises preserves unrelated annotations
      and formatting to the agreed MVP extent.
- [ ] The marker column is positioned immediately before history and is narrow
      enough not to distract from workout data.
- [ ] Retired tabs are manually confirmed unchanged.
- [ ] Any live-test fixture writes are opt-in, restricted to an approved copy,
      and reset or retained according to the owner's instruction.
- [ ] Static analysis, the full local suite, and the required supported Apple
      build gates pass after the visual acceptance changes.

### Blocked by

- Slice 8: Clean the completed behavior test suite.

### User stories covered

- PRD user stories 1-31, with emphasis on user stories 30-31.
