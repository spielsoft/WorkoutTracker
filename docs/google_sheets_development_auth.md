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

Create a Google Cloud project, enable the Drive and Sheets APIs, configure its
OAuth consent screen, and create native OAuth clients matching the builder's
bundle identifiers and signing identities.

Real exports and local values belong under:

```text
local_google_credentials/
```

JSON files there are git-ignored. See
`local_google_credentials/README.md` for the current filenames. Native Dart
configuration recognizes:

```text
WORKOUT_TRACKER_GOOGLE_CLIENT_ID
WORKOUT_TRACKER_GOOGLE_SERVER_CLIENT_ID
```

iOS reads its client and reversed client values through
`ios/Flutter/GoogleSignIn.xcconfig`. macOS reads the corresponding values from
`macos/Runner/Configs/AppInfo.xcconfig`; both platform `Info.plist` files expose
them to the sign-in plugin.

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
- Android: not ready. Network permission, package/signing identity, OAuth
  configuration, SDK build, and physical-device validation are deferred.
- Linux and Windows: not configured for Google account access.

Build commands are in [`COMPILE.md`](../COMPILE.md). Real Google validation is
opt-in and documented in [`docs/testing.md`](testing.md).

## Expected Manual Flow

1. Open the avatar menu and log in once.
2. Choose or create a workout Sheet without another login prompt.
3. Validate and use the workbook.
4. Restart and confirm the account and account-bound selection restore.
5. Log out and confirm the saved Google workspace selection is cleared.
