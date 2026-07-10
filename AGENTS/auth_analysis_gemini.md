# Authentication Analysis: WorkoutTracker (Updated for Single-Login Constraint)

## Summary

The app uses a Web-based Google Drive Picker (`trigger_onepick`) via `launchUrl` to handle both authentication and file selection in one step. Because it uses the OAuth2 **implicit grant** (`response_type=token`), it receives a short-lived (1-hour) access token with **no refresh capability**. 

You explicitly noted a critical constraint: **Users must not have to log in twice** (once for native auth, once for the picker). Because native sign-in often uses a secure sandbox (like `ASWebAuthenticationSession` on iOS/macOS) while `launchUrl` uses the system browser, their cookie states don't sync. This makes it impossible to securely pass a native sign-in session to the URL-based picker.

---

## The Root Cause of the 1-Hour Limit

The picker path uses `response_type=token` (implicit grant). This flow **never issues a refresh token**. 

[selection.dart#L368](file:///Users/ispielma/Code/Apps/WorkoutTracker/lib/src/app/selection.dart#L368)
```dart
'response_type': 'token',
```

The app persists this raw 1-hour access token to `state.json` on disk. When the app is restarted within an hour, it works. After an hour, the token expires, the next Google Sheets API call fails with a 401 Unauthorized, and the app throws an error instead of renewing the session (because it can't).

---

## Why Native Sign-In + URL Picker = Double Login

You observed that if you use `google_sign_in` first, the Picker still asks the user to log in again. This happens because:
1. `google_sign_in` uses platform-native secure credential stores (e.g., iOS `ASWebAuthenticationSession` or Android Account Manager).
2. The Picker uses `launchUrl(..., mode: LaunchMode.externalApplication)` which opens Safari/Chrome.
3. The secure session from step 1 is intentionally isolated from the general browser in step 2 for security and anti-tracking reasons.

Therefore, relying on the `launchUrl` Picker for *both* auth and file selection was a logical choice to enforce a single login, but the use of the implicit grant (`token`) broke long-term persistence.

---

## Solutions for Single-Login + Long-Lived Sessions

To fix this while honoring the single-login constraint, we must either get a refresh token out of the Picker flow, or run the Picker inside the Native flow's session.

### Option 1: Upgrade Picker Flow to Authorization Code + PKCE (Recommended)

Google's OAuth endpoints support the Authorization Code flow for installed apps. By changing the Picker request to return a `code`, you can exchange it for both an access token AND a refresh token.

**How it works:**
1. Change `selection.dart` to use `'response_type': 'code'`.
2. Generate a PKCE `code_verifier` and `code_challenge`, and append them to the URL.
3. The callback will receive a `code` instead of an `access_token`.
4. In the app, make a backend-less POST request to `https://oauth2.googleapis.com/token` exchanging the `code` and `code_verifier` for `access_token`, `refresh_token`, and `expires_in`.
5. Store the `refresh_token` securely (use `flutter_secure_storage`, not plaintext `state.json`).
6. Use the `refresh_token` to get new access tokens silently when the old ones expire.

**Pros:** Single login screen, keeps your current `trigger_onepick` UI, provides infinite gym session lifetimes.
**Cons:** Requires verifying if Google's undocumented `trigger_onepick` parameter correctly returns the `picked_file_ids` alongside the `code`. (If it drops the file IDs in code flow, this option won't work).

### Option 2: Native Sign-In + In-App WebView Picker

If `trigger_onepick` doesn't support `response_type=code`, you can move the Picker *inside* the app.

**How it works:**
1. Use `google_sign_in` (Native) for authentication. This gives you a robust, refreshable access token and zero 1-hour expirations.
2. Instead of using `launchUrl` to open the Picker, use a Flutter WebView plugin.
3. Load a local HTML file in the WebView that implements the standard [Google Picker JavaScript API](https://developers.google.com/drive/picker/guides/overview).
4. Inject the access token from `google_sign_in` into the JS Picker using `setOAuthToken(token)`.

**Pros:** 100% standard, documented APIs. Native sign-in handles all token refreshes flawlessly. Single login.
**Cons:** Requires adding a WebView dependency.

### Option 3: Silent Re-Auth Loop (Workaround)

If you must keep `response_type=token`, you can try to automatically renew it.

**How it works:**
1. When the app detects a 401 Unauthorized (or realizes 1 hour has passed), it constructs a new OAuth URL with `prompt=none` and without `trigger_onepick`.
2. It launches this URL.
3. Because the user is already logged into Google in their system browser, Google immediately redirects back to the app with a fresh 1-hour token without showing a UI.

**Pros:** Minimal structural changes.
**Cons:** On iOS, `ASWebAuthenticationSession` always prompts "App wants to use google.com to sign in", so `prompt=none` still interrupts the user. Highly fragile.

---

## Conclusion

The current implementation guarantees session expiry every 60 minutes. 

To fix this without introducing a double-login, **Option 1 (Auth Code + PKCE)** is the cleanest approach, provided Google's `trigger_onepick` supports it. If it doesn't, **Option 2 (Native Auth + WebView JS Picker)** is the industry-standard way to embed a Drive Picker into a mobile/desktop app using native credentials.
