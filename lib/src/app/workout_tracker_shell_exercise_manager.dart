part of 'workout_tracker_shell.dart';

class _ExerciseManagerInventory extends StatelessWidget {
  const _ExerciseManagerInventory({
    required this.sheetLabel,
    required this.exercises,
    required this.onBack,
    required this.onAddExercise,
    required this.onEditExercise,
  });

  final String sheetLabel;
  final List<CanonicalExercise> exercises;
  final VoidCallback onBack;
  final VoidCallback? onAddExercise;
  final ValueChanged<CanonicalExercise>? onEditExercise;

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
          trailing: onAddExercise == null
              ? null
              : IconButton.filled(
                  key: const ValueKey('add-canonical-exercise'),
                  tooltip: 'Add Exercise',
                  onPressed: onAddExercise,
                  icon: const Icon(Icons.add_outlined),
                ),
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
            _ExerciseInventoryRow(
              exercise: exercise,
              onTap: onEditExercise == null
                  ? null
                  : () => onEditExercise!(exercise),
            ),
            const SizedBox(height: 8),
          ],
      ],
    );
  }
}

class _ExerciseInventoryRow extends StatelessWidget {
  const _ExerciseInventoryRow({required this.exercise, required this.onTap});

  final CanonicalExercise exercise;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final description = exercise.description.trim();
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
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
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (onTap != null) ...[
                  const SizedBox(width: 8),
                  Icon(
                    Icons.edit_outlined,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
