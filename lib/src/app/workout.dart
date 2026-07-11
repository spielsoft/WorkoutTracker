import 'package:flutter/material.dart';
import 'package:workout_tracker/contract.dart';

import 'ui/shared/a11y.dart';
import 'ui/shared/status.dart';

Future<bool> confirmWorkoutDelete(
  BuildContext context,
  WorkoutOverviewSlot slot,
) async {
  return await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Delete ${slot.exercise}?'),
          content: Text(
            'This removes ${slot.exercise} from the workout, including '
            'associated backups and logged history for those rows.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.of(context).pop(true),
              icon: const Icon(Icons.delete_outline),
              label: const Text('Delete exercise'),
            ),
          ],
        ),
      ) ??
      false;
}

class WorkoutList extends StatelessWidget {
  const WorkoutList({
    super.key,
    required this.overview,
    required this.onOpenExercise,
    this.onAddPrimary,
    this.onAddBackup,
    this.onDeleteExercise,
    this.onReorderExercises,
    this.compact = false,
    this.showTitle = true,
  });

  final WorkoutOverview overview;
  final ValueChanged<int> onOpenExercise;
  final VoidCallback? onAddPrimary;
  final ValueChanged<WorkoutOverviewSlot>? onAddBackup;
  final ValueChanged<WorkoutOverviewSlot>? onDeleteExercise;
  final Future<bool> Function(ReorderIntent intent)? onReorderExercises;
  final bool compact;
  final bool showTitle;

  @override
  Widget build(BuildContext context) {
    return A11yScreen(
      label: '${overview.workout} exercises',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (showTitle) ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${overview.workout} exercises',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                if (onAddPrimary != null)
                  IconButton.filled(
                    key: const ValueKey('add-primary-exercise-from-setup'),
                    tooltip: 'Add to workout',
                    onPressed: onAddPrimary,
                    icon: const Icon(Icons.add_outlined),
                  ),
              ],
            ),
            const SizedBox(height: 8),
          ],
          if (overview.slots.isNotEmpty)
            ReorderableListView.builder(
              buildDefaultDragHandles: false,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: overview.slots.length,
              onReorderItem: onReorderExercises == null
                  ? (_, _) {}
                  : (oldIndex, newIndex) {
                      onReorderExercises!(
                        ReorderIntent(fromIndex: oldIndex, toIndex: newIndex),
                      );
                    },
              itemBuilder: (context, index) {
                final slot = overview.slots[index];
                return Padding(
                  key: ValueKey('workout-exercise-${slot.sheetRowNumber}'),
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _WorkoutOverviewTile(
                    index: index,
                    slot: slot,
                    onOpenExercise: onOpenExercise,
                    onAddBackup: onAddBackup,
                    onDeleteExercise: onDeleteExercise,
                    canReorder: onReorderExercises != null,
                    compact: compact,
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

class _WorkoutOverviewTile extends StatelessWidget {
  const _WorkoutOverviewTile({
    required this.index,
    required this.slot,
    required this.onOpenExercise,
    required this.onAddBackup,
    required this.onDeleteExercise,
    required this.canReorder,
    required this.compact,
  });

  final int index;
  final WorkoutOverviewSlot slot;
  final ValueChanged<int> onOpenExercise;
  final ValueChanged<WorkoutOverviewSlot>? onAddBackup;
  final ValueChanged<WorkoutOverviewSlot>? onDeleteExercise;
  final bool canReorder;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final setLabel = slot.setCount == 1 ? '1 set' : '${slot.setCount} sets';
    final backupSummaryLabel = slot.backups.length == 1
        ? '1 backup'
        : '${slot.backups.length} backups';
    final hasExerciseActions = onAddBackup != null || onDeleteExercise != null;
    final exerciseActionButton = !hasExerciseActions
        ? null
        : Semantics(
            button: true,
            label: 'Exercise actions for ${slot.exercise}',
            child: PopupMenuButton<_PrimaryExerciseAction>(
              key: ValueKey('exercise-actions-${slot.sheetRowNumber}'),
              tooltip: 'Exercise actions for ${slot.exercise}',
              icon: const Icon(Icons.more_vert),
              itemBuilder: (context) => [
                if (onAddBackup != null)
                  PopupMenuItem(
                    value: _PrimaryExerciseAction.addBackup,
                    child: _AddBackupMenuItem(exercise: slot.exercise),
                  ),
                if (onDeleteExercise != null)
                  PopupMenuItem(
                    value: _PrimaryExerciseAction.delete,
                    child: _DeleteExerciseMenuItem(exercise: slot.exercise),
                  ),
              ],
              onSelected: _handleExerciseAction,
            ),
          );
    final openLogButton = Semantics(
      button: true,
      label: 'Open logging for ${slot.exercise}',
      child: Tooltip(
        message: 'Open logging for ${slot.exercise}',
        child: TextButton.icon(
          onPressed: () => onOpenExercise(slot.sheetRowNumber),
          icon: const Icon(Icons.edit_note_outlined),
          label: const Text('Open log'),
        ),
      ),
    );
    return GestureDetector(
      excludeFromSemantics: true,
      onSecondaryTapDown: !hasExerciseActions
          ? null
          : (details) =>
                _showPrimaryExerciseMenu(context, details.globalPosition),
      onLongPressStart: !hasExerciseActions
          ? null
          : (details) =>
                _showPrimaryExerciseMenu(context, details.globalPosition),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Material(
          color: Theme.of(context).colorScheme.surface,
          shape: RoundedRectangleBorder(
            side: BorderSide(color: Theme.of(context).colorScheme.outline),
            borderRadius: BorderRadius.circular(8),
          ),
          child: InkWell(
            excludeFromSemantics: true,
            borderRadius: BorderRadius.circular(8),
            onTap: () => onOpenExercise(slot.sheetRowNumber),
            child: Padding(
              padding: EdgeInsets.all(compact ? 10 : 14),
              child: compact
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    slot.exercise,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleMedium,
                                  ),
                                  if (slot.backups.isNotEmpty) ...[
                                    const SizedBox(height: 6),
                                    StChip(
                                      state: VisualSt.backup,
                                      label: backupSummaryLabel,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(setLabel),
                            if (exerciseActionButton != null) ...[
                              const SizedBox(width: 4),
                              exerciseActionButton,
                            ],
                            if (canReorder) ...[
                              const SizedBox(width: 4),
                              _WorkoutReorderHandle(
                                index: index,
                                label: slot.exercise,
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: openLogButton,
                        ),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    slot.exercise,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleMedium,
                                  ),
                                  if (slot.backups.isNotEmpty) ...[
                                    const SizedBox(height: 6),
                                    StChip(
                                      state: VisualSt.backup,
                                      label: backupSummaryLabel,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(setLabel),
                            if (exerciseActionButton != null) ...[
                              const SizedBox(width: 4),
                              exerciseActionButton,
                            ],
                            if (canReorder) ...[
                              const SizedBox(width: 4),
                              _WorkoutReorderHandle(
                                index: index,
                                label: slot.exercise,
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: openLogButton,
                        ),
                        if (slot.backups.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Padding(
                            padding: const EdgeInsets.only(left: 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                for (final (index, backup)
                                    in slot.backups.indexed)
                                  Padding(
                                    padding: EdgeInsets.only(
                                      bottom: index < slot.backups.length - 1
                                          ? 6
                                          : 0,
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.subdirectory_arrow_right,
                                          size: 18,
                                        ),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            backup.exercise,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
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

  void _handleExerciseAction(_PrimaryExerciseAction action) {
    switch (action) {
      case _PrimaryExerciseAction.addBackup:
        onAddBackup?.call(slot);
      case _PrimaryExerciseAction.delete:
        onDeleteExercise?.call(slot);
    }
  }

  Future<void> _showPrimaryExerciseMenu(
    BuildContext context,
    Offset globalPosition,
  ) async {
    final onAddBackup = this.onAddBackup;
    final onDeleteExercise = this.onDeleteExercise;
    if (onAddBackup == null && onDeleteExercise == null) {
      return;
    }
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final selected = await showMenu<_PrimaryExerciseAction>(
      context: context,
      position: RelativeRect.fromRect(
        Rect.fromPoints(globalPosition, globalPosition),
        Offset.zero & overlay.size,
      ),
      items: [
        if (onAddBackup != null)
          PopupMenuItem(
            value: _PrimaryExerciseAction.addBackup,
            child: _AddBackupMenuItem(exercise: slot.exercise),
          ),
        if (onDeleteExercise != null)
          PopupMenuItem(
            value: _PrimaryExerciseAction.delete,
            child: _DeleteExerciseMenuItem(exercise: slot.exercise),
          ),
      ],
    );
    switch (selected) {
      case _PrimaryExerciseAction.addBackup:
        onAddBackup?.call(slot);
      case _PrimaryExerciseAction.delete:
        onDeleteExercise?.call(slot);
      case null:
    }
  }
}

class _WorkoutReorderHandle extends StatelessWidget {
  const _WorkoutReorderHandle({required this.index, required this.label});

  final int index;
  final String label;

  @override
  Widget build(BuildContext context) {
    return ReorderableDragStartListener(
      index: index,
      child: Tooltip(
        message: 'Reorder $label',
        child: Semantics(
          button: true,
          label: 'Reorder $label',
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Icon(
              Icons.drag_handle_outlined,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

enum _PrimaryExerciseAction { addBackup, delete }

class _AddBackupMenuItem extends StatelessWidget {
  const _AddBackupMenuItem({required this.exercise});

  final String exercise;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Add backup exercise for $exercise',
      child: SizedBox(
        width: 220,
        child: Row(
          children: [
            Icon(Icons.subdirectory_arrow_right),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Add backup exercise',
                semanticsLabel: 'Add backup exercise for $exercise',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DeleteExerciseMenuItem extends StatelessWidget {
  const _DeleteExerciseMenuItem({required this.exercise});

  final String exercise;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: 'Delete exercise $exercise',
      child: SizedBox(
        width: 220,
        child: Row(
          children: [
            Icon(Icons.delete_outline, color: colorScheme.error),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Delete exercise',
                semanticsLabel: 'Delete exercise $exercise',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: colorScheme.error),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
