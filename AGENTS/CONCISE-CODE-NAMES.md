# Repo-Specific Concise Code Names

Use these repo-local shorthand hints case-insensitively. They are not a mandate
to abbreviate everything. Prefer dropping redundant context first, then use a
stable shorthand when the remaining long word still repeats often in this repo.

## Drop Before Abbreviating

- `WorkoutTracker` -> drop
- `Google` -> drop when the module or package already supplies Google context
- `Spreadsheet` -> prefer `Sheet` when the value is specifically a selected
  Google Sheet in this app
- `Canonical` -> drop when the current scope already works only with
  `Exercises`
- `ActiveSheet` -> prefer `active`, `sheet`, or drop the phrase entirely when
  the file already establishes active-sheet context

## Preferred Shorthands

| Word | Preferred shorthand | Notes |
| --- | --- | --- |
| `Workbook` | `Wbk` | `wb` is also fine for tight local variables |
| `Factory` | `Fact` | |
| `Template` | `Tmpl` | |
| `Validate` / `Validation` | `Val` | use `val` for locals |
| `Selection` / `Selected` | `Sel` | |
| `Exercise` | `Exe` | keep full `exercise` when the scope mixes multiple exercise concepts |
| `Controller` | `Ctrl` | |
| `Controllers` | `Ctrls` | |
| `Picker` | `Pkr` | |
| `Account` | `Acct` | |
| `Authorize` / `Authorization` | `Auth` | use the whole word `auth` rather than inventing `authz` in this repo |
| `Callback` | `Cb` | |
| `Config` / `Configuration` | `Cfg` | |
| `Initialize` / `Initializer` / `Initialization` | `Init` | |
| `Service` | `Svc` | |
| `Session` | `Sess` | |
| `Context` | `Ctx` | |
| `Definition` | `Def` | |
| `Expectation` | `Expct` | |
| `Defaults` | `Defs` | |
| `State` | `St` | prefer full `state` when it is already short enough or part of a public UI type |
| `Availability` | `Avail` | |

## Repo Notes

- These suggestions are derived from the concise-name replacement log and from
  names already stabilized in this repo.
- Prefer whole-word replacements like `Sheet` over opaque abbreviations for
  domain concepts the app uses constantly.
- Keep domain words such as `workout`, `backup`, `history`, `formula`,
  `repair`, `placement`, and `logging` unless surrounding scope makes them
  truly redundant.
- Avoid near-miss variants once a shorthand is established here. For example,
  prefer `Wbk` over `Wb` in public-ish names if the word must stay.
