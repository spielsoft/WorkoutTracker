part of 'shell.dart';

const _addWorkoutMenuValue = '__workout_tracker_add_workout__';
const _addBlockMenuValue = '__workout_tracker_add_history_block__';

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
              _A11yHeader(
                label: subtitle == null ? title : '$title, $subtitle',
                child: Text(
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

class _WorkoutPane extends StatelessWidget {
  const _WorkoutPane({
    required this.setup,
    required this.sheetLabel,
    required this.screen,
    required this.onBackToSheets,
    required this.onOpenSetup,
    required this.onBackToSetup,
    required this.onOpenLibrary,
    required this.editingExercise,
    required this.onWorkoutChanged,
    required this.onHistoryBlockChanged,
    required this.onAddWorkout,
    required this.onAddHistoryBlock,
    required this.onCreateExercise,
    required this.onEditExercise,
    required this.highlightedExerciseRow,
    required this.onReorderExercises,
    required this.onReorderWorkout,
    required this.onOpenExercise,
    required this.onAddPrimary,
    required this.onAddBackup,
    required this.onDeleteExercise,
    required this.addReturnScreen,
    required this.addIntent,
    required this.onCloseExerciseAdd,
    required this.onSubmitExercise,
    required this.onSubmitExerciseEdit,
    required this.onCloseExerciseEdit,
    required this.onSubmitPlacement,
    required this.onSubmitAndAddAnother,
    required this.onCloseExercise,
    required this.onLoggingRowChanged,
    required this.onExecute,
  });

  final WorkoutSetupReadModel setup;
  final String sheetLabel;
  final _AppScreen screen;
  final VoidCallback onBackToSheets;
  final VoidCallback onOpenSetup;
  final VoidCallback onBackToSetup;
  final VoidCallback onOpenLibrary;
  final CanonicalExercise? editingExercise;
  final ValueChanged<String?> onWorkoutChanged;
  final ValueChanged<String?> onHistoryBlockChanged;
  final VoidCallback? onAddWorkout;
  final VoidCallback? onAddHistoryBlock;
  final VoidCallback? onCreateExercise;
  final ValueChanged<CanonicalExercise>? onEditExercise;
  final int? highlightedExerciseRow;
  final Future<bool> Function(ReorderIntent intent)? onReorderExercises;
  final Future<bool> Function(ReorderIntent intent)? onReorderWorkout;
  final ValueChanged<int> onOpenExercise;
  final ValueChanged<String> onAddPrimary;
  final ValueChanged<WorkoutOverviewSlot> onAddBackup;
  final ValueChanged<WorkoutOverviewSlot>? onDeleteExercise;
  final _AppScreen addReturnScreen;
  final _PlaceIntent? addIntent;
  final VoidCallback onCloseExerciseAdd;
  final ValueChanged<CanonicalExerciseDraft> onSubmitExercise;
  final ValueChanged<CanonicalExerciseDraft> onSubmitExerciseEdit;
  final VoidCallback onCloseExerciseEdit;
  final ValueChanged<_ExercisePlacementDraft> onSubmitPlacement;
  final Future<bool> Function(_ExercisePlacementDraft draft)
  onSubmitAndAddAnother;
  final VoidCallback onCloseExercise;
  final ValueChanged<int> onLoggingRowChanged;
  final Future<bool> Function(WbkCmd cmd) onExecute;

  @override
  Widget build(BuildContext context) {
    final activeSheet = setup.activeSheet;
    final workouts = setup.workouts;
    final historyBlocks = setup.historyBlocks;
    final selectedWorkout = setup.selectedWorkout;
    final selectedHistoryBlock = setup.selectedHistoryBlock;
    final overview = setup.overview;

    if (screen == _AppScreen.exerciseLogging && setup.loggingTarget != null) {
      final target = setup.loggingTarget!;
      return LogScreen(
        view: LogView(
          isBusy: false,
          setup: setup,
          sheetLabel: sheetLabel,
          target: target,
        ),
        run: _runLog,
      );
    }

    if (screen == _AppScreen.addExercise) {
      final intent = addIntent;
      if (intent != null) {
        final backTooltip = addReturnScreen == _AppScreen.workoutSetup
            ? 'Back to workout setup'
            : 'Back to exercises';
        return _PlaceExerciseScreen(
          sheetLabel: sheetLabel,
          intent: intent,
          exercises: activeSheet.canonicalExercises,
          backTooltip: backTooltip,
          onBack: onCloseExerciseAdd,
          onSubmit: onSubmitPlacement,
          onSubmitAndAddAnother: onSubmitAndAddAnother,
        );
      }
      return _CreateExerciseScreen(
        sheetLabel: sheetLabel,
        backTooltip: addReturnScreen == _AppScreen.exerciseManager
            ? 'Back to edit exercises'
            : 'Back to workout setup',
        onBack: onCloseExerciseAdd,
        onSubmit: onSubmitExercise,
      );
    }

    if (screen == _AppScreen.editExercise && editingExercise != null) {
      return _EditExerciseScreen(
        sheetLabel: sheetLabel,
        exercise: editingExercise!,
        onBack: onCloseExerciseEdit,
        onSubmit: onSubmitExerciseEdit,
      );
    }

    if (screen == _AppScreen.exerciseManager) {
      return _ExerciseLibrary(
        sheetLabel: sheetLabel,
        exercises: activeSheet.canonicalExercises,
        onBack: onBackToSetup,
        onAddExercise: onCreateExercise,
        onEditExercise: onEditExercise,
        onReorderExercises: onReorderExercises,
        highlightedRow: highlightedExerciseRow,
      );
    }

    if (screen == _AppScreen.exercisePicker) {
      final title = selectedWorkout == null || selectedHistoryBlock == null
          ? 'Exercises'
          : '$selectedWorkout - $selectedHistoryBlock';
      return _A11yScreen(
        label: '$title exercise list',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ScreenHeader(
              title: sheetLabel,
              subtitle: title,
              compactTitle: true,
              backTooltip: 'Back to workout setup',
              onBack: onBackToSetup,
              trailing: selectedWorkout == null
                  ? null
                  : IconButton.filled(
                      key: const ValueKey('add-primary-exercise'),
                      tooltip: 'Add to workout',
                      onPressed: () => onAddPrimary(selectedWorkout),
                      icon: const Icon(Icons.add_outlined),
                    ),
            ),
            const SizedBox(height: 12),
            if (overview != null)
              _WorkoutOverviewList(
                key: const ValueKey('full-workout-overview'),
                overview: overview,
                onOpenExercise: onOpenExercise,
                onAddBackup: onAddBackup,
                onDeleteExercise: onDeleteExercise,
                onReorderExercises: onReorderWorkout,
                showTitle: false,
              ),
          ],
        ),
      );
    }

    return _A11yScreen(
      label: 'Workout setup',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ScreenHeader(
            title: sheetLabel,
            compactTitle: true,
            backTooltip: 'Back to sheet selection',
            onBack: onBackToSheets,
            trailing: IconButton.filledTonal(
              key: const ValueKey('open-exercise-manager'),
              tooltip: 'Edit exercise library',
              onPressed: onOpenLibrary,
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
                      workouts: workouts,
                      selectedWorkout: selectedWorkout,
                      progressByWorkout: setup.progressByWorkout,
                      onWorkoutChanged: onWorkoutChanged,
                      onAddWorkout: onAddWorkout,
                    ),
                  ),
                  SizedBox(
                    width: fieldWidth,
                    child: _HistoryField(
                      historyBlocks: historyBlocks,
                      selectedHistoryBlock: selectedHistoryBlock,
                      onHistoryBlockChanged: onHistoryBlockChanged,
                      onAddHistoryBlock: onAddHistoryBlock,
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            key: const ValueKey('select-workout-setup'),
            onPressed: overview == null ? null : onOpenSetup,
            icon: const Icon(Icons.check_circle_outline),
            label: const Text('Select'),
          ),
          const SizedBox(height: 16),
          if (overview != null)
            _WorkoutOverviewList(
              key: const ValueKey('compact-workout-overview'),
              overview: overview,
              onOpenExercise: onOpenExercise,
              onAddPrimary: selectedWorkout == null
                  ? null
                  : () => onAddPrimary(selectedWorkout),
              onAddBackup: onAddBackup,
              onDeleteExercise: onDeleteExercise,
              onReorderExercises: onReorderWorkout,
              compact: true,
            ),
        ],
      ),
    );
  }

  Future<CmdResult> _runLog(LogCmd cmd) async {
    return switch (cmd) {
      CloseLog() => _closeLog(),
      SelectLogRow(:final sheetRow) => _selectLogRow(sheetRow),
      ExecuteWbk(:final cmd) => await _executeWbk(cmd),
    };
  }

  CmdResult _closeLog() {
    onCloseExercise();
    return const CmdResult.done();
  }

  CmdResult _selectLogRow(int sheetRow) {
    onLoggingRowChanged(sheetRow);
    return const CmdResult.done();
  }

  Future<CmdResult> _executeWbk(WbkCmd cmd) async {
    return await onExecute(cmd)
        ? const CmdResult.done()
        : const CmdResult.failed();
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
    return _A11yScreen(
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
                                    _StChip(
                                      state: _WorkoutVisualSt.backup,
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
                                    _StChip(
                                      state: _WorkoutVisualSt.backup,
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

class _PlaceExerciseScreen extends StatelessWidget {
  const _PlaceExerciseScreen({
    required this.sheetLabel,
    required this.intent,
    required this.exercises,
    required this.backTooltip,
    required this.onBack,
    required this.onSubmit,
    required this.onSubmitAndAddAnother,
  });

  final String sheetLabel;
  final _PlaceIntent intent;
  final List<CanonicalExercise> exercises;
  final String backTooltip;
  final VoidCallback onBack;
  final ValueChanged<_ExercisePlacementDraft> onSubmit;
  final Future<bool> Function(_ExercisePlacementDraft draft)
  onSubmitAndAddAnother;

  @override
  Widget build(BuildContext context) {
    final isBackup = intent.kind == _PlaceKind.backup;
    return _A11yScreen(
      label: isBackup ? 'Add backup exercise' : 'Add exercise to workout',
      child: Column(
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
          _PlaceForm(
            exercises: exercises,
            initialExercise: null,
            onSubmit: onSubmit,
            onSubmitAndAddAnother: onSubmitAndAddAnother,
          ),
        ],
      ),
    );
  }
}

class _PlaceForm extends StatefulWidget {
  const _PlaceForm({
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
  State<_PlaceForm> createState() => _PlaceFormSt();
}

class _PlaceFormSt extends State<_PlaceForm> {
  CanonicalExercise? _selectedExercise;
  late final TextEditingController _searchCtrl;
  late final TextEditingController _setsCtrl;
  late final TextEditingController _repsCtrl;
  late final TextEditingController _rpeCtrl;
  late final TextEditingController _restCtrl;
  late final TextEditingController _tempoCtrl;
  late final TextEditingController _notesCtrl;

  @override
  void initState() {
    super.initState();
    _searchCtrl = TextEditingController();
    _searchCtrl.addListener(_handleSearch);
    _setsCtrl = TextEditingController();
    _repsCtrl = TextEditingController();
    _rpeCtrl = TextEditingController();
    _restCtrl = TextEditingController();
    _tempoCtrl = TextEditingController();
    _notesCtrl = TextEditingController();
    _selectedExercise = widget.initialExercise;
    _loadDefaults(_selectedExercise);
  }

  @override
  void didUpdateWidget(_PlaceForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.exercises.contains(_selectedExercise)) {
      _selectedExercise = widget.initialExercise;
      _loadDefaults(_selectedExercise);
    }
  }

  @override
  void dispose() {
    _searchCtrl.removeListener(_handleSearch);
    _searchCtrl.dispose();
    _setsCtrl.dispose();
    _repsCtrl.dispose();
    _rpeCtrl.dispose();
    _restCtrl.dispose();
    _tempoCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  void _handleSearch() {
    setState(() {});
  }

  void _loadDefaults(CanonicalExercise? exercise) {
    _setsCtrl.text = exercise?.defaultSets ?? '';
    _repsCtrl.text = exercise?.defaultReps ?? '';
    _rpeCtrl.text = exercise?.defaultRpe ?? '';
    _restCtrl.text = exercise?.defaultRest ?? '';
    _tempoCtrl.text = exercise?.defaultTempo ?? '';
    _notesCtrl.text = exercise?.notes ?? '';
  }

  void _clearForNext() {
    setState(() {
      _selectedExercise = null;
      _searchCtrl.clear();
      _loadDefaults(null);
    });
  }

  WorkoutPlacementMetadata _metadata() {
    return WorkoutPlacementMetadata(
      sets: _setsCtrl.text.trim(),
      reps: _repsCtrl.text.trim(),
      rpe: _rpeCtrl.text.trim(),
      rest: _restCtrl.text.trim(),
      tempo: _tempoCtrl.text.trim(),
      notes: _notesCtrl.text.trim(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final exercises = widget.exercises;
    final selectedExercise = _selectedExercise;
    final exerciseQuery = _searchCtrl.text.trim().toLowerCase();
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
        _A11yTextField(
          label: 'Search exercises',
          valueListenable: _searchCtrl,
          child: TextField(
            key: const ValueKey('exercise-picker-search'),
            controller: _searchCtrl,
            decoration: InputDecoration(
              labelText: 'Search exercises',
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.search_outlined),
              suffixIcon: exerciseQuery.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear exercise search',
                      onPressed: _searchCtrl.clear,
                      icon: const Icon(Icons.clear_outlined),
                    ),
            ),
            textInputAction: TextInputAction.search,
          ),
        ),
        const SizedBox(height: 12),
        Semantics(
          label: 'Exercise selector',
          value: selectedExercise?.displayName ?? 'No exercise selected',
          hint: 'Choose an exercise',
          child: DropdownButtonFormField<CanonicalExercise>(
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
                      _loadDefaults(exercise);
                    });
                  },
          ),
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
                    child: _MetaField(
                      controller: _setsCtrl,
                      labelText: 'Sets',
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  SizedBox(
                    width: fieldWidth,
                    child: _MetaField(controller: _repsCtrl, labelText: 'Reps'),
                  ),
                  SizedBox(
                    width: fieldWidth,
                    child: _MetaField(
                      controller: _rpeCtrl,
                      labelText: 'RPE',
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  SizedBox(
                    width: fieldWidth,
                    child: _MetaField(controller: _restCtrl, labelText: 'Rest'),
                  ),
                  SizedBox(
                    width: fieldWidth,
                    child: _MetaField(
                      controller: _tempoCtrl,
                      labelText: 'Tempo',
                    ),
                  ),
                  SizedBox(
                    width: fieldWidth,
                    child: _MetaField(
                      controller: _notesCtrl,
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
                        metadata: _metadata(),
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
                          metadata: _metadata(),
                        ),
                      );
                      if (added) {
                        _clearForNext();
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

class _MetaField extends StatelessWidget {
  const _MetaField({
    required this.controller,
    required this.labelText,
    this.keyboardType,
  });

  final TextEditingController controller;
  final String labelText;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return _A11yTextField(
      label: labelText,
      valueListenable: controller,
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: labelText,
          border: const OutlineInputBorder(),
        ),
        textInputAction: TextInputAction.next,
      ),
    );
  }
}

class _CreateExerciseScreen extends StatelessWidget {
  const _CreateExerciseScreen({
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
    return _A11yScreen(
      label: 'New exercise',
      child: Column(
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
      ),
    );
  }
}

class _EditExerciseScreen extends StatelessWidget {
  const _EditExerciseScreen({
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
    return _A11yScreen(
      label: 'Edit exercise ${exercise.displayName}',
      child: Column(
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
      ),
    );
  }
}
