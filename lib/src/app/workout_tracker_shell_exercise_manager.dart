part of 'workout_tracker_shell.dart';

class _ExerciseManagerInventory extends StatelessWidget {
  const _ExerciseManagerInventory({
    required this.sheetLabel,
    required this.exercises,
    required this.highlightedExerciseSheetRowNumber,
    required this.onBack,
    required this.onAddExercise,
    required this.onEditExercise,
    required this.onReorderExercises,
  });

  final String sheetLabel;
  final List<CanonicalExercise> exercises;
  final int? highlightedExerciseSheetRowNumber;
  final VoidCallback onBack;
  final VoidCallback? onAddExercise;
  final ValueChanged<CanonicalExercise>? onEditExercise;
  final Future<bool> Function(ReorderIntent intent)? onReorderExercises;

  @override
  Widget build(BuildContext context) {
    final highlightedExerciseSheetRowNumber =
        this.highlightedExerciseSheetRowNumber;
    if (highlightedExerciseSheetRowNumber != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final highlightedContext = _highlightedExerciseKey.currentContext;
        if (highlightedContext != null) {
          Scrollable.ensureVisible(
            highlightedContext,
            alignment: 0.5,
            duration: const Duration(milliseconds: 1),
          );
        }
      });
    }
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
                  tooltip: 'Create exercise',
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
          ReorderableListView.builder(
            buildDefaultDragHandles: false,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: exercises.length,
            onReorderItem: onReorderExercises == null
                ? (_, _) {}
                : (oldIndex, newIndex) {
                    onReorderExercises!(
                      ReorderIntent(fromIndex: oldIndex, toIndex: newIndex),
                    );
                  },
            itemBuilder: (context, index) {
              final exercise = exercises[index];
              final isHighlighted =
                  exercise.sheetRowNumber == highlightedExerciseSheetRowNumber;
              return Padding(
                key: isHighlighted
                    ? _highlightedExerciseKey
                    : ValueKey('canonical-exercise-${exercise.sheetRowNumber}'),
                padding: const EdgeInsets.only(bottom: 8),
                child: _ExerciseInventoryRow(
                  index: index,
                  exercise: exercise,
                  isHighlighted: isHighlighted,
                  canReorder: onReorderExercises != null,
                  onTap: onEditExercise == null
                      ? null
                      : () => onEditExercise!(exercise),
                ),
              );
            },
          ),
      ],
    );
  }
}

final _highlightedExerciseKey = GlobalKey();

class _ExerciseInventoryRow extends StatelessWidget {
  const _ExerciseInventoryRow({
    required this.index,
    required this.exercise,
    required this.isHighlighted,
    required this.canReorder,
    required this.onTap,
  });

  final int index;
  final CanonicalExercise exercise;
  final bool isHighlighted;
  final bool canReorder;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final description = exercise.description.trim();
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(
              color: isHighlighted
                  ? colorScheme.primary
                  : colorScheme.outlineVariant,
              width: isHighlighted ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(8),
            color: isHighlighted ? colorScheme.primaryContainer : null,
          ),
          child: KeyedSubtree(
            key: isHighlighted
                ? const ValueKey('saved-exercise-highlight')
                : null,
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
                    Tooltip(
                      message: 'Edit ${exercise.displayName}',
                      child: Icon(
                        Icons.edit_outlined,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  if (canReorder) ...[
                    const SizedBox(width: 8),
                    ReorderableDragStartListener(
                      index: index,
                      child: Tooltip(
                        message: 'Reorder ${exercise.displayName}',
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Icon(
                            Icons.drag_handle_outlined,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
