part of 'shell.dart';

enum _WorkoutVisualSt { logged, current, backup, warning, error }

class _StChip extends StatelessWidget {
  const _StChip({required this.state, required this.label});

  final _WorkoutVisualSt state;
  final String label;

  @override
  Widget build(BuildContext context) {
    final style = _stateStyle(Theme.of(context).colorScheme, state);
    final textStyle = Theme.of(context).textTheme.labelMedium?.copyWith(
      color: style.foreground,
      fontWeight: FontWeight.w700,
    );
    return _A11yStatus(
      label: label,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: style.background.withValues(alpha: 0.55),
          border: Border.all(color: style.border),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(style.icon, size: 14, color: style.foreground),
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

({Color background, Color border, Color foreground, IconData icon}) _stateStyle(
  ColorScheme colorScheme,
  _WorkoutVisualSt state,
) {
  switch (state) {
    case _WorkoutVisualSt.logged:
      return (
        background: colorScheme.secondaryContainer,
        border: colorScheme.secondary.withValues(alpha: 0.55),
        foreground: colorScheme.onSecondaryContainer,
        icon: Icons.check_circle_outline,
      );
    case _WorkoutVisualSt.current:
      return (
        background: const Color(0xFFE7F0FF),
        border: const Color(0xFF4B74B9),
        foreground: const Color(0xFF173A6A),
        icon: Icons.radio_button_checked,
      );
    case _WorkoutVisualSt.backup:
      return (
        background: const Color(0xFFF0E9FF),
        border: const Color(0xFF7A5DB5),
        foreground: const Color(0xFF3F2869),
        icon: Icons.alt_route_outlined,
      );
    case _WorkoutVisualSt.warning:
      return (
        background: const Color(0xFFFFF6D6),
        border: const Color(0xFFB28A00),
        foreground: const Color(0xFF5F4600),
        icon: Icons.warning_amber_outlined,
      );
    case _WorkoutVisualSt.error:
      return (
        background: colorScheme.errorContainer,
        border: colorScheme.error.withValues(alpha: 0.55),
        foreground: colorScheme.onErrorContainer,
        icon: Icons.report_problem_outlined,
      );
  }
}
