part of 'workout_tracker_shell.dart';

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
    required this.onWorkoutChanged,
    required this.onHistoryBlockChanged,
    required this.onAddWorkout,
    required this.onAddHistoryBlock,
    required this.onCreateCanonicalExercise,
    required this.onOpenExercise,
    required this.onAddPrimaryExercise,
    required this.onAddBackupExercise,
    required this.addExercisePlacementIntent,
    required this.onCloseExerciseAdd,
    required this.onSubmitCanonicalExercise,
    required this.onSubmitExercisePlacement,
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
  final ValueChanged<String?> onWorkoutChanged;
  final ValueChanged<String?> onHistoryBlockChanged;
  final VoidCallback? onAddWorkout;
  final VoidCallback? onAddHistoryBlock;
  final VoidCallback? onCreateCanonicalExercise;
  final ValueChanged<int> onOpenExercise;
  final ValueChanged<String> onAddPrimaryExercise;
  final ValueChanged<WorkoutOverviewSlot> onAddBackupExercise;
  final _AddExercisePlacementIntent? addExercisePlacementIntent;
  final VoidCallback onCloseExerciseAdd;
  final ValueChanged<CanonicalExerciseDraft> onSubmitCanonicalExercise;
  final ValueChanged<_ExercisePlacementDraft> onSubmitExercisePlacement;
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
        return _AddExercisePlacementScreen(
          sheetLabel: sheetLabel,
          intent: intent,
          exercises: activeSheet.canonicalExercises,
          onBack: onCloseExerciseAdd,
          onSubmit: onSubmitExercisePlacement,
        );
      }
      return _CanonicalExerciseCreationScreen(
        sheetLabel: sheetLabel,
        onBack: onCloseExerciseAdd,
        onSubmit: onSubmitCanonicalExercise,
      );
    }

    if (screen == _WorkoutTrackerScreen.exerciseManager) {
      return _ExerciseManagerInventory(
        sheetLabel: sheetLabel,
        exercises: activeSheet.canonicalExercises,
        onBack: onBackToWorkoutSetup,
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
          title: sheetLabel,
          compactTitle: true,
          backTooltip: 'Back to sheet selection',
          onBack: onBackToSheetSelection,
          trailing: onCreateCanonicalExercise == null
              ? null
              : IconButton.filledTonal(
                  key: const ValueKey('create-canonical-exercise'),
                  tooltip: 'Create exercise',
                  onPressed: onCreateCanonicalExercise,
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      DropdownButtonFormField<String>(
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
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        key: const ValueKey('add-workout'),
                        onPressed: onAddWorkout,
                        icon: const Icon(Icons.add_outlined),
                        label: const Text('Add workout'),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: fieldWidth,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      DropdownButtonFormField<String>(
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
                        ],
                        onChanged: onHistoryBlockChanged,
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        key: const ValueKey('add-history-block'),
                        onPressed: onAddHistoryBlock,
                        icon: const Icon(Icons.add_outlined),
                        label: const Text('Add history'),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 24),
        OutlinedButton.icon(
          key: const ValueKey('open-exercise-manager'),
          onPressed: onOpenExerciseManager,
          icon: const Icon(Icons.edit_note_outlined),
          label: const Text('Edit exercises'),
        ),
        const SizedBox(height: 12),
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
    this.compact = false,
    this.showTitle = true,
  });

  final WorkoutOverview overview;
  final ValueChanged<int> onOpenExercise;
  final VoidCallback? onAddPrimaryExercise;
  final ValueChanged<WorkoutOverviewSlot>? onAddBackupExercise;
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
                  tooltip: 'Add exercise',
                  onPressed: onAddPrimaryExercise,
                  icon: const Icon(Icons.add_outlined),
                ),
            ],
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
    final backupSummaryLabel = slot.backups.length == 1
        ? '1 backup'
        : '${slot.backups.length} backups';
    final backupActionButton = onAddBackupExercise == null
        ? null
        : PopupMenuButton<_PrimaryExerciseAction>(
            key: ValueKey('backup-actions-${slot.sheetRowNumber}'),
            tooltip: 'Backup actions for ${slot.exercise}',
            icon: const Icon(Icons.alt_route_outlined),
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: _PrimaryExerciseAction.addBackup,
                child: _PrimaryExerciseActionMenuItem(),
              ),
            ],
            onSelected: _handlePrimaryExerciseAction,
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
                  ? Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                slot.exercise,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.titleMedium,
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
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Wrap(
                                spacing: 8,
                                runSpacing: 6,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Text(
                                    slot.exercise,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleMedium,
                                  ),
                                  if (slot.backups.isNotEmpty)
                                    _StateChip(
                                      state: _WorkoutVisualState.backup,
                                      label: backupSummaryLabel,
                                    ),
                                ],
                              ),
                            ),
                            Text(setLabel),
                            if (backupActionButton != null) ...[
                              const SizedBox(width: 4),
                              backupActionButton,
                            ],
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
                                      ConstrainedBox(
                                        constraints: const BoxConstraints(
                                          maxWidth: 240,
                                        ),
                                        child: Text(
                                          backup.exercise,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
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
      items: const [
        PopupMenuItem(
          value: _PrimaryExerciseAction.addBackup,
          child: _PrimaryExerciseActionMenuItem(),
        ),
      ],
    );
    if (selected == _PrimaryExerciseAction.addBackup) {
      onAddBackupExercise(slot);
    }
  }
}

enum _PrimaryExerciseAction { addBackup }

class _PrimaryExerciseActionMenuItem extends StatelessWidget {
  const _PrimaryExerciseActionMenuItem();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 220,
      child: Row(
        children: [
          Icon(Icons.subdirectory_arrow_right),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Add backup exercise',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _AddExercisePlacementScreen extends StatelessWidget {
  const _AddExercisePlacementScreen({
    required this.sheetLabel,
    required this.intent,
    required this.exercises,
    required this.onBack,
    required this.onSubmit,
  });

  final String sheetLabel;
  final _AddExercisePlacementIntent intent;
  final List<CanonicalExercise> exercises;
  final VoidCallback onBack;
  final ValueChanged<_ExercisePlacementDraft> onSubmit;

  @override
  Widget build(BuildContext context) {
    final isBackup = intent.kind == _ExercisePlacementKind.backup;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ScreenHeader(
          title: sheetLabel,
          subtitle: isBackup ? 'Add backup exercise' : 'Add exercise',
          compactTitle: true,
          backTooltip: 'Back to exercises',
          onBack: onBack,
        ),
        const SizedBox(height: 16),
        _ExercisePlacementForm(
          exercises: exercises,
          initialExercise: null,
          onSubmit: onSubmit,
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
  });

  final List<CanonicalExercise> exercises;
  final CanonicalExercise? initialExercise;
  final ValueChanged<_ExercisePlacementDraft> onSubmit;

  @override
  State<_ExercisePlacementForm> createState() => _ExercisePlacementFormState();
}

class _ExercisePlacementFormState extends State<_ExercisePlacementForm> {
  CanonicalExercise? _selectedExercise;
  late final TextEditingController _setsController;
  late final TextEditingController _repsController;
  late final TextEditingController _rpeController;
  late final TextEditingController _restController;
  late final TextEditingController _tempoController;
  late final TextEditingController _notesController;

  @override
  void initState() {
    super.initState();
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
    _setsController.dispose();
    _repsController.dispose();
    _rpeController.dispose();
    _restController.dispose();
    _tempoController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _loadExerciseDefaults(CanonicalExercise? exercise) {
    _setsController.text = exercise?.defaultSets ?? '';
    _repsController.text = exercise?.defaultReps ?? '';
    _rpeController.text = exercise?.defaultRpe ?? '';
    _restController.text = exercise?.defaultRest ?? '';
    _tempoController.text = exercise?.defaultTempo ?? '';
    _notesController.text = exercise?.notes ?? '';
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<CanonicalExercise>(
          key: const ValueKey('existing-exercise-selector'),
          initialValue: selectedExercise,
          hint: const Text('Choose exercise'),
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Exercise',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.fitness_center_outlined),
          ),
          items: [
            for (final exercise in exercises)
              DropdownMenuItem(
                value: exercise,
                child: Text(
                  exercise.displayName,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: exercises.isEmpty
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
    required this.onBack,
    required this.onSubmit,
  });

  final String sheetLabel;
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
          backTooltip: 'Back to workout setup',
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
