# Single-Login Google Picker Migration PRD

## Problem Statement

The source-MVP custom chooser discovers Google Sheets with broad authorization:
restricted Drive metadata access plus sensitive access to every spreadsheet.
That is a poor fit for an unrestricted store release and gives the application
more access than its per-file logging model needs. Google recommends the
non-sensitive `drive.file` scope together with Google Picker for applications
that work only with user-selected files.

WorkoutTracker has already attempted Picker integration twice. One design
launched a combined browser OAuth/Picker flow after native Google login, asking
the user to authenticate or consent again. Another treated a short-lived Picker
access token as the entire application session, so authorization expired
without a durable native refresh owner. Neither result is acceptable.

The migration has a strict product requirement: the avatar login remains the
only account authentication. After that native login, choosing or changing a
sheet must open Picker directly without another account chooser, credential
request, OAuth consent screen, or independent session. Picker must consume an
access token from the already authenticated native account. This behavior is
not sufficiently guaranteed by documentation and must be proven against real
Google services on physical iOS and macOS before the production chooser is
removed.

## Solution

Develop the Picker migration as an isolated, disposable experiment on a new
`new_picker` branch created from the gym-tested and repaired `main` baseline.

Keep native Google Sign-In as the sole account and token authority. At the
explicit avatar login, authenticate the account and authorize only
`drive.file`. Expose a narrow operation that returns a current access token for
that same account without persisting it. Build a minimal Picker surface that
constructs Google Web Picker with `setOAuthToken` using that token. The surface
must not initialize Google Identity Services, open an OAuth endpoint, request a
token, or transport the token through a URL.

First implement only enough to prove account identity, Picker display,
selection, repeated selection, restart restoration, and refreshed-token
behavior. Validate it live. If Picker displays any second authentication or
consent surface, leaks the token, cannot work reliably on macOS and iOS, or
cannot grant per-file access usable by the Sheets API, stop and discard the
migration branch.

Only after the proof gate passes should production selection, creation,
validation, repair, authoring, and logging move to `drive.file`. Then remove the
custom chooser, broad scopes, Drive listing, retired assets, callbacks, and
obsolete documentation together. Android Picker work remains deferred with the
rest of Android release readiness.

## User Stories

1. As a user, I want to log in from the avatar once, so that account setup is understandable.
2. As a user, I want Picker to use the account I already selected, so that I never enter credentials twice.
3. As a user, I want choosing a sheet to open directly to my files, so that no redundant consent interrupts setup.
4. As a user changing sheets, I want repeated Picker launches without authentication prompts, so that sheet selection remains lightweight.
5. As a returning user, I want my native Google account restored silently, so that restart does not repeat setup.
6. As a returning user, I want a refreshed token obtained silently, so that an expired access token does not force another login.
7. As a user, I want the app to access only Sheets I explicitly choose or create, so that unrelated Drive files remain outside its authority.
8. As a user, I want Picker to show only Google Sheets relevant to the task, so that selection is focused.
9. As a user, I want a cancelled Picker to return safely to the app, so that cancellation never signs me out or changes my current sheet.
10. As a user, I want Picker failures to offer retry without relogin, so that transient display problems do not destroy my session.
11. As a user, I want the selected sheet title shown without exposing its opaque Drive ID, so that the interface remains human-readable.
12. As a user, I want the selected file bound to the native account that chose it, so that another account cannot inherit it silently.
13. As a user switching accounts, I want the old sheet disconnected before the new account chooses a file, so that writes cannot cross accounts.
14. As a user, I want existing selected Sheets to validate and load through per-file access, so that least privilege does not remove functionality.
15. As a user, I want app-created workout Sheets to remain writable after restart, so that creation works under the same narrow scope.
16. As a user, I want logging, repair, exercise authoring, and workout placement to work normally, so that the authorization migration is behavior-neutral.
17. As an iOS user, I want Picker to behave like an in-app file chooser without opening a second sign-in flow.
18. As a macOS tester, I want the same single-login behavior as mobile, so that front-line testing represents the mobile architecture.
19. As a source user, I want Android Picker support marked as deferred, so that this migration does not imply Android release readiness.
20. As the project owner, I want a live go/no-go proof before removing the current chooser, so that another failed Picker attempt does not destabilize the MVP.
21. As the project owner, I want a failed experiment isolated on its own branch, so that the accepted gym baseline remains intact.
22. As a maintainer, I want one module to own account authorization, token renewal, Picker display, selection, and account binding, so that callers cannot accidentally create a second auth flow.
23. As a maintainer, I want OAuth tokens absent from URLs, logs, callbacks, state files, and hosted analytics, so that the Picker surface does not leak credentials.
24. As a source builder, I want Picker App ID and API key configuration supplied through the established local configuration contract, so that forks use their own Google project.
25. As a source builder, I want an actionable configuration error when Picker is unavailable, so that setup failures are diagnosable.
26. As a maintainer, I want broad Drive and Sheets scopes removed after migration, so that verification reflects actual least privilege.
27. As a maintainer, I want the custom Drive listing chooser and its tests deleted after cutover, so that two selection architectures cannot diverge.
28. As a maintainer, I want live validation to distinguish real Google behavior from local interface tests, so that the single-login claim has evidence.
29. As the project owner, I want clean release bundles after cutover, so that retired Picker or chooser assets cannot survive incrementally.
30. As a store-release owner, I want the final privacy and authorization documentation to match `drive.file`, so that review materials are accurate.

## Implementation Decisions

- This work starts only on a new `new_picker` branch created from `main` after
  the current candidate has been gym-tested, repaired, and accepted.
- Native Google Sign-In remains the sole account authority. Picker must not own,
  persist, restore, or refresh a separate account session.
- Authorize only `drive.file` for Google file and Sheets operations. Do not
  combine it with broad `spreadsheets`, Drive metadata, full Drive, OpenID, or
  profile scopes for the Picker flow.
- Account display data continues to come from the native authenticated account,
  not from Picker callbacks or Drive profile reconstruction.
- The native authorization module owns interactive authorization and silent
  token renewal. Callers request a Picker selection or Google operation, not a
  scope list or token.
- Picker receives an already issued access token and constructs its view with
  `setOAuthToken`. It must contain no Google Identity Services token client and
  no OAuth authorization URL.
- Never put an access token in a query string, fragment, deep link, persisted
  state, diagnostic log, crash report, or hosted callback.
- Use the same builder-owned Google Cloud project for the native OAuth client,
  Picker API, API key, and Picker App ID. Restrict the API key as tightly as the
  proven hosting/origin design permits.
- The Picker presentation adapter may vary by platform, but account and
  selection semantics remain behind one deep interface. Platform UI details
  must not leak into workspace callers.
- The initial slice is a proof, not a production replacement. Keep the current
  chooser reachable until the live proof passes.
- The proof must cover first login, first selection, repeated selection,
  cancellation, relaunch, account switch, and token renewal. Tests using fake
  JavaScript callbacks do not satisfy the proof.
- A Picker credential or consent prompt after successful native login is an
  immediate no-go result. Do not rationalize it as a platform quirk.
- A selected file must be readable and writable through the Sheets API using
  the same `drive.file` native authorization before migration proceeds.
- Sheet creation must also use `drive.file`, and the created file must remain
  accessible after restart without broad scopes.
- After cutover, delete custom Drive `files.list` discovery, restricted and
  sensitive scope constants, retired chooser UI, obsolete tests, and stale
  hosted/configuration surfaces in the same migration.
- Preserve saved-sheet account binding, serialized startup, stale-result
  rejection, workbook validation, and the loaded-workbook command gate.
- Do not implement Android Picker presentation or validation in this plan.
  Document it as part of the deferred Android readiness effort.

## Testing Decisions

- Local authorization tests assert that avatar login is the only operation
  permitted to request interactive authorization.
- Local Picker tests assert that the surface receives an existing token and
  emits a selected file or cancellation. They must also prove that no OAuth URL,
  token-client request, or token persistence is produced by application code.
- Public module tests cover account mismatch, stale selection, cancellation,
  retry, unavailable configuration, and token-renewal failure.
- Existing sheet-contract and logging tests remain authoritative for workbook
  behavior under the new scope.
- An opt-in live proof is mandatory on a physical iOS device and macOS. It must
  record every visible Google interaction and explicitly report whether any
  account chooser, credential request, or consent screen appeared after login.
- Token-renewal evidence must use an actually renewed or invalidated token path;
  a fake token timeout is insufficient evidence of Google behavior.
- A live selected Sheet must be read and written, then reset, through the same
  production composition.
- Do not add Android-specific tests or claim Android Picker support.
- Use the `test-cleanup` skill after cutover to delete old chooser tests and
  spike-only scaffolding while retaining the single-auth invariant and public
  selection behavior.
- Final validation includes analysis, the full local suite, opt-in live Google
  gates, and clean macOS and iOS release builds.

## Out of Scope

- Beginning this work before the gym-tested `main` baseline exists.
- Preserving either failed historical Picker authorization architecture.
- Letting Picker replace the native avatar account session.
- Persisting access or refresh tokens in the application state store.
- A server-side OAuth token broker or application data backend.
- Falling back to broad scopes when a `drive.file` operation fails.
- New workout features or sheet-schema changes.
- Store submission itself; this PRD prepares the authorization architecture for
  later submission.
- Claiming the proof passed based only on mocks, widget tests, documentation, or
  a browser already authenticated through an unrelated flow.
- Android Picker implementation, OAuth setup, builds, device testing, or
  release-readiness claims.

## Further Notes

The official desktop/mobile OnePick flow launches OAuth with a required consent
prompt and therefore does not satisfy the product requirement when placed after
native login. The experiment instead composes two documented primitives: a
native, refreshable authorization and Web Picker's ability to accept an
existing OAuth token. Because Google does not explicitly guarantee this native
embedding composition on every target, live proof is the central deliverable,
not a ceremonial final check.

If the proof fails, preserve the accepted `main` branch, document the observed
failure, and stop. Do not continue into production migration slices.
