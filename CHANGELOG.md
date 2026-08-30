# Changelog

User-visible changes to WorkoutTracker are recorded here. Releases follow
[Semantic Versioning](https://semver.org/).

## Unreleased

### Added

- Public-source policy, builder-owned configuration, CI, and release guidance.
- Durable application-support persistence and production-composed live Google
  validation.

### Changed

- Support, privacy, and self-build documentation now describe the source MVP.
- Minimum supported operating systems are now iOS 15 and macOS 12 (Monterey),
  matching the Flutter SDK the application is built and validated against.

### Fixed

- Screen, countdown, and exercise-authoring headings announce as headings
  again to VoiceOver and TalkBack.
- A cancelled or interrupted Google authorization now reports that no headers
  are available instead of raising the cancellation as an error.

## 1.0.0-rc.1 - Pending

The first source-MVP GitHub release will freeze the owner-accepted gym-test
baseline. It is not published until the release process in `RELEASING.md` is
complete.
