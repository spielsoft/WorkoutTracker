---
name: concise-code-names
description: Use this whenever generating code, refactoring code, reviewing agent-written code, or naming variables, functions, classes, files, tests, fixtures, services, factories, initializers, and helpers, especially when names repeat obvious project, package, or module context.
metadata:
  uuid: "c7173f7f-e92a-49fc-a2a1-e033cc67df88"
---

# Concise Code Names

Use names that are readable in their local context without restating the whole
project, package, directory, or enclosing type.

Long names cost attention and tokens every time future agents read, discuss,
or edit the code. Prefer the shortest name that remains clear at the call site
or in the containing directory.

## Repo-Specific Shorthands

For this repository, read `AGENTS/CONCISE-CODE-NAMES.md` before introducing or
preserving repeated abbreviations. Treat that file as the repo-local shorthand
table.

- The table is case-insensitive.
- Repo-local shorthand guidance overrides the generic examples in this skill
  when they conflict.
- Prefer dropping redundant context entirely before applying a shorthand from
  the table.
- When a broad rename pass establishes a new stable shorthand in this repo,
  update `AGENTS/CONCISE-CODE-NAMES.md` so later agents reuse it instead of
  inventing a near-miss.

## Rules

- Drop project and product prefixes when the repository already supplies that
  context.
- Drop package, module, and enclosing-type words when nearby code already makes
  them obvious.
- Apply the same rule to filenames and paths. A file only needs to be
  unambiguous within its directory and import context, not across the whole
  repository.
- Prefer established short names when they are idiomatic for the scope. A
  familiar one-letter name is often clearer than a padded descriptive name.
- Prefer conventional short forms for common code words: `cfg`, `ctx`, `db`,
  `dir`, `doc`, `err`, `fn`, `id`, `idx`, `init`, `opts`, `repo`, `req`, `res`,
  `svc`, `tmp`, `tx`, `url`, `wb`.
- Keep domain words when they distinguish real concepts in the same scope.
- Use longer names when two nearby concepts would otherwise be confused.
- For tests, fixtures, helpers, and adapters, do not repeat words already
  carried by the parent directory. Keep required framework suffixes such as
  `_test.dart`, but shorten everything before that suffix.
- When renaming files, update imports, exports, generated references, and any
  replacement logs or plans that point at the old path.
- Rename excessive identifiers opportunistically when touching the code, but do
  not start a broad rename pass unless the user asks for one.

## Naming Check

Before introducing or preserving a long identifier or filename, ask:

1. Which words are only repeating project, package, file, or class context?
2. Would a shorter name be clear to someone reading this function, call site,
   or directory listing?
3. Is this name optimized for global uniqueness instead of local comprehension?
4. For a filename, is the parent directory already carrying most of the needed
   context?
5. Does `AGENTS/CONCISE-CODE-NAMES.md` already define a repo-local shorthand
   for one of these words?

If the answer is yes, shorten it.

## Established Short Names

Trust established programming, math, and project-local shorthand. Before
inventing a descriptive phrase, ask what name an experienced maintainer would
expect in this small scope.

Use short conventional names for roles such as axes, coordinates, scalars,
vectors, loop indices, nested indices, lengths, bounds, key/value pairs, rows,
columns, deltas, tolerances, files, callbacks, contexts, options, errors, and
temporary values. The agent already knows these idioms; the point is to choose
them instead of spelling out the role in full.

Do not expand an idiom into names like `currentIntegerLoopIndex`,
`dictionaryKeyValuePairKey`, or `realValuedXAxisCoordinate` unless that extra
language disambiguates a real conflict.

## Examples

- `WorkoutTrackerWorkbookInitializerFactory` -> `WbInitFactory` or
  `WbInitFact`, if that abbreviation is local and readable.
- `realValuedXAxisCoordinate` -> `x`, in math or plotting code.
- `currentIntegerLoopIndex` -> `i`, or `j`/`k` for nested loops.
- `dictionaryEntryKey` and `dictionaryEntryValue` -> `k` and `v`, in a tight
  map iteration.
- `UserAuthenticationTokenValidationResult` -> `TokVal` or
  `TokChk`, if user authentication is already the module context.
- `SpreadsheetExportConfigurationOptions` -> `ExportOpts`, if the file already
  handles spreadsheet export.
- `test/google_sheets/google_sheets_write_adapter_test.dart` ->
  `test/sheets/write_adapter_test.dart`, because the directory already supplies
  the Sheets and test context.
- `lib/src/app/workout_tracker_controller.dart` ->
  `lib/src/app/controller.dart`, because the module path already supplies the
  app context.
- In this repo, if `Workbook`, `Factory`, and `Template` must stay, prefer the
  repo-local forms from `AGENTS/CONCISE-CODE-NAMES.md` rather than inventing a
  new variant.
