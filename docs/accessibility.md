# Accessibility

Accessibility is part of each UI change, not a release-only pass.

## UI Contract

- Every interactive control has an accessible name and correct role.
- Repeated fields include context, for example `New set Weight` and
  `S1 Weight`.
- State conveyed by color, icon, or shape is also present in semantics.
- Tap targets and text contrast meet Flutter's Android and iOS guidelines.
- Layout remains usable with large text and narrow mobile widths.
- Format-generated defaults and targets use stable `Default <field>` and
  `<field>` names in declaration order; responsive columns must not change
  keyboard or screen-reader traversal order.

Add a focused semantics test only for a feature-specific contract. The broad
safety net is `test/app/ui/shell_test.dart`, whose core-state test runs:

```text
labeledTapTargetGuideline
androidTapTargetGuideline
iOSTapTargetGuideline
textContrastGuideline
```

Run focused UI tests during development and the full suite for a release gate;
see [`docs/testing.md`](testing.md).

## macOS Accessibility Smoke Test

After launching the macOS app, run:

```sh
swift scripts/verify_macos_ax_labels.swift
```

The probe uses accessibility hit testing to find representative Flutter
semantics in the initial state. The macOS runner enables the engine semantics
bridge because child enumeration alone can be shallow for Flutter host views.
