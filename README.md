# WorkoutTracker

WorkoutTracker is a focused gym logging app backed by a user-owned Google
Sheet. It presents spreadsheet workouts as a fast phone and desktop workflow
while keeping the Sheet readable and editable without the app.

The app can:

- sign in with Google and choose or create a workout Sheet;
- validate damaged workbook structure before allowing writes;
- organize exercises by workout, including attached backup exercises;
- create and edit canonical exercises;
- create visible history blocks and log compact set notation; and
- preserve manually entered set text it cannot parse.

It is not a coaching, progression, or program-generation service. Workout data
is not copied to an application backend.

## Editing the Sheet Directly

Each exercise's `Log Format` declares its logging fields, such as
`{Weight}x{Reps}@{RPE}` or
`({Height (in)}, {Weight (lbs)})x{Reps}@{RPE},{Pain}`. Names inside braces are
exact fields, and every other character is literal text. A format has one to
five fields; units belong in names while structured entries remain numeric.
The `Exercises` tab stores matching `Default Values`; active workout rows store
independently editable `Targets`. Sets, Rest, and Tempo remain fixed metadata.
Blank field values are valid, but a nonblank Default Values or Targets cell
that does not match its Log Format blocks app writes until corrected.
Declared `0.9` sheets preview their Python-style conversion before a confirmed,
stale-checked batch. Default Values and Targets retain their meaning, and
history stays byte-for-byte unchanged; entries the current format cannot parse
remain available as raw text.

## Current Status

macOS and iOS are the prepared source-build targets; the repository does not
ship signed public bundles. Android readiness is deferred, while Linux and
Windows remain unvalidated. [`BUILDING.md`](BUILDING.md) defines the exact
platform boundaries.

The current source-MVP uses native Google Sign-In plus an in-app Flutter chooser
that lists Sheets through the Drive API. Each public source builder is expected
to supply a separate Google Cloud project and OAuth configuration. A future,
separately gated migration will evaluate Google Picker with per-file access.

## Build and Run

[`BUILDING.md`](BUILDING.md) is the authoritative clone-to-run and clean-release
guide. It covers prerequisites, builder-owned Google configuration, tests,
Apple signing, release artifacts, platform limits, and the opt-in live Google
gate.

## Documentation

| Topic | Document |
| --- | --- |
| Workbook schema and write invariants | [`docs/domain_contract.md`](docs/domain_contract.md) |
| Test tiers and live integration | [`docs/testing.md`](docs/testing.md) |
| Google account and chooser architecture | [`docs/google_sheets_development_auth.md`](docs/google_sheets_development_auth.md) |
| UI accessibility contract | [`docs/accessibility.md`](docs/accessibility.md) |
| Clone, run, and clean release builds | [`BUILDING.md`](BUILDING.md) |
| Dependency update policy and review | [`DEPENDENCIES.md`](DEPENDENCIES.md) |
| Versioning and GitHub releases | [`RELEASING.md`](RELEASING.md) |
| User-visible release history | [`CHANGELOG.md`](CHANGELOG.md) |

## Project Policy

WorkoutTracker is licensed under the
[Apache License 2.0](LICENSE). The license permits use, modification, and
distribution, including commercial use, subject to its terms. Project names
and branding are addressed separately in [TRADEMARKS.md](TRADEMARKS.md).

See [CONTRIBUTING.md](CONTRIBUTING.md) for the DCO-based contribution workflow,
[SECURITY.md](SECURITY.md) for private vulnerability reporting and supported
release expectations, and [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) for
the direct runtime dependency license inventory.
