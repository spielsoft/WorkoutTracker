# Source MVP Release Readiness PRD

## Problem Statement

WorkoutTracker is close to its functional MVP, but the repository is not yet a
safe, reproducible public source release. A technically inclined user cannot
currently clone the repository, supply their own Google configuration, and
reliably build the supported applications from the checked-in instructions.
Some platform configuration is developer-specific, application state storage
is based on desktop environment guesses, and the live Google test does not
exercise the same composition used by the application. Android has additional
known networking, OAuth, signing, and toolchain gaps; it will be documented as
not release-ready rather than partially prepared in this milestone.

The project also lacks the legal and operational material expected of a public
repository. Apache-2.0 has been selected but is not yet applied. Contribution,
security, notices, release, and third-party dependency expectations are not
documented. Support and privacy pages contain placeholder contact language and
must describe the current application accurately. Existing build and store
documentation was produced during several obsolete authorization designs and
cannot be treated as authoritative.

The current custom Flutter sheet chooser is acceptable only for the first
source-distributed MVP, where each builder supplies and controls their own
Google Cloud project. Its sensitive and restricted scopes remain unsuitable
for a centrally authorized, unrestricted store release. Replacing that chooser
with Google Picker is deliberately isolated in `ISSUES_PICKER_PRD.md` and must
not destabilize this release baseline.

## Solution

Publish a source-first MVP baseline that is legally clear, reproducibly
buildable, honestly documented, and validated through the same application
interfaces used at runtime.

Apply Apache-2.0 and add lightweight contribution, security, trademark, and
third-party notice guidance. Establish one documented local configuration
location containing checked-in examples but git-ignored real Google
credentials. Validate required values early with actionable errors, remove
developer-specific values from tracked release configuration, and complete the
minimum platform networking and signing setup needed by public builders.

Use platform application-support storage for local account/sheet state. Make
the opt-in live Google test enter through the production account, workspace,
validation, and logging composition while retaining explicit protection around
the writable development sheet. Update support/privacy resources and public
build documentation from current source behavior, not from historical store
notes.

Add a small continuous-integration and release gate that runs static analysis,
behavioral tests, configuration checks, and feasible clean builds. Finish by
cleaning tests that only assert documentation text or implementation details.
The completed branch becomes the gym-test candidate. It is merged to `main`
only after validation; gym findings are repaired and accepted on `main` before
the separate Picker branch is created.

## User Stories

1. As a source user, I want to understand the license before cloning or contributing, so that I know what I may do with the project.
2. As the project owner, I want Apache-2.0 applied consistently, so that use and contributions have clear terms.
3. As the project owner, I want the product name and branding treated separately from the code license, so that forks do not imply endorsement.
4. As a contributor, I want a concise contribution workflow, so that I can submit a compatible change.
5. As a security reporter, I want a private reporting path, so that vulnerabilities are not disclosed prematurely.
6. As a source user, I want an inventory of direct third-party dependencies and their licenses, so that redistribution obligations are understandable.
7. As a source user, I want one documented local Google configuration directory, so that setup is discoverable.
8. As a source user, I want example configuration files without real credentials, so that I know the required shape.
9. As the project owner, I want real credential exports excluded from git, so that secrets and local project material are not published accidentally.
10. As a source user, I want the application to detect missing configuration before opening a broken login flow, so that setup errors are actionable.
11. As an iOS builder, I want instructions for creating an OAuth client matching my bundle and signing identity, so that native login works.
12. As a macOS builder, I want instructions for OAuth, signing, entitlements, and clean release builds, so that the app bundle works outside a debug session.
13. As an Android builder, I want the repository to state plainly that Android is not release-ready and list the known missing work, so that I do not mistake Flutter scaffolding for support.
14. As the project owner, I want Android readiness deferred as one coherent future effort, so that this release is not delayed by an unvalidated platform.
15. As a source builder, I want to understand that my Google Cloud project and consent screen are my responsibility, so that the repository does not imply access through the owner's production credentials.
16. As the project owner, I want the current chooser explicitly classified as source-MVP-only, so that it is not accidentally submitted as the final store authorization design.
17. As a mobile user, I want account and selected-sheet state stored in a platform-supported application directory, so that restart behavior is reliable.
18. As a user, I want persistence failures surfaced without silently switching to temporary storage, so that lost selections are not surprising.
19. As a user switching Google accounts, I want persisted sheet ownership checks preserved, so that another account never inherits a saved selection silently.
20. As a maintainer, I want the live integration test to use production account and workspace orchestration, so that it detects composition regressions.
21. As a maintainer, I want the live test disabled unless explicitly enabled, so that normal tests never modify a real sheet.
22. As a maintainer, I want the live test command to name its required target device, so that it can actually be reproduced.
23. As a maintainer, I want the development sheet reset after live validation, so that repeated runs start from a known state.
24. As a prospective user, I want an accurate privacy page, so that I understand the data stored locally and in Google Sheets.
25. As a user needing help, I want an actual support contact, so that the support page is useful.
26. As the project owner, I want hosted pages to describe only currently deployed behavior, so that obsolete Picker callbacks and backend implications do not return.
27. As a source user, I want a short clone-to-build guide, so that I can install the app without reconstructing internal history.
28. As a source user, I want supported and unvalidated platforms distinguished, so that platform claims are honest.
29. As a maintainer, I want stale or contradictory release documents removed or clearly archived, so that source code and current guides remain authoritative.
30. As a maintainer, I want dependency updates reviewed and tested, so that known platform fixes are not needlessly missed.
31. As a contributor, I want continuous integration to reject analysis and test failures, so that the public default branch remains usable.
32. As the project owner, I want a repeatable clean release gate, so that deleted assets cannot survive incremental builds.
33. As the project owner, I want release notes and versioning expectations, so that later GitHub releases are traceable.
34. As a maintainer, I want tests to protect behavior rather than prose or private structure, so that documentation and refactoring remain inexpensive.
35. As a gym user, I want the accepted current version frozen before authorization experiments begin, so that Picker work cannot obscure ordinary workout bugs.

## Implementation Decisions

- Apache-2.0 is the repository license. Add the canonical license text and
  concise notice, contribution, security, trademark, and third-party material.
- Begin with Developer Certificate of Origin sign-off rather than a contributor
  license agreement. A CLA is unnecessary unless future proprietary
  relicensing becomes a real requirement.
- Keep the present custom Flutter chooser for this source MVP only. Do not
  change its authorization architecture or scope set in this plan.
- Every public builder supplies a separate Google Cloud project and native
  OAuth clients. The owner's Cloud project is not a shared public credential
  service.
- Use one local configuration directory for credential exports and generated
  build values. Track templates and documentation; ignore concrete JSON,
  platform service files, generated values, and secrets.
- OAuth client IDs are identifiers rather than secrets, but owner-specific
  release values should not be the default configuration for forks.
- Configuration validation must report the missing key and the setup guide to
  follow. It must not dump credential content.
- Do not implement Android readiness in this plan. Document the missing SDK
  validation, release networking, package/signing identity, OAuth client, and
  physical-device testing as deferred work.
- Use a platform application-support provider for state paths. Do not infer
  mobile storage from `HOME`, `APPDATA`, or a temporary-directory fallback.
- Preserve the existing serialized workspace restoration and account-binding
  rules when changing storage.
- The live Google test should compose the production account session, scoped
  access, workspace/session behavior, and public logging commands. Test-only
  sheet reset remains an explicit harness around that flow.
- Live Google validation remains opt-in and destructive only to the named
  development fixture. Local fakes prove only application-owned interfaces.
- Support and privacy pages remain static hosted resources. They are not an app
  backend and must not claim that Firebase stores workout data.
- Public documentation is derived from code, platform configuration, and
  successful commands. Historical store documentation is an audit target, not
  an authority.
- CI should prioritize analysis and the fast local suite on every change.
  Platform builds may use separate jobs where runner availability and signing
  constraints allow them.
- Release validation uses clean build outputs for macOS and unsigned iOS. Never
  validate deletion through an incremental bundle alone.
- The first plan ends with a tested candidate and handoff. Merging to `main`,
  gym testing, and accepting gym repairs occur before creating `new_picker`.
- Do not add Picker implementation, WebView dependencies, Picker callbacks, or
  `drive.file` migration work under this PRD.

## Testing Decisions

- Test configuration behavior through a public loader/validator using example,
  missing, and malformed inputs. Do not assert secret values or private parser
  helpers.
- Test state persistence through its public store contract using controlled
  directories and observable restore/save failures.
- Keep account-binding and startup serialization tests around the public
  workspace state and commands.
- Do not add Android readiness tests. Documentation should state the known gaps
  and avoid implying that generated Flutter scaffolding has been validated.
- Refactor the live Google integration test so its entry point uses production
  composition. Only a real opt-in run can establish Google behavior.
- Verify static support/privacy resources for required destinations and basic
  safety properties. Do not test exact documentation prose.
- CI runs static analysis and the default Flutter suite. The release gate also
  runs clean supported-platform builds and bundle inspection.
- Use the `test-cleanup` skill near the end. Remove tests that assert docs,
  filenames without runtime significance, private widget structure, or canned
  third-party behavior. Retain durable sheet-contract, command, screen, and
  configuration behavior tests.
- Record commands and outcomes in the final handoff. A skipped live test must
  be reported as skipped, never as passing Google integration.

## Out of Scope

- Replacing the current chooser with Google Picker.
- Reducing authorization to `drive.file`.
- Adding a WebView or hosted Picker surface.
- Central OAuth verification for unrestricted store users.
- App Store or Play Store submission.
- Shipping signed public app bundles in the first GitHub MVP.
- New workout features, coaching, timers, notifications, or a separate data
  backend.
- Solving gym-test findings before the user has performed that test.
- Android networking, OAuth configuration, signing, builds, device validation,
  Picker integration, or release-readiness claims.

## Further Notes

This plan is intentionally conservative. It makes the current implementation a
credible public source release without confusing that milestone with the later
store authorization design.

After every slice is complete and validated, stop for the owner-directed merge
to `main`. The owner will test that exact baseline in the gym. All resulting
repairs must land and be accepted on `main`. Only then should a new branch named
`new_picker` be created from `main` and the work in `ISSUES_PICKER.md` begin.
