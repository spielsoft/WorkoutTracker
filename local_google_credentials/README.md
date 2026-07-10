# Local Google Credentials

This directory is the visible local-only place for Google Cloud credential
exports used while developing WorkoutTracker.

The JSON files in this directory are ignored by git:

- `project.json`
- `api_keys.json`
- `oauth_web_client.json`
- `oauth_ios_client.json`
- `oauth_macos_desktop_client.json`
- `flutter_dart_defines.json`

Native Google Sign-In expects these local Dart defines when the values are not
already supplied by platform config:

- `WORKOUT_TRACKER_GOOGLE_CLIENT_ID`
- `WORKOUT_TRACKER_GOOGLE_SERVER_CLIENT_ID`
