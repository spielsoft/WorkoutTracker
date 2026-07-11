import 'package:flutter/material.dart';
import 'package:workout_tracker/contract.dart';

import 'ui/view.dart';
import 'ui/shared/a11y.dart';
import 'ui/shared/header.dart';
import 'ui/shared/status.dart';

final class LibraryView extends LoadedView {
  const LibraryView({
    required super.isBusy,
    required this.exercises,
    required super.sheetLabel,
    required this.highlightedRow,
    super.error,
  });

  final List<CanonicalExercise> exercises;
  final int? highlightedRow;
}

abstract interface class LibraryActions {
  Future<void> close();

  Future<void> create();

  Future<void> edit(CanonicalExercise exercise);

  Future<bool> reorder(ReorderIntent intent);
}

class ExerciseLibraryScreen extends StatefulWidget {
  const ExerciseLibraryScreen({
    required this.view,
    required this.actions,
    super.key,
  });

  final LibraryView view;
  final LibraryActions actions;

  @override
  State<ExerciseLibraryScreen> createState() => _ExerciseLibraryScreenSt();
}

class _ExerciseLibraryScreenSt extends State<ExerciseLibraryScreen> {
  final _scrollCtrl = ScrollController();
  final _highlightKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _showHighlight();
  }

  @override
  void didUpdateWidget(covariant ExerciseLibraryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.view.highlightedRow != widget.view.highlightedRow) {
      _showHighlight();
    }
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _showHighlight() {
    final row = widget.view.highlightedRow;
    if (row == null) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollCtrl.hasClients) {
        return;
      }
      final exercises = widget.view.exercises;
      final index = exercises.indexWhere((item) => item.sheetRowNumber == row);
      if (index < 0) {
        return;
      }
      final lastIndex = exercises.length - 1;
      final ratio = lastIndex == 0 ? 0.0 : index / lastIndex;
      _scrollCtrl.jumpTo(_scrollCtrl.position.maxScrollExtent * ratio);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final context = _highlightKey.currentContext;
        if (mounted && context != null) {
          Scrollable.ensureVisible(
            context,
            alignment: 0.5,
            duration: const Duration(milliseconds: 1),
          );
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final view = widget.view;
    final actions = widget.actions;
    final exercises = view.exercises;
    final highlightedRow = view.highlightedRow;
    final header = _LibraryHeader(
      view: view,
      onClose: actions.close,
      onCreate: actions.create,
    );
    return A11yScreen(
      label: 'Edit exercise library',
      child: exercises.isEmpty
          ? ListView(
              controller: _scrollCtrl,
              children: [
                header,
                const StCallout(
                  state: VisualSt.current,
                  icon: Icons.fitness_center_outlined,
                  title: 'No exercises in this sheet.',
                  children: [Text('The exercise library is empty.')],
                ),
              ],
            )
          : ReorderableListView.builder(
              scrollController: _scrollCtrl,
              key: const PageStorageKey('exercise-library'),
              header: header,
              buildDefaultDragHandles: false,
              itemCount: exercises.length,
              onReorderItem: view.isBusy
                  ? (_, _) {}
                  : (oldIndex, newIndex) {
                      actions.reorder(
                        ReorderIntent(fromIndex: oldIndex, toIndex: newIndex),
                      );
                    },
              itemBuilder: (context, index) {
                final exercise = exercises[index];
                final isHighlighted = exercise.sheetRowNumber == highlightedRow;
                return Padding(
                  key: isHighlighted
                      ? _highlightKey
                      : ValueKey(
                          'canonical-exercise-${exercise.sheetRowNumber}',
                        ),
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _ExerciseInventoryRow(
                    index: index,
                    exercise: exercise,
                    isHighlighted: isHighlighted,
                    canReorder: !view.isBusy,
                    onTap: view.isBusy ? null : () => actions.edit(exercise),
                  ),
                );
              },
            ),
    );
  }
}

class _LibraryHeader extends StatelessWidget {
  const _LibraryHeader({
    required this.view,
    required this.onClose,
    required this.onCreate,
  });

  final LibraryView view;
  final VoidCallback onClose;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ScreenHeader(
          title: view.sheetLabel,
          subtitle: 'Edit exercises',
          compactTitle: true,
          backTooltip: 'Back to workout setup',
          onBack: onClose,
          trailing: view.isBusy
              ? null
              : IconButton.filled(
                  key: const ValueKey('add-canonical-exercise'),
                  tooltip: 'Create exercise',
                  onPressed: onCreate,
                  icon: const Icon(Icons.add_outlined),
                ),
        ),
        const SizedBox(height: 16),
        Text('Edit exercises', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
      ],
    );
  }
}

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
    final rowLabel = description.isEmpty
        ? exercise.displayName
        : '${exercise.displayName}, $description';
    return Semantics(
      button: onTap != null,
      label: onTap == null ? rowLabel : 'Edit $rowLabel',
      child: Material(
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
                          child: Semantics(
                            button: true,
                            label: 'Reorder ${exercise.displayName}',
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
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
