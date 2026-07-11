# Release Process

WorkoutTracker uses Semantic Versioning for source releases:

- patch releases contain backward-compatible corrections;
- minor releases add backward-compatible behavior; and
- major releases may change the workbook, configuration, or application
  contract incompatibly.

The `version` in `pubspec.yaml` is the release version. Its `+build` suffix is
the monotonically increasing Apple build number and does not change semantic
version precedence.

## Prepare a GitHub Release

1. Move relevant entries from `Unreleased` in `CHANGELOG.md` into a dated
   version section.
2. Set the matching version and next build number in `pubspec.yaml`.
3. Run the credential-free CI gate and the clean local Apple release gate in
   `BUILDING.md`. Record skipped live Google validation explicitly.
4. Tag the accepted commit as `vMAJOR.MINOR.PATCH`; do not move an existing
   release tag.
5. Create GitHub release notes from the changelog. Summarize user-visible
   changes, configuration or migration work, validation performed, known
   limitations, and the exact commit.

GitHub releases publish source and notes only. Do not attach public app bundles,
signing material, Google credentials, or personal fixture data. Each builder
supplies a Google Cloud project and OAuth clients; a release does not create a
central credential service, Firebase application backend, or workout-data
backend. Android remains deferred and must not be presented as validated.
