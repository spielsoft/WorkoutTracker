# Slice 17 Toolchain Blockers

These are local environment blockers discovered during Slice 17 packaging
validation. They are not project architecture, framework, or package dependency
blockers, but they must be cleared before GUI slices can verify runnable
platform builds on this machine.

## Xcode CoreSimulator Framework Missing

Affected commands:

- `flutter build macos`
- `flutter build ios --config-only`

Observed failure:

```text
xcodebuild failed to load a required plug-in.
Library not loaded:
/Library/Developer/PrivateFrameworks/CoreSimulator.framework/Versions/A/CoreSimulator
```

Flutter reported that Xcode could not load
`com.apple.dt.IDESimulatorFoundation` and suggested running:

```sh
xcodebuild -runFirstLaunch
```

If that does not restore the missing framework, reinstall or repair Xcode and
rerun the affected commands.

## Android SDK Not Configured

Affected command:

- `flutter build appbundle`

Observed failure:

```text
[!] No Android SDK found. Try setting the ANDROID_HOME environment variable.
```

Install/configure the Android SDK or set `ANDROID_HOME` to the existing SDK
path, then rerun `flutter build appbundle`.
