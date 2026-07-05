part of 'shell.dart';

enum _WorkoutVisualState { logged, current, backup, warning, error }

class _SetProgressStrip extends StatelessWidget {
  const _SetProgressStrip({
    required this.loggedSetNumbers,
    required this.currentSetNumber,
    required this.totalSetCount,
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
    return _A11yStatus(
      label: 'Workout progress: $logged of $total sets logged.',
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          _StateChip(
            state: _WorkoutVisualState.logged,
            label: 'Progress $logged/$total',
            emphasized: true,
          ),
          for (var setNumber = 1; setNumber <= total; setNumber += 1)
            if (loggedSetNumbers.contains(setNumber))
              _StateChip(
                state: _WorkoutVisualState.logged,
                label: 'Logged S$setNumber',
              )
            else if (setNumber == currentSetNumber)
              _StateChip(
                state: _WorkoutVisualState.current,
                label: 'Current S$setNumber',
                emphasized: true,
              ),
        ],
      ),
    );
  }
}

class _StateChip extends StatelessWidget {
  const _StateChip({
    required this.state,
    required this.label,
    this.emphasized = false,
  });

  final _WorkoutVisualState state;
  final String label;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final style = _stateStyle(Theme.of(context).colorScheme, state);
    final textStyle =
        (emphasized
                ? Theme.of(context).textTheme.labelLarge
                : Theme.of(context).textTheme.labelMedium)
            ?.copyWith(color: style.foreground, fontWeight: FontWeight.w700);
    return _A11yStatus(
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

class _StateCallout extends StatelessWidget {
  const _StateCallout({
    required this.state,
    required this.icon,
    required this.title,
    required this.children,
    this.action,
  });

  final _WorkoutVisualState state;
  final IconData icon;
  final String title;
  final List<Widget> children;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final style = _stateStyle(Theme.of(context).colorScheme, state);
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
                _StateChip(
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

String _stateLabel(_WorkoutVisualState state) {
  switch (state) {
    case _WorkoutVisualState.logged:
      return 'Logged';
    case _WorkoutVisualState.current:
      return 'Current';
    case _WorkoutVisualState.backup:
      return 'Backup';
    case _WorkoutVisualState.warning:
      return 'Warning';
    case _WorkoutVisualState.error:
      return 'Error';
  }
}

({Color background, Color border, Color foreground, IconData icon}) _stateStyle(
  ColorScheme colorScheme,
  _WorkoutVisualState state,
) {
  switch (state) {
    case _WorkoutVisualState.logged:
      return (
        background: colorScheme.secondaryContainer,
        border: colorScheme.secondary.withValues(alpha: 0.55),
        foreground: colorScheme.onSecondaryContainer,
        icon: Icons.check_circle_outline,
      );
    case _WorkoutVisualState.current:
      return (
        background: const Color(0xFFE7F0FF),
        border: const Color(0xFF4B74B9),
        foreground: const Color(0xFF173A6A),
        icon: Icons.radio_button_checked,
      );
    case _WorkoutVisualState.backup:
      return (
        background: const Color(0xFFF0E9FF),
        border: const Color(0xFF7A5DB5),
        foreground: const Color(0xFF3F2869),
        icon: Icons.alt_route_outlined,
      );
    case _WorkoutVisualState.warning:
      return (
        background: const Color(0xFFFFF6D6),
        border: const Color(0xFFB28A00),
        foreground: const Color(0xFF5F4600),
        icon: Icons.warning_amber_outlined,
      );
    case _WorkoutVisualState.error:
      return (
        background: colorScheme.errorContainer,
        border: colorScheme.error.withValues(alpha: 0.55),
        foreground: colorScheme.onErrorContainer,
        icon: Icons.report_problem_outlined,
      );
  }
}
