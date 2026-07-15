# Google Account and Sheet Access

This document describes the current source-MVP implementation. It is not a
store-submission plan.

## Runtime Ownership

Native `google_sign_in` is the only account authority on iOS and macOS. It owns
account restore, explicit login, logout, and token refresh.

While disconnected, sheet choice and creation are disabled; login is available
from the account avatar. Login requests the complete current scope set once.
Later chooser, validation, creation, and write operations may obtain headers
silently but must not open account UI.

The current chooser is Flutter UI backed by Drive `files.list`; it is not
Google Picker. It shows recent or searched Google Sheets, then binds the chosen
file to the active account. A restored selection cannot be used by another
account without explicit confirmation or reselection.

## Current Scopes

```text
https://www.googleapis.com/auth/drive.metadata.readonly
https://www.googleapis.com/auth/spreadsheets
```

Drive metadata supports discovery. Writable Sheets access supports workbook
creation, validation, repair, authoring, and logging. These restricted and
sensitive scopes are acceptable only for the source MVP where each builder
controls their own Google Cloud project; they are not the intended unrestricted
store-release design.

## Builder Configuration

Every builder owns their Google Cloud project, consent screen, quotas, OAuth
clients, and any verification obligations. The project owner's credentials are
not a shared service for forks or source builds.

In Google Cloud Console:

1. Create or select the builder-owned project.
2. Enable both the Google Drive API and Google Sheets API.
3. Configure the OAuth consent screen. While its publishing status is
   **Testing**, add every Google account that will exercise the app as a test
   user. Google limits test-mode access and may expire grants.
4. In Xcode, choose the builder's Apple development team and assign unique iOS
   and macOS bundle identifiers. Do not use the repository owner's team.
5. Create native OAuth clients matching those bundle identifiers. Download
   their configuration only into the local directory below.

The app retains the source-MVP scope set shown above. Because Drive metadata
and writable Sheets access are sensitive or restricted, a builder who changes
the audience or distributes broadly is responsible for Google's consent-screen
publication, verification, and policy requirements.

Real exports and local values belong under:

```text
local_google_credentials/
```

All real exports and generated Apple values there are git-ignored. Start from
its checked-in example file; see
[`local_google_credentials/README.md`](../local_google_credentials/README.md)
for the copy command.

Both iOS and macOS load the builder's bundle ID, Apple team, client ID, and
reversed-client build settings from the ignored
`local_google_credentials/AppleBuild.xcconfig`. Their tracked `Info.plist`
files expose the client settings directly to the sign-in SDK. Normal Apple
builds and runs need no credential command-line arguments.

Optional `WORKOUT_TRACKER_GOOGLE_CLIENT_ID` and
`WORKOUT_TRACKER_GOOGLE_SERVER_CLIENT_ID` Dart defines remain available for a
platform or diagnostic run that cannot use native configuration. When omitted,
the app deliberately passes no override and lets the Apple SDK read
`Info.plist`. When supplied, malformed IDs are rejected without printing their
values.

## Apple Builder Setup

For iOS, open `ios/Runner.xcworkspace` in Xcode, select the Runner target, and
set the builder's team and unique bundle identifier. Create the matching iOS
OAuth client, copy its client and reversed client IDs into the local xcconfig,
and use a physical device for release-facing login validation. An unsigned
build establishes compilation only; installation and native login require a
valid signing identity and provisioning profile.

For macOS, open `macos/Runner.xcworkspace`, set the builder's team and unique
bundle identifier, and create the matching native OAuth client. Release builds
retain the App Sandbox network-client entitlement and Google Sign-In keychain
access group. A signed bundle is required to validate stable keychain and
native login behavior outside a debug session. The compile-only unsigned build
in `BUILDING.md` does not prove authentication.

OAuth client IDs embedded in an installed app are identifiers, not confidential
client secrets. Exported credentials, API keys, and builder-specific generated
configuration must still remain out of source control.

Firebase Hosting serves only the checked-in support and privacy pages. It is
not an authentication or workout-data backend.

## Platform Status

- macOS: configured development and release-build target; signing is required
  for reliable native Google Sign-In and keychain behavior.
- iOS: configured mobile target; use a physical device for release-facing
  authentication validation.
- Android: not release-ready. Release networking and network permission,
  package and signing identity, OAuth client configuration, SDK/toolchain
  build validation, and physical-device authentication testing are all
  deferred as one future effort. Generated Flutter scaffolding is not evidence
  of Android support.
- Linux and Windows: not configured for Google account access.

Build commands are in [`BUILDING.md`](../BUILDING.md). Real Google validation is
opt-in and documented in [`docs/testing.md`](testing.md).

## Expected Manual Flow

1. Open the avatar menu and log in once.
2. Choose or create a workout Sheet without another login prompt.
3. Validate and use the workbook.
4. Restart and confirm the account and account-bound selection restore.
5. Log out and confirm the saved Google workspace selection is cleared.
