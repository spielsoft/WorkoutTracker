import 'package:flutter/material.dart';

import 'a11y.dart';

enum VisualSt { logged, current, backup, warning, error }

class SetProgressStrip extends StatelessWidget {
  const SetProgressStrip({
    required this.loggedSetNumbers,
    required this.currentSetNumber,
    required this.totalSetCount,
    super.key,
  });

  final Set<int> loggedSetNumbers;
  final int currentSetNumber;
  final int totalSetCount;

  @override
  Widget build(BuildContext context) {
    final total = totalSetCount < currentSetNumber
        ? currentSetNumber
        : totalSetCount;
    final logged = loggedSetNumbers.length;
    return A11yStatus(
      label: 'Workout progress: $logged of $total sets logged.',
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          StChip(
            state: VisualSt.logged,
            label: 'Progress $logged/$total',
            emphasized: true,
          ),
          for (var setNumber = 1; setNumber <= total; setNumber += 1)
            if (loggedSetNumbers.contains(setNumber))
              StChip(state: VisualSt.logged, label: 'Logged S$setNumber')
            else if (setNumber == currentSetNumber)
              StChip(
                state: VisualSt.current,
                label: 'Current S$setNumber',
                emphasized: true,
              ),
        ],
      ),
    );
  }
}

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
          color: emphasized
              ? style.background
              : style.background.withValues(alpha: 0.55),
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

({Color background, Color border, Color foreground, IconData icon}) stateStyle(
  ColorScheme colors,
  VisualSt state,
) {
  return switch (state) {
    VisualSt.logged => (
      background: colors.secondaryContainer,
      border: colors.secondary.withValues(alpha: 0.55),
      foreground: colors.onSecondaryContainer,
      icon: Icons.check_circle_outline,
    ),
    VisualSt.current => (
      background: const Color(0xFFE7F0FF),
      border: const Color(0xFF4B74B9),
      foreground: const Color(0xFF173A6A),
      icon: Icons.radio_button_checked,
    ),
    VisualSt.backup => (
      background: const Color(0xFFF0E9FF),
      border: const Color(0xFF7A5DB5),
      foreground: const Color(0xFF3F2869),
      icon: Icons.alt_route_outlined,
    ),
    VisualSt.warning => (
      background: const Color(0xFFFFF6D6),
      border: const Color(0xFFB28A00),
      foreground: const Color(0xFF5F4600),
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
