# Accessibility

WorkoutTracker treats Flutter accessibility support as part of normal GUI
development, not as a release-only cleanup step.

The app follows Flutter's standard accessibility practices:

- controls that can be tapped must have an accessible name;
- custom controls must expose the role they visually represent, such as button,
  text field, header, or status;
- repeated fields must include enough context to distinguish them, such as
  `New set Weight` and `S1 Weight` instead of several anonymous `Weight`
  fields;
- visual-only state such as color, icons, and chips must also be represented in
  semantics labels;
- tap targets must meet Flutter's Android and iOS guideline checks;
- text and controls must satisfy Flutter's contrast guideline checks.

Flutter documents these as normal app responsibilities in its
[accessibility guide](https://docs.flutter.dev/ui/accessibility) and release
checklist, and exposes them to tests through the
[Accessibility Guideline API](https://api.flutter.dev/flutter/flutter_test/meetsGuideline.html).
The project therefore includes a single broad widget smoke test named:

```text
meets Flutter accessibility guidelines across core GUI states
```

That test pumps representative sheet-selection, workout-setup, exercise-list,
logging, exercise-library, and exercise-authoring states, then runs:

```dart
meetsGuideline(labeledTapTargetGuideline)
meetsGuideline(androidTapTargetGuideline)
meetsGuideline(iOSTapTargetGuideline)
meetsGuideline(textContrastGuideline)
```

This is the global accessibility safety net. Feature-specific semantics tests
are still appropriate when a feature has a non-obvious accessibility contract,
but routine GUI additions should first make this global test pass.

## macOS AX smoke status

Native macOS AX automation is covered by a small smoke probe:

```text
swift scripts/verify_macos_ax_labels.swift
```

Run it after launching the macOS app. It scans the running app with
`AXUIElementCopyElementAtPosition` and fails unless the initial empty state
exposes representative Flutter semantics labels, including
`No workout sheet selected`, `Choose workout sheet`, and `Create sheet`.

The macOS runner explicitly enables Flutter engine semantics after launch so
native AX automation clients can see the Flutter semantics bridge even when a
system assistive technology has not already requested it. This uses guarded
Objective-C runtime selectors because the current FlutterMacOS public headers
do not expose a runner-level API for forcing the native semantics bridge on.

Tree enumeration through `AXChildren` can still be shallow for the Flutter host
view, so use hit testing rather than child traversal for the current native AX
smoke gate.
