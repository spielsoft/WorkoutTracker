# Dependency Review

Dependency changes are accepted when an upstream release contains a compatible
security, crash, or correctness fix that matters to this application. A newer
version number alone is not a reason to update, and major upgrades require a
separate compatibility review.

## Source-MVP Review

The source-MVP dependency review was performed on 2026-07-11. Direct Dart
packages were checked against their installed upstream `CHANGELOG.md` and
package metadata. Apple implementations were checked against the resolved
Swift package graph and upstream release notes.

| Dependency | Resolved version | Review result |
| --- | --- | --- |
| `googleapis` | 16.0.0 | Current installed release; its changes are generated API coverage rather than an applicable workout-flow fix. |
| `http` | 1.6.0 | Retained. It includes the JSON decoding, completed-response cancellation, and web stream-cancellation corrections from 1.4.0-1.6.0. |
| `google_sign_in` | 7.2.0 | Retained. The application already uses the current 7.x authentication/authorization API and structured errors. |
| `path_provider` | 2.1.6 | Retained. The lockfile already selects the current compatible Apple implementation used by application-support persistence. |
| `url_launcher` | 6.3.2 | Retained. It includes the current launch-mode correctness fix; no newer compatible installed fix was identified. |

## Direct Dependency Additions

`clock` was promoted from transitive to `direct main` on 2026-08-29 for the
shared exercise countdown, which measures an exact deadline and must be
fakeable under `flutter_test`. No new code ships as a result: the resolved
graph already contained `clock` 1.1.2 through `package_info_plus`, and the
promotion only records a package the application now references directly, as
`depend_on_referenced_packages` requires. It is a pure-Dart Dart-team package
with no platform implementation, so the Apple graph is unchanged.

The resolved Apple graph is identical for iOS and macOS. Its important sign-in
pins are `GoogleSignIn-iOS` 9.2.0 and `AppAuth-iOS` 2.1.0, with
`GTMAppAuth` 5.0.0 and `GTMSessionFetcher` 3.5.0. The Flutter
`google_sign_in_ios` 6.3.0 implementation also contains the earlier fixes that
turn configuration failures into Dart exceptions instead of native crashes,
return newly granted authorization tokens correctly, and support UIScene.
AppAuth 2.1.0 removes an unsafe external-browser fallback and reports invalid
authorization-flow URLs as errors. No manual Swift pin was changed because the
Flutter plugin owns the compatible version range and the checked-in
`Package.resolved` files already capture the selected graph.

`flutter pub outdated` reported all direct and development dependencies as
current. It also reported one resolvable transitive update,
`google_sign_in_android` 7.2.13 to 7.2.15. That Android-only implementation is
not adopted in this source-MVP slice because Android runtime and build
validation are explicitly deferred; changing its lock would not establish
Android correctness or benefit the prepared Apple targets.

Authoritative upstream records:

- [Dart HTTP changelog](https://github.com/dart-lang/http/blob/master/pkgs/http/CHANGELOG.md)
- [Flutter Google Sign-In changelog](https://github.com/flutter/packages/blob/main/packages/google_sign_in/google_sign_in/CHANGELOG.md)
- [Flutter Google Sign-In Apple changelog](https://github.com/flutter/packages/blob/main/packages/google_sign_in/google_sign_in_ios/CHANGELOG.md)
- [Flutter path provider changelog](https://github.com/flutter/packages/blob/main/packages/path_provider/path_provider/CHANGELOG.md)
- [Flutter URL launcher changelog](https://github.com/flutter/packages/blob/main/packages/url_launcher/url_launcher/CHANGELOG.md)
- [Google Sign-In for Apple changelog](https://github.com/google/GoogleSignIn-iOS/blob/main/CHANGELOG.md)
- [AppAuth for iOS and macOS changelog](https://github.com/openid/AppAuth-iOS/blob/master/CHANGELOG.md)

Run `flutter pub outdated` during each review, inspect the changelogs for every
direct update and important platform implementation, and run the complete
default suite after changing the lockfile. Apple graph changes also require the
clean local builds in `BUILDING.md`. Do not infer Google or OAuth correctness
from package tests or local fakes.
