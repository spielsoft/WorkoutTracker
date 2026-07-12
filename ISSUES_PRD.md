# Human-Friendly Workout Sheets PRD

## Problem Statement

WorkoutTracker treats a user-owned Google Sheet as durable workout data, but
the active tab it creates and maintains is optimized for machine safety rather
than comfortable human use. Generated sheets lack the frozen panes, sensible
column widths, grouped history headers, and visible workout sections that make
a training program easy to scan or edit directly in Google Sheets.

The current parser also decides that a row is an exercise primarily because its
Exercise cell is non-empty. That makes ordinary human annotations risky: a
label typed in the first column may be interpreted as workout data unless the
row happens to use a recognized merge. Empty rows are ignored today, but row
identity should be explicit rather than inferred from content or formatting.

Formatting and semantic data have different ownership. WorkoutTracker should
make a sane attempt to format structures it creates or extends, while user
values and unrelated annotation rows remain safe. Manual changes to formatting
on the active tab are allowed but unsupported: they may be replaced when an
operation must restructure the affected rows or columns. Unaffected formatting
should remain untouched where the Sheets API permits it. Extra retired tabs
must be allowed, preserved, and ignored for now.

## Solution

Introduce a new active-sheet schema whose final fixed metadata column is a
narrow `is_exercise` marker immediately before history. A literal `x` means the
row is an exercise; a blank marker means the row is not exercise data,
regardless of visible text. Unknown non-empty marker values are blocking schema
damage rather than input to guess about.

Workout headings are durable annotation rows. They have a blank
`is_exercise`, show the workout name in the visible Exercise area, and carry
the workout identity in the existing Workout metadata column. This lets an
empty workout survive deletion of its final exercise and a later reload.
Ordinary annotation or spacing rows leave both machine-owned fields blank and
are ignored and preserved.

Generate an approachable active tab with two frozen header rows, fixed
metadata frozen before horizontally scrolling history, deliberate widths and
text wrapping modeled on the reference sheet, de-emphasized machine columns, a
very narrow centered exercise-marker column, vertically grouped fixed headers,
horizontally merged history labels, and grey workout heading rows. Omit the
example workbook's obsolete Starting point column and visible `Backup:`
prefixes; backup identity remains in `is_backup`.

Formatting is best-effort and local. New workbooks receive the full default
style. Adding a workout, exercise, history block, or set formats only the new
structure and any merge directly affected by that insertion. Deletion and
reordering use structural operations where practical so formatting moves with
owned rows, and they do not broadly reformat surviving content. WorkoutTracker
does not interpret colors, fonts, borders, or widths as schema.

Existing WorkoutTracker workbooks receive an explicit, expectation-checked
upgrade. The upgrade inserts `is_exercise` at the fixed-metadata boundary,
marks only rows accepted by the legacy parser, leaves unrecognized and empty
rows unmarked, creates durable workout headings, and applies the default active
tab layout without changing workout history values or unrelated tabs. A failed
or stale upgrade performs no unsafe follow-up writes.

## User Stories

1. As a user creating a workout sheet, I want it to look organized immediately, so that I can use it directly in Google Sheets without manual cleanup.
2. As a gym user, I want workout names shown as grey section headings, so that I can scan a long program quickly.
3. As a sheet user, I want the metadata and header rows frozen, so that exercise identity remains visible while I scroll through history.
4. As a sheet user, I want history labels merged over their set columns, so that S1, S2, and later sets are visibly grouped under the correct block.
5. As a sheet user, I want useful widths and wrapped notes, so that important content is readable without constant resizing.
6. As a sheet user, I want machine-only columns visually de-emphasized, so that workout content remains the focus.
7. As a user, I want the exercise marker at the final metadata boundary, so that it does not interrupt the human-readable workout fields.
8. As a user, I want the exercise marker column narrow and centered, so that its `x` values consume almost no screen space.
9. As a user adding a workout, I want its heading persisted immediately, so that an empty workout survives reloads.
10. As a user deleting the last exercise, I want the empty workout to remain selected and represented in the sheet, so that the app does not silently switch workouts.
11. As a user adding an exercise, I want it inserted into the selected workout section, so that the physical sheet remains grouped.
12. As a user adding a backup, I want its clean exercise name retained, so that the sheet does not duplicate backup state in visible prose.
13. As a user adding a history block, I want its header and first set column formatted consistently with existing history.
14. As a user adding another set, I want the new column included in the visible history group, so that the block remains understandable.
15. As a user inserting an empty row, I want WorkoutTracker to ignore and preserve it, so that spacing is safe.
16. As a user adding a note or section annotation, I want it ignored when it is not marked as an exercise, so that visible text is not mistaken for workout data.
17. As a user changing cell formatting, I want unrelated operations to leave it alone where possible, so that small personal adjustments are not needlessly destroyed.
18. As a user, I accept that formatting in a structurally affected range may be normalized, so that the app can keep generated structure coherent.
19. As a user reordering exercises, I want formatting to travel with owned rows where practical, so that row presentation does not become detached from its exercise.
20. As a user deleting an exercise, I want only that exercise and its backups removed, so that intervening annotations and other formatting remain.
21. As a user with retired tabs, I want them preserved and ignored, so that old programs remain available for reference.
22. As a user, I want the first tab to remain the active workout for this release, so that extra tabs do not create ambiguous selection rules.
23. As an existing user, I want a safe upgrade from the legacy WorkoutTracker schema, so that I do not need to rebuild my workout history.
24. As an existing user, I want the upgrade to mark only rows already accepted as exercises, so that annotations do not become data during migration.
25. As an existing user, I want stale or malformed workbooks blocked before migration writes, so that an upgrade cannot corrupt the source of truth.
26. As a direct sheet editor, I want copied exercise rows to retain their marker, so that ordinary copy-and-edit workflows continue to work.
27. As a direct sheet editor, I want an unknown exercise marker rejected clearly, so that typographical mistakes are not interpreted unpredictably.
28. As a maintainer, I want formatting concerns outside the semantic parser, so that style changes cannot alter workout meaning.
29. As a maintainer, I want adapter tests to prove the app's requested values, dimensions, merges, and formats without pretending to prove Google behavior.
30. As the project owner, I want a live visual acceptance pass on representative sheets, so that the generated layout is confirmed in Google Sheets before release.
31. As the project owner, I want to approve a disposable prototype sheet before production integration, so that widths and visual hierarchy are grounded in the real Google Sheets renderer.

## Implementation Decisions

- The active tab's fixed columns, in order, are Exercise, Sets, Reps, RPE,
  Rest, Tempo, Notes, Log Format, Workout, is_backup, and is_exercise. History
  begins immediately after is_exercise.
- `is_exercise` accepts only blank or the literal `x`. The parser reads an
  exercise only when this marker is `x`; a non-empty Exercise cell alone has no
  semantic meaning.
- A workout heading has a blank exercise marker and a non-empty Workout value.
  Its visible label occupies the human-readable Exercise area. Other unmarked
  rows with no Workout identity are annotations and are ignored.
- Exercise rows retain Workout and is_backup as the authoritative grouping
  metadata. Visible text never carries a `Backup:` prefix.
- The first tab remains the active workout tab and the Exercises tab retains
  its current canonical role. Every other tab is ignored and never mutated by
  active-workout commands.
- The generated active tab uses two header rows. Fixed metadata headers may be
  vertically merged; each history label is horizontally merged over its set
  columns and set labels remain in the second row.
- Freeze the two header rows and the fixed metadata band. Machine-oriented
  columns may be hidden or visually de-emphasized; is_exercise remains the
  final, narrow metadata column before history.
- Treat column proportions as intentional presentation behavior. Initial pixel
  widths should closely follow the reference: Exercise 250, Sets 80, Reps 96,
  RPE 96, Rest 96, Tempo 96, Notes 330, is_exercise 28, and every history set
  column 128. Hidden machine columns may retain practical internal widths
  because they do not participate in the visible layout.
- Exercise is wide enough for ordinary names but may truncate exceptionally
  long names; Notes is the dominant wrapped-text column; target fields stay
  compact; history columns remain uniform as blocks grow. Do not add the
  reference workbook's wide Starting point column.
- Grey workout headings are merged only across a stable visible metadata
  range. New history columns receive matching heading-row fill without
  requiring full-width workout-row merges to be rebuilt.
- Default styling includes the specified widths, wrapping for descriptive text,
  clear header emphasis, restrained borders, and accessible contrast. Exact
  width constants are an intentional presentation contract; incidental request
  order remains an implementation detail.
- Formatting is app-owned but applied narrowly after initialization. Manual
  formatting is unsupported and may be replaced inside a structurally affected
  range; the app must not normalize the entire workbook after ordinary writes.
- Colors, fonts, borders, widths, frozen panes, hidden state, and merges are not
  inputs to workout parsing. The presentation layer consumes explicit semantic
  structure and emits Sheets formatting requests.
- Creating a workout becomes a durable workbook mutation that writes and
  formats its heading. Deleting the final exercise does not delete that heading.
- Primary exercise placement targets the selected workout section. Backup
  placement remains adjacent to its parent primary.
- Prefer row or dimension moves when reordering so row formatting moves with
  the owned data. User annotation rows are not silently converted, cleared, or
  included in deletion plans.
- History insertion applies default format only to new columns and directly
  affected header merges. Unrelated history blocks are not reformatted.
- Legacy upgrade is explicit and uses the same reread, expectation, write, and
  refreshed-report safety model as other workbook mutations.
- Legacy recognition exists only inside the versioned upgrade path. Normal
  post-upgrade parsing does not fall back to Exercise-cell inference.
- Existing values, formulas, raw history text, empty rows, annotations, and
  extra tabs survive migration unless a user explicitly chooses an operation
  that removes them.
- Before production formatting integration, use isolated prototype code to
  create a disposable representative Google Sheet containing the proposed
  schema, multiple workouts, primary and backup rows, notes, and multiple
  history blocks. Owner approval of that real sheet locks the presentation
  constants and may update this PRD before implementation continues.
- Prototype success proves visual design only. It does not bypass production
  session safety, adapter, migration, or behavioral acceptance requirements.

## Testing Decisions

- Test the new schema through public parsing, validation, planning, workbook
  session, and screen contracts. Do not test private classification helpers.
- Keep fixtures with empty rows, visible annotations in the Exercise column,
  workout headings, primary exercises, backups, and unparseable raw history.
- Prove that only `x` rows become exercises, headings create durable workouts,
  blanks are ignored, and unknown marker values block writes.
- Test legacy upgrade from representative valid workbooks and assert the
  refreshed workbook retains formulas, raw history, ignored rows, and tab
  identity.
- Adapter tests may assert essential request ranges and formatting operations,
  including freezes, the intentional pixel widths, hidden/de-emphasized
  columns, merges, and grey heading treatment. Avoid brittle assertions about
  every generated request or documentation prose.
- Test additions and removals through observable workbook results. Ensure
  unaffected annotations and rows survive rather than asserting internal call
  order.
- Test that ordinary value writes do not include broad formatting updates and
  that structural formatting requests target only newly created or directly
  affected ranges.
- Fakes prove WorkoutTracker's request contract only. A final opt-in live check
  must inspect a new workbook, a migrated workbook, history growth, exercise
  deletion, and retained extra tabs in Google Sheets.
- Run an early HITL prototype review before production integration. It must
  exercise the actual Sheets renderer and explicitly approve or revise widths,
  wrapping, freezes, hidden columns, merges, and workout-heading treatment.
- Use the test-cleanup skill after implementation to remove TDD scaffolding and
  retain the smallest durable behavior suite.

## Out of Scope

- Importing the referenced example workbook as a supported schema.
- Retaining its Starting point column or visible `Backup:` name prefixes.
- Treating arbitrary colors, fonts, borders, widths, or merges as semantic data.
- Guaranteeing that every manual formatting change survives a structural edit.
- A user-facing formatting editor or theme chooser.
- Using retired tabs as the top-level workout organization model.
- Selecting an active workout tab other than the first tab.
- Adding new workout, history-block, or set deletion features solely for this
  layout project.
- Google Picker replacement or any work in the preserved Picker plans.
- Android release readiness or new app-store packaging work.

## Further Notes

The referenced workbook is a visual model, not a migration source. The target
is a similarly readable sheet that retains WorkoutTracker's safe formula,
metadata, and history contracts.

The prototype review is deliberately early and separate from final live
acceptance. The first locks visual reality before production integration; the
last proves that application workflows preserve it.

Manual formatting is not prohibited in Google Sheets. It is simply outside the
compatibility guarantee. The implementation should preserve it whenever that
falls naturally out of targeted value writes and structural row moves, while
favoring deterministic, understandable behavior over complex formatting
provenance logic.
