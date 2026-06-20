part of 'workout_tracker_shell.dart';

class _ScreenHeader extends StatelessWidget {
  const _ScreenHeader({
    required this.title,
    required this.backTooltip,
    required this.onBack,
    this.trailing,
  });

  final String title;
  final String backTooltip;
  final VoidCallback onBack;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          tooltip: backTooltip,
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back_outlined),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.headlineSmall),
        ),
        if (trailing != null) ...[const SizedBox(width: 8), trailing!],
      ],
    );
  }
}

class _WorkoutAndHistorySelection extends StatelessWidget {
  const _WorkoutAndHistorySelection({
    required this.setup,
    required this.screen,
    required this.newHistoryBlockController,
    required this.onBackToSheetSelection,
    required this.onSelectWorkoutSetup,
    required this.onBackToWorkoutSetup,
    required this.onWorkoutChanged,
    required this.onHistoryBlockChanged,
    required this.onOpenExercise,
    required this.onAddPrimaryExercise,
    required this.onAddBackupExercise,
    required this.addExercisePlacementIntent,
    required this.onCloseExerciseAdd,
    required this.onSubmitExerciseAdd,
    required this.onCloseExercise,
    required this.onLoggingRowChanged,
    required this.onApplyWritePlan,
    required this.onCreateHistoryBlock,
  });

  final WorkoutSetupReadModel setup;
  final _WorkoutTrackerScreen screen;
  final TextEditingController newHistoryBlockController;
  final VoidCallback onBackToSheetSelection;
  final VoidCallback onSelectWorkoutSetup;
  final VoidCallback onBackToWorkoutSetup;
  final ValueChanged<String?> onWorkoutChanged;
  final ValueChanged<String?> onHistoryBlockChanged;
  final ValueChanged<int> onOpenExercise;
  final ValueChanged<String> onAddPrimaryExercise;
  final ValueChanged<WorkoutOverviewSlot> onAddBackupExercise;
  final _AddExercisePlacementIntent? addExercisePlacementIntent;
  final VoidCallback onCloseExerciseAdd;
  final ValueChanged<CanonicalExerciseDraft> onSubmitExerciseAdd;
  final VoidCallback onCloseExercise;
  final ValueChanged<int> onLoggingRowChanged;
  final Future<bool> Function(ActiveSheetWritePlan plan) onApplyWritePlan;
  final VoidCallback? onCreateHistoryBlock;

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
        activeSheet: activeSheet,
        historyBlockLabel: target.historyBlockLabel,
        primarySheetRowNumber: target.primarySheetRowNumber,
        selectedSheetRowNumber: target.selectedSheetRowNumber,
        onChoiceChanged: onLoggingRowChanged,
        onClose: onCloseExercise,
        onApplyWritePlan: onApplyWritePlan,
      );
    }

    if (screen == _WorkoutTrackerScreen.addExercise &&
        addExercisePlacementIntent != null) {
      return _AddExercisePlacementScreen(
        intent: addExercisePlacementIntent!,
        onBack: onCloseExerciseAdd,
        onSubmit: onSubmitExerciseAdd,
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
            title: title,
            backTooltip: 'Back to workout setup',
            onBack: onBackToWorkoutSetup,
            trailing: selectedWorkout == null
                ? null
                : IconButton.filled(
                    key: const ValueKey('add-primary-exercise'),
                    tooltip: 'Add exercise',
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
              showTitle: false,
            ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ScreenHeader(
          title: 'Workout setup',
          backTooltip: 'Back to sheet selection',
          onBack: onBackToSheetSelection,
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            SizedBox(
              width: 260,
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
                ],
                onChanged: onWorkoutChanged,
              ),
            ),
            SizedBox(
              width: 260,
              child: DropdownButtonFormField<String>(
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
                      child: Text(block.label, overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: onHistoryBlockChanged,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 260,
              child: TextField(
                key: const ValueKey('new-history-block-label'),
                controller: newHistoryBlockController,
                decoration: const InputDecoration(
                  labelText: 'New history block label',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.add_chart_outlined),
                ),
                textInputAction: TextInputAction.done,
              ),
            ),
            FilledButton.icon(
              onPressed: onCreateHistoryBlock,
              icon: const Icon(Icons.add_outlined),
              label: const Text('Create history block'),
            ),
          ],
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
    this.onAddBackupExercise,
    this.compact = false,
    this.showTitle = true,
  });

  final WorkoutOverview overview;
  final ValueChanged<int> onOpenExercise;
  final ValueChanged<WorkoutOverviewSlot>? onAddBackupExercise;
  final bool compact;
  final bool showTitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showTitle) ...[
          Text(
            '${overview.workout} exercises',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
        ],
        for (final slot in overview.slots)
          _WorkoutOverviewTile(
            slot: slot,
            onOpenExercise: onOpenExercise,
            onAddBackupExercise: onAddBackupExercise,
            compact: compact,
          ),
      ],
    );
  }
}

class _WorkoutOverviewTile extends StatelessWidget {
  const _WorkoutOverviewTile({
    required this.slot,
    required this.onOpenExercise,
    required this.onAddBackupExercise,
    required this.compact,
  });

  final WorkoutOverviewSlot slot;
  final ValueChanged<int> onOpenExercise;
  final ValueChanged<WorkoutOverviewSlot>? onAddBackupExercise;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final setLabel = slot.setCount == 1 ? '1 set' : '${slot.setCount} sets';
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
                  ? Row(
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Flexible(
                                child: Text(
                                  slot.exercise,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),
                              ),
                              for (final backup in slot.backups) ...[
                                const SizedBox(width: 10),
                                const Icon(
                                  Icons.subdirectory_arrow_right,
                                  size: 18,
                                ),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    backup.exercise,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(setLabel),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                slot.exercise,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
                            Text(setLabel),
                          ],
                        ),
                        if (slot.backups.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Padding(
                            padding: const EdgeInsets.only(left: 16),
                            child: Wrap(
                              spacing: 16,
                              runSpacing: 6,
                              children: [
                                for (final backup in slot.backups)
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.subdirectory_arrow_right,
                                        size: 18,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(backup.exercise),
                                    ],
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
      items: const [
        PopupMenuItem(
          value: _PrimaryExerciseAction.addBackup,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.subdirectory_arrow_right),
              SizedBox(width: 8),
              Text('Add backup exercise'),
            ],
          ),
        ),
      ],
    );
    if (selected == _PrimaryExerciseAction.addBackup) {
      onAddBackupExercise(slot);
    }
  }
}

enum _PrimaryExerciseAction { addBackup }

class _AddExercisePlacementScreen extends StatelessWidget {
  const _AddExercisePlacementScreen({
    required this.intent,
    required this.onBack,
    required this.onSubmit,
  });

  final _AddExercisePlacementIntent intent;
  final VoidCallback onBack;
  final ValueChanged<CanonicalExerciseDraft> onSubmit;

  @override
  Widget build(BuildContext context) {
    final isBackup = intent.kind == _ExercisePlacementKind.backup;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ScreenHeader(
          title: isBackup ? 'Add backup exercise' : 'Add exercise',
          backTooltip: 'Back to exercises',
          onBack: onBack,
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(color: Theme.of(context).colorScheme.outline),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Wrap(
                spacing: 16,
                runSpacing: 8,
                children: [
                  Text('Workout: ${intent.workout}'),
                  if (isBackup) Text('Backup for: ${intent.primaryExercise}'),
                  if (isBackup)
                    Text('Primary row: ${intent.primarySheetRowNumber}'),
                ],
              ),
            ),
          ),
        ),
        ExerciseAuthoringForm(
          authoringContext: ExerciseAuthoringContext.workoutPlacement,
          onCancel: onBack,
          onSubmit: onSubmit,
        ),
      ],
    );
  }
}
