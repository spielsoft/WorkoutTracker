# Workbook Domain Contract

The selected Google Sheet is WorkoutTracker's durable data. The app must leave
it useful to a person working directly in Google Sheets.

## Workbook Version

WorkoutTracker stores a document-visible Google Sheets developer-metadata
entry named `workouttracker.schema_version`. Version `1.1`, which requires the
Exercises `Timer Fields` column, is the only version the app supports. New
workbooks receive that version token.

Every other declared version, and an absent key, is blocking schema damage
reported on the ordinary repair path. There is no in-app conversion or upgrade:
bringing a workbook to `1.1` is owner-performed work in Google Sheets. A
declared version is never inferred from headers.

The version never replaces structural validation. Headers, values, formulas,
and writable columns must still satisfy the `1.1` contract before ordinary
writes.

## Required Tabs and Headers

The first tab is the active workout sheet. Its fixed columns must appear in
this exact order before any history columns:

```text
Exercise | Sets | Rest | Tempo | Targets | Notes | Log Format | Workout | is_backup | is_exercise
```

The workbook must also contain an `Exercises` tab with exactly these columns:

```text
Exercise | Description | Default Sets | Default Rest | Default Tempo | Notes | Log Format | Default Values | Timer Fields
```

A missing or empty required tab, missing or reordered required column, or
unsupported non-empty `Exercises` column is blocking schema damage. Writable
column positions must never be guessed.

## Active Rows and Workouts

An active-sheet row currently represents an exercise when its first display
cell is non-empty and not part of a merged human-only first-column row. New
rows also carry `x` in `is_exercise`; the styled-layout plan will make that
marker authoritative. Other rows are ignored.

- Blank `Workout` means the default workout.
- Blank `is_backup` means false.
- A primary row has a false or blank `is_backup` value.
- A backup row belongs to the nearest preceding primary row in the same
  workout.
- A backup without such a primary is blocking schema damage.

The active sheet owns workout placement and row-local metadata: fixed `Sets`,
`Rest`, and `Tempo`; format-driven `Targets`; plus `Notes`, `Workout`,
`is_backup`, and `is_exercise`.

`Exercises.Default Values` and active-row `Targets` use their row's `Log
Format` to render the declared field map into one cell. Labels are exact,
case-sensitive, unique keys. A blank value is allowed, including a blank
user-specific Weight alongside populated Reps and RPE. If every declared value
is blank, the stored cell is blank. A nonblank value that cannot be parsed by
its paired format is blocking schema damage.

## Exercise Ownership and Formulas

`Exercises` owns canonical exercise definitions. The active sheet references a
canonical row with direct formulas in:

- `Exercise` -> `Exercises.Exercise`
- `Log Format` -> `Exercises.Log Format`

The app may heal missing or incorrect formulas in those two columns after
validation. It must not heal row-local targets from canonical defaults or
introduce app-only identifiers.

The `Exercise` formula is a placement's only binding to a canonical row.
Canonical names may repeat, so a name match identifies nothing and is never a
binding. A placement is bound only when its `Exercise` cell holds a direct
reference into the `Exercises` name column, such as `=Exercises!A7`, and the
referenced row names an exercise. A missing formula, a computed lookup, a
reference into another column, and a reference outside the grid all leave the
placement unbound.

An unbound placement reads no canonical configuration at all, so no field is
timed. Timing is opt-in configuration rather than a default, the repair path
already reports the missing or broken formula, and the alternative would be
guessing a row by name; a placement never borrows another row's timers.

`Exercises.Timer Fields` is canonical timer configuration owned by that row
alone. A blank cell means no field is timed. A populated cell is a visible list
of exact Log Format labels such as `['Seconds']`, written and read in Log
Format declaration order so direct Sheet edits stay stable. Malformed syntax, a
repeated label, or a label the same row's Log Format does not declare is
blocking schema damage. Timer configuration is never copied to the active
sheet, has no placement-level override, and never rewrites targets or history.
A placement reads it from the row its `Exercise` formula binds it to.

A Log Format label may hold any character except braces, so the two characters
the list itself reserves are escaped with a backslash inside the quotes:

- `\'` is an apostrophe, as in `['Athlete\'s Hold']`;
- `\\` is a backslash, as in `['Tempo \\ Hold']`.

Nothing else is escaped. Commas, brackets, spaces, and non-ASCII text stand for
themselves inside the quotes, so `['Hold, Seconds']` and `['Sekundenhalt ⏱']`
are each one label and a label keeps its own leading and trailing spaces. Only
padding outside the quotes is ignored. A backslash before any other character
is malformed rather than a guess, so a hand-typed mistake is reported instead
of quietly becoming a different label; write `\\` to mean a literal backslash.

Creating a canonical exercise appends one `Exercises` row. Adding that exercise
to a workout creates a placement row: direct formulas for identity and log
format, copied defaults for row-local targets, the selected workout, backup
state, and empty history cells.

The bundled exercise catalog seeds a new workbook once. Its optional
`timerFields` array, absent meaning empty, sets the `Timer Fields` a new
workbook starts with. It is never synchronized into an existing workbook, so
changing the catalog cannot alter a workbook a person is already using.

A primary placement is added from the workout exercise list. A backup placement
must begin from its parent primary so insertion preserves adjacency and
ownership.

## History Blocks

History begins immediately after `is_exercise` and uses two header rows:

- row 1 starts each block with a unique human label such as `Week 1`;
- row 2 names its set columns consecutively `S1`, `S2`, and so on.

Every block must contain at least `S1`. A set header without a preceding block
label, a duplicate block label, an empty block, or skipped set number is
blocking schema damage.

New blocks are inserted nearest the fixed metadata and start with `S1`.
Additional set columns extend the selected block. History labels are plain
human labels, not dates or hidden identifiers.

## Literal Log Formats

Each exercise defines how structured fields become compact cell text. Blank
`Log Format` uses:

```text
{Weight}x{Reps}@{RPE}
```

The language is literal:

- `{Field}` declares an exact user-authored field label.
- Every character outside field braces is literal text that is always emitted.
- A format contains one to five uniquely named fields.
- Empty or unmatched braces, duplicate fields, and adjacent fields without a
  literal extraction boundary are invalid.
- Field labels do not imply numeric or application-owned semantics.

Provided definitions carry stable measurement context in exact names such as
`{Weight (lbs)}` and `{Height (in)}` rather than embedding units in values.
Their defaults are numeric, including `Pain=0` where Pain is declared. The
structured set editor uses numeric keyboards for every format field while
the storage boundary still preserves unexpected history as raw text.

Examples:

```text
{Weight}x{Reps}@{RPE}
({Height (in)}, {Weight (lbs)})x{Reps}@{RPE},{Pain}
{Reps}@{RPE}
{Seconds}s@{RPE}
```

An invalid row-local format blocks structured writes for the workbook. An
existing history cell that does not parse under its row's format must remain
available as unchanged or explicitly edited raw text; it must never be silently
discarded.

## Write Safety

Before every mutation, the loaded workbook session rereads and validates the
relevant workbook state, checks the planned expectations against that reread,
applies the write, and returns a newly read report. Schema damage, stale
expectations, missing tabs, or lost authorization stop the write rather than
falling back to inferred positions or cached state.
