# WorkoutTracker Domain Contract

WorkoutTracker is a logging surface over a user-owned Google Sheet. The sheet is
the source of truth; the app does not maintain a separate workout database.

## Workbook Shape

The first spreadsheet tab is the active workout sheet. It stores the current
workout rows and visible workout history. The `Exercises` tab stores canonical
exercise metadata and is read-only for the MVP.

The active sheet starts with fixed columns, followed by visible history blocks:

```text
Exercise | Sets | Reps | RPE | Rest | Tempo | Notes | Log Format | Workout | is_backup | history blocks...
```

Display cells in the active sheet are direct spreadsheet formulas into
`Exercises` wherever the sheet needs canonical exercise metadata. The app may
repair those formulas, but it must preserve the sheet as human-readable data.
For the MVP formula-healing planner, the active sheet's formula-driven columns
are `Exercise`, `Sets`, `Reps`, `RPE`, `Rest`, `Tempo`, `Notes`, and
`Log Format`. They map to `Exercises` columns `Exercise`, `Default Sets`,
`Default Reps`, `Default RPE`, `Default Rest`, `Default Tempo`, `Notes`, and
`Log Format` respectively. `Workout` and `is_backup` remain active-sheet
context and are not healed from `Exercises`; `is_backup` remains the final
metadata column before history blocks.

## Literal Log Formats

The `Exercises` tab owns a human-readable `Log Format` metadata column. The
active sheet mirrors that value by direct formula so each row can define the
structured logging fields and compact sheet notation used for its history
cells. A blank `Log Format` means the default format:

```text
{Weight}[x]{Reps}[@]{RPE}
```

The format language is literal:

- Text inside `{}` is an app field label. Field labels are exact
  user-authored text, not app-owned semantic names.
- Text inside `[]` is literal sheet text.
- Literal text inside `[]` is always rendered and is never automatically
  omitted when an adjacent field value is blank.
- The initial app supports one to four fields per format.
- Existing history cells that cannot be parsed by the row-local format remain
  raw text and stay editable.

Examples:

```text
{Weight}[x]{Reps}[@]{RPE}
{Height}[x]{Reps}[@]{RPE}[,]{Pain}
{Reps}[@]{RPE}
{Seconds}[s@]{RPE}
```

## Vocabulary

- **Active sheet**: the first tab in the selected spreadsheet. It is canonical
  for workout rows, backup placement, and row-local history.
- **Workout**: the visible grouping value in the active sheet's `Workout`
  column. A blank `Workout` cell means the default workout.
- **History block**: a visible group of set columns such as `Week 1` with set
  columns such as `S1`, `S2`, and `S3`. Labels are plain human labels, not date
  metadata.
- **Exercise row**: an app-readable active-sheet row whose first display cell is
  not blank or merged. Rows with a blank or merged first display cell are human
  section/header rows and are ignored by backend parsing.
- **Primary row**: an exercise row whose `is_backup` cell is blank or false.
  Primary rows are the workout overview rows.
- **Backup row**: an exercise row whose `is_backup` cell is true. A backup row
  belongs to the nearest preceding primary row in the same workout. A workout
  whose first app-readable row is a backup violates the contract.
- **Formula healing**: planning or applying repairs for missing or broken
  active-sheet display formulas so they point directly into `Exercises` again.
  Healing must not introduce app-only IDs or replace the human-readable sheet
  contract.

## Test Fixtures

Local backend tests should use in-memory sheet grids instead of Google access
until a slice explicitly covers Google adapters. Slice 1 fixtures live in
`test/fixtures/workout_sheet_fixtures.dart` and include:

- a valid active workout sheet with fixed columns and history blocks;
- a valid `Exercises` tab;
- primary and backup rows in named workouts;
- a default workout row with blank `Workout`;
- ignored human section/header rows, including a merged first-column row.

The named writable integration fixture for later Google-backed slices is:

```text
WorkoutTracker development sheet
https://docs.google.com/spreadsheets/d/1zQrmCYelrNqRMv4WtJcOrtezSxoaVniXzXi4XgKva_E/edit?gid=0#gid=0
```

Integration tests that write to this sheet must reset or clean up after
themselves.
