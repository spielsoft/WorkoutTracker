import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:workout_tracker/google_sheets.dart';
import 'package:workout_tracker/sheet_contract.dart';

import 'app_state_store.dart';
import 'exercise_logging_flow.dart';
import 'spreadsheet_validation.dart';
import 'workout_tracker_controller.dart';

class WorkoutTrackerApp extends StatelessWidget {
  const WorkoutTrackerApp({
    required this.validationService,
    this.accountSession,
    this.appStateStore,
    this.initialSpreadsheetText = '',
    super.key,
  });

  final SpreadsheetValidationService validationService;
  final GoogleAccountSession? accountSession;
  final AppStateStore? appStateStore;
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
        appStateStore: appStateStore,
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
    this.appStateStore,
    required this.initialSpreadsheetText,
    super.key,
  });

  final SpreadsheetValidationService validationService;
  final GoogleAccountSession? accountSession;
  final AppStateStore? appStateStore;
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
    _spreadsheetController.addListener(_persistSpreadsheetText);
    _newHistoryBlockController = TextEditingController();
    unawaited(_restoreAccount());
    unawaited(_restoreSpreadsheetText());
  }

  @override
  void dispose() {
    _controller.dispose();
    _spreadsheetController.removeListener(_persistSpreadsheetText);
    _spreadsheetController.dispose();
    _newHistoryBlockController.dispose();
    super.dispose();
  }

  Future<void> _restoreAccount() async {
    try {
      await widget.accountSession?.restoreAccount();
    } on Object {
      // Silent restore is best-effort; explicit account actions still report.
    }
  }

  Future<void> _restoreSpreadsheetText() async {
    String? savedText;
    try {
      savedText = await widget.appStateStore?.readSpreadsheetText();
    } on Object {
      return;
    }
    if (!mounted ||
        savedText == null ||
        savedText == _spreadsheetController.text) {
      return;
    }
    _spreadsheetController.text = savedText;
  }

  void _persistSpreadsheetText() {
    final store = widget.appStateStore;
    if (store == null) {
      return;
    }
    unawaited(
      store
          .writeSpreadsheetText(_spreadsheetController.text)
          .catchError((_) {}),
    );
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: TextField(
                              key: const ValueKey(
                                'spreadsheet-selection-input',
                              ),
                              controller: _spreadsheetController,
                              decoration: const InputDecoration(
                                labelText:
                                    'Google Sheets URL or spreadsheet ID',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.table_chart_outlined),
                              ),
                              textInputAction: TextInputAction.done,
                              onSubmitted: (_) =>
                                  _validateSelectedSpreadsheet(),
                            ),
                          ),
                          if (widget.accountSession != null) ...[
                            const SizedBox(width: 8),
                            _GoogleAccountMenu(
                              accountSession: widget.accountSession!,
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        key: const ValueKey('validate-spreadsheet'),
                        onPressed: isBusy ? null : _validateSelectedSpreadsheet,
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
      await widget.accountSession.switchAccount(
        scopes: GoogleApisSheetsWriteClient.writeScopes,
      );
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
    final progressByWorkout = {
      for (final workout in workouts)
        workout: _progressForWorkout(workout, selectedHistoryBlock),
    };
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
                        '$workout ${progressByWorkout[workout]!.label}',
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

  _WorkoutProgress _progressForWorkout(
    String workout,
    String? historyBlockLabel,
  ) {
    final overview = activeSheet.buildWorkoutOverview(
      workout: workout,
      historyBlockLabel: historyBlockLabel ?? '',
    );
    final done = historyBlockLabel == null
        ? 0
        : overview.slots.where((slot) => slot.setCount > 0).length;
    return _WorkoutProgress(done: done, total: overview.slots.length);
  }
}

class _WorkoutProgress {
  const _WorkoutProgress({required this.done, required this.total});

  final int done;
  final int total;

  String get label => '($done/$total done)';
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
  late final ExerciseLoggingFlow _flow;

  @override
  void initState() {
    super.initState();
    _flow = _createFlow();
  }

  @override
  void didUpdateWidget(_ExerciseLoggingScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedSheetRowNumber != widget.selectedSheetRowNumber ||
        oldWidget.historyBlockLabel != widget.historyBlockLabel ||
        oldWidget.primarySheetRowNumber != widget.primarySheetRowNumber ||
        oldWidget.activeSheet != widget.activeSheet) {
      _flow.update(
        activeSheet: widget.activeSheet,
        historyBlockLabel: widget.historyBlockLabel,
        primarySheetRowNumber: widget.primarySheetRowNumber,
        selectedSheetRowNumber: widget.selectedSheetRowNumber,
      );
    }
  }

  @override
  void dispose() {
    _flow.dispose();
    super.dispose();
  }

  ExerciseLoggingFlow _createFlow() {
    return ExerciseLoggingFlow(
      activeSheet: widget.activeSheet,
      historyBlockLabel: widget.historyBlockLabel,
      primarySheetRowNumber: widget.primarySheetRowNumber,
      selectedSheetRowNumber: widget.selectedSheetRowNumber,
    );
  }

  Future<void> _saveStructuredSet() async {
    final plan = _flow.planStructuredSetSave();
    if (plan == null) {
      return;
    }

    final saved = await widget.onApplyWritePlan(plan);
    if (!saved) {
      return;
    }
    _flow.clearNewSetControllers();
  }

  Future<void> _saveRawSet(RowHistoryEntry entry) async {
    await widget.onApplyWritePlan(_flow.planRawSetEdit(entry));
  }

  Future<void> _saveStructuredSetEdit(RowHistoryEntry entry) async {
    final plan = _flow.planStructuredSetEdit(entry);
    if (plan == null) {
      return;
    }
    await widget.onApplyWritePlan(plan);
  }

  Future<void> _clearSet(RowHistoryEntry entry) async {
    await widget.onApplyWritePlan(_flow.planSetClear(entry));
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = _flow.viewModel;
    final loggingContext = viewModel.context;
    final selectedChoice = loggingContext.selectedChoice;

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
          selectedChoice.exercise,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final direction = constraints.maxWidth < 520
                ? Axis.vertical
                : Axis.horizontal;
            return SegmentedButton<int>(
              direction: direction,
              segments: [
                for (final choice in loggingContext.choices)
                  ButtonSegment(
                    value: choice.sheetRowNumber,
                    label: Text(
                      choice.exercise,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
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
            );
          },
        ),
        const SizedBox(height: 16),
        _ExerciseContextPanel(
          context: loggingContext,
          latestHistoryValue: viewModel.latestHistoryValue,
        ),
        const SizedBox(height: 16),
        Text(
          'Next set S${viewModel.nextSetNumber}',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        _StructuredSetEditor(
          logFormat: loggingContext.logFormat,
          controllers: viewModel.newSetControllers,
          onSave: _saveStructuredSet,
        ),
        const SizedBox(height: 16),
        Text('Logged sets', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        if (viewModel.loggedEntries.isEmpty)
          const Text('No sets logged in this block.')
        else
          for (final entry in viewModel.loggedEntries)
            if (entry.logEntry case FormattedLogEntry(:final fieldLabels))
              _LoggedFormattedSetEditor(
                entry: entry,
                fieldLabels: fieldLabels,
                controllers:
                    viewModel.loggedFormattedControllers[entry.setNumber]!,
                onSave: () => _saveStructuredSetEdit(entry),
                onClear: () => _clearSet(entry),
              )
            else
              _LoggedSetEditor(
                entry: entry,
                controller: viewModel.rawControllers[entry.setNumber]!,
                onSave: () => _saveRawSet(entry),
                onClear: () => _clearSet(entry),
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
  const _ExerciseContextPanel({
    required this.context,
    required this.latestHistoryValue,
  });

  final ExerciseLoggingContext context;
  final String? latestHistoryValue;

  @override
  Widget build(BuildContext context) {
    final targets = this.context.targets;
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
            if (latestHistoryValue != null)
              Text('Latest history: $latestHistoryValue'),
          ],
        ),
      ),
    );
  }
}

class _StructuredSetEditor extends StatelessWidget {
  const _StructuredSetEditor({
    required this.logFormat,
    required this.controllers,
    required this.onSave,
  });

  final LogFormatParseResult logFormat;
  final Map<String, TextEditingController> controllers;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final fieldLabels = switch (logFormat) {
      ParsedLogFormat(:final fieldLabels) => fieldLabels,
      InvalidLogFormat() => const <String>[],
    };
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final label in fieldLabels)
          SizedBox(
            width: 112,
            child: TextField(
              key: ValueKey('set-field-$label'),
              controller: controllers[label],
              decoration: InputDecoration(
                labelText: label,
                border: const OutlineInputBorder(),
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

class _LoggedFormattedSetEditor extends StatelessWidget {
  const _LoggedFormattedSetEditor({
    required this.entry,
    required this.fieldLabels,
    required this.controllers,
    required this.onSave,
    required this.onClear,
  });

  final RowHistoryEntry entry;
  final List<String> fieldLabels;
  final Map<String, TextEditingController> controllers;
  final VoidCallback onSave;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(width: 36, child: Text(entry.setLabel)),
          for (final label in fieldLabels)
            SizedBox(
              width: 112,
              child: TextField(
                key: ValueKey('logged-${entry.setLabel}-field-$label'),
                controller: controllers[label],
                decoration: InputDecoration(
                  labelText: label,
                  border: const OutlineInputBorder(),
                ),
              ),
            ),
          IconButton(
            key: ValueKey('save-${entry.setLabel}'),
            tooltip: 'Save structured set',
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
    final entries = block.entries
        .where((entry) => entry.rawValue.trim().isNotEmpty)
        .toList();
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(block.label, style: Theme.of(context).textTheme.labelLarge),
          Wrap(
            spacing: 16,
            runSpacing: 4,
            children: [
              for (final entry in entries)
                Text('${entry.setLabel}: ${entry.rawValue}'),
            ],
          ),
        ],
      ),
    );
  }
}

class _ValidationSummary extends StatelessWidget {
  const _ValidationSummary({required this.report});

  final SpreadsheetValidationReport report;

  @override
  Widget build(BuildContext context) {
    final panels = <Widget>[
      if (report.hasBlockingSchemaViolations)
        _IssuePanel(
          icon: Icons.report_problem_outlined,
          title: 'Sheet contract issues',
          lines: report.schemaViolations.map(_schemaViolationLine).toList(),
          tone: _IssueTone.error,
        ),
      if (report.formulaHealingIssues.isNotEmpty)
        _IssuePanel(
          icon: Icons.build_outlined,
          title: 'Formula repair needed',
          lines: report.formulaHealingIssues
              .expand(_formulaHealingIssueLines)
              .toList(),
          tone: _IssueTone.warning,
        ),
    ];

    if (panels.isEmpty) {
      return const SizedBox.shrink();
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

enum _IssueTone { error, warning }

class _IssuePanel extends StatelessWidget {
  const _IssuePanel({
    required this.icon,
    required this.title,
    required this.lines,
    required this.tone,
  });

  final IconData icon;
  final String title;
  final List<String> lines;
  final _IssueTone tone;

  @override
  Widget build(BuildContext context) {
    final colors = _colorsForTone(Theme.of(context).colorScheme, tone);
    return DecoratedBox(
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
  }
}
