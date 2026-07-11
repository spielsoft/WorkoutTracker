# Contributing

Thank you for improving WorkoutTracker. Contributions should preserve the
product and architecture contracts documented in `AGENTS.md` and the relevant
files it routes to.

## Workflow

1. Open an issue before a large behavior or architecture change.
2. Create a focused branch and include public-contract tests for changed
   behavior.
3. Run formatting verification, `flutter analyze`, and the narrowest relevant
   tests described in `docs/testing.md`. Dependency changes require the full
   default suite and the review in `DEPENDENCIES.md`.
4. Submit a pull request that explains the user-visible result, validation,
   and any skipped gates or remaining risks.

Do not include credentials, personal workout data, or other confidential
material. Contributions must be original or otherwise legally compatible with
the repository's Apache License 2.0. Unless explicitly stated otherwise, an
accepted contribution is licensed under Apache-2.0 as described in `LICENSE`.

## Developer Certificate of Origin

Every commit must include a `Signed-off-by` trailer certifying the
[Developer Certificate of Origin 1.1](https://developercertificate.org/). Add
it with:

```sh
git commit --signoff
```

The sign-off uses your real name and an email address you are authorized to
use. By signing off, you certify that you have the right to submit the change
under the project's license. Fix a missing sign-off before review; a separate
contributor license agreement is not required.
