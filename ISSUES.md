# Source MVP Release Issues

This plan implements `ISSUES_PRD.md` while deliberately retaining the current
custom Flutter chooser. Complete it on the current branch. Do not begin
`ISSUES_PICKER.md` here.

## Progress

- [x] Slice 1: Apply Apache-2.0 and public project policy
- [x] Slice 2: Make builder-owned Google configuration safe and complete
- [x] Slice 3: Make mobile state persistence durable
- [ ] Slice 4: Exercise production composition in live Google validation
- [ ] Slice 5: Publish accurate support and privacy resources
- [ ] Slice 6: Replace historical setup notes with a public self-build guide
- [ ] Slice 7: Add dependency and continuous-integration gates
- [ ] Slice 8: Clean the release test suite
- [ ] Slice 9: Produce and hand off the gym-test candidate

## Slice 1: Apply Apache-2.0 and public project policy

### Type

`AFK`

### What to build

Apply the decided Apache-2.0 license and add the minimum durable policy needed
for public use and contributions. Separate code licensing from product naming,
document DCO-based contributions, provide private security-reporting guidance,
and record direct third-party license obligations without claiming ownership of
dependencies.

### Acceptance criteria

- [x] The repository contains the canonical Apache License 2.0 text.
- [x] The README identifies Apache-2.0 accurately and links to the license.
- [x] Contribution guidance requires compatible contributions and DCO sign-off.
- [x] Trademark guidance prevents forks from implying endorsement while
      preserving Apache rights.
- [x] Security guidance provides a real private reporting method and supported
      release expectations.
- [x] Direct runtime dependencies and their license families are inventoried
      from authoritative package metadata.
- [x] No policy claims exclusive commercial rights that conflict with
      Apache-2.0.

### Blocked by

None - can start immediately.

### User stories covered

- PRD user stories 1-6.

## Slice 2: Make builder-owned Google configuration safe and complete

### Type

`AFK`

### What to build

Turn local Google configuration into a reproducible public-builder contract.
Provide sanitized templates, ignore real exports and generated platform values,
validate missing configuration before login, and complete the platform
requirements for iOS and macOS. Preserve the current chooser and its scope
behavior. Document Android as deferred rather than partially preparing it.

### Acceptance criteria

- [x] One documented local directory owns real Google Cloud exports and build
      configuration for every supported platform.
- [x] Example files describe every required value without containing usable
      owner credentials or secrets.
- [x] Git ignore rules cover real JSON exports, platform service files,
      generated values, and other credential-bearing artifacts.
- [x] Tracked iOS and macOS configuration no longer makes the owner's OAuth
      clients the implicit default for forks.
- [x] Android is explicitly marked not release-ready, with its missing network,
      package/signing, OAuth, SDK, and device-validation work listed as deferred.
- [x] Missing or malformed configuration produces an actionable pre-login
      error without printing credential content.
- [x] The guide explains Google API enablement, consent-screen test users, and
      builder ownership of quotas and verification.
- [x] Focused tests cover configuration presence and errors without asserting
      platform-file trivia.

### Blocked by

None - can start immediately.

### User stories covered

- PRD user stories 7-16.

## Slice 3: Make mobile state persistence durable

### Type

`AFK`

### What to build

Store application state in the platform-supported application-support location
on mobile and desktop. Preserve serialized restore, explicit failure reporting,
and account-to-sheet binding. Remove environment-variable guesses and silent
temporary-directory fallbacks from production behavior.

### Acceptance criteria

- [x] Production state paths come from a supported platform application-data
      provider on iOS and macOS.
- [x] Saving and restoring a selected sheet survives a normal restart.
- [x] A storage failure is observable through the existing application status
      flow and never silently switches to temporary storage.
- [x] Account mismatch still requires explicit reselection or confirmation.
- [x] Restore remains serialized against login, logout, choose, and create
      commands.
- [x] Public store tests cover successful persistence, corrupt input, and I/O
      failure without pinning the provider implementation.

### Blocked by

None - can start immediately.

### User stories covered

- PRD user stories 17-19.

## Slice 4: Exercise production composition in live Google validation

### Type

`AFK`

### What to build

Refactor the opt-in live Google integration so it enters through the same
account, scoped access, workspace restoration, workbook session, validation,
and logging command interfaces as the application. Keep the development-sheet
reset harness explicit and make the runnable device command truthful.

### Acceptance criteria

- [ ] The live test uses production application composition rather than a
      separately assembled authorization and adapter path.
- [ ] Without the opt-in environment flag, the test skips before login or any
      Google request.
- [ ] With the flag, the command identifies a supported device target and the
      destructive development sheet clearly.
- [ ] A successful run selects or resolves the fixture, validates it, performs
      a representative logged-set write, rereads the result, and resets the
      fixture.
- [ ] Cancellation, missing credentials, and reset failure are reported
      distinctly.
- [ ] Local tests cover only the app-owned integration entry contract; they do
      not simulate Google success as proof.

### Blocked by

- Slice 2: Make builder-owned Google configuration safe and complete.
- Slice 3: Make mobile state persistence durable.

### User stories covered

- PRD user stories 20-23.

## Slice 5: Publish accurate support and privacy resources

### Type

`HITL`

### What to build

Make the hosted support and privacy surface suitable for a public source MVP.
Describe the present native login, custom chooser, Google APIs, local state, and
user-owned Sheet accurately. Replace placeholder contact language with an
owner-approved support and privacy contact, and ensure no retired Picker
callback or Firebase-data claim remains.

### Acceptance criteria

- [ ] The owner supplies or approves a public support/privacy contact channel.
- [ ] Support content gives users a concrete way to request help and report a
      problem.
- [ ] Privacy content distinguishes local app state, Google account identity,
      Google Sheet data, and static Firebase Hosting.
- [ ] The current scopes and their purposes are stated accurately for the
      source-MVP implementation.
- [ ] The pages explain deletion/revocation options without promising behavior
      the app or Google does not provide.
- [ ] No retired hosted Picker, callback, server token storage, or app backend
      is implied.
- [ ] Tests check destinations and essential disclosures, not exact prose.
- [ ] The deployed pages are manually compared with the checked-in resources.

### Blocked by

- Slice 2: Make builder-owned Google configuration safe and complete.

### User stories covered

- PRD user stories 24-26.

## Slice 6: Replace historical setup notes with a public self-build guide

### Type

`AFK`

### What to build

Create a concise clone-to-run and clean-release guide for technically inclined
macOS and iOS builders. Derive it from successful commands and the new local
configuration contract. Identify Android scaffolding as not release-ready.
Remove, archive, or label historical store notes so they cannot override source
code and verified instructions.

### Acceptance criteria

- [ ] A new user can identify prerequisites, clone, install dependencies,
      configure Google, run tests, and build a supported target in order.
- [ ] iOS and macOS signing, bundle identity, OAuth configuration, and clean
      release commands are described without the owner's team identity.
- [ ] Android is clearly deferred, with known missing SDK, package/signing,
      OAuth, network, build, and physical-device validation work summarized.
- [ ] Supported, experimentally viable, and currently unvalidated platforms
      are distinguished.
- [ ] The source-MVP authorization limitations and future Picker plan are
      stated plainly.
- [ ] Historical store documentation is removed or marked non-authoritative;
      no current guide cites it as evidence.
- [ ] Commands, paths, bundle names, and opt-in live-test invocation match the
      repository and a clean local run.
- [ ] Documentation correctness is reviewed manually rather than enforced with
      brittle prose tests.

### Blocked by

- Slice 1: Apply Apache-2.0 and public project policy.
- Slice 2: Make builder-owned Google configuration safe and complete.
- Slice 4: Exercise production composition in live Google validation.
- Slice 5: Publish accurate support and privacy resources.

### User stories covered

- PRD user stories 27-29.

## Slice 7: Add dependency and continuous-integration gates

### Type

`AFK`

### What to build

Review direct and platform-resolved dependencies, take compatible fixes, and
add a small public continuous-integration workflow. The default gate should
catch formatting, analysis, and local behavior regressions without requiring
Google credentials. Document versioning and release-note expectations for later
GitHub releases.

### Acceptance criteria

- [ ] Direct dependencies and important platform implementations are checked
      against current authoritative release notes.
- [ ] Compatible crash, security, and correctness fixes are adopted and tested.
- [ ] CI runs formatting verification, static analysis, and the default Flutter
      test suite without Google credentials.
- [ ] Live Google validation remains outside the default CI path.
- [ ] Platform build jobs are included only where unsigned runners can execute
      them reliably; omitted builds have a documented local gate.
- [ ] The repository defines versioning, changelog, and GitHub release
      expectations without publishing app bundles.
- [ ] CI and dependency changes do not introduce a Firebase application backend
      or centralized credentials.

### Blocked by

- Slice 1: Apply Apache-2.0 and public project policy.
- Slice 2: Make builder-owned Google configuration safe and complete.

### User stories covered

- PRD user stories 30-33.

## Slice 8: Clean the release test suite

### Type

`AFK`

### What to build

Use the `test-cleanup` skill to remove temporary TDD scaffolding and tests that
assert documentation prose, private widget structure, or invented third-party
behavior. Retain the smallest durable safety net around workbook contracts,
application commands, public screen behavior, configuration, and release
requirements.

### Acceptance criteria

- [ ] Tests whose only subject is documentation wording are removed or replaced
      with an appropriate non-test validation step.
- [ ] Private helpers, incidental callback order, and widget-tree trivia are not
      treated as public contracts.
- [ ] Fakes assert only this app's requested scopes, adapter calls, plans, and
      accepted callback shapes.
- [ ] Workbook safety, account binding, command serialization, and major user
      flows retain behavior coverage.
- [ ] The default suite remains credential-free and fast enough for CI.
- [ ] The final test inventory explains the purpose of unusual integration or
      platform checks.

### Blocked by

- Slices 1-7.

### User stories covered

- PRD user story 34.
- PRD testing decisions.

## Slice 9: Produce and hand off the gym-test candidate

### Type

`HITL`

### What to build

Run the complete clean release gate on the current branch, inspect the produced
bundles, and hand the exact candidate to the owner. This slice stops before any
Picker work. After the owner directs the merge to `main`, the owner will test
that version in the gym and ordinary defects will be repaired on `main` before
the Picker branch is created.

### Acceptance criteria

- [ ] Formatting, static analysis, and the complete default test suite pass.
- [ ] A clean macOS release bundle and clean unsigned iOS release bundle build
      successfully and are inspected for retired assets/configuration.
- [ ] Android is not built or presented as validated; the handoff links to its
      documented deferred-readiness gaps.
- [ ] The opt-in live Google flow is either run successfully with user approval
      or explicitly reported as pending HITL validation.
- [ ] The handoff records commit hashes, commands, build artifact locations,
      skipped checks, and remaining risks.
- [ ] No Picker migration, WebView dependency, or scope reduction is present.
- [ ] The branch is declared ready for owner-directed merge; the agent does not
      create `new_picker` prematurely.
- [ ] The owner confirms the merged `main` baseline is the version to test in
      the gym.

### Blocked by

- Slice 8: Clean the release test suite.

### User stories covered

- PRD user story 35.
- PRD release sequencing.
