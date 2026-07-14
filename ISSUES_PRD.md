## Problem Statement

WorkoutTracker cannot represent every measurement needed for dumbbell step-ups.
The exercise needs five independently extractable values: height, weight, reps,
RPE, and pain. The current implementation accepts at most four fields and uses
an incorrect bracket-token notation for literal text. That implementation does
not match the intended Python-style format contract, where names inside braces
are variables and every character outside braces is literal text.

The current DB Step-Up definition therefore omits weight. Several provided
exercise defaults also place units, ranges, or qualifiers inside values, which
makes gym entry and later extraction less consistent. A gym user should enter
numbers with a numeric keyboard, while field names carry measurement context
such as `Height (in)` and `Weight (lbs)`. For DB Step-Up, the canonical format
must be `({Height (in)}, {Weight (lbs)})x{Reps}@{RPE},{Pain}`, with a rendered
entry such as `(12, 15)x8@8,0`.

This is not only a parser change. Existing workbooks contain the incorrect
bracket notation, active rows receive canonical formats through formulas, and
row-local Targets must continue matching those formats. Updating only an
exercise definition can make placed rows fail workbook validation. Existing
history must never be silently rewritten or discarded.

## Solution

Adopt one public Python-style log-format language. Exact field names appear
inside `{}` and all other text is literal. Formats support one through five
unique fields, including unit-bearing names. Structured gym entry remains
numeric and preserves the existing numeric keyboard. Rendering produces compact
numeric cells, while parsing returns values keyed by their exact field names so
units and measurement context remain available to extraction without being
embedded in the values.

Move new workbooks to schema version `1.0`. Provide a deliberate converter for
declared `0.9` workbooks that rewrites the repository's incorrect bracket-token
formats into equivalent Python-style formats without changing their rendered
Targets or history. The ordinary `1.0` parser must expose only the intended
Python-style contract; recognition of the old notation belongs inside the
versioned converter rather than the public format language.

Update provided exercise definitions so all declared default values are
present, pain is `0` wherever available, measurement units live in exact field
names, and entered defaults are numeric. DB Step-Up receives the agreed
five-field format and novice male strength/hypertrophy defaults: height `12`,
weight `15`, reps `8`, RPE `8`, and pain `0`.

Make exercise format changes safe for exercises already placed in workouts.
When fields change, the app must present the affected row-local Targets for
review, preserve exact matching fields, seed new fields from canonical defaults,
and let the user correct every affected placement. The canonical exercise and
all affected Targets are then written in one stale-checked Google Sheets batch.
Historical set cells remain unchanged. Entries that cannot parse under a new
format remain visible and editable as raw text.

## User Stories

1. As a lifter, I want DB Step-Up to capture height, dumbbell weight, reps, RPE, and pain, so that a logged set contains every measurement I use in the gym.
2. As a lifter, I want DB Step-Up rendered as compact numeric notation, so that the Sheet remains easy to scan.
3. As a lifter, I want the DB Step-Up entry `(12, 15)x8@8,0` to be recoverable as five separate values, so that I can analyze it later.
4. As a lifter, I want units carried by field names such as `Height (in)` and `Weight (lbs)`, so that extracted numbers retain their meaning.
5. As a lifter, I want numeric keyboards for structured set entry, so that entering results during a workout stays fast.
6. As a lifter, I want field order to follow the authored format exactly, so that the app matches the Sheet notation I designed.
7. As a lifter, I want target/default context visible beside numeric entry fields, so that I know the planned values without typing unit text.
8. As a lifter, I want pain to default to `0` whenever it is part of an exercise, so that absence of pain is explicit.
9. As a lifter, I want every provided exercise field to have a default, so that a newly created workbook is immediately usable.
10. As a novice male lifter, I want conservative provided defaults aimed at strength and hypertrophy, so that initial targets are plausible starting points.
11. As a Sheet owner, I want formats to use familiar Python-style placeholders, so that I can understand and edit them directly.
12. As a Sheet owner, I want all characters outside `{Field}` placeholders treated as literal text, so that formats do not require a second bracket-token language.
13. As a Sheet owner, I want malformed or unmatched braces rejected clearly, so that invalid formats cannot enable unsafe writes.
14. As a Sheet owner, I want duplicate field names rejected, so that extracted values are never assigned ambiguously.
15. As a Sheet owner, I want adjacent fields without an extraction boundary rejected, so that parsing a stored cell has one stable interpretation.
16. As a Sheet owner, I want formats limited to five fields, so that logging remains usable and parsing work remains bounded.
17. As a user with a `0.9` workbook, I want a preview of the notation conversion before any write, so that I can understand how my Sheet will change.
18. As a user with a `0.9` workbook, I want equivalent format conversion to preserve rendered Targets and history, so that adopting the corrected syntax does not alter workout data.
19. As a user with an original unversioned workbook, I want the existing legacy conversion path to remain explicit, so that schema versions are never guessed from headers.
20. As a user opening a `1.0` workbook, I want strict Python-style validation, so that the obsolete notation cannot silently return.
21. As a user editing a placed exercise's format, I want to review every affected placement Target, so that row-specific programming is not overwritten invisibly.
22. As a user editing a placed exercise's format, I want unchanged field values preserved automatically, so that I only resolve genuinely new or renamed fields.
23. As a user editing a placed exercise's format, I want new fields seeded from canonical defaults, so that adding Weight to DB Step-Up is efficient.
24. As a user editing a placed exercise's format, I want the update to be atomic across Exercises and active Targets, so that the workbook is never left temporarily invalid.
25. As a user editing a placed exercise's format, I want stale workbook changes detected before applying, so that concurrent Sheet edits are not overwritten.
26. As a user with older DB Step-Up history, I want those cells preserved unchanged if they lack Weight, so that the app never invents historical data.
27. As a user with unparseable history, I want raw editing and clearing to remain available, so that format evolution never traps my data.
28. As a keyboard or screen-reader user, I want exact unit-bearing field names in stable traversal order, so that five-field entry remains understandable.
29. As a mobile user with large text, I want five fields and the save action to remain reachable without overlap, so that logging works at the gym.
30. As a maintainer, I want parser, conversion, write planning, adapters, orchestration, and UI to remain separate concerns, so that future format changes stay testable.
31. As a maintainer, I want new-workbook defaults and existing-workbook conversion tested independently, so that fixture success is not mistaken for migration safety.
32. As a maintainer, I want live Google validation to remain opt-in, so that planning and local tests never modify a real workbook implicitly.

## Implementation Decisions

- The public `1.0` format grammar is Python-style: `{Field name}` declares an exact field and every character outside braces is literal text.
- Field names are exact, case-sensitive, and may include units or context in parentheses.
- A valid format contains one through five unique fields.
- Empty fields, unmatched braces, duplicate names, and adjacent fields without a literal boundary are invalid.
- The exact DB Step-Up format is `({Height (in)}, {Weight (lbs)})x{Reps}@{RPE},{Pain}`.
- DB Step-Up defaults are numeric strings: `12`, `15`, `8`, `8`, and `0` in field order.
- Rendering the DB Step-Up defaults produces `(12, 15)x8@8,0`.
- Structured logging continues to use numeric keyboards. The storage boundary remains lossless so existing unexpected text can still be preserved as raw data rather than discarded.
- Unit and measurement context belongs in field names for provided definitions, not inside their numeric default values.
- Provided definitions retain non-field coaching and range guidance in descriptions or notes where useful; it is not embedded into numeric logged values.
- Blank structured values remain representable under the workbook contract, but every provided exercise default is populated.
- `Pain` is exactly `0` in every provided format that declares it.
- New workbooks use schema version `1.0` and contain only Python-style formats.
- Declared `0.9` workbooks use a dedicated versioned converter. The ordinary parser does not advertise or normalize the incorrect bracket notation as a supported public syntax.
- The `0.9` converter removes notation-only brackets while proving that rendered Default Values, Targets, and already parseable history remain semantically equivalent.
- Missing schema metadata continues to select only the existing original-workbook conversion path; versions are never inferred from headers.
- Exercise format edits that affect placed rows use one workflow-owning plan covering the canonical row and all affected active Targets.
- The format-edit workflow rereads and validates the workbook, checks expectations, collects placement-specific target values, and applies one Google Sheets batch.
- Exact matching fields retain their placement values. New or renamed fields are presented for explicit review and begin with canonical defaults.
- The UI reports how many placements and existing history cells are affected before a format-changing update is confirmed.
- Historical set cells are never automatically rewritten to invent a value for a newly introduced field.
- History that no longer parses remains raw, visible, editable, and clearable.
- The dynamic authoring, placement, new-set, and logged-set interfaces remain driven by ordered format fields rather than exercise-specific widgets.
- The fixed four-sample preview assumption is removed so previews work for all supported field counts.

## Testing Decisions

- Tests assert behavior through the public format, workbook, command, adapter, and visible UI interfaces rather than private parsing helpers or widget structure.
- Core notation coverage proves parsing and rendering of the exact DB Step-Up format, one- and five-field boundaries, exact unit-bearing names, literal text, decimals, blanks, and malformed formats.
- Extraction coverage proves `(12, 15)x8@8,0` returns five ordered values keyed by the exact declared names.
- New-workbook coverage proves every provided definition uses the `1.0` grammar, declares matching nonblank defaults, uses numeric provided values, and assigns pain `0` where present.
- Catalog coverage specifically proves DB Step-Up has five fields and renders the agreed default entry.
- Workbook parsing coverage proves Python-style Default Values and Targets round-trip and invalid formats block writes.
- Conversion coverage starts with declared `0.9` workbooks and proves dry-run reporting, exact expectations, equivalent rendered values, version stamping, idempotence, and rejection of stale or damaged input.
- Format-edit planning coverage proves canonical and placement Target updates are composed atomically, preserve exact matching values, seed new fields, and reject stale rows.
- Adapter coverage proves one Sheets batch contains writes to both the Exercises tab and active sheet when required.
- Logging-flow coverage proves five numeric fields appear in declaration order, use numeric keyboard configuration, render the exact compact cell, and restore numeric values from history.
- Accessibility coverage proves stable names such as `New set Height (in)` and `S1 Weight (lbs)`, correct traversal order, reachable controls at narrow widths, and large-text usability.
- Raw-history coverage proves old DB Step-Up cells remain byte-for-byte unchanged and editable after its format gains Weight.
- Existing stale-write and schema-safety tests remain authoritative and are extended rather than duplicated through private implementation tests.
- Live Google validation is HITL and opt-in. It runs only against the named development fixture or a disposable copy and must reset after itself.
- After TDD slices, the test-cleanup skill removes scaffolding tests that pin implementation details while retaining the smallest durable public safety net.

## Out of Scope

- Rewriting historical DB Step-Up cells to invent unknown Weight values.
- Automatic unit conversion between pounds and kilograms or inches and centimeters.
- Inferring field meaning from names at runtime.
- Adding an exercise-specific DB Step-Up logging screen.
- Moving workout data out of the user-owned Google Sheet.
- Automatically mutating a live Google workbook without explicit opt-in confirmation.
- Android support or release preparation.
- General workout-program generation or coaching beyond the provided defaults and notes.
- Supporting unlimited field counts or ambiguous adjacent placeholders.
- Treating the obsolete bracket-token notation as part of the public `1.0` language.

## Further Notes

- The repository currently documents and implements the bracket-token notation,
  so this work is a contract correction plus migration, not a cosmetic syntax
  change.
- Changing an Exercises format currently updates formula-driven active formats
  without updating row-local Targets. The atomic format-edit workflow closes
  that existing safety gap for all exercises, not only DB Step-Up.
- Most format conversions can preserve historical parsing because rendered
  delimiters do not change. DB Step-Up is the intentional exception: adding
  Weight changes its cell shape, so older entries remain raw.
- The Google Sheet remains the durable, human-readable source of truth throughout
  conversion and format evolution.
