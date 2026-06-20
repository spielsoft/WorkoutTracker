part of 'workout_tracker_shell.dart';

class _ExerciseManagerInventory extends StatelessWidget {
  const _ExerciseManagerInventory({
    required this.sheetLabel,
    required this.exercises,
    required this.onBack,
  });

  final String sheetLabel;
  final List<CanonicalExercise> exercises;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ScreenHeader(
          title: sheetLabel,
          subtitle: 'Edit exercises',
          compactTitle: true,
          backTooltip: 'Back to workout setup',
          onBack: onBack,
        ),
        const SizedBox(height: 16),
        Text('Edit exercises', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        if (exercises.isEmpty)
          const _StateCallout(
            state: _WorkoutVisualState.current,
            icon: Icons.fitness_center_outlined,
            title: 'No exercises in this sheet.',
            children: [Text('The exercise library is empty.')],
          )
        else
          for (final exercise in exercises) ...[
            _ExerciseInventoryRow(exercise: exercise),
            const SizedBox(height: 8),
          ],
      ],
    );
  }
}

class _ExerciseInventoryRow extends StatelessWidget {
  const _ExerciseInventoryRow({required this.exercise});

  final CanonicalExercise exercise;

  @override
  Widget build(BuildContext context) {
    final description = exercise.description.trim();
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(
              Icons.fitness_center_outlined,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    exercise.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  if (description.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
