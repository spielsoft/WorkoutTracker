part of 'workout_tracker_shell.dart';

const _addWorkoutMenuValue = '__workout_tracker_add_workout__';
const _addHistoryBlockMenuValue = '__workout_tracker_add_history_block__';

class _ScreenHeader extends StatelessWidget {
  const _ScreenHeader({
    required this.title,
    required this.backTooltip,
    required this.onBack,
    this.subtitle,
    this.compactTitle = false,
    this.trailing,
  });

  final String title;
  final String backTooltip;
  final VoidCallback onBack;
  final String? subtitle;
  final bool compactTitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final subtitle = this.subtitle;
    return Row(
      children: [
        IconButton(
          tooltip: backTooltip,
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back_outlined),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                key: compactTitle
                    ? const ValueKey('current-workout-sheet-label')
                    : null,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                softWrap: false,
                style: compactTitle
                    ? Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      )
                    : Theme.of(context).textTheme.headlineSmall,
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  softWrap: false,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: 8), trailing!],
      ],
    );
  }
}

class _WorkoutAndHistorySelection extends StatelessWidget {
  const _WorkoutAndHistorySelection({
    required this.setup,
    required this.sheetLabel,
    required this.screen,
    required this.onBackToSheetSelection,
    required this.onSelectWorkoutSetup,
    required this.onBackToWorkoutSetup,
    required this.onOpenExerciseManager,
    required this.canonicalExerciseBeingEdited,
    required this.onWorkoutChanged,
    required this.onHistoryBlockChanged,
    required this.onAddWorkout,
    required this.onAddHistoryBlock,
    required this.onCreateCanonicalExercise,
    required this.onEditCanonicalExercise,
    required this.highlightedCanonicalExerciseName,
    required this.onReorderCanonicalExercises,
    required this.onReorderWorkoutExercises,
    required this.onOpenExercise,
    required this.onAddPrimaryExercise,
    required this.onAddBackupExercise,
    required this.exerciseAddReturnScreen,
    required this.addExercisePlacementIntent,
    required this.onCloseExerciseAdd,
    required this.onSubmitCanonicalExercise,
    required this.onSubmitCanonicalExerciseEdit,
    required this.onCloseExerciseEdit,
    required this.onSubmitExercisePlacement,
    required this.onSubmitExercisePlacementAndAddAnother,
    required this.onCloseExercise,
    required this.onLoggingRowChanged,
    required this.onApplyWritePlan,
  });

  final WorkoutSetupReadModel setup;
  final String sheetLabel;
  final _WorkoutTrackerScreen screen;
  final VoidCallback onBackToSheetSelection;
  final VoidCallback onSelectWorkoutSetup;
  final VoidCallback onBackToWorkoutSetup;
  final VoidCallback onOpenExerciseManager;
  final CanonicalExercise? canonicalExerciseBeingEdited;
  final ValueChanged<String?> onWorkoutChanged;
  final ValueChanged<String?> onHistoryBlockChanged;
  final VoidCallback? onAddWorkout;
  final VoidCallback? onAddHistoryBlock;
  final VoidCallback? onCreateCanonicalExercise;
  final ValueChanged<CanonicalExercise>? onEditCanonicalExercise;
  final String? highlightedCanonicalExerciseName;
  final Future<bool> Function(ReorderIntent intent)?
  onReorderCanonicalExercises;
  final Future<bool> Function(ReorderIntent intent)? onReorderWorkoutExercises;
  final ValueChanged<int> onOpenExercise;
  final ValueChanged<String> onAddPrimaryExercise;
  final ValueChanged<WorkoutOverviewSlot> onAddBackupExercise;
  final _WorkoutTrackerScreen exerciseAddReturnScreen;
  final _AddExercisePlacementIntent? addExercisePlacementIntent;
  final VoidCallback onCloseExerciseAdd;
  final ValueChanged<CanonicalExerciseDraft> onSubmitCanonicalExercise;
  final ValueChanged<CanonicalExerciseDraft> onSubmitCanonicalExerciseEdit;
  final VoidCallback onCloseExerciseEdit;
  final ValueChanged<_ExercisePlacementDraft> onSubmitExercisePlacement;
  final Future<bool> Function(_ExercisePlacementDraft draft)
  onSubmitExercisePlacementAndAddAnother;
  final VoidCallback onCloseExercise;
  final ValueChanged<int> onLoggingRowChanged;
  final Future<bool> Function(ActiveSheetWritePlan plan) onApplyWritePlan;

  @override
  Widget build(BuildContext context) {
    final activeSheet = setup.activeSheet;
    final workouts = setup.workouts;
    final historyBlocks = setup.historyBlocks;
    final selectedWorkout = setup.selectedWorkout;
    final selectedHistoryBlock = setup.selectedHistoryBlock;
    final overview = setup.overview;

    if (screen == _WorkoutTrackerScreen.exerciseLogging &&
        setup.loggingTarget != null) {
      final target = setup.loggingTarget!;
      return _ExerciseLoggingScreen(
        sheetLabel: sheetLabel,
        activeSheet: activeSheet,
        historyBlockLabel: target.historyBlockLabel,
        primarySheetRowNumber: target.primarySheetRowNumber,
        selectedSheetRowNumber: target.selectedSheetRowNumber,
        onChoiceChanged: onLoggingRowChanged,
        onClose: onCloseExercise,
        onApplyWritePlan: onApplyWritePlan,
      );
    }

    if (screen == _WorkoutTrackerScreen.addExercise) {
      final intent = addExercisePlacementIntent;
      if (intent != null) {
        final backTooltip =
            exerciseAddReturnScreen == _WorkoutTrackerScreen.workoutSetup
            ? 'Back to workout setup'
            : 'Back to exercises';
        return _AddExercisePlacementScreen(
          sheetLabel: sheetLabel,
          intent: intent,
          exercises: activeSheet.canonicalExercises,
          backTooltip: backTooltip,
          onBack: onCloseExerciseAdd,
          onSubmit: onSubmitExercisePlacement,
          onSubmitAndAddAnother: onSubmitExercisePlacementAndAddAnother,
        );
      }
      return _CanonicalExerciseCreationScreen(
        sheetLabel: sheetLabel,
        backTooltip:
            exerciseAddReturnScreen == _WorkoutTrackerScreen.exerciseManager
            ? 'Back to edit exercises'
            : 'Back to workout setup',
        onBack: onCloseExerciseAdd,
        onSubmit: onSubmitCanonicalExercise,
      );
    }

    if (screen == _WorkoutTrackerScreen.editExercise &&
        canonicalExerciseBeingEdited != null) {
      return _CanonicalExerciseEditScreen(
        sheetLabel: sheetLabel,
        exercise: canonicalExerciseBeingEdited!,
        onBack: onCloseExerciseEdit,
        onSubmit: onSubmitCanonicalExerciseEdit,
      );
    }

    if (screen == _WorkoutTrackerScreen.exerciseManager) {
      return _ExerciseManagerInventory(
        sheetLabel: sheetLabel,
        exercises: activeSheet.canonicalExercises,
        onBack: onBackToWorkoutSetup,
        onAddExercise: onCreateCanonicalExercise,
        onEditExercise: onEditCanonicalExercise,
        onReorderExercises: onReorderCanonicalExercises,
        highlightedExerciseName: highlightedCanonicalExerciseName,
      );
    }

    if (screen == _WorkoutTrackerScreen.exercisePicker) {
      final title = selectedWorkout == null || selectedHistoryBlock == null
          ? 'Exercises'
          : '$selectedWorkout - $selectedHistoryBlock';
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ScreenHeader(
            title: sheetLabel,
            subtitle: title,
            compactTitle: true,
            backTooltip: 'Back to workout setup',
            onBack: onBackToWorkoutSetup,
            trailing: selectedWorkout == null
                ? null
                : IconButton.filled(
                    key: const ValueKey('add-primary-exercise'),
                    tooltip: 'Add to workout',
                    onPressed: () => onAddPrimaryExercise(selectedWorkout),
                    icon: const Icon(Icons.add_outlined),
                  ),
          ),
          const SizedBox(height: 12),
          if (overview != null)
            _WorkoutOverviewList(
              key: const ValueKey('full-workout-overview'),
              overview: overview,
              onOpenExercise: onOpenExercise,
              onAddBackupExercise: onAddBackupExercise,
              onReorderExercises: onReorderWorkoutExercises,
              showTitle: false,
            ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ScreenHeader(
          title: sheetLabel,
          compactTitle: true,
          backTooltip: 'Back to sheet selection',
          onBack: onBackToSheetSelection,
          trailing: IconButton.filledTonal(
            key: const ValueKey('open-exercise-manager'),
            tooltip: 'Edit exercise library',
            onPressed: onOpenExerciseManager,
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
                  child: DropdownButtonFormField<String>(
                    initialValue: selectedWorkout,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Workout',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.fitness_center_outlined),
                    ),
                    items: [
                      for (final workout in workouts)
                        DropdownMenuItem(
                          value: workout,
                          child: Text(
                            '$workout ${setup.progressByWorkout[workout]!.label}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      if (onAddWorkout != null)
                        const DropdownMenuItem(
                          value: _addWorkoutMenuValue,
                          child: Row(
                            children: [
                              Icon(Icons.add_outlined),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Add workout...',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                    onChanged: (value) {
                      if (value == _addWorkoutMenuValue) {
                        onAddWorkout?.call();
                        return;
                      }
                      onWorkoutChanged(value);
                    },
                  ),
                ),
                SizedBox(
                  width: fieldWidth,
                  child: DropdownButtonFormField<String>(
                    key: ValueKey('history-block-$selectedHistoryBlock'),
                    initialValue: selectedHistoryBlock,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'History block',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.history_outlined),
                    ),
                    items: [
                      for (final block in historyBlocks)
                        DropdownMenuItem(
                          value: block.label,
                          child: Text(
                            block.label,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      if (onAddHistoryBlock != null)
                        const DropdownMenuItem(
                          value: _addHistoryBlockMenuValue,
                          child: Row(
                            children: [
                              Icon(Icons.add_outlined),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Add history block...',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                    onChanged: (value) {
                      if (value == _addHistoryBlockMenuValue) {
                        onAddHistoryBlock?.call();
                        return;
                      }
                      onHistoryBlockChanged(value);
                    },
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          key: const ValueKey('select-workout-setup'),
          onPressed: overview == null ? null : onSelectWorkoutSetup,
          icon: const Icon(Icons.check_circle_outline),
          label: const Text('Select'),
        ),
        const SizedBox(height: 16),
        if (overview != null)
          _WorkoutOverviewList(
            key: const ValueKey('compact-workout-overview'),
            overview: overview,
            onOpenExercise: onOpenExercise,
            onAddPrimaryExercise: selectedWorkout == null
                ? null
                : () => onAddPrimaryExercise(selectedWorkout),
            onAddBackupExercise: onAddBackupExercise,
            onReorderExercises: onReorderWorkoutExercises,
            compact: true,
          ),
      ],
    );
  }
}

class _WorkoutOverviewList extends StatelessWidget {
  const _WorkoutOverviewList({
    super.key,
    required this.overview,
    required this.onOpenExercise,
    this.onAddPrimaryExercise,
    this.onAddBackupExercise,
    this.onReorderExercises,
    this.compact = false,
    this.showTitle = true,
  });

  final WorkoutOverview overview;
  final ValueChanged<int> onOpenExercise;
  final VoidCallback? onAddPrimaryExercise;
  final ValueChanged<WorkoutOverviewSlot>? onAddBackupExercise;
  final Future<bool> Function(ReorderIntent intent)? onReorderExercises;
  final bool compact;
  final bool showTitle;

  @override
  Widget build(BuildContext context) {
    return Column(
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
              if (onAddPrimaryExercise != null)
                IconButton.filled(
                  key: const ValueKey('add-primary-exercise-from-setup'),
                  tooltip: 'Add to workout',
                  onPressed: onAddPrimaryExercise,
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
                  onAddBackupExercise: onAddBackupExercise,
                  canReorder: onReorderExercises != null,
                  compact: compact,
                ),
              );
            },
          ),
      ],
    );
  }
}

class _WorkoutOverviewTile extends StatelessWidget {
  const _WorkoutOverviewTile({
    required this.index,
    required this.slot,
    required this.onOpenExercise,
    required this.onAddBackupExercise,
    required this.canReorder,
    required this.compact,
  });

  final int index;
  final WorkoutOverviewSlot slot;
  final ValueChanged<int> onOpenExercise;
  final ValueChanged<WorkoutOverviewSlot>? onAddBackupExercise;
  final bool canReorder;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final setLabel = slot.setCount == 1 ? '1 set' : '${slot.setCount} sets';
    final backupSummaryLabel = slot.backups.length == 1
        ? '1 backup'
        : '${slot.backups.length} backups';
    final backupActionButton = onAddBackupExercise == null
        ? null
        : Semantics(
            button: true,
            label: 'Backup actions for ${slot.exercise}',
            child: PopupMenuButton<_PrimaryExerciseAction>(
              key: ValueKey('backup-actions-${slot.sheetRowNumber}'),
              tooltip: 'Backup actions for ${slot.exercise}',
              icon: const Icon(Icons.alt_route_outlined),
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: _PrimaryExerciseAction.addBackup,
                  child: _PrimaryExerciseActionMenuItem(
                    exercise: slot.exercise,
                  ),
                ),
              ],
              onSelected: _handlePrimaryExerciseAction,
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
      onSecondaryTapDown: onAddBackupExercise == null
          ? null
          : (details) =>
                _showPrimaryExerciseMenu(context, details.globalPosition),
      onLongPressStart: onAddBackupExercise == null
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
                                    _StateChip(
                                      state: _WorkoutVisualState.backup,
                                      label: backupSummaryLabel,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(setLabel),
                            if (backupActionButton != null) ...[
                              const SizedBox(width: 4),
                              backupActionButton,
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
                                    _StateChip(
                                      state: _WorkoutVisualState.backup,
                                      label: backupSummaryLabel,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(setLabel),
                            if (backupActionButton != null) ...[
                              const SizedBox(width: 4),
                              backupActionButton,
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

  void _handlePrimaryExerciseAction(_PrimaryExerciseAction action) {
    if (action == _PrimaryExerciseAction.addBackup) {
      onAddBackupExercise?.call(slot);
    }
  }

  Future<void> _showPrimaryExerciseMenu(
    BuildContext context,
    Offset globalPosition,
  ) async {
    final onAddBackupExercise = this.onAddBackupExercise;
    if (onAddBackupExercise == null) {
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
        PopupMenuItem(
          value: _PrimaryExerciseAction.addBackup,
          child: _PrimaryExerciseActionMenuItem(exercise: slot.exercise),
        ),
      ],
    );
    if (selected == _PrimaryExerciseAction.addBackup) {
      onAddBackupExercise(slot);
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

enum _PrimaryExerciseAction { addBackup }

class _PrimaryExerciseActionMenuItem extends StatelessWidget {
  const _PrimaryExerciseActionMenuItem({required this.exercise});

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

class _AddExercisePlacementScreen extends StatelessWidget {
  const _AddExercisePlacementScreen({
    required this.sheetLabel,
    required this.intent,
    required this.exercises,
    required this.backTooltip,
    required this.onBack,
    required this.onSubmit,
    required this.onSubmitAndAddAnother,
  });

  final String sheetLabel;
  final _AddExercisePlacementIntent intent;
  final List<CanonicalExercise> exercises;
  final String backTooltip;
  final VoidCallback onBack;
  final ValueChanged<_ExercisePlacementDraft> onSubmit;
  final Future<bool> Function(_ExercisePlacementDraft draft)
  onSubmitAndAddAnother;

  @override
  Widget build(BuildContext context) {
    final isBackup = intent.kind == _ExercisePlacementKind.backup;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ScreenHeader(
          title: sheetLabel,
          subtitle: isBackup ? 'Add backup exercise' : 'Add to workout',
          compactTitle: true,
          backTooltip: backTooltip,
          onBack: onBack,
        ),
        const SizedBox(height: 16),
        _ExercisePlacementForm(
          exercises: exercises,
          initialExercise: null,
          onSubmit: onSubmit,
          onSubmitAndAddAnother: onSubmitAndAddAnother,
        ),
      ],
    );
  }
}

class _ExercisePlacementForm extends StatefulWidget {
  const _ExercisePlacementForm({
    required this.exercises,
    required this.initialExercise,
    required this.onSubmit,
    required this.onSubmitAndAddAnother,
  });

  final List<CanonicalExercise> exercises;
  final CanonicalExercise? initialExercise;
  final ValueChanged<_ExercisePlacementDraft> onSubmit;
  final Future<bool> Function(_ExercisePlacementDraft draft)
  onSubmitAndAddAnother;

  @override
  State<_ExercisePlacementForm> createState() => _ExercisePlacementFormState();
}

class _ExercisePlacementFormState extends State<_ExercisePlacementForm> {
  CanonicalExercise? _selectedExercise;
  late final TextEditingController _exerciseSearchController;
  late final TextEditingController _setsController;
  late final TextEditingController _repsController;
  late final TextEditingController _rpeController;
  late final TextEditingController _restController;
  late final TextEditingController _tempoController;
  late final TextEditingController _notesController;

  @override
  void initState() {
    super.initState();
    _exerciseSearchController = TextEditingController();
    _exerciseSearchController.addListener(_handleExerciseSearchChanged);
    _setsController = TextEditingController();
    _repsController = TextEditingController();
    _rpeController = TextEditingController();
    _restController = TextEditingController();
    _tempoController = TextEditingController();
    _notesController = TextEditingController();
    _selectedExercise = widget.initialExercise;
    _loadExerciseDefaults(_selectedExercise);
  }

  @override
  void didUpdateWidget(_ExercisePlacementForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.exercises.contains(_selectedExercise)) {
      _selectedExercise = widget.initialExercise;
      _loadExerciseDefaults(_selectedExercise);
    }
  }

  @override
  void dispose() {
    _exerciseSearchController.removeListener(_handleExerciseSearchChanged);
    _exerciseSearchController.dispose();
    _setsController.dispose();
    _repsController.dispose();
    _rpeController.dispose();
    _restController.dispose();
    _tempoController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _handleExerciseSearchChanged() {
    setState(() {});
  }

  void _loadExerciseDefaults(CanonicalExercise? exercise) {
    _setsController.text = exercise?.defaultSets ?? '';
    _repsController.text = exercise?.defaultReps ?? '';
    _rpeController.text = exercise?.defaultRpe ?? '';
    _restController.text = exercise?.defaultRest ?? '';
    _tempoController.text = exercise?.defaultTempo ?? '';
    _notesController.text = exercise?.notes ?? '';
  }

  void _clearSelectionForAnother() {
    setState(() {
      _selectedExercise = null;
      _exerciseSearchController.clear();
      _loadExerciseDefaults(null);
    });
  }

  WorkoutPlacementMetadata _metadataFromControllers() {
    return WorkoutPlacementMetadata(
      sets: _setsController.text.trim(),
      reps: _repsController.text.trim(),
      rpe: _rpeController.text.trim(),
      rest: _restController.text.trim(),
      tempo: _tempoController.text.trim(),
      notes: _notesController.text.trim(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final exercises = widget.exercises;
    final selectedExercise = _selectedExercise;
    final exerciseQuery = _exerciseSearchController.text.trim().toLowerCase();
    final matchingExercises = exerciseQuery.isEmpty
        ? exercises
        : exercises.where((exercise) {
            return exercise.displayName.toLowerCase().contains(exerciseQuery) ||
                exercise.description.toLowerCase().contains(exerciseQuery);
          }).toList();
    final selectableExercises =
        selectedExercise != null &&
            !matchingExercises.contains(selectedExercise)
        ? [selectedExercise, ...matchingExercises]
        : matchingExercises;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          key: const ValueKey('exercise-picker-search'),
          controller: _exerciseSearchController,
          decoration: InputDecoration(
            labelText: 'Search exercises',
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.search_outlined),
            suffixIcon: exerciseQuery.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Clear exercise search',
                    onPressed: _exerciseSearchController.clear,
                    icon: const Icon(Icons.clear_outlined),
                  ),
          ),
          textInputAction: TextInputAction.search,
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<CanonicalExercise>(
          key: const ValueKey('existing-exercise-selector'),
          initialValue: selectedExercise,
          hint: Text(
            exerciseQuery.isEmpty || selectableExercises.isNotEmpty
                ? 'Choose exercise'
                : 'No matching exercises',
          ),
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Exercise',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.fitness_center_outlined),
          ),
          items: [
            for (final exercise in selectableExercises)
              DropdownMenuItem(
                value: exercise,
                child: Text(
                  exercise.displayName,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: selectableExercises.isEmpty
              ? null
              : (exercise) {
                  setState(() {
                    _selectedExercise = exercise;
                    _loadExerciseDefaults(exercise);
                  });
                },
        ),
        if (selectedExercise != null) ...[
          const SizedBox(height: 12),
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
                    child: _PlacementMetadataField(
                      controller: _setsController,
                      labelText: 'Sets',
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  SizedBox(
                    width: fieldWidth,
                    child: _PlacementMetadataField(
                      controller: _repsController,
                      labelText: 'Reps',
                    ),
                  ),
                  SizedBox(
                    width: fieldWidth,
                    child: _PlacementMetadataField(
                      controller: _rpeController,
                      labelText: 'RPE',
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  SizedBox(
                    width: fieldWidth,
                    child: _PlacementMetadataField(
                      controller: _restController,
                      labelText: 'Rest',
                    ),
                  ),
                  SizedBox(
                    width: fieldWidth,
                    child: _PlacementMetadataField(
                      controller: _tempoController,
                      labelText: 'Tempo',
                    ),
                  ),
                  SizedBox(
                    width: fieldWidth,
                    child: _PlacementMetadataField(
                      controller: _notesController,
                      labelText: 'Notes',
                    ),
                  ),
                ],
              );
            },
          ),
        ],
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              key: const ValueKey('place-existing-exercise'),
              onPressed: selectedExercise == null
                  ? null
                  : () => widget.onSubmit(
                      _ExercisePlacementDraft(
                        exercise: selectedExercise,
                        metadata: _metadataFromControllers(),
                      ),
                    ),
              icon: const Icon(Icons.playlist_add_outlined),
              label: const Text('Add to workout'),
            ),
            OutlinedButton.icon(
              key: const ValueKey('place-existing-exercise-add-another'),
              onPressed: selectedExercise == null
                  ? null
                  : () async {
                      final added = await widget.onSubmitAndAddAnother(
                        _ExercisePlacementDraft(
                          exercise: selectedExercise,
                          metadata: _metadataFromControllers(),
                        ),
                      );
                      if (added) {
                        _clearSelectionForAnother();
                      }
                    },
              icon: const Icon(Icons.add_outlined),
              label: const Text('Add another'),
            ),
          ],
        ),
      ],
    );
  }
}

class _ExercisePlacementDraft {
  const _ExercisePlacementDraft({
    required this.exercise,
    required this.metadata,
  });

  final CanonicalExercise exercise;
  final WorkoutPlacementMetadata metadata;
}

class _PlacementMetadataField extends StatelessWidget {
  const _PlacementMetadataField({
    required this.controller,
    required this.labelText,
    this.keyboardType,
  });

  final TextEditingController controller;
  final String labelText;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: labelText,
        border: const OutlineInputBorder(),
      ),
      textInputAction: TextInputAction.next,
    );
  }
}

class _CanonicalExerciseCreationScreen extends StatelessWidget {
  const _CanonicalExerciseCreationScreen({
    required this.sheetLabel,
    required this.backTooltip,
    required this.onBack,
    required this.onSubmit,
  });

  final String sheetLabel;
  final String backTooltip;
  final VoidCallback onBack;
  final ValueChanged<CanonicalExerciseDraft> onSubmit;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ScreenHeader(
          title: sheetLabel,
          subtitle: 'New exercise',
          compactTitle: true,
          backTooltip: backTooltip,
          onBack: onBack,
        ),
        const SizedBox(height: 16),
        ExerciseAuthoringForm(
          authoringContext: ExerciseAuthoringContext.canonicalExercise,
          onCancel: onBack,
          onSubmit: onSubmit,
        ),
      ],
    );
  }
}

class _CanonicalExerciseEditScreen extends StatelessWidget {
  const _CanonicalExerciseEditScreen({
    required this.sheetLabel,
    required this.exercise,
    required this.onBack,
    required this.onSubmit,
  });

  final String sheetLabel;
  final CanonicalExercise exercise;
  final VoidCallback onBack;
  final ValueChanged<CanonicalExerciseDraft> onSubmit;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ScreenHeader(
          title: sheetLabel,
          subtitle: 'Edit exercise',
          compactTitle: true,
          backTooltip: 'Back to edit exercises',
          onBack: onBack,
        ),
        const SizedBox(height: 16),
        ExerciseAuthoringForm(
          authoringContext: ExerciseAuthoringContext.canonicalExercise,
          initialDraft: CanonicalExerciseDraft.fromExercise(exercise),
          onCancel: onBack,
          onSubmit: onSubmit,
        ),
      ],
    );
  }
}
