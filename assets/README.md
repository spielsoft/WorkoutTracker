# Assets

## Branding

`assets/branding/workout_tracker_icon_source.png` is the high-resolution source
artwork for the platform app icons. It is not declared in `pubspec.yaml`
because the app does not load it at runtime.

Generated app icon assets live in the platform folders:

- `ios/Runner/Assets.xcassets/AppIcon.appiconset/`
- `macos/Runner/Assets.xcassets/AppIcon.appiconset/`
- `android/app/src/main/res/mipmap-*/`
- `windows/runner/resources/app_icon.ico`

When the app icon changes, regenerate those platform assets from the source
image and keep this source file as the editable reference.
