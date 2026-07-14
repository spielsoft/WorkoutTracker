# Workbook Domain Contract

The selected Google Sheet is WorkoutTracker's durable data. The app must leave
it useful to a person working directly in Google Sheets.

## Workbook Version

WorkoutTracker stores a document-visible Google Sheets developer-metadata
entry named `workouttracker.schema_version`. The current workbook version is
`1.0`. Declared `0.9` workbooks retain their previous syntax until deliberately
converted. An absent key identifies the original legacy workbook format.

The version selects a migration path but never replaces structural validation.
Headers, values, formulas, and writable columns must still satisfy the declared
version's contract before ordinary writes. New workbooks and successful legacy
conversions receive the current version token.

## Required Tabs and Headers

The first tab is the active workout sheet. Its fixed columns must appear in
this exact order before any history columns:

```text
Exercise | Sets | Rest | Tempo | Targets | Notes | Log Format | Workout | is_backup | is_exercise
```

The workbook must also contain an `Exercises` tab with exactly these columns:

```text
Exercise | Description | Default Sets | Default Rest | Default Tempo | Notes | Log Format | Default Values
```

A missing or empty required tab, missing or reordered required column, or
unsupported non-empty `Exercises` column is blocking schema damage. Writable
column positions must never be guessed.

## Active Rows and Workouts

An active-sheet row currently represents an exercise when its first display
cell is non-empty and not part of a merged human-only first-column row. New and
migrated rows also carry `x` in `is_exercise`; the styled-layout plan will make
that marker authoritative after the owner migration is complete. Other rows
are ignored.

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

Creating a canonical exercise appends one `Exercises` row. Adding that exercise
to a workout creates a placement row: direct formulas for identity and log
format, copied defaults for row-local targets, the selected workout, backup
state, and empty history cells.

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

Examples:

```text
{Weight}x{Reps}@{RPE}
{Height}x{Reps}@{RPE},{Pain}
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
