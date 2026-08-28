import 'package:flutter/material.dart';

import 'a11y.dart';

enum VisualSt { logged, current, warning, error }

class StChip extends StatelessWidget {
  const StChip({
    required this.state,
    required this.label,
    this.emphasized = false,
    super.key,
  });

  final VisualSt state;
  final String label;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final style = stateStyle(Theme.of(context).colorScheme, state);
    final textStyle =
        (emphasized
                ? Theme.of(context).textTheme.labelLarge
                : Theme.of(context).textTheme.labelMedium)
            ?.copyWith(color: style.foreground, fontWeight: FontWeight.w700);
    return A11yStatus(
      label: label,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: style.background,
          border: Border.all(color: style.border),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: emphasized ? 10 : 8,
            vertical: emphasized ? 6 : 5,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                style.icon,
                size: emphasized ? 16 : 14,
                color: style.foreground,
              ),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textStyle,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class StCallout extends StatelessWidget {
  const StCallout({
    required this.state,
    required this.icon,
    required this.title,
    required this.children,
    this.action,
    super.key,
  });

  final VisualSt state;
  final IconData icon;
  final String title;
  final List<Widget> children;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final style = stateStyle(Theme.of(context).colorScheme, state);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: style.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: style.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                StChip(
                  state: state,
                  label: _stateLabel(state),
                  emphasized: true,
                ),
                Icon(icon, color: style.foreground),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: style.foreground,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ...children,
            if (action != null) ...[
              const SizedBox(height: 6),
              Align(alignment: Alignment.centerLeft, child: action),
            ],
          ],
        ),
      ),
    );
  }
}

String _stateLabel(VisualSt state) {
  return switch (state) {
    VisualSt.logged => 'Logged',
    VisualSt.current => 'Current',
    VisualSt.warning => 'Warning',
    VisualSt.error => 'Error',
  };
}

const _warningSeed = Color(0xFFFFB300);

ColorScheme _warningScheme(ColorScheme colors) {
  return ColorScheme.fromSeed(
    seedColor: _warningSeed,
    brightness: colors.brightness,
  );
}

/// Foreground for a logging value the athlete has not confirmed for this set.
///
/// Shares the warning seed with [VisualSt.warning] so the app keeps a single
/// warm accent, but takes a light tone deliberately. The value sits directly
/// on the page surface rather than inside a warning container, and has to read
/// as easily as ordinary entered text under poor gym lighting, so this is
/// brighter than the surrounding chrome rather than dimmer.
Color suggestedValueColor(ColorScheme colors) {
  return _warningScheme(colors).onPrimaryContainer;
}

({Color background, Color border, Color foreground, IconData icon}) stateStyle(
  ColorScheme colors,
  VisualSt state,
) {
  final warning = _warningScheme(colors);
  return switch (state) {
    VisualSt.logged => (
      background: colors.secondaryContainer,
      border: colors.secondary.withValues(alpha: 0.55),
      foreground: colors.onSecondaryContainer,
      icon: Icons.check_circle_outline,
    ),
    VisualSt.current => (
      background: colors.primaryContainer,
      border: colors.primary,
      foreground: colors.onPrimaryContainer,
      icon: Icons.radio_button_checked,
    ),
    VisualSt.warning => (
      background: warning.primaryContainer,
      border: warning.primary,
      foreground: warning.onPrimaryContainer,
      icon: Icons.warning_amber_outlined,
    ),
    VisualSt.error => (
      background: colors.errorContainer,
      border: colors.error.withValues(alpha: 0.55),
      foreground: colors.onErrorContainer,
      icon: Icons.report_problem_outlined,
    ),
  };
}
