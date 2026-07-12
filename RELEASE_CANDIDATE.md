# Source MVP Gym-Test Candidate

## Candidate Identity

- Candidate base before this handoff: `69e3e1fd59a38d2127c6376dab5b1c5413bc00ce` (`Clean release behavior tests`).
- Candidate commit: the commit containing this `RELEASE_CANDIDATE.md` file.
- Branch at handoff preparation: `login-fix`.

Completed source-MVP slice commits:

| Slice | Commit |
| --- | --- |
| 1 | `c27569a` |
| 2 | `718737e` |
| 3 | `31e14fa` |
| 4 | `8f111c9` |
| 5 | `4d5c21c` |
| 6 | `b7f96d8` |
| 7 | `3d8e10e` |
| 8 | `69e3e1f` |

The source baseline is ready for owner-directed review and merge. No merge,
`new_picker` branch, or Picker-plan work is part of this handoff.

## Clean Release Gate

| Gate | Command | Outcome |
| --- | --- | --- |
| Clean | `flutter clean` | Passed after granting Flutter SDK-cache access; prior generated outputs were deleted. |
| Dependencies | `flutter pub get` | Passed. Direct dependencies resolved from the lockfile. |
| Formatting | `dart format --output=none --set-exit-if-changed lib test integration_test` | Passed: 109 files, 0 changes. |
| Analysis | `flutter analyze` | Passed: no issues. |
| Default tests | `flutter test` | Passed: 292 tests after the local-credential regression repair. |
| macOS Release | `flutter build macos --release` | Passed with the ignored local Apple configuration loaded automatically. |
| macOS inspection | `scripts/validate_macos_app_bundle.sh --compile-only "build/macos/Build/Products/Release/WorkoutTracker.app"` plus compiled-plist comparison | Passed bundle structure; client ID, reversed URL scheme, bundle ID, and team match the ignored local configuration. The bundle is signed, but this machine does not trust the local certificate chain. |
| iOS Release | `flutter build ios --release` | Passed: signed arm64 device Release bundle with the ignored local client ID, reversed URL scheme, and bundle ID. |
| iOS signing | `codesign --verify --deep --strict` plus embedded-profile inspection | Passed: valid signature and development profile for the configured bundle; the connected iPhone is included in the profile. |
| iOS installation | `xcrun devicectl device install app` | Passed on the connected physical iPhone. |
| Bundle/source audit | Inspected metadata, assets, binaries, dependency declarations, and changed paths | Passed for source-MVP boundaries: no owner OAuth/team values, Picker migration, `drive.file`, WebView, hosted callback, Firebase data SDK/backend, debug kernel, or Android build change was found. |

Clean only once before the two Apple builds so that both final artifacts remain
available. Release builds are required; debug artifacts do not satisfy this
gate. Real local credentials and signing configuration remain ignored and
must never be printed or committed.

## Expected Artifact Locations

- macOS: `build/macos/Build/Products/Release/WorkoutTracker.app`
- signed iOS development app: `build/ios/iphoneos/Runner.app`

- macOS bundle: 52.0 MB, universal arm64/x86_64 Mach-O, signed with a locally
  untrusted certificate chain, bundle ID `com.spielman.workouttracker`, version
  `1.0.0` build `1`.
- iOS bundle: 22.0 MB, signed arm64 Mach-O with an embedded development
  profile containing the connected iPhone, bundle ID
  `com.spielman.workouttracker`, version `1.0.0` build `1`.

Both bundles contain nonempty Google client ID and reversed-client URL settings
that match the ignored `local_google_credentials/AppleBuild.xcconfig`. Normal
Apple build commands now use that native configuration without a separate Dart
defines file or command-line flag.

## Manual and Skipped Validation

- Live Google validation: pending HITL. It was not run because explicit
  approval for destructive writes to the named development Sheet was not
  given. This is skipped, not passing.
- macOS runtime launch: passed; the rebuilt bundle launched and remained
  running. Completing native Google account interaction remains a user/HITL
  check. The local certificate chain is not trusted, so distribution validation
  remains pending.
- Signed iOS installation and provisioning: passed on the connected iPhone.
  First launch is pending the phone's one-time explicit trust of the refreshed
  personal-development profile. Physical-device Google login remains a
  user/HITL check.
- Firebase Hosting deployment/manual production-page comparison belongs to
  the already completed support/privacy slice and is not repeated by this
  release build gate.
- Android: deliberately not built or validated. Its deferred SDK/toolchain,
  release networking and permission, package/signing identity, OAuth client,
  and physical-device work is documented in `BUILDING.md` and
  `docs/google_sheets_development_auth.md`.

## Authorization and Scope Boundary

This source MVP retains native Google Sign-In, the custom Flutter Sheet
chooser, Drive metadata discovery, and writable Sheets access. The clean audit
confirmed that it adds no Google Picker migration, WebView dependency,
hosted Picker callback, Firebase workout-data backend, or scope reduction.
Those changes remain outside `ISSUES_PRD.md` and must not begin from this
candidate.

## Remaining Risks Before Gym Test

- Native Google client configuration is present in both local artifacts, and
  signed iOS installation is proven. A real account login remains a user/HITL
  validation.
- Real Google/OAuth behavior remains unverified until the owner approves and
  completes the destructive live test.
- An unsigned or locally untrusted Apple build proves compilation and bundle
  structure only; it does not prove installability, native Google login,
  stable keychain behavior, notarization, or distribution readiness.
- The current restricted/sensitive scope design is intentionally limited to
  builder-owned source-MVP Cloud projects and is not suitable for an
  unrestricted store release.

## Owner Handoff Sequence

1. Review the final diff, ensure only the intended Slice 9 handoff/checklist
   changes are staged, and commit them separately.
2. With explicit owner direction, merge the exact candidate commit to `main`.
3. Rebuild that exact commit in Release mode with builder-owned signing and
   Google configuration.
4. The owner confirms that merged `main` commit is the version to exercise in
   the gym.
5. Repair ordinary gym findings on `main` and have the owner accept that
   baseline.
6. Only after that acceptance, and only with explicit owner direction, create
   `new_picker` from the accepted `main`. Do not perform work from
   `ISSUES_PICKER.md` before then.
