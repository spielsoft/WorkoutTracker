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

A direct macOS Accessibility API probe currently sees the stock Flutter host
view and app menus, but not the full Flutter semantics subtree. Adding widget
semantics and forcing a Dart semantics handle did not change that native AX
dump, so the remaining work is likely in the macOS runner or Flutter macOS
embedding/accessibility bridge rather than in individual widget annotations.

Before relying on native AX automation as a release gate, add a dedicated
macOS-side investigation that proves labeled Flutter controls such as
`Google Sheets URL or ID`, `Select`, and `Open logging for Squat` are visible
to an AX client.
