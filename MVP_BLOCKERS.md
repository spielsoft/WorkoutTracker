# MVP Blockers

This file tracks release-blocking MVP work that should survive daily deletion
of transient `ISSUES_*` files.

## Blocker 1: Live Google Sheet Write Validation

Status: pending explicit live Google authorization

Why this blocks MVP:

- The local readiness gate passed for analyzer, tests, simulator build, and
  no-codesign iOS device build.
- The remaining unverified behavior is the real Google authorization and
  development-sheet read/write flow.
- The live test can reset or write to the shared development spreadsheet, so it
  must not run without explicit approval.

Validation command:

```sh
WORKOUT_TRACKER_RUN_LIVE_GOOGLE_TESTS=1 flutter test integration_test/live_logging_flow_test.dart
```

Development sheet:

```text
https://docs.google.com/spreadsheets/d/1zQrmCYelrNqRMv4WtJcOrtezSxoaVniXzXi4XgKva_E/edit?gid=0#gid=0
```

To clear:

- Get explicit approval that development-sheet writes are acceptable.
- Run the live integration test.
- Complete any Google login or consent prompt if the local machine requests it.
- Confirm the test resets or cleans up the development sheet as expected.
