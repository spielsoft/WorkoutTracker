# iOS App Store Release Plan

This document is the human release plan for shipping WorkoutTracker on the
Apple App Store for iOS. It assumes the app remains a Flutter/Dart app whose
durable data artifact is a user-owned Google Sheet.

The goal is not just to upload a build. The goal is to make the app acceptable
to Apple review, acceptable to Google's OAuth verification process, and
straightforward to test on a simulator, on a real iPhone, in TestFlight, and in
production.

## Current Project Facts

These are the important iOS facts currently visible in this repository:

- App display name: `Workout Tracker`
- iOS bundle identifier: `com.spielman.workouttracker`
- iOS minimum deployment target: `13.0`
- Flutter package version: `1.0.0+1`
- Google Sign-In is configured through `ios/Flutter/GoogleSignIn.xcconfig`.
- `ios/Runner/Info.plist` already references:
  - `GIDClientID = $(WORKOUT_TRACKER_GOOGLE_CLIENT_ID)`
  - URL scheme `$(WORKOUT_TRACKER_GOOGLE_REVERSED_CLIENT_ID)`
- The project currently uses the `google_sign_in`, `googleapis`, and `http`
  packages.

Before submission, confirm whether `com.spielman.workouttracker` is the final
bundle identifier. It is expensive to change identity after App Store Connect,
Google OAuth, screenshots, review notes, and installed TestFlight builds are
all tied to it.

## Release Dependencies

You will need:

- A Mac with the current full Xcode installed from Apple.
- A current Flutter SDK that passes `flutter doctor -v` for iOS.
- An Apple Account with two-factor authentication enabled.
- Apple Developer Program membership.
- Access to App Store Connect.
- A Google Cloud project for the production app.
- A public support page and privacy policy page.
- A real iPhone for final device testing.
- A dedicated Google reviewer/test account and a demo Google Sheet for Apple
  review.

## Phase 1: Enroll With Apple

1. Create or choose the Apple Account that will own the app.
2. Enable two-factor authentication for that Apple Account.
3. Enroll in the Apple Developer Program.
4. Choose the enrollment type:
   - Individual if you are publishing personally.
   - Organization if you want a company seller name. Organization enrollment
     requires a legal entity and a D-U-N-S Number.
5. Complete payment and agreements.
6. Confirm that you can access:
   - Apple Developer account
   - Certificates, Identifiers & Profiles
   - App Store Connect

Apple currently documents the annual Apple Developer Program membership as
99 USD per membership year, with regional variation.

Official references:

- [Apple Developer Program enrollment](https://developer.apple.com/programs/enroll/)
- [App Store Connect](https://appstoreconnect.apple.com/)

## Phase 2: Create the Apple App Identity

In Certificates, Identifiers & Profiles:

1. Create or confirm an App ID for `com.spielman.workouttracker`.
2. Keep capabilities minimal.
3. Do not enable capabilities just in case.
4. If Apple later determines Sign in with Apple is required, add that
   capability deliberately as a follow-up release task.

In Xcode:

1. Open `ios/Runner.xcworkspace`, not `ios/Runner.xcodeproj`.
2. Select the `Runner` target.
3. Set the Team to your Apple Developer Program team.
4. Confirm the bundle identifier is `com.spielman.workouttracker`.
5. Confirm automatic signing works for Debug and Release.
6. Build once from Xcode to let it resolve signing and provisioning.

The macOS project already has a development team configured, but the iOS
project should be checked separately.

## Phase 3: Decide App Store Metadata

Prepare this before the first upload:

- App name: likely `Workout Tracker`, unless that is unavailable.
- Subtitle: concise, not keyword-stuffed.
- SKU: any stable internal identifier, for example `workout-tracker-ios`.
- Primary category: likely `Health & Fitness`.
- Secondary category: optional. Consider `Productivity` only if it fits.
- Age rating: answer honestly. This app should not be in the Kids category.
- Price: free unless a monetization plan exists.
- Countries/regions: choose intended launch regions.
- Support URL: public page with a contact method.
- Privacy Policy URL: public page on the same domain used for Google OAuth
  verification if possible.
- Marketing URL: optional.
- App description: explain that WorkoutTracker logs gym workouts into the
  user's own Google Sheet.
- Keywords: simple and accurate. Do not include competitor names or unrelated
  terms.
- Screenshots: show the app in use, not only the sign-in screen.

Apple review guidance specifically calls out complete metadata, testing for
crashes, full reviewer access, accurate screenshots, and detailed review notes.

Official references:

- [Add a new app record](https://developer.apple.com/help/app-store-connect/create-an-app-record/add-a-new-app)
- [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)

## Phase 4: Prepare Privacy, Support, and Review Pages

Create a small public website or GitHub Pages site with at least:

1. A home/support page.
2. A privacy policy.
3. A contact method.

The privacy policy must say, in plain language:

- The app lets the user connect a Google account to read and write a selected
  Google Sheet.
- Workout data is stored in the user's Google Sheet.
- The developer does not operate a separate workout database for the MVP unless
  that changes later.
- Google account identity, OAuth tokens, and permissions are handled through
  Google Sign-In / Google authorization mechanisms.
- What, if anything, is stored locally on the device, such as the selected
  spreadsheet identifier or cached UI state.
- How the user can disconnect Google access.
- How the user can delete their data, which for the MVP means deleting rows or
  sheets from their own Google Sheet and revoking app access from their Google
  Account.
- Whether analytics, crash reporting, ads, tracking, or third-party SDKs are
  used. If none are used, say so clearly.
- That the app is a workout logging tool, not a medical diagnostic tool.

For Apple App Privacy:

- Be conservative and accurate.
- Do not claim "data not collected" if the app sends workout content through a
  developer-controlled server. The MVP should avoid any developer-controlled
  server.
- If the app only talks directly to Google APIs and stores data in the user's
  Google Sheet, describe that carefully in the privacy policy and App Store
  review notes.
- Do not use tracking unless there is a deliberate privacy and product decision
  to do so. There is no current product reason to track users.

For Google OAuth:

- The privacy policy URL must be listed in the OAuth client configuration when
  the app is public.
- The OAuth consent screen and privacy policy must accurately describe the
  Google user data accessed, used, stored, and shared.

Official references:

- [Apple App Review privacy guidelines](https://developer.apple.com/app-store/review/guidelines/)
- [Google API Services User Data Policy](https://developers.google.com/terms/api-services-user-data-policy)

## Phase 4.5: Audit Third-Party SDK Privacy Requirements

Apple requires privacy manifests for listed commonly used third-party SDKs when
submitting new apps or app updates that include those SDKs. Google also notes
that apps using GoogleSignIn-iOS should use a version that includes the required
privacy manifest support.

Before the first TestFlight upload:

1. Run dependency inspection:

```bash
flutter pub deps
```

2. Build the iOS app once so CocoaPods resolves native dependencies:

```bash
flutter build ios --release --no-codesign
```

3. Inspect `ios/Podfile.lock` after the build and confirm which native Google
   Sign-In packages are included.
4. Confirm the resolved GoogleSignIn-iOS dependency is new enough for Apple's
   privacy manifest requirements.
5. Review whether any other listed SDKs are present.
6. Keep the App Store privacy answers consistent with the SDK privacy report
   Xcode generates during archive/export.

Do not add analytics, crash reporting, ads, or tracking SDKs during release
cleanup unless there is an explicit product decision and the privacy policy,
App Store privacy answers, and Google OAuth disclosures are updated at the same
time.

Official references:

- [Apple third-party SDK requirements](https://developer.apple.com/support/third-party-SDK-requirements/)
- [Google Sign-In for iOS and macOS](https://developers.google.com/identity/sign-in/ios/start-integrating)

## Phase 5: Register the App With Google

This app needs Google authorization because it writes to a user-owned Google
Sheet. That means it needs a production Google Cloud setup before App Store
release.

### Create the Production Google Cloud Project

1. Go to Google Cloud Console.
2. Create a production project, for example `WorkoutTracker Production`.
3. Enable the Google Sheets API.
4. Configure the OAuth consent screen:
   - User type: External for a public App Store app.
   - App name: same as the App Store name.
   - User support email: one you monitor.
   - Developer contact email: one you monitor.
   - App home page: public page for WorkoutTracker.
   - Privacy policy URL: public privacy policy.
   - Authorized domains: the domain hosting the home and privacy pages.
5. Add the exact scopes the app requests.

### Scope Choice

The current product needs read/write access to a user-selected sheet. The
obvious Sheets scope is:

```text
https://www.googleapis.com/auth/spreadsheets
```

Google classifies this as sensitive. Public apps using sensitive scopes usually
need OAuth verification to remove the unverified-app warning.

Also evaluate whether this app can use:

```text
https://www.googleapis.com/auth/drive.file
```

Google lists `drive.file` as recommended and non-sensitive for per-file access.
However, this may require a Google Picker or a flow where the file is created or
opened through the app. It may not fit the current user-provided spreadsheet ID
model. Do not switch scopes casually. If the app keeps the current model, plan
on sensitive-scope verification for `spreadsheets`.

Official reference:

- [Google Sheets API scopes](https://developers.google.com/workspace/sheets/api/scopes)

### Create the iOS OAuth Client

1. In Google Cloud Console, create an OAuth client ID.
2. Application type: iOS.
3. Bundle ID: `com.spielman.workouttracker`, unless the final bundle ID changes.
4. Save the client ID and iOS URL scheme.
5. Update `ios/Flutter/GoogleSignIn.xcconfig`:

```xcconfig
WORKOUT_TRACKER_GOOGLE_CLIENT_ID = <ios-client-id>.apps.googleusercontent.com
WORKOUT_TRACKER_GOOGLE_REVERSED_CLIENT_ID = com.googleusercontent.apps.<reversed-id>
```

Do not commit private files or credentials that are not meant to be public. An
iOS OAuth client ID is normally embedded in the app, but keep the release
configuration intentional and documented.

The current `Info.plist` already uses the correct shape for Google Sign-In:
`GIDClientID` plus a custom URL scheme based on the reversed client ID.

Official references:

- [Google Sign-In for iOS and macOS](https://developers.google.com/identity/sign-in/ios/start-integrating)
- [google_sign_in package](https://pub.dev/packages/google_sign_in)

### Complete Google OAuth Verification

For production release:

1. Confirm the production OAuth consent screen is accurate.
2. Verify ownership of the authorized domain.
3. Declare all requested scopes.
4. Write a justification for each sensitive scope.
5. Record an unlisted YouTube demo video showing:
   - Google sign-in / consent.
   - The app name on the consent screen.
   - The requested Sheets permission.
   - Selecting a sheet.
   - Reading workouts from the sheet.
   - Writing workout log data back to the sheet.
6. Submit through Google's Verification Center.
7. Monitor the support and developer contact inboxes.

Google currently says sensitive-scope verification can take up to 10 days.
Build that delay into the launch plan.

Official reference:

- [Google sensitive scope verification](https://developers.google.com/identity/protocols/oauth2/production-readiness/sensitive-scope-verification)

## Phase 6: Check Sign in With Apple Risk

Apple Guideline 4.8 can require Sign in with Apple when an app uses a
third-party or social login service as the primary way to set up or
authenticate an account.

WorkoutTracker should avoid presenting Google as an app account login. The
product framing should be:

- "Connect Google Sheets"
- "Choose the Google Sheet that stores your workouts"
- "Authorize access so WorkoutTracker can read and write that sheet"

That framing is accurate because the app does not have an app-owned backend
account. Google is needed to access the user's chosen storage provider.

In App Review notes, explain:

```text
WorkoutTracker does not create or authenticate a WorkoutTracker account. Google
authorization is required only so the app can access the user's selected Google
Sheet, which is the user-owned data store for workout logging. The app has no
separate server-side workout database.
```

If Apple still requires Sign in with Apple, treat it as a follow-up product
decision. Sign in with Apple cannot replace Google Sheets authorization; at
most it can identify the user to a future WorkoutTracker account system.

Official reference:

- [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)

## Phase 7: Local iOS Testing

### One-Time Local Setup

1. Install the full current Xcode.
2. Open Xcode once and install requested components.
3. Accept licenses if prompted.
4. Install or update Flutter.
5. From the repository root, run:

```bash
flutter doctor -v
flutter pub get
```

Resolve all iOS-related Flutter doctor issues before continuing.

### Simulator Test

1. Start a simulator from Xcode or with:

```bash
open -a Simulator
```

2. List devices:

```bash
flutter devices
```

3. Run the app:

```bash
flutter run -d <simulator-id>
```

4. Verify:
   - App launches.
   - Google authorization flow opens.
   - The configured development sheet can be read.
   - Workouts and exercise rows render.
   - Logging writes to the expected columns.
   - Error states are readable.

Simulator testing is useful, but do not rely on it as final validation for
Google Sign-In, keychain behavior, or app review readiness.

### Real iPhone Test

1. Connect the iPhone by cable.
2. Trust the computer on the phone.
3. Enable Developer Mode on the iPhone if iOS requires it.
4. Confirm Xcode sees the device.
5. Confirm the Runner target uses your Apple developer team.
6. Run:

```bash
flutter devices
flutter run -d <device-id>
```

7. Verify the full gym logging flow on the physical device.

For a release candidate, also test a release build on the device:

```bash
flutter run --release -d <device-id>
```

Official reference:

- [Flutter iOS deployment](https://docs.flutter.dev/deployment/ios)

## Phase 8: App Store Build and Upload

Before every release upload:

1. Confirm the worktree is clean or intentionally dirty only with release
   changes.
2. Update `pubspec.yaml` version and build number.
3. Use a unique build number for every upload. Apple will not accept a reused
   build number for the same version.
4. Run local validation:

```bash
flutter test
flutter analyze
```

5. Build the iOS archive and IPA:

```bash
flutter build ipa --release --build-name 1.0.0 --build-number 1
```

Flutter writes the archive under `build/ios/archive/` and the IPA under
`build/ios/ipa/`.

6. Upload with one of:
   - Xcode Organizer
   - Apple Transporter
   - App Store Connect API tooling

The most human-friendly path for the first release is:

1. Run `flutter build ipa --release`.
2. Open the generated `.xcarchive` in Xcode.
3. Validate the app.
4. Distribute to App Store Connect.

Official reference:

- [Flutter build and release an iOS app](https://docs.flutter.dev/deployment/ios)

## Phase 9: TestFlight

After upload:

1. Wait for App Store Connect processing.
2. Complete missing compliance questions.
3. Answer export compliance accurately.
   - The app uses HTTPS/TLS through standard platform and Google APIs.
   - It should not claim custom cryptography unless that changes.
4. Add internal testers first.
5. Install from TestFlight on your own iPhone.
6. Run the full logging flow against a test sheet.
7. Add external testers if needed.
8. For external testers, provide beta review notes and a demo account/sheet if
   the reviewer cannot otherwise access the app.

TestFlight is the right place for beta builds. Do not submit a beta-quality app
as a public App Store release.

Official references:

- [Invite external testers](https://developer.apple.com/help/app-store-connect/test-a-beta-version/invite-external-testers)
- [App Review Guidelines, beta testing](https://developer.apple.com/app-store/review/guidelines/)

## Phase 10: Prepare Apple Review Access

Apple must be able to review the whole app.

Prepare:

1. A dedicated Google account for App Review.
2. A demo Google Sheet owned by or shared with that account.
3. The sheet formatted with realistic upper and lower workouts, exercises,
   backups, metadata, and history.
4. A short review-note script.

Recommended review notes:

```text
WorkoutTracker is a gym workout logging app that stores data in a user-owned
Google Sheet.

To review:
1. Launch the app.
2. Tap Connect Google Sheets.
3. Sign in with the provided Google reviewer account.
4. Select or enter the provided demo sheet.
5. Choose a workout.
6. Open an exercise and log a set.
7. Confirm the set appears in the app and in the Google Sheet.

Google authorization is required only to access the user's selected Google
Sheet. WorkoutTracker does not create a separate app account and does not use a
developer-owned workout database.

Demo Google account:
<account>

Demo Google Sheet:
<url>
```

Before submission, test those exact credentials and instructions on a device
that is not already signed in as you.

If the app cannot provide reviewer credentials for legal or operational reasons,
build a fully featured demo mode and ask Apple in review notes to use it. A demo
mode is more engineering work, but it is sometimes easier than maintaining a
third-party account for review.

Official reference:

- [App Review Guidelines, Before You Submit](https://developer.apple.com/app-store/review/guidelines/)

## Phase 11: Final App Store Submission

In App Store Connect:

1. Select the processed build.
2. Complete App Privacy.
3. Complete age rating.
4. Complete export compliance.
5. Add screenshots.
6. Add description, subtitle, keywords, support URL, and privacy URL.
7. Add review notes and demo credentials.
8. Confirm pricing and availability.
9. Submit for review.

After submission:

1. Monitor App Store Connect messages.
2. Monitor the Apple developer contact email.
3. Monitor the Google OAuth support/developer emails.
4. Respond quickly to review questions.
5. If rejected, preserve the rejection text internally, diagnose the smallest
   fix, and resubmit with clear notes.

Official reference:

- [Overview of submitting for review](https://developer.apple.com/help/app-store-connect/manage-submissions-to-app-review/overview-of-submitting-for-review)

## Release Readiness Checklist

Use this as the final gate before App Store submission.

### Apple Account

- [ ] Apple Developer Program enrollment complete.
- [ ] App Store Connect accessible.
- [ ] Paid Applications agreement handled if needed.
- [ ] Tax/banking handled if the app is paid or has paid features.

### App Identity

- [ ] Final app name chosen.
- [ ] Final bundle id chosen.
- [ ] App ID exists in Apple developer portal.
- [ ] iOS Runner target has correct signing team.
- [ ] Release signing works.

### Google

- [ ] Production Google Cloud project exists.
- [ ] Google Sheets API enabled.
- [ ] OAuth consent screen configured as External.
- [ ] Public support page exists.
- [ ] Public privacy policy exists.
- [ ] Authorized domain verified.
- [ ] iOS OAuth client uses final bundle id.
- [ ] `GoogleSignIn.xcconfig` uses production client values.
- [ ] Requested scopes are minimal.
- [ ] Sensitive-scope verification submitted or complete.
- [ ] No unverified-app warning remains for normal users, or launch is delayed.

### Product

- [ ] App copy says "Connect Google Sheets" rather than implying a
  WorkoutTracker account.
- [ ] App has a disconnect/revoke-access path or clear instructions.
- [ ] App handles missing/broken sheet setup gracefully.
- [ ] App does not make medical claims.
- [ ] App does not include placeholder Flutter text or template metadata.
- [ ] `pubspec.yaml` description is no longer "A new Flutter project."

### Validation

- [ ] `flutter test` passes.
- [ ] `flutter analyze` passes.
- [ ] Simulator smoke test passes.
- [ ] Physical iPhone debug test passes.
- [ ] Physical iPhone release test passes.
- [ ] TestFlight install passes.
- [ ] TestFlight full logging flow passes.
- [ ] Demo reviewer account and sheet work from a clean device.

### App Store Connect

- [ ] App record created.
- [ ] App privacy answers complete.
- [ ] Age rating complete.
- [ ] Export compliance complete.
- [ ] Screenshots uploaded.
- [ ] Description and metadata complete.
- [ ] Support URL works.
- [ ] Privacy Policy URL works.
- [ ] Review notes include Google Sheet rationale and reviewer steps.
- [ ] Build selected.
- [ ] Submitted for review.

## Agent Prompts

Use these prompts when asking agents to prepare release work. Do not ask agents
to handle private Apple or Google account actions directly unless you are
present for the login step.

### 1. App Store Readiness Audit

```text
You are working in the WorkoutTracker repository.

Read AGENTS.md, APP_STORE.md, and PROMPTS.md first. Do not rely on deleted issue
plans. Audit the repository for iOS App Store readiness.

Check the Flutter iOS project, bundle identifiers, display name, versioning,
Google Sign-In configuration, privacy-sensitive dependencies, app metadata
placeholders, tests, and release build path. Do not modify files.

Report findings ordered by release risk. Include exact file references and a
short recommended fix for each finding. Pay special attention to anything that
could cause App Review rejection, Google OAuth warnings, failed signing, or a
broken reviewer flow.
```

### 2. iOS Signing and Build Configuration Cleanup

```text
You are working in the WorkoutTracker repository.

Read AGENTS.md and APP_STORE.md first. Prepare the iOS Flutter project for App
Store build configuration without committing secrets.

Use TDD or the smallest available validation for code changes. Preserve
unrelated worktree changes. Keep edits scoped to iOS release configuration,
version metadata, app display metadata, and documentation needed for repeatable
builds.

Do not create or modify Apple certificates manually. Do not invent team IDs or
bundle IDs. If a human must choose a signing team in Xcode, stop and report the
exact action needed.

At the end, report changed files, validation commands run, and any required
human App Store Connect or Xcode actions.
```

### 3. Google OAuth Production Audit

```text
You are working in the WorkoutTracker repository.

Read AGENTS.md and APP_STORE.md first. Audit the Google OAuth and Google Sheets
integration for production iOS release.

Check requested scopes, Google Sign-In iOS configuration, Info.plist URL scheme
configuration, user-facing auth wording, disconnect behavior, and any docs that
must be updated for OAuth verification.

Do not commit private credentials. Do not log into Google unless the human is
present and explicitly asks you to continue. If Google Cloud Console work is
needed, produce a precise human checklist instead of guessing.

At the end, report release blockers, recommended scope strategy, and the exact
OAuth verification evidence the human must prepare.
```

### 4. Privacy Policy and Review Notes Draft

```text
You are working in the WorkoutTracker repository.

Read AGENTS.md and APP_STORE.md first. Draft the human-facing privacy policy,
support-page copy, App Store description, and App Review notes for the iOS
release.

The copy must accurately reflect the MVP: workout data is stored in a
user-owned Google Sheet; the app does not operate a separate workout database;
Google authorization is used to read and write the selected sheet; the app is a
logging tool and not a medical device.

Do not overclaim privacy. Clearly identify any uncertainty that needs human
confirmation, such as analytics, crash reporting, or support email address.
```

### 5. TestFlight Release Candidate Validation

```text
You are working in the WorkoutTracker repository.

Read AGENTS.md and APP_STORE.md first. Validate the current iOS release
candidate for TestFlight.

Run the local test and analysis commands, then attempt the iOS release build
using the standard Flutter path. If signing, Apple login, or device trust
requires human interaction, stop at the smallest necessary HITL point and state
exactly what action is needed.

After a build is uploaded by the human, use the app on a physical iPhone through
TestFlight and verify the full Google Sheet logging flow if the human provides
access. Do not mark the candidate ready unless the reviewer demo flow has been
tested from a clean account/device path.
```

### 6. Final Submission Gate

```text
You are working in the WorkoutTracker repository.

Read AGENTS.md and APP_STORE.md first. Perform the final pre-submission gate for
the iOS App Store release.

Confirm the release checklist in APP_STORE.md using repository evidence where
possible. For account-console items that cannot be checked from the repository,
produce a human checklist and mark them as requiring human confirmation.

Do not submit the app yourself unless explicitly asked and the human is present
for account access. Report blockers first, then residual risks, then the exact
next human actions.
```

## Known Release Risks

- Google OAuth verification may take days and can block a clean public launch.
- The `spreadsheets` scope is sensitive. If a narrower flow using `drive.file`
  is feasible later, it may reduce verification friction, but it changes the
  product flow and should be designed deliberately.
- Apple may question Google sign-in unless the app clearly frames it as Google
  Sheets authorization rather than app account authentication.
- Apple review needs full access. A reviewer Google account and demo sheet must
  be maintained and tested.
- Privacy answers must be consistent across the app, App Store Connect, Google
  OAuth consent screen, privacy policy, and review notes.
- Template Flutter metadata, generic icons, or placeholder screenshots can
  cause a low-quality review outcome even if the binary works.

## Source Links

- [Apple Developer Program enrollment](https://developer.apple.com/programs/enroll/)
- [App Store Connect: Add a new app](https://developer.apple.com/help/app-store-connect/create-an-app-record/add-a-new-app)
- [App Store Connect: Submit for review](https://developer.apple.com/help/app-store-connect/manage-submissions-to-app-review/overview-of-submitting-for-review)
- [Apple App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- [Apple third-party SDK requirements](https://developer.apple.com/support/third-party-SDK-requirements/)
- [Flutter iOS deployment](https://docs.flutter.dev/deployment/ios)
- [Google Sign-In for iOS and macOS](https://developers.google.com/identity/sign-in/ios/start-integrating)
- [Google Sheets API scopes](https://developers.google.com/workspace/sheets/api/scopes)
- [Google sensitive scope verification](https://developers.google.com/identity/protocols/oauth2/production-readiness/sensitive-scope-verification)
- [Google API Services User Data Policy](https://developers.google.com/terms/api-services-user-data-policy)
