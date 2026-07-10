# App Store Release Plan

This is the release checklist for selling Workout Tracker through the Apple App
Store. The app is a Flutter application whose durable data store is a
user-owned Google Sheet; it does not operate a Workout Tracker account server
or a separate workout database.

The immediate target is iOS/iPadOS App Store release. The macOS bundle should
continue to build for desktop testing, but iOS/iPadOS device testing and
TestFlight are the release gates.

## Current Project Facts

- App display name: `Workout Tracker`
- iOS bundle identifier: `com.spielman.workouttracker`
- macOS bundle identifier: `com.spielman.workouttracker`
- Flutter version string: from `pubspec.yaml` `version: 1.0.0+1`
- iOS Google client ID:
  `657151291920-5j2u9pdgrn9b99nrk4np4dcnooal2ksk.apps.googleusercontent.com`
- iOS Google URL scheme:
  `com.googleusercontent.apps.657151291920-5j2u9pdgrn9b99nrk4np4dcnooal2ksk`
- Google Sign-In config lives in `ios/Flutter/GoogleSignIn.xcconfig`.
- `ios/Runner/Info.plist` reads `GIDClientID` and URL scheme values from that
  xcconfig.
- The app currently requests writable Google Sheets authorization for normal
  sheet use.
- Native Google Sign-In is the single runtime account authority.
- Existing sheet selection requests Drive metadata access and uses the in-app
  Flutter chooser.
- Firebase project ID: `workouttracker-16285`.
- Configured production support URL, after live Firebase deploy:
  `https://workouttracker-16285.web.app/`.
- Configured production privacy URL, after live Firebase deploy:
  `https://workouttracker-16285.web.app/privacy.html`.
- Firebase Hosting is a static support/privacy surface. It is not a
  Workout Tracker account server and does not store workout data.

Do not change the bundle identifier once App Store Connect, Google OAuth,
TestFlight installs, screenshots, and review notes depend on it.

## Release Sources

Use these official sources when resolving release ambiguity:

- Apple App Review Guidelines:
  <https://developer.apple.com/app-store/review/guidelines/>
- App Store Connect submission overview:
  <https://developer.apple.com/help/app-store-connect/manage-submissions-to-app-review/overview-of-submitting-for-review/>
- App Store Connect app privacy:
  <https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy/>
- Apple third-party SDK privacy manifest requirements:
  <https://developer.apple.com/support/third-party-SDK-requirements/>
- Apple TestFlight external tester workflow:
  <https://developer.apple.com/help/app-store-connect/test-a-beta-version/invite-external-testers/>
- Apple Developer device registration:
  <https://developer.apple.com/help/account/devices/register-a-single-device/>
- Flutter iOS deployment:
  <https://docs.flutter.dev/deployment/ios>
- Google OAuth sensitive scope verification:
  <https://developers.google.com/identity/protocols/oauth2/production-readiness/sensitive-scope-verification>
- Google API Services User Data Policy:
  <https://developers.google.com/terms/api-services-user-data-policy>

## Phase 1: Apple Account And App Identity

1. Enroll in the Apple Developer Program, or confirm the active membership.
2. Confirm access to App Store Connect.
3. Confirm agreements are complete:
   - free app: account agreements are usually enough;
   - paid app: paid apps agreement, tax, and banking must be complete.
4. In Certificates, Identifiers & Profiles, create or confirm the App ID:
   `com.spielman.workouttracker`.
5. Keep capabilities minimal. Do not enable push, iCloud, HealthKit, Sign in
   with Apple, or In-App Purchase unless the app actually uses them.
6. In Xcode, open `ios/Runner.xcworkspace`, select `Runner`, set the Apple
   Developer Team, and confirm automatic signing for Debug, Profile, and
   Release.
7. Build once from Xcode so it resolves signing and provisioning.

## Phase 2: Google Production Configuration

Use a production Google Cloud project before public release. A development
project is acceptable for local testing, but the App Store build should point at
the production OAuth consent screen and production OAuth clients.

1. Enable the Google Sheets API and Google Drive API.
2. Configure the OAuth consent screen:
   - user type: External;
   - app name: `Workout Tracker`;
   - support email: monitored;
   - developer contact email: monitored;
   - app home page: `https://workouttracker-16285.web.app/`;
   - privacy policy URL:
     `https://workouttracker-16285.web.app/privacy.html`;
   - authorized domain: the Firebase Hosting domain accepted by Google for
     those URLs.
3. Add exactly the scopes used by the app. Sheet selection requires Drive
   metadata access, and normal sheet use requires writable Sheets access:

```text
https://www.googleapis.com/auth/drive.metadata.readonly
https://www.googleapis.com/auth/spreadsheets
```

4. Confirm Google Sign-In basic profile scopes are present if Google adds them
   automatically.
5. Create an iOS OAuth client with bundle ID
   `com.spielman.workouttracker`.
6. Create or confirm a macOS OAuth client for
   `com.spielman.workouttracker`.
7. Update `ios/Flutter/GoogleSignIn.xcconfig` and
   `macos/Runner/Configs/AppInfo.xcconfig` if the production clients differ
   from the current development client.
8. Keep secret JSON exports and API keys out of source control. Public mobile
   OAuth client IDs are embedded in app config; client secrets are not app
   secrets in an installed mobile binary.

Google treats sensitive scopes as requiring verification unless an exception
applies. Plan for verification before launch:

1. In Google Cloud Verification Center, declare the Sheets scope.
2. Explain that Workout Tracker reads and writes only the user-selected workout
   spreadsheet.
3. Link the public privacy policy.
4. Provide a demo video showing:
   - Google authorization;
   - selecting or creating a workout sheet;
   - reading workouts from the sheet;
   - writing a set back to the sheet;
   - the updated Google Sheet.
5. Monitor the support and developer contact emails. Google documents that
   sensitive-scope verification can take up to 10 days.

## Phase 3: Public Support And Privacy Pages

Firebase Hosting provides the public pages needed before TestFlight external
testing. Deploy the repo-root Hosting source to the live channel and verify
these URLs return HTTP 200 before entering them in App Store Connect or Google
Cloud:

1. Support/home page:
   `https://workouttracker-16285.web.app/`.
2. Privacy policy page:
   `https://workouttracker-16285.web.app/privacy.html`.
3. Contact method.

The privacy policy must state:

- Workout Tracker uses Google authorization to access the user's selected
  Google Sheet.
- Workout data is stored in the user's Google Sheet.
- The app does not operate a separate workout database for the MVP.
- The app stores local UI state such as selected spreadsheet metadata and
  workout/history selection.
- The app does not use ads or tracking unless that changes.
- Whether analytics or crash reporting are present. If none are present, say
  so explicitly.
- Users can delete workout data by editing/deleting their Google Sheet and can
  revoke Google access from their Google Account.
- Workout Tracker is a logging tool, not medical advice or a diagnostic tool.

Apple App Privacy answers must match the privacy policy and SDK privacy report.
Do not select privacy answers by guesswork.

## Phase 4: Local Code And Packaging Gate

Run these from the repository root before building release candidates:

```bash
flutter pub get
flutter analyze
flutter test
flutter build macos
flutter build ios --release --no-codesign
```

Expected build outputs:

- macOS app:
  `build/macos/Build/Products/Release/Workout Tracker.app`
- iOS no-codesign app bundle:
  `build/ios/iphoneos/Runner.app`

Before uploading to App Store Connect, create a signed archive or IPA:

```bash
flutter build ipa --release --build-name 1.0.0 --build-number 1
```

Flutter writes the archive under `build/ios/archive/` and the IPA under
`build/ios/ipa/`. Flutter documents that `--build-name` maps to
`CFBundleShortVersionString` and `--build-number` maps to `CFBundleVersion`.
Apple will reject reused build numbers for the same app version.

If `flutter build ipa` fails because signing is not ready, fix signing in
Xcode first; do not work around it by changing bundle identifiers.

## Phase 5: iPhone And iPad Development-Mode Testing

Do this before TestFlight. Test both iPhone and iPad because this is a
universal iOS/iPadOS Flutter app. The normal development-device loop should
use release builds. Debug builds are reserved for diagnosing a specific Flutter
or native crash and are not the default validation artifact.

### One-Time Device Setup

1. Install the current full Xcode.
2. Open Xcode once and install requested components.
3. Accept licenses if prompted:

```bash
sudo xcodebuild -license
```

4. Connect the iPhone or iPad by cable.
5. Trust the computer on the device.
6. Enable Developer Mode if prompted by iOS/iPadOS:
   - open Settings on the device;
   - go to Privacy & Security;
   - enable Developer Mode;
   - restart and confirm.
7. In Xcode's Devices and Simulators window, confirm the device is visible.
8. If automatic signing does not register the device, register its UDID in the
   Apple Developer account. Apple documents that registered devices are needed
   for development and ad hoc provisioning profiles, while Xcode automatic
   signing can register connected devices.

### Release Build On Device

For each device:

```bash
flutter devices
flutter run --release -d <device-id>
```

Verify:

- app launches without template text;
- Google Sheets authorization opens;
- selected sheet persists after force-quit and relaunch;
- workout and history selection persists after relaunch;
- creating a new sheet works;
- selecting an existing sheet works;
- adding a workout from the workout dropdown works;
- adding a history block from the history dropdown works;
- opening the exercise manager works;
- creating/editing/reordering canonical exercises works;
- adding a primary workout exercise works;
- adding a backup from an existing primary exercise works;
- reordering exercises within a workout works;
- logging a set writes to the correct visible history block;
- stale-sheet/write-conflict errors are understandable;
- no unexpected browser/login loop appears after the sheet is already
  authorized.

If runtime observability is needed without switching all the way to debug mode,
use profile mode explicitly:

```bash
flutter run --profile -d <device-id>
```

Do not use plain `flutter run -d <device-id>` for release validation; it
defaults to debug mode.

## Phase 6: Live Google Integration Gate

The broad local suite intentionally skips live Google writes. Before a release
candidate, run the live test only when you are ready for it to reset/write the
development sheet:

```bash
WORKOUT_TRACKER_RUN_LIVE_GOOGLE_TESTS=1 flutter test integration_test/live_logging_flow_test.dart
```

Use the development spreadsheet only for this opt-in validation:

```text
https://docs.google.com/spreadsheets/d/1zQrmCYelrNqRMv4WtJcOrtezSxoaVniXzXi4XgKva_E/edit?gid=0#gid=0
```

Do not run this test against a personal production workout sheet.

## Phase 7: Third-Party SDK Privacy Review

Before the first archive upload:

1. Resolve pods by building iOS once:

```bash
flutter build ios --release --no-codesign
```

2. Inspect `ios/Podfile.lock`.
3. Confirm SDKs listed by Apple have privacy manifests/signatures where
   required. This app includes Flutter, Google Sign-In dependencies, and
   `url_launcher`; Apple lists Flutter, GoogleSignIn, and `url_launcher_ios` in
   its commonly used SDK requirement list.
4. In Xcode, archive and inspect the generated privacy report.
5. Make App Privacy answers match the report and privacy policy.

Do not add analytics, crash reporting, ads, or tracking SDKs during release
cleanup unless the privacy policy and App Privacy answers are updated in the
same change.

## Phase 8: TestFlight

1. Build a signed IPA:

```bash
flutter build ipa --release --build-name 1.0.0 --build-number <unique-number>
```

2. Upload using Xcode Organizer, Apple Transporter, or App Store Connect API
   tooling.
3. Wait for processing.
4. Complete export compliance. The app uses standard HTTPS/TLS through Apple
   and Google APIs; do not claim custom cryptography unless that changes.
5. Add internal testers first.
6. Install with TestFlight on your own iPhone and iPad.
7. Run the full device smoke checklist.
8. Add external testers only after internal testing passes.
9. For external testers, provide clear test notes and a demo Google account or
   demo sheet if needed.

Apple documents that external testers can be invited by email or public link
after builds are available and added to a group.

## Phase 9: Apple Review Package

Apple must be able to review the complete app.

Prepare:

1. Demo Google account dedicated to app review.
2. Demo Google Sheet owned by or shared with that account.
3. Realistic sheet data: workouts, exercises, backups, metadata, and history.
4. Review notes explaining why Google authorization is required.
5. Screenshots from the current build on required device sizes.
6. Support URL and privacy URL.
7. App Privacy answers.
8. Age rating.
9. Export compliance answers.
10. Pricing and availability.

Recommended review notes:

```text
Workout Tracker is a gym workout logging app that stores data in a user-owned
Google Sheet.

To review:
1. Launch the app.
2. Connect Google Sheets with the provided Google reviewer account.
3. Select the provided demo sheet, or create a new Workout Tracker sheet.
4. Choose a workout and history block.
5. Open an exercise and log a set.
6. Confirm the set appears in the app and in the Google Sheet.

Google authorization is required only to access the user's selected Google
Sheet. Workout Tracker does not create a separate app account and does not use
a developer-owned workout database.

Demo Google account:
<account>

Demo Google Sheet:
<url>
```

Apple Guideline 4.8 requires an equivalent login option when a third-party
login sets up or authenticates the user's primary app account. Workout Tracker
should be framed as Google Sheets authorization, not app account login, because
Google access is required to reach the user's chosen storage provider. If Apple
requires Sign in with Apple anyway, treat that as a product decision; it cannot
replace Google Sheets authorization.

## Phase 10: Submit For Review

In App Store Connect:

1. Create or open the app record.
2. Select the processed build.
3. Complete App Privacy.
4. Complete age rating.
5. Complete export compliance.
6. Add screenshots and metadata.
7. Add support and privacy URLs.
8. Add review notes and demo credentials.
9. Confirm pricing and availability.
10. Submit for App Review.

Apple documents that app versions and related submission items are reviewed
together when included in the same submission.

After submission:

1. Monitor App Store Connect.
2. Monitor Apple developer email.
3. Monitor Google OAuth verification email.
4. Preserve rejection text exactly.
5. Fix the smallest real issue.
6. Resubmit with clear review notes.

## Final Release Checklist

### Repository

- [ ] Worktree clean except intentional release changes.
- [ ] `flutter analyze` passes.
- [ ] `flutter test` passes.
- [ ] Live Google integration test has been run intentionally or explicitly
  deferred.
- [ ] `flutter build macos` passes.
- [ ] `flutter build ios --release --no-codesign` passes.
- [ ] `flutter build ipa --release` passes before upload.
- [ ] No stale development-only selection docs remain.
- [ ] Production app imports do not expose development reset helpers.

### Apple

- [ ] Apple Developer Program active.
- [ ] App Store Connect accessible.
- [ ] App ID exists for `com.spielman.workouttracker`.
- [ ] iOS Runner target signing works for Release/Profile, with Debug kept only
      for targeted diagnostics.
- [ ] App record exists.
- [ ] Screenshots prepared.
- [ ] App metadata prepared.
- [ ] App Privacy answers complete.
- [ ] Age rating complete.
- [ ] Export compliance complete.
- [ ] Pricing and availability set.

### Google

- [ ] Production Google Cloud project exists.
- [ ] Google Sheets API enabled.
- [ ] OAuth consent screen configured.
- [ ] Public support URL configured.
- [ ] Public privacy URL configured.
- [ ] Authorized domain verified.
- [ ] iOS OAuth client uses final bundle ID.
- [ ] App requests only necessary Google scopes.
- [ ] Sensitive-scope verification submitted or complete.
- [ ] Demo reviewer account and sheet are ready.

### Device Testing

- [ ] iPhone release build tested.
- [ ] iPad release build tested.
- [ ] Profile/debug diagnostics were run only if needed and did not replace
      release-device validation.
- [ ] TestFlight install tested on iPhone.
- [ ] TestFlight install tested on iPad.
- [ ] Clean-device reviewer instructions tested.

### Product

- [ ] UI frames Google as Google Sheets authorization, not a Workout Tracker
  account.
- [ ] Selected sheet persists across relaunch.
- [ ] Workout/history selection persists across relaunch.
- [ ] Existing-sheet selection works.
- [ ] New-sheet creation works.
- [ ] Exercise manager works.
- [ ] Workout exercise add/backup/reorder flows work.
- [ ] Logging writes to the selected Google Sheet.
- [ ] Error states are understandable.
- [ ] No medical claims are made.
