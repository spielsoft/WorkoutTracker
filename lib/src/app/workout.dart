import 'package:flutter/material.dart';
import 'package:workout_tracker/contract.dart';

import 'controller.dart';
import 'exercise_library.dart';
import 'exercise_screens.dart';
import 'logging.dart';
import 'repair.dart';
import 'ui/flow.dart';
import 'ui/shared/a11y.dart';
import 'ui/shared/header.dart';
import 'ui/shared/name_dialog.dart';
import 'ui/shared/status.dart';

const _addWorkoutMenuValue = '__workout_tracker_add_workout__';
const _addBlockMenuValue = '__workout_tracker_add_history_block__';

class WorkoutScreens extends StatelessWidget {
  const WorkoutScreens({required this.view, required this.run, super.key});

  final LoadedView view;
  final Future<CmdResult> Function(UiCmd cmd) run;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (view.error case final error?) ...[
          IssuePanel(
            icon: Icons.error_outline,
            title: 'Connection or validation failed',
            lines: [error],
            tone: IssueTone.error,
          ),
          const SizedBox(height: 16),
        ],
        switch (view) {
          SetupView() => _setup(context),
          WorkoutView() => _workout(context),
          LibraryView() => _library(),
          CreateExerciseView() => _create(),
          EditExerciseView() => _edit(),
          PlacementView() => _placement(),
          LogView() => _log(),
        },
      ],
    );
  }

  Widget _setup(BuildContext context) {
    final setup = view.setup;
    final selectedWorkout = setup.selectedWorkout;
    final overview = setup.overview;
    return A11yScreen(
      label: 'Workout setup',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ScreenHeader(
            title: view.sheetLabel,
            compactTitle: true,
            backTooltip: 'Back to sheet selection',
            onBack: () => run(const ReturnToSheet()),
            trailing: IconButton.filledTonal(
              key: const ValueKey('open-exercise-manager'),
              tooltip: 'Edit exercise library',
              onPressed: () => run(const OpenLibrary()),
              icon: const Icon(Icons.fitness_center_outlined),
            ),
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final twoColumn = constraints.maxWidth >= 620;
              final fieldWidth = twoColumn
                  ? (constraints.maxWidth - 12) / 2
                  : constraints.maxWidth;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: fieldWidth,
                    child: _WorkoutField(
                      workouts: setup.workouts,
                      selectedWorkout: selectedWorkout,
                      progressByWorkout: setup.progressByWorkout,
                      onWorkoutChanged: (value) => run(SelectWorkout(value)),
                      onAddWorkout: view.isBusy
                          ? null
                          : () => _addWorkout(context),
                    ),
                  ),
                  SizedBox(
                    width: fieldWidth,
                    child: _HistoryField(
                      historyBlocks: setup.historyBlocks,
                      selectedHistoryBlock: setup.selectedHistoryBlock,
                      onHistoryBlockChanged: (value) =>
                          run(SelectHistory(value)),
                      onAddHistoryBlock: view.isBusy
                          ? null
                          : () => _addHistory(context),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            key: const ValueKey('select-workout-setup'),
            onPressed: overview == null ? null : () => run(const OpenWorkout()),
            icon: const Icon(Icons.check_circle_outline),
            label: const Text('Select'),
          ),
          const SizedBox(height: 16),
          if (overview != null)
            _WorkoutOverviewList(
              key: const ValueKey('compact-workout-overview'),
              overview: overview,
              onOpenExercise: (row) => run(OpenLog(row)),
              onAddPrimary: selectedWorkout == null
                  ? null
                  : () => run(AddPrimary(selectedWorkout)),
              onAddBackup: (slot) => run(AddBackup(slot)),
              onDeleteExercise: view.isBusy
                  ? null
                  : (slot) => _delete(context, slot),
              onReorderExercises: view.isBusy ? null : _reorderWorkout,
              compact: true,
            ),
        ],
      ),
    );
  }

  Widget _workout(BuildContext context) {
    final setup = view.setup;
    final selectedWorkout = setup.selectedWorkout;
    final selectedHistory = setup.selectedHistoryBlock;
    final title = selectedWorkout == null || selectedHistory == null
        ? 'Exercises'
        : '$selectedWorkout - $selectedHistory';
    return A11yScreen(
      label: '$title exercise list',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ScreenHeader(
            title: view.sheetLabel,
            subtitle: title,
            compactTitle: true,
            backTooltip: 'Back to workout setup',
            onBack: () => run(const BackToSetup()),
            trailing: selectedWorkout == null
                ? null
                : IconButton.filled(
                    key: const ValueKey('add-primary-exercise'),
                    tooltip: 'Add to workout',
                    onPressed: () => run(AddPrimary(selectedWorkout)),
                    icon: const Icon(Icons.add_outlined),
                  ),
          ),
          const SizedBox(height: 12),
          if (setup.overview case final overview?)
            _WorkoutOverviewList(
              key: const ValueKey('full-workout-overview'),
              overview: overview,
              onOpenExercise: (row) => run(OpenLog(row)),
              onAddBackup: (slot) => run(AddBackup(slot)),
              onDeleteExercise: view.isBusy
                  ? null
                  : (slot) => _delete(context, slot),
              onReorderExercises: view.isBusy ? null : _reorderWorkout,
              showTitle: false,
            ),
        ],
      ),
    );
  }

  Widget _library() {
    final library = view as LibraryView;
    return ExerciseLibraryScreen(view: library, run: (cmd) => run(cmd));
  }

  Widget _create() {
    final create = view as CreateExerciseView;
    return CreateExerciseScreen(view: create, run: (cmd) => run(cmd));
  }

  Widget _edit() {
    final edit = view as EditExerciseView;
    return EditExerciseScreen(view: edit, run: (cmd) => run(cmd));
  }

  Widget _placement() {
    final placement = view as PlacementView;
    return PlacementScreen(view: placement, run: (cmd) => run(cmd));
  }

  Widget _log() {
    return LogScreen(view: view as LogView, run: (cmd) => run(cmd));
  }

  Future<bool> _reorderWorkout(ReorderIntent intent) async {
    return (await run(ReorderWorkout(intent))).ok;
  }

  Future<void> _addWorkout(BuildContext context) async {
    final name = await _prompt(context, 'Add workout', 'Workout name');
    if (name != null) {
      await run(AddWorkout(name));
    }
  }

  Future<void> _addHistory(BuildContext context) async {
    final name = await _prompt(
      context,
      'Add history block',
      'History block label',
    );
    if (name != null) {
      await run(AddHistory(name));
    }
  }

  Future<String?> _prompt(
    BuildContext context,
    String title,
    String label,
  ) async {
    final value = await showDialog<String>(
      context: context,
      builder: (context) => NameDialog(title: title, label: label),
    );
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  Future<void> _delete(BuildContext context, WorkoutOverviewSlot slot) async {
    final confirmed = await showDialog<bool>(
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
    );
    if (confirmed == true) {
      await run(DeleteWorkoutExercise(slot.sheetRowNumber));
    }
  }
}

class _WorkoutField extends StatefulWidget {
  const _WorkoutField({
    required this.workouts,
    required this.selectedWorkout,
    required this.progressByWorkout,
    required this.onWorkoutChanged,
    required this.onAddWorkout,
  });

  final List<String> workouts;
  final String? selectedWorkout;
  final Map<String, WorkoutSetupProgress> progressByWorkout;
  final ValueChanged<String?> onWorkoutChanged;
  final VoidCallback? onAddWorkout;

  @override
  State<_WorkoutField> createState() => _WorkoutFieldSt();
}

class _WorkoutFieldSt extends State<_WorkoutField> {
  @override
  Widget build(BuildContext context) {
    return _SetupSelectorField(
      keyPrefix: 'workout-selector',
      label: 'Workout',
      emptyPrompt: 'Add workout...',
      prefixIcon: Icons.fitness_center_outlined,
      selectedValue: widget.selectedWorkout,
      addValue: _addWorkoutMenuValue,
      onAdd: widget.onAddWorkout,
      onChanged: widget.onWorkoutChanged,
      items: [
        for (final workout in widget.workouts)
          DropdownMenuItem(
            value: workout,
            child: Text(
              '$workout ${widget.progressByWorkout[workout]!.label}',
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
    );
  }
}

class _HistoryField extends StatefulWidget {
  const _HistoryField({
    required this.historyBlocks,
    required this.selectedHistoryBlock,
    required this.onHistoryBlockChanged,
    required this.onAddHistoryBlock,
  });

  final List<HistoryBlock> historyBlocks;
  final String? selectedHistoryBlock;
  final ValueChanged<String?> onHistoryBlockChanged;
  final VoidCallback? onAddHistoryBlock;

  @override
  State<_HistoryField> createState() => _HistoryFieldSt();
}

class _HistoryFieldSt extends State<_HistoryField> {
  @override
  Widget build(BuildContext context) {
    return _SetupSelectorField(
      keyPrefix: 'history-block-selector',
      label: 'History block',
      emptyPrompt: 'Add history block...',
      prefixIcon: Icons.history_outlined,
      selectedValue: widget.selectedHistoryBlock,
      addValue: _addBlockMenuValue,
      onAdd: widget.onAddHistoryBlock,
      onChanged: widget.onHistoryBlockChanged,
      items: [
        for (final block in widget.historyBlocks)
          DropdownMenuItem(
            value: block.label,
            child: Text(block.label, overflow: TextOverflow.ellipsis),
          ),
      ],
    );
  }
}

class _SetupSelectorField extends StatefulWidget {
  const _SetupSelectorField({
    required this.keyPrefix,
    required this.label,
    required this.emptyPrompt,
    required this.prefixIcon,
    required this.selectedValue,
    required this.addValue,
    required this.items,
    required this.onChanged,
    required this.onAdd,
  });

  final String keyPrefix;
  final String label;
  final String emptyPrompt;
  final IconData prefixIcon;
  final String? selectedValue;
  final String addValue;
  final List<DropdownMenuItem<String>> items;
  final ValueChanged<String?> onChanged;
  final VoidCallback? onAdd;

  @override
  State<_SetupSelectorField> createState() => _SetupSelectorFieldSt();
}

class _SetupSelectorFieldSt extends State<_SetupSelectorField> {
  int _resetEpoch = 0;

  void _openAddAfterClose() {
    setState(() {
      _resetEpoch += 1;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        widget.onAdd?.call();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '${widget.label} selector',
      value:
          widget.selectedValue ?? 'No ${widget.label.toLowerCase()} selected',
      hint: 'Choose ${widget.label.toLowerCase()}',
      child: DropdownButtonFormField<String>(
        key: ValueKey(
          '${widget.keyPrefix}-${widget.selectedValue}-$_resetEpoch',
        ),
        initialValue: widget.selectedValue,
        isExpanded: true,
        hint: Text(widget.emptyPrompt, overflow: TextOverflow.ellipsis),
        decoration: InputDecoration(
          labelText: widget.label,
          floatingLabelBehavior: FloatingLabelBehavior.always,
          border: const OutlineInputBorder(),
          prefixIcon: Icon(widget.prefixIcon),
        ),
        items: [
          ...widget.items,
          if (widget.onAdd != null)
            DropdownMenuItem(
              value: widget.addValue,
              child: Row(
                children: [
                  const Icon(Icons.add_outlined),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.emptyPrompt,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
        ],
        onChanged: (value) {
          if (value == widget.addValue) {
            _openAddAfterClose();
            return;
          }
          widget.onChanged(value);
        },
      ),
    );
  }
}

class _WorkoutOverviewList extends StatelessWidget {
  const _WorkoutOverviewList({
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
