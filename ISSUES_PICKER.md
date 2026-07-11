# Single-Login Google Picker Issues

This plan implements `ISSUES_PICKER_PRD.md`. It must run only on a new
`new_picker` branch created from the gym-tested, repaired, and accepted `main`
baseline. Slices after the live proof are blocked unless the owner explicitly
accepts the proof result.

## Progress

- [ ] Slice 1: Establish the isolated Picker experiment
- [ ] Slice 2: Pass the native token into a minimal Picker surface
- [ ] Slice 3: Prove one-login Picker behavior on macOS and iOS
- [ ] Slice 4: Cut production sheet selection over to Picker
- [ ] Slice 5: Move creation and workbook access to per-file authorization
- [ ] Slice 6: Remove the custom chooser and broad authorization
- [ ] Slice 7: Clean tests, documentation, and release bundles

## Slice 1: Establish the isolated Picker experiment

### Type

`HITL`

### What to build

Confirm that the accepted gym-tested baseline is on `main`, create the isolated
`new_picker` branch from that exact commit, and add the smallest builder-owned
Picker configuration contract. The existing chooser remains the default and
the experiment is explicitly gated so a failed spike can be discarded without
touching the accepted baseline.

### Acceptance criteria

- [ ] The owner confirms all gym findings have been repaired and accepted on
      `main`.
- [ ] `new_picker` is created from the recorded accepted `main` commit.
- [ ] The worktree contains no unrelated uncommitted changes when the
      experiment begins.
- [ ] Builder-local configuration covers Picker API enablement, App ID, API
      key, and platform OAuth clients without committing usable secrets.
- [ ] Missing Picker configuration disables only the experimental path and
      reports an actionable setup error.
- [ ] The current chooser remains available as the control implementation.
- [ ] The go/no-go criteria from the PRD are visible to anyone running the
      spike.

### Blocked by

- Completion of `ISSUES.md`.
- Owner-directed merge of the current branch into `main`.
- Gym testing and acceptance of all resulting repairs on `main`.

### User stories covered

- PRD user stories 20-21 and 24-25.

## Slice 2: Pass the native token into a minimal Picker surface

### Type

`AFK`

### What to build

Add a narrow native-account operation that silently supplies a current
`drive.file` access token for the authenticated account. Feed that token to a
minimal platform Picker surface that displays filtered Google Sheets and
returns a selected file or cancellation. Do not change production selection or
persist the token.

### Acceptance criteria

- [ ] Avatar login is the only application command that can start interactive
      Google authentication or authorization.
- [ ] The native account authorizes `drive.file` and can silently return a
      current token for that same account.
- [ ] Picker is constructed with the supplied token using `setOAuthToken`.
- [ ] Picker code contains no Identity Services token client, OAuth URL,
      `requestAccessToken`, or independent account state.
- [ ] Access tokens never enter URLs, deep links, logs, persisted state, crash
      metadata, or returned selection models.
- [ ] The Picker filters for Google Sheets and returns a human label plus file
      identity through a typed result.
- [ ] Cancellation and presentation failure leave the native account and
      current production selection unchanged.
- [ ] Local tests verify these application-owned invariants without claiming
      that Google displayed Picker successfully.

### Blocked by

- Slice 1: Establish the isolated Picker experiment.

### User stories covered

- PRD user stories 1-3, 8-11, 22-25.

## Slice 3: Prove one-login Picker behavior on macOS and iOS

### Type

`HITL`

### What to build

Run the minimal experiment against real Google services on macOS and a physical
iOS device. Record the visible interaction sequence and prove that Picker uses
the native account without an account chooser, credential request, consent
screen, or second session. Also prove repeated selection, restart, account
switching, token renewal, and per-file Sheets access.

### Acceptance criteria

- [ ] A fresh install shows one native account/consent flow from avatar login.
- [ ] The first Picker launch after login opens directly to file selection with
      no additional account, credential, or consent UI.
- [ ] At least two later Picker launches remain prompt-free.
- [ ] Cancellation returns to the app without signing out or changing the
      selected sheet.
- [ ] Relaunch restores the native account and can reopen Picker without login.
- [ ] An actually renewed or invalidated access-token path reopens Picker
      without interactive authorization.
- [ ] A Picker-selected development Sheet is read and written through the
      Sheets API using only the native `drive.file` authorization, then reset.
- [ ] Switching accounts prevents the new account from inheriting the old
      selection.
- [ ] macOS and physical iOS results, build commits, and observed Google screens
      are recorded.
- [ ] Any second auth/consent prompt, token leak, unsupported platform surface,
      or unusable per-file grant produces a no-go result and stops the plan.
- [ ] The owner explicitly approves the go result before Slice 4 begins.

### Blocked by

- Slice 2: Pass the native token into a minimal Picker surface.

### User stories covered

- PRD user stories 1-7, 9-10, 12-14, 17-18, 20-21, and 28.

## Slice 4: Cut production sheet selection over to Picker

### Type

`AFK`

### What to build

After an approved live proof, make the proven Picker module own choosing,
resolving, retrying, and binding selected Sheets in the production workspace.
Preserve startup serialization, stale-result rejection, explicit login, and
account mismatch behavior while keeping the old chooser temporarily available
only as rollback code.

### Acceptance criteria

- [ ] Production Choose sheet uses the proven Picker surface and never requests
      authorization itself.
- [ ] Selected results resolve to a human title without displaying opaque IDs.
- [ ] The selected Sheet is persisted with the native account identity.
- [ ] Cancellation, transient failure, and unavailable configuration preserve
      the prior stable workspace state.
- [ ] Restore and choose commands remain serialized; stale Picker results cannot
      overwrite a newer account or selection.
- [ ] Account switch or logout disconnects an incompatible saved Sheet before
      any Google operation.
- [ ] Callers use a small typed choose/restore interface and never handle scope
      lists, OAuth tokens, or platform presentation details.
- [ ] Public workspace and screen tests cover behavior through that interface.

### Blocked by

- Slice 3: Prove one-login Picker behavior on macOS and iOS.
- Explicit owner approval of the live proof.

### User stories covered

- PRD user stories 3-14, 17-18, and 22.

## Slice 5: Move creation and workbook access to per-file authorization

### Type

`AFK`

### What to build

Use the same native `drive.file` account authorization for app-created Sheets
and every workbook read/write path. Prove that created and Picker-selected files
support validation, repair, exercise authoring, placement, history creation,
logging, rereading, and restart without broad Sheets or Drive scopes.

### Acceptance criteria

- [ ] Creating a workout Sheet uses `drive.file` and returns a selected,
      account-bound workbook.
- [ ] A created Sheet remains readable and writable after app restart.
- [ ] Existing Picker-selected Sheets pass schema validation and expose normal
      workout actions.
- [ ] Validation, repair, exercise authoring, placement, history creation, set
      logging, and rereading succeed through the same scoped access owner.
- [ ] No operation silently retries with `spreadsheets`, Drive metadata, full
      Drive, or another account.
- [ ] Permission loss produces a focused reselection/reconnect state rather than
      an authorization loop.
- [ ] The opt-in live flow covers both a selected existing Sheet and an
      app-created Sheet, with fixture cleanup.
- [ ] Sheet-contract and loaded-workbook command behavior remains unchanged.

### Blocked by

- Slice 4: Cut production sheet selection over to Picker.

### User stories covered

- PRD user stories 7, 14-16, 22, and 26.

## Slice 6: Remove the custom chooser and broad authorization

### Type

`AFK`

### What to build

Once all production workbook operations pass under `drive.file`, delete the
custom Drive listing chooser, its search UI, restricted Drive metadata scope,
sensitive Sheets scope, rollback wiring, and obsolete authorization tests and
configuration. Leave one account authority and one Picker selection path.

### Acceptance criteria

- [ ] Production authorization requests only `drive.file` for Google workbook
      access.
- [ ] Drive `files.list` discovery and the custom recent/search chooser are
      removed.
- [ ] Restricted Drive metadata and sensitive all-spreadsheets scope constants
      have no runtime or documentation references.
- [ ] No historical Picker token store, OAuth callback, app-link handler,
      hosted callback, or retired configuration asset is reintroduced.
- [ ] The account menu, choose/create controls, and unavailable states describe
      the single remaining architecture.
- [ ] Tests for deleted implementation details are removed while public
      selection behavior remains covered.
- [ ] Dependency and bundle inspection confirms retired chooser/authorization
      code and assets are absent.

### Blocked by

- Slice 5: Move creation and workbook access to per-file authorization.

### User stories covered

- PRD user stories 22-23 and 26-27.

## Slice 7: Clean tests, documentation, and release bundles

### Type

`AFK`

### What to build

Use the `test-cleanup` skill to remove spike scaffolding and obsolete chooser
tests, then update public build, authorization, support, and privacy guidance to
the proven single-login `drive.file` architecture. Run the complete local, live,
and clean-build gates and inspect bundles for retired assets.

### Acceptance criteria

- [ ] Spike-only flags, debug diagnostics, and temporary dual-path code are
      removed.
- [ ] Tests protect the one-interactive-login invariant, token non-persistence,
      account binding, public Picker result contract, and workbook behavior
      without pinning JavaScript or widget internals.
- [ ] Authorization and build guides describe native login, Picker token
      handoff, builder-owned configuration, and `drive.file` accurately.
- [ ] Android Picker and release readiness are explicitly documented as
      deferred and are not implied by shared Flutter source.
- [ ] Support/privacy resources state the final scope and data handling without
      mentioning retired callbacks or broad access.
- [ ] Formatting, static analysis, and the complete default suite pass.
- [ ] Approved live macOS and physical iOS gates pass and record the absence of
      a second auth prompt.
- [ ] Clean macOS and unsigned iOS release builds pass.
- [ ] Bundle inspection finds no custom chooser, retired callback, stale config,
      broad-scope text, or token-bearing artifact.
- [ ] Final handoff reports commits, commands, devices, visible auth sequence,
      remaining risks, and store-verification work still outside this plan.

### Blocked by

- Slice 6: Remove the custom chooser and broad authorization.

### User stories covered

- PRD user stories 23-30.
- PRD testing and release decisions.
