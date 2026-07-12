# Dynamic Exercise Field Issues

This plan replaces hard-coded Reps and RPE defaults with fields derived from
each exercise's Log Format. Complete it before integrating the human-friendly
sheet layout plan, because it changes both tab schemas and their visible column
widths.

## Decisions and behavior goals

1. Sets, Rest, and Tempo remain fixed exercise and placement metadata.
2. Every valid Log Format field produces one default input in declaration order.
3. Field labels are unique and are the stable keys used to preserve values when a format changes.
4. Exercises stores dynamic defaults as one `Default Values` cell rendered by its Log Format.
5. Active workout rows store row-local dynamic defaults as one `Targets` cell rendered by their row-local Log Format.
6. Default Values are copied into Targets when an exercise is placed, after which Targets are independently editable.
7. Logging fields are generated from Log Format and initially populated from Targets when no saved set value supersedes them.
8. Empty user-specific defaults such as Weight are allowed; the corresponding field must still be present.
9. Preview text is rendered from the values currently entered by the user rather than canned samples.
10. Bundled exercises have non-empty, sensible Sets, Rest, and Tempo plus format-matching dynamic defaults.
11. Legacy migration is owner-only, expectation-checked, and isolated in one temporary Dart file that will be deleted before MVP release.
12. The pre-MVP app may expose this exact converter behind explicit confirmation; no legacy parser fallback, conversion UI, or migration code ships in the MVP.
13. Workbooks use `workouttracker.schema_version`: missing means the original legacy format, `0.9` is the current pre-MVP format, and `1.0` is reserved for MVP.
14. Raw historical set text and unparseable saved history remain preserved under the existing contract.
15. The workbook contract, layout plan, testing guidance, and relevant user documentation must describe the same field-driven model.

## Progress

- [x] Slice 1: Author exercise defaults from Log Format fields
- [x] Slice 2: Carry dynamic targets through placement and logging
- [ ] Slice 3: Curate and approve bundled exercise defaults
- [ ] Slice 4: Migrate the owner's legacy field columns
- [x] Slice 5: Reconcile contracts, plans, and documentation
- [x] Slice 6: Clean the dynamic-field test suite
- [ ] Slice 7: Validate dynamic fields in the app and a live sheet

## Slice 1: Author exercise defaults from Log Format fields

### Type

`AFK`

### What to build

Replace the canonical exercise model's fixed Reps and RPE defaults with an
ordered field-value map derived from Log Format. Make the Exercises tab store
that map as one `Default Values` string rendered by the same format. The create
and edit exercise screen retains fixed Sets, Rest, Tempo, and Log Format fields,
then generates a responsive grid of `Default <field>` inputs from every valid
format field. Saving and rereading an exercise must reproduce the same field
labels and values.

### Acceptance criteria

- [x] Valid Log Formats require one to four unique field labels; duplicate
      labels produce clear validation errors rather than ambiguous map keys.
- [x] The exercise definition exposes immutable dynamic defaults keyed by the
      parsed labels and no longer exposes privileged Reps or RPE properties.
- [x] The Exercises schema contains fixed exercise metadata, Log Format, and a
      single `Default Values` column; it has no Default Reps or Default RPE
      columns.
- [x] Default Values round-trip losslessly through the public exercise parser,
      append/update plans, Sheets adapter, and refreshed canonical exercise.
- [x] A completely blank dynamic-default map stores as a blank cell; partial
      maps, including blank Weight with populated Reps and RPE, remain
      parseable and preserve every declared key.
- [x] The new/edit screen lays out Default Sets with Default Tempo, Default Rest
      with Log Format, and a subsequent two-column responsive grid of dynamic
      defaults in format order.
- [x] Editing a valid format retains values for exact matching labels, adds
      blank controls for new labels, and defers removal of obsolete values until
      the exercise edit is saved.
- [x] Invalid in-progress format text shows format feedback, cannot be saved,
      and does not silently relabel or discard the last valid draft values.
- [x] Preview output uses the current dynamic defaults and updates when either
      the format or a default value changes.
- [x] Accessibility labels and traversal expose each generated control as
      `Default <field>` without relying on its grid position.
- [x] Public contract and widget tests cover default, timed, bodyweight, and
      four-field formats without asserting a private controller arrangement.

### Blocked by

None - can start immediately.

### User stories covered

- Behavior goals 1-5, 8-9, and 13.

## Slice 2: Carry dynamic targets through placement and logging

### Type

`AFK`

### What to build

Replace active-row Reps and RPE metadata with one row-local `Targets` value
paired with Log Format. The primary and backup placement screens generate
target inputs from the selected exercise's format, prepopulate them from its
canonical defaults, and allow row-local edits. Placement writes the rendered
Targets value. Opening an unsaved set prepopulates the existing dynamic logging
form from Targets, while an existing saved set remains authoritative when it is
viewed or edited.

### Acceptance criteria

- [x] The active fixed metadata uses Sets, Rest, Tempo, Targets, Notes, Log
      Format, Workout, and backup/row ownership metadata; static Reps and RPE
      columns are absent.
- [x] Parsed workout slots expose ordered row-local targets matching their Log
      Format rather than fixed reps/rpe fields.
- [x] A malformed nonblank Targets value is reported clearly and cannot be used
      for a structured workout write; raw historical cells remain preserved.
- [x] Primary placement copies canonical Default Values into editable target
      controls and persists the rendered result with the other row-local data.
- [x] Backup placement uses the backup exercise's own format and defaults rather
      than inheriting the primary's target keys or values.
- [x] The placement screen keeps fixed Sets, Rest, and Tempo controls separate
      from its generated target grid and exposes accessible field labels.
- [x] Opening a new empty set initializes dynamic logging inputs from the
      selected primary or backup Targets.
- [x] Opening a populated history cell uses the parsed saved entry instead of
      overwriting it with Targets.
- [x] Saving or clearing history never mutates Targets implicitly.
- [x] Default Weight may remain blank while Reps/RPE or other exercise-specific
      targets prepopulate normally.
- [x] Creation, reread, stale-expectation rejection, and logging behavior are
      tested through public planning, session, and screen interfaces.

### Blocked by

- Slice 1: Author exercise defaults from Log Format fields.

### User stories covered

- Behavior goals 1-9 and 13.

## Slice 3: Curate and approve bundled exercise defaults

### Type

`HITL`

### What to build

Convert every bundled exercise to the dynamic-default asset contract and audit
the prescriptions as a coherent starter library. Each entry receives valid
field defaults matching its Log Format and non-empty Sets, Rest, and Tempo.
Weight and other user-specific loads may be blank, but Reps, RPE, Seconds,
Pain, Height, or similar fields should have an appropriate value where a useful
generic default exists. Produce a concise review artifact so the owner can
approve exercise-specific tempo and target choices before they become the
template for newly created sheets.

### Acceptance criteria

- [x] Every bundled entry uses dynamic field defaults and contains no legacy
      defaultReps/defaultRpe asset keys.
- [x] Every entry has non-empty Default Sets, Default Rest, and Default Tempo.
- [x] Tempo choices are exercise-appropriate: lifts use meaningful movement
      notation, while isometrics or timed holds use suitable hold/control text
      rather than an arbitrary lift tempo.
- [x] Every dynamic-default key exactly matches one unique field in the entry's
      parsed Log Format, with no missing or extra keys.
- [x] User-specific load fields may be blank; generally useful prescription
      fields are populated with sensible starter values.
- [x] Timed, unilateral, bodyweight, height/pain, and conventional weighted
      examples are all represented and load successfully.
- [x] The generated Exercises tab and exercise editor show the same approved
      defaults after a template round-trip.
- [x] An automated asset validator reports the exercise name and violated rule
      for blank fixed defaults, invalid formats, duplicate labels, or key
      mismatch.
- [ ] The owner receives a compact exercise/default review and explicitly
      approves or revises questionable tempo and target prescriptions.

### Blocked by

- Slice 1: Author exercise defaults from Log Format fields.

### User stories covered

- Behavior goals 1-5 and 8-10.

## Slice 4: Migrate the owner's legacy field columns

### Type

`HITL`

### What to build

Create one explicitly temporary Dart migration module for the owner's legacy
WorkoutTracker sheets. It converts canonical Default Reps/RPE and active
Reps/RPE columns into format-keyed Default Values and Targets, preserves Weight
as blank when no prior value exists, and leaves all history text untouched.
The migrator performs a dry-run report, restricts execution to explicitly
approved spreadsheet IDs or copies, then uses reread, expectations, writes,
and refreshed validation. Keep all legacy recognition inside this file so it
can later absorb the row-marker/layout migration and be deleted wholesale
before MVP release.
The pre-MVP app recognizes only an exact unversioned legacy workbook, shows the
dry-run result, and requires confirmation before invoking it. Successful
conversion writes workbook version `0.9`; version `1.0` remains reserved for
the MVP contract.

### Acceptance criteria

- [x] All legacy schema recognition and conversion logic lives in one clearly
      temporary Dart file and is not a fallback in the production parser.
- [x] The migration entry point requires explicit opt-in and an allowlisted
      spreadsheet ID or owner-approved copy; it cannot scan or mutate arbitrary
      Drive files.
- [x] Dry-run output identifies proposed column changes, exercises/rows mapped,
      and every nonblank legacy value that cannot be represented by its format.
- [x] Legacy Reps maps to `Reps` when declared and otherwise to the explicit
      v1 duration alias `Seconds`; legacy RPE maps only to `RPE`. Other
      unmappable nonblank values block that workbook rather than being discarded.
- [x] Default-format rows resolve Weight/Reps/RPE, preserve Reps/RPE, and create
      a blank Weight target/default.
- [x] Canonical defaults, row-local targets, formulas, raw and unparseable
      history, empty rows, annotations, workout grouping, and unrelated tabs
      survive the migration.
- [x] The migrator rereads and expectation-checks before mutation and returns a
      newly validated report; stale or malformed input causes no unsafe
      follow-up write.
- [x] Migration-specific tests and fixtures remain colocated conceptually with
      the temporary module and are marked for deletion with it before MVP.
- [ ] The owner first validates a copied workbook, then explicitly approves and
      records successful migration of every remaining legacy sheet.
- [x] The main layout plan is updated to extend this same temporary migrator for
      `is_exercise` and workout headings instead of shipping a production
      upgrade screen.

### Blocked by

- Slice 2: Carry dynamic targets through placement and logging.
- Slice 3: Curate and approve bundled exercise defaults.

### User stories covered

- Behavior goals 4-8 and 11-13.

## Slice 5: Reconcile contracts, plans, and documentation

### Type

`AFK`

### What to build

Update every authoritative contract and relevant guide to describe the
field-driven model that now exists. Remove static Reps/RPE assumptions from the
workbook contract, reconcile the human-friendly layout PRD and issue plan with
Targets and the changed widths, document direct-sheet behavior and validation,
and state that owner-only migration is temporary and absent from the release.
Keep information in its routed source rather than repeating it across agent and
user documentation.

### Acceptance criteria

- [x] The workbook domain contract lists the final Exercises and active fixed
      columns, defines Default Values and Targets, requires unique Log Format
      labels, and explains blank/partial dynamic defaults.
- [x] The contract distinguishes fixed Sets/Rest/Tempo metadata from arbitrary
      format-derived fields and preserves the raw-history guarantee.
- [x] The sheet-layout PRD and implementation issues no longer allocate static
      Reps/RPE columns; their prototype and production width criteria include a
      suitable Targets column and retain `is_exercise` as the final metadata
      column before history.
- [x] The layout plan replaces its shipped upgrade UI/fallback with the single
      temporary owner migration file and includes deletion before MVP release.
- [x] Testing guidance and the test inventory identify the durable dynamic-field
      contracts, temporary migration validation, and required live checks
      without testing documentation prose.
- [x] Accessibility guidance covers generated Default/Target fields, stable
      labels, responsive ordering, and keyboard/screen-reader traversal where
      those expectations are not already stated.
- [x] Human-facing setup or sheet documentation explains how direct editors use
      Log Format with Default Values/Targets and how invalid combinations are
      reported, but does not expose temporary owner-only migration as a public
      feature.
- [x] Historical and Picker documents remain untouched unless a current factual
      reference to the changed workbook columns must be corrected.
- [x] Repository-wide searches find no current documentation or public contract
      that still describes Reps/RPE as privileged default fields.

### Blocked by

- Slice 4: Migrate the owner's legacy field columns.

### User stories covered

- Behavior goals 1-14.

## Slice 6: Clean the dynamic-field test suite

### Type

`AFK`

### What to build

Use the `test-cleanup` skill to remove TDD scaffolding and tests that pin map
implementations, controller counts, exact widget trees, or incidental request
order. Retain the smallest useful behavior suite for format-derived exercise
defaults, row-local targets, placement/logging precedence, bundled asset
quality, schema safety, and raw-history preservation. Do not delete the
temporary migration module or its essential verification tests until the
combined sheet migration has been completed and accepted for MVP removal.

### Acceptance criteria

- [x] Tests primarily exercise public format, workbook, session, adapter, and
      screen behavior rather than private dynamic-controller implementation.
- [x] Durable coverage retains unique-label validation, field-value round-trip,
      format editing, target copying, saved-history precedence, and stale-write
      rejection.
- [x] Bundled asset checks validate meaningful invariants without snapshotting
      the entire exercise library or documentation prose.
- [x] Raw and unparseable history preservation remains covered across the
      schema change.
- [x] Temporary migration tests are clearly separable for later wholesale
      deletion and do not leak legacy fallback behavior into production tests.
- [x] Static analysis and the full credential-free Flutter suite pass.

### Blocked by

- Slice 5: Reconcile contracts, plans, and documentation.

### User stories covered

- Behavior goals 1-14.

## Slice 7: Validate dynamic fields in the app and a live sheet

### Type

`HITL`

### What to build

Perform final owner-assisted acceptance of the field-driven workflow before it
becomes a dependency of the layout integration. Exercise creation/editing,
primary and backup placement, logging, and direct Google Sheet inspection must
demonstrate conventional and non-conventional formats. Confirm the revised
active columns and Targets width in the early layout prototype, and record any
remaining changes in both issue plans.

### Acceptance criteria

- [ ] The owner creates or edits an exercise with the default Weight/Reps/RPE
      format and sees all three dynamic default controls.
- [ ] The owner verifies at least one timed or custom four-field format and sees
      exactly its declared controls in order.
- [ ] Changing a format visibly preserves matching defaults, adds new blank
      fields, and does not discard removed values until save.
- [ ] Preview text reflects the entered defaults, including a blank Weight with
      populated Reps/RPE.
- [ ] Primary and backup placement show their own dynamic target defaults and a
      new logging form prepopulates from the selected row's Targets.
- [ ] A saved history entry remains authoritative when reopened and Targets do
      not change after save or clear.
- [ ] A newly created or migrated real Sheet shows the agreed Default Values and
      Targets representation without static Reps/RPE metadata columns.
- [ ] The owner approves the bundled exercise defaults and non-empty tempo
      choices in the actual app/template experience.
- [ ] The layout prototype is rerun or revised with the final metadata columns
      and approved Targets width before layout production integration begins.
- [ ] Static analysis, the full local suite, and the relevant opt-in live Google
      validation pass or are reported accurately as skipped.

### Blocked by

- Slice 6: Clean the dynamic-field test suite.

### User stories covered

- Behavior goals 1-14.
