import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:workout_tracker/set_notation.dart';
import 'package:workout_tracker/sheet_contract.dart';

import 'spreadsheet_validation.dart';
import 'workout_tracker_controller.dart';

class WorkoutTrackerApp extends StatelessWidget {
  const WorkoutTrackerApp({
    required this.validationService,
    this.accountSession,
    this.initialSpreadsheetText = '',
    super.key,
  });

  final SpreadsheetValidationService validationService;
  final GoogleAccountSession? accountSession;
  final String initialSpreadsheetText;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WorkoutTracker',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0E7C66)),
        useMaterial3: true,
      ),
      scrollBehavior: const WorkoutTrackerScrollBehavior(),
      home: SpreadsheetValidationShell(
        validationService: validationService,
        accountSession: accountSession,
        initialSpreadsheetText: initialSpreadsheetText,
      ),
    );
  }
}

class WorkoutTrackerScrollBehavior extends MaterialScrollBehavior {
  const WorkoutTrackerScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices {
    return {
      PointerDeviceKind.touch,
      PointerDeviceKind.mouse,
      PointerDeviceKind.stylus,
      PointerDeviceKind.invertedStylus,
      PointerDeviceKind.trackpad,
    };
  }
}

class SpreadsheetValidationShell extends StatefulWidget {
  const SpreadsheetValidationShell({
    required this.validationService,
    this.accountSession,
    required this.initialSpreadsheetText,
    super.key,
  });

  final SpreadsheetValidationService validationService;
  final GoogleAccountSession? accountSession;
  final String initialSpreadsheetText;

  @override
  State<SpreadsheetValidationShell> createState() {
    return _SpreadsheetValidationShellState();
  }
}

class _SpreadsheetValidationShellState
    extends State<SpreadsheetValidationShell> {
  late final TextEditingController _spreadsheetController;
  late final TextEditingController _newHistoryBlockController;
  late final WorkoutTrackerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = WorkoutTrackerController(
      validationService: widget.validationService,
    );
    _spreadsheetController = TextEditingController(
      text: widget.initialSpreadsheetText,
    );
    _newHistoryBlockController = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    _spreadsheetController.dispose();
    _newHistoryBlockController.dispose();
    super.dispose();
  }

  Future<void> _validateSelectedSpreadsheet() async {
    await _controller.validateSpreadsheetSelection(_spreadsheetController.text);
  }

  Future<void> _createHistoryBlock() async {
    final created = await _controller.createHistoryBlock(
      _newHistoryBlockController.text,
    );
    if (created && mounted) {
      _newHistoryBlockController.clear();
    }
  }

  void _useDevelopmentSheet() {
    _spreadsheetController.text = workoutTrackerDevelopmentSpreadsheetUrl;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('WorkoutTracker'),
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        actions: [
          if (widget.accountSession != null)
            _GoogleAccountMenu(accountSession: widget.accountSession!),
        ],
      ),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: _controller,
          builder: (context, _) {
            final report = _controller.report;
            final error = _controller.error;
            final isBusy = _controller.isBusy;
            return ListView(
              padding: const EdgeInsets.all(24),
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 840),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        key: const ValueKey('spreadsheet-selection-input'),
                        controller: _spreadsheetController,
                        decoration: const InputDecoration(
                          labelText: 'Google Sheets URL or spreadsheet ID',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.table_chart_outlined),
                        ),
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _validateSelectedSpreadsheet(),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: FilledButton.icon(
                              key: const ValueKey('validate-spreadsheet'),
                              onPressed: isBusy
                                  ? null
                                  : _validateSelectedSpreadsheet,
                              icon: isBusy
                                  ? const SizedBox.square(
                                      dimension: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.verified_outlined),
                              label: const Text('Validate'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton.icon(
                              key: const ValueKey('use-development-sheet'),
                              onPressed: isBusy ? null : _useDevelopmentSheet,
                              icon: const Icon(Icons.science_outlined),
                              label: const Text('Development'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      if (error != null)
                        _IssuePanel(
                          icon: Icons.error_outline,
                          title: 'Connection or validation failed',
                          lines: [error],
                          tone: _IssueTone.error,
                        ),
                      if (report != null) ...[
                        _ValidationSummary(report: report),
                        if (!report.hasBlockingSchemaViolations) ...[
                          const SizedBox(height: 24),
                          _WorkoutAndHistorySelection(
                            activeSheet: report.activeSheet,
                            selectedWorkout: _controller.selectedWorkout,
                            selectedHistoryBlock:
                                _controller.selectedHistoryBlock,
                            loggingPrimarySheetRowNumber:
                                _controller.loggingPrimarySheetRowNumber,
                            selectedLoggingSheetRowNumber:
                                _controller.selectedLoggingSheetRowNumber,
                            newHistoryBlockController:
                                _newHistoryBlockController,
                            onWorkoutChanged: _controller.selectWorkout,
                            onHistoryBlockChanged:
                                _controller.selectHistoryBlock,
                            onOpenExercise: _controller.openExercise,
                            onCloseExercise: _controller.closeExercise,
                            onLoggingRowChanged: _controller.selectLoggingRow,
                            onApplyWritePlan:
                                _controller.applyActiveSheetWritePlan,
                            onCreateHistoryBlock: isBusy
                                ? null
                                : _createHistoryBlock,
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _GoogleAccountMenu extends StatefulWidget {
  const _GoogleAccountMenu({required this.accountSession});

  final GoogleAccountSession accountSession;

  @override
  State<_GoogleAccountMenu> createState() => _GoogleAccountMenuState();
}

class _GoogleAccountMenuState extends State<_GoogleAccountMenu> {
  bool _isSwitching = false;

  Future<void> _switchAccount() async {
    setState(() {
      _isSwitching = true;
    });
    try {
      await widget.accountSession.switchAccount();
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to switch Google accounts: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSwitching = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.accountSession,
      builder: (context, _) {
        final account = widget.accountSession.currentAccount;
        return PopupMenuButton<_GoogleAccountAction>(
          tooltip: account == null
              ? 'Google account'
              : 'Google account: ${account.email}',
          enabled: !_isSwitching,
          icon: _GoogleAccountAvatar(account: account, isBusy: _isSwitching),
          onSelected: (action) {
            switch (action) {
              case _GoogleAccountAction.switchAccount:
                _switchAccount();
            }
          },
          itemBuilder: (context) {
            return [
              PopupMenuItem<_GoogleAccountAction>(
                enabled: false,
                child: _GoogleAccountSummary(account: account),
              ),
              const PopupMenuDivider(),
              PopupMenuItem<_GoogleAccountAction>(
                value: _GoogleAccountAction.switchAccount,
                child: Row(
                  children: [
                    const Icon(Icons.switch_account_outlined),
                    const SizedBox(width: 12),
                    Text(account == null ? 'Sign in' : 'Switch account'),
                  ],
                ),
              ),
            ];
          },
        );
      },
    );
  }
}

enum _GoogleAccountAction { switchAccount }

class _GoogleAccountSummary extends StatelessWidget {
  const _GoogleAccountSummary({required this.account});

  final GoogleAccountProfile? account;

  @override
  Widget build(BuildContext context) {
    final account = this.account;
    final textTheme = Theme.of(context).textTheme;
    if (account == null) {
      return Text('No Google account selected', style: textTheme.bodyMedium);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          account.label,
          style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        Text(account.email, style: textTheme.bodySmall),
      ],
    );
  }
}

class _GoogleAccountAvatar extends StatelessWidget {
  const _GoogleAccountAvatar({required this.account, required this.isBusy});

  final GoogleAccountProfile? account;
  final bool isBusy;

  @override
  Widget build(BuildContext context) {
    if (isBusy) {
      return const SizedBox.square(
        dimension: 24,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }
    final account = this.account;
    if (account == null) {
      return const Icon(Icons.account_circle_outlined);
    }
    final photoUrl = account.photoUrl;
    if (photoUrl != null && photoUrl.isNotEmpty) {
      return CircleAvatar(radius: 13, backgroundImage: NetworkImage(photoUrl));
    }
    final initial = account.label.isEmpty
        ? '?'
        : account.label[0].toUpperCase();
    return CircleAvatar(radius: 13, child: Text(initial));
  }
}

class _WorkoutAndHistorySelection extends StatelessWidget {
  const _WorkoutAndHistorySelection({
    required this.activeSheet,
    required this.selectedWorkout,
    required this.selectedHistoryBlock,
    required this.loggingPrimarySheetRowNumber,
    required this.selectedLoggingSheetRowNumber,
    required this.newHistoryBlockController,
    required this.onWorkoutChanged,
    required this.onHistoryBlockChanged,
    required this.onOpenExercise,
    required this.onCloseExercise,
    required this.onLoggingRowChanged,
    required this.onApplyWritePlan,
    required this.onCreateHistoryBlock,
  });

  final ParsedActiveSheet activeSheet;
  final String? selectedWorkout;
  final String? selectedHistoryBlock;
  final int? loggingPrimarySheetRowNumber;
  final int? selectedLoggingSheetRowNumber;
  final TextEditingController newHistoryBlockController;
  final ValueChanged<String?> onWorkoutChanged;
  final ValueChanged<String?> onHistoryBlockChanged;
  final ValueChanged<int> onOpenExercise;
  final VoidCallback onCloseExercise;
  final ValueChanged<int> onLoggingRowChanged;
  final Future<bool> Function(ActiveSheetWritePlan plan) onApplyWritePlan;
  final VoidCallback? onCreateHistoryBlock;

  @override
  Widget build(BuildContext context) {
    final workouts = activeSheet.selectableWorkouts;
    final historyBlocks = activeSheet.historyBlocks;
    final selectedWorkout = workouts.contains(this.selectedWorkout)
        ? this.selectedWorkout
        : workouts.firstOrNull;
    final selectedHistoryBlock =
        historyBlocks.any((block) => block.label == this.selectedHistoryBlock)
        ? this.selectedHistoryBlock
        : historyBlocks.firstOrNull?.label;
    final overview = selectedWorkout == null || selectedHistoryBlock == null
        ? null
        : activeSheet.buildWorkoutOverview(
            workout: selectedWorkout,
            historyBlockLabel: selectedHistoryBlock,
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Workout setup', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            SizedBox(
              width: 260,
              child: DropdownButtonFormField<String>(
                initialValue: selectedWorkout,
                decoration: const InputDecoration(
                  labelText: 'Workout',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.fitness_center_outlined),
                ),
                items: [
                  for (final workout in workouts)
                    DropdownMenuItem(value: workout, child: Text(workout)),
                ],
                onChanged: onWorkoutChanged,
              ),
            ),
            SizedBox(
              width: 260,
              child: DropdownButtonFormField<String>(
                initialValue: selectedHistoryBlock,
                decoration: const InputDecoration(
                  labelText: 'History block',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.history_outlined),
                ),
                items: [
                  for (final block in historyBlocks)
                    DropdownMenuItem(
                      value: block.label,
                      child: Text(block.label),
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
        if (overview != null && loggingPrimarySheetRowNumber == null)
          _WorkoutOverviewList(
            overview: overview,
            onOpenExercise: onOpenExercise,
          ),
        if (selectedHistoryBlock != null &&
            loggingPrimarySheetRowNumber != null)
          _ExerciseLoggingScreen(
            activeSheet: activeSheet,
            historyBlockLabel: selectedHistoryBlock,
            primarySheetRowNumber: loggingPrimarySheetRowNumber!,
            selectedSheetRowNumber:
                selectedLoggingSheetRowNumber ?? loggingPrimarySheetRowNumber!,
            onChoiceChanged: onLoggingRowChanged,
            onClose: onCloseExercise,
            onApplyWritePlan: onApplyWritePlan,
          ),
      ],
    );
  }
}

class _WorkoutOverviewList extends StatelessWidget {
  const _WorkoutOverviewList({
    required this.overview,
    required this.onOpenExercise,
  });

  final WorkoutOverview overview;
  final ValueChanged<int> onOpenExercise;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '${overview.workout} exercises',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        for (final slot in overview.slots)
          _WorkoutOverviewTile(slot: slot, onOpenExercise: onOpenExercise),
      ],
    );
  }
}

class _WorkoutOverviewTile extends StatelessWidget {
  const _WorkoutOverviewTile({
    required this.slot,
    required this.onOpenExercise,
  });

  final WorkoutOverviewSlot slot;
  final ValueChanged<int> onOpenExercise;

  @override
  Widget build(BuildContext context) {
    final setLabel = slot.setCount == 1 ? '1 set' : '${slot.setCount} sets';
    return Padding(
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
            padding: const EdgeInsets.all(14),
            child: Column(
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
                for (final backup in slot.backups) ...[
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.only(left: 16),
                    child: Row(
                      children: [
                        const Icon(Icons.subdirectory_arrow_right, size: 18),
                        const SizedBox(width: 8),
                        Expanded(child: Text(backup.exercise)),
                      ],
                    ),
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

class _ExerciseLoggingScreen extends StatefulWidget {
  const _ExerciseLoggingScreen({
    required this.activeSheet,
    required this.historyBlockLabel,
    required this.primarySheetRowNumber,
    required this.selectedSheetRowNumber,
    required this.onChoiceChanged,
    required this.onClose,
    required this.onApplyWritePlan,
  });

  final ParsedActiveSheet activeSheet;
  final String historyBlockLabel;
  final int primarySheetRowNumber;
  final int selectedSheetRowNumber;
  final ValueChanged<int> onChoiceChanged;
  final VoidCallback onClose;
  final Future<bool> Function(ActiveSheetWritePlan plan) onApplyWritePlan;

  @override
  State<_ExerciseLoggingScreen> createState() => _ExerciseLoggingScreenState();
}

class _ExerciseLoggingScreenState extends State<_ExerciseLoggingScreen> {
  final _weightController = TextEditingController();
  final _repsController = TextEditingController();
  final _rpeController = TextEditingController(text: '8');
  final _painController = TextEditingController();
  final _noteController = TextEditingController();
  final _rawControllers = <int, TextEditingController>{};

  @override
  void initState() {
    super.initState();
    _syncRawControllers(_context);
  }

  @override
  void didUpdateWidget(_ExerciseLoggingScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedSheetRowNumber != widget.selectedSheetRowNumber ||
        oldWidget.historyBlockLabel != widget.historyBlockLabel ||
        oldWidget.activeSheet != widget.activeSheet) {
      _syncRawControllers(_context);
    }
  }

  @override
  void dispose() {
    _weightController.dispose();
    _repsController.dispose();
    _rpeController.dispose();
    _painController.dispose();
    _noteController.dispose();
    for (final controller in _rawControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  ExerciseLoggingContext get _context {
    return widget.activeSheet.buildExerciseLoggingContext(
      primarySheetRowNumber: widget.primarySheetRowNumber,
      selectedSheetRowNumber: widget.selectedSheetRowNumber,
      historyBlockLabel: widget.historyBlockLabel,
    );
  }

  void _syncRawControllers(ExerciseLoggingContext context) {
    final nonEmptyEntries = context.selectedHistory.entries.where(
      (entry) => entry.rawValue.trim().isNotEmpty,
    );
    final activeSetNumbers = {
      for (final entry in nonEmptyEntries) entry.setNumber,
    };
    final removedSetNumbers = _rawControllers.keys
        .where((setNumber) => !activeSetNumbers.contains(setNumber))
        .toList();
    for (final setNumber in removedSetNumbers) {
      _rawControllers.remove(setNumber)?.dispose();
    }
    for (final entry in nonEmptyEntries) {
      final controller = _rawControllers.putIfAbsent(
        entry.setNumber,
        TextEditingController.new,
      );
      if (controller.text != entry.rawValue) {
        controller.text = entry.rawValue;
      }
    }
  }

  Future<void> _saveStructuredSet(ExerciseLoggingContext context) async {
    final weight = _weightController.text.trim();
    final reps = _repsController.text.trim();
    final rpe = _rpeController.text.trim();
    if (weight.isEmpty || reps.isEmpty || rpe.isEmpty) {
      return;
    }

    final saved = await widget.onApplyWritePlan(
      widget.activeSheet.planSetLoggingWrite(
        historyBlockLabel: widget.historyBlockLabel,
        sheetRowNumber: context.selectedChoice.sheetRowNumber,
        set: LoggedSet(
          result: WeightedReps(weight: weight, reps: reps),
          rpe: rpe,
          pain: _blankToNull(_painController.text),
          note: _blankToNull(_noteController.text),
        ),
      ),
    );
    if (!saved) {
      return;
    }
    _weightController.clear();
    _repsController.clear();
    _painController.clear();
    _noteController.clear();
  }

  Future<void> _saveRawSet(
    ExerciseLoggingContext context,
    RowHistoryEntry entry,
  ) async {
    await widget.onApplyWritePlan(
      widget.activeSheet.planSetEdit(
        historyBlockLabel: widget.historyBlockLabel,
        sheetRowNumber: context.selectedChoice.sheetRowNumber,
        setNumber: entry.setNumber,
        set: RawSetNotation(_rawControllers[entry.setNumber]?.text ?? ''),
      ),
    );
  }

  Future<void> _clearSet(
    ExerciseLoggingContext context,
    RowHistoryEntry entry,
  ) async {
    await widget.onApplyWritePlan(
      widget.activeSheet.planSetClear(
        historyBlockLabel: widget.historyBlockLabel,
        sheetRowNumber: context.selectedChoice.sheetRowNumber,
        setNumber: entry.setNumber,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loggingContext = _context;
    final selectedChoice = loggingContext.selectedChoice;
    final loggedEntries =
        loggingContext.selectedHistory.entries
            .where((entry) => entry.rawValue.trim().isNotEmpty)
            .toList()
          ..sort((left, right) => right.setNumber.compareTo(left.setNumber));
    final nextSetNumber = _nextSetNumber(loggingContext.selectedHistory);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: widget.onClose,
            icon: const Icon(Icons.arrow_back_outlined),
            label: const Text('Back to exercises'),
          ),
        ),
        Text(
          '${selectedChoice.exercise} logging',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        SegmentedButton<int>(
          segments: [
            for (final choice in loggingContext.choices)
              ButtonSegment(
                value: choice.sheetRowNumber,
                label: Text(choice.exercise),
                icon: Icon(
                  choice.isBackup
                      ? Icons.alt_route_outlined
                      : Icons.fitness_center_outlined,
                ),
              ),
          ],
          selected: {selectedChoice.sheetRowNumber},
          onSelectionChanged: (selection) {
            widget.onChoiceChanged(selection.single);
          },
        ),
        const SizedBox(height: 16),
        _ExerciseContextPanel(context: loggingContext),
        const SizedBox(height: 16),
        Text(
          'Next set S$nextSetNumber',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        _StructuredSetEditor(
          weightController: _weightController,
          repsController: _repsController,
          rpeController: _rpeController,
          painController: _painController,
          noteController: _noteController,
          onSave: () => _saveStructuredSet(loggingContext),
        ),
        const SizedBox(height: 16),
        Text('Logged sets', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        if (loggedEntries.isEmpty)
          const Text('No sets logged in this block.')
        else
          for (final entry in loggedEntries)
            _LoggedSetEditor(
              entry: entry,
              controller: _rawControllers[entry.setNumber]!,
              onSave: () => _saveRawSet(loggingContext, entry),
              onClear: () => _clearSet(loggingContext, entry),
            ),
        const SizedBox(height: 16),
        Text('Recent history', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        if (loggingContext.recentHistoryBlocks.isEmpty)
          const Text('No row-local history yet.')
        else
          for (final block in loggingContext.recentHistoryBlocks)
            _RecentHistoryBlock(block: block),
      ],
    );
  }
}

class _ExerciseContextPanel extends StatelessWidget {
  const _ExerciseContextPanel({required this.context});

  final ExerciseLoggingContext context;

  @override
  Widget build(BuildContext context) {
    final targets = this.context.targets;
    final latestHistory = _latestHistoryValue(this.context);
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Target: ${targets.sets} sets x ${targets.reps} @ ${targets.rpe}',
            ),
            Text('Rest: ${this.context.rest}'),
            if (targets.tempo.trim().isNotEmpty)
              Text('Tempo: ${targets.tempo}'),
            if (this.context.notes.trim().isNotEmpty) Text(this.context.notes),
            if (latestHistory != null) Text('Latest history: $latestHistory'),
          ],
        ),
      ),
    );
  }
}

class _StructuredSetEditor extends StatelessWidget {
  const _StructuredSetEditor({
    required this.weightController,
    required this.repsController,
    required this.rpeController,
    required this.painController,
    required this.noteController,
    required this.onSave,
  });

  final TextEditingController weightController;
  final TextEditingController repsController;
  final TextEditingController rpeController;
  final TextEditingController painController;
  final TextEditingController noteController;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 96,
          child: TextField(
            key: const ValueKey('set-weight'),
            controller: weightController,
            decoration: const InputDecoration(
              labelText: 'Weight',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        SizedBox(
          width: 96,
          child: TextField(
            key: const ValueKey('set-reps'),
            controller: repsController,
            decoration: const InputDecoration(
              labelText: 'Reps',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        SizedBox(
          width: 96,
          child: TextField(
            key: const ValueKey('set-rpe'),
            controller: rpeController,
            decoration: const InputDecoration(
              labelText: 'RPE',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        SizedBox(
          width: 96,
          child: TextField(
            controller: painController,
            decoration: const InputDecoration(
              labelText: 'Pain',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        SizedBox(
          width: 180,
          child: TextField(
            controller: noteController,
            decoration: const InputDecoration(
              labelText: 'Set note',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        FilledButton.icon(
          onPressed: onSave,
          icon: const Icon(Icons.save_outlined),
          label: const Text('Save set'),
        ),
      ],
    );
  }
}

class _LoggedSetEditor extends StatelessWidget {
  const _LoggedSetEditor({
    required this.entry,
    required this.controller,
    required this.onSave,
    required this.onClear,
  });

  final RowHistoryEntry entry;
  final TextEditingController controller;
  final VoidCallback onSave;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 36, child: Text(entry.setLabel)),
          Expanded(
            child: TextField(
              key: ValueKey('raw-${entry.setLabel}'),
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Raw set text',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            key: ValueKey('save-${entry.setLabel}'),
            tooltip: 'Save raw set text',
            onPressed: onSave,
            icon: const Icon(Icons.check_outlined),
          ),
          IconButton(
            key: ValueKey('clear-${entry.setLabel}'),
            tooltip: 'Clear set',
            onPressed: onClear,
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
    );
  }
}

class _RecentHistoryBlock extends StatelessWidget {
  const _RecentHistoryBlock({required this.block});

  final RowHistoryBlock block;

  @override
  Widget build(BuildContext context) {
    final entries = block.entries.where(
      (entry) => entry.rawValue.trim().isNotEmpty,
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(block.label, style: Theme.of(context).textTheme.labelLarge),
          for (final entry in entries)
            Text('${block.label} ${entry.setLabel}: ${entry.rawValue}'),
        ],
      ),
    );
  }
}

int _nextSetNumber(RowHistoryBlock block) {
  for (final entry in block.entries) {
    if (entry.rawValue.trim().isEmpty) {
      return entry.setNumber;
    }
  }
  return block.entries.length + 1;
}

String? _blankToNull(String value) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

String? _latestHistoryValue(ExerciseLoggingContext context) {
  for (final block in context.recentHistoryBlocks) {
    for (final entry in block.entries) {
      if (entry.rawValue.trim().isNotEmpty) {
        return entry.rawValue;
      }
    }
  }
  return null;
}

class _ValidationSummary extends StatefulWidget {
  const _ValidationSummary({required this.report});

  final SpreadsheetValidationReport report;

  @override
  State<_ValidationSummary> createState() => _ValidationSummaryState();
}

class _ValidationSummaryState extends State<_ValidationSummary> {
  final _dismissedSuccessPanels = <String>{};

  @override
  void didUpdateWidget(_ValidationSummary oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.report != widget.report) {
      _dismissedSuccessPanels.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final report = widget.report;
    final panels = <Widget>[
      if (report.hasBlockingSchemaViolations ||
          !_dismissedSuccessPanels.contains('Sheet contract valid'))
        _IssuePanel(
          icon: report.hasBlockingSchemaViolations
              ? Icons.report_problem_outlined
              : Icons.check_circle_outline,
          title: report.hasBlockingSchemaViolations
              ? 'Sheet contract issues'
              : 'Sheet contract valid',
          lines: report.hasBlockingSchemaViolations
              ? report.schemaViolations.map(_schemaViolationLine).toList()
              : [
                  'No blocking schema errors found in spreadsheet '
                      '${report.spreadsheetId}.',
                ],
          tone: report.hasBlockingSchemaViolations
              ? _IssueTone.error
              : _IssueTone.success,
          onDismiss: report.hasBlockingSchemaViolations
              ? null
              : () => _dismissSuccessPanel('Sheet contract valid'),
        ),
    ];

    if (report.formulaHealingIssues.isEmpty) {
      if (!_dismissedSuccessPanels.contains('Formulas valid')) {
        panels.add(
          _IssuePanel(
            icon: Icons.check_circle_outline,
            title: 'Formulas valid',
            lines: const ['No formula repair issues found.'],
            tone: _IssueTone.success,
            onDismiss: () => _dismissSuccessPanel('Formulas valid'),
          ),
        );
      }
    } else {
      panels.add(
        _IssuePanel(
          icon: Icons.build_outlined,
          title: 'Formula repair needed',
          lines: report.formulaHealingIssues
              .expand(_formulaHealingIssueLines)
              .toList(),
          tone: _IssueTone.warning,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var index = 0; index < panels.length; index += 1) ...[
          if (index > 0) const SizedBox(height: 12),
          panels[index],
        ],
      ],
    );
  }

  void _dismissSuccessPanel(String title) {
    setState(() {
      _dismissedSuccessPanels.add(title);
    });
  }
}

String _schemaViolationLine(SchemaViolation violation) {
  return 'Row ${violation.sheetRowNumber}, ${violation.workout}: '
      '${violation.message}';
}

Iterable<String> _formulaHealingIssueLines(FormulaHealingIssue issue) sync* {
  final selection = issue.requiresUserSelection
      ? 'requires exercise selection'
      : 'preselects Exercises row ${issue.preselectedExerciseSheetRowNumber}';
  yield 'Row ${issue.activeSheetRowNumber}, ${issue.displayedExerciseName}: '
      '$selection.';
  for (final cell in issue.cells) {
    yield '${cell.columnName}: ${_formulaReasonLabel(cell.reason)}';
  }
}

String _formulaReasonLabel(FormulaHealingIssueReason reason) {
  switch (reason) {
    case FormulaHealingIssueReason.missingFormula:
      return 'missing formula';
    case FormulaHealingIssueReason.brokenFormula:
      return 'broken formula';
  }
}

enum _IssueTone { error, warning, success }

class _IssuePanel extends StatelessWidget {
  const _IssuePanel({
    required this.icon,
    required this.title,
    required this.lines,
    required this.tone,
    this.onDismiss,
  });

  final IconData icon;
  final String title;
  final List<String> lines;
  final _IssueTone tone;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    final colors = _colorsForTone(Theme.of(context).colorScheme, tone);
    final panel = DecoratedBox(
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: colors.foreground),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: colors.foreground,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (onDismiss != null) ...[
                  const SizedBox(width: 8),
                  Icon(Icons.close_outlined, color: colors.foreground),
                ],
              ],
            ),
            const SizedBox(height: 10),
            for (final line in lines)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(line),
              ),
          ],
        ),
      ),
    );
    if (onDismiss == null) {
      return panel;
    }
    return Semantics(
      button: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onDismiss,
        child: panel,
      ),
    );
  }
}

({Color background, Color border, Color foreground}) _colorsForTone(
  ColorScheme colorScheme,
  _IssueTone tone,
) {
  switch (tone) {
    case _IssueTone.error:
      return (
        background: colorScheme.errorContainer,
        border: colorScheme.error.withValues(alpha: 0.5),
        foreground: colorScheme.onErrorContainer,
      );
    case _IssueTone.warning:
      return (
        background: const Color(0xFFFFF6D6),
        border: const Color(0xFFB28A00),
        foreground: const Color(0xFF5F4600),
      );
    case _IssueTone.success:
      return (
        background: const Color(0xFFE6F4EA),
        border: const Color(0xFF4F9D69),
        foreground: const Color(0xFF145A32),
      );
  }
}
