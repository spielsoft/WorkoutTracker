import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:workout_tracker/sheet_contract.dart';

import 'app_state_store.dart';
import 'exercise_logging_flow.dart';
import 'spreadsheet_validation.dart';
import 'spreadsheet_selection.dart';
import 'workout_tracker_controller.dart';

part 'workout_tracker_shell_account.dart';
part 'workout_tracker_shell_workout.dart';
part 'workout_tracker_shell_exercise_authoring.dart';
part 'workout_tracker_shell_logging.dart';
part 'workout_tracker_shell_validation.dart';

const _compactSegmentedButtonRadius = 8.0;

enum _WorkoutTrackerScreen {
  sheetSelection,
  workoutSetup,
  exercisePicker,
  addExercise,
  exerciseLogging,
}

enum _ExercisePlacementKind { primary, backup }

class _AddExercisePlacementIntent {
  const _AddExercisePlacementIntent.primary({required this.workout})
    : kind = _ExercisePlacementKind.primary,
      primarySheetRowNumber = null,
      primaryExercise = null;

  const _AddExercisePlacementIntent.backup({
    required this.workout,
    required this.primarySheetRowNumber,
    required this.primaryExercise,
  }) : kind = _ExercisePlacementKind.backup;

  final _ExercisePlacementKind kind;
  final String workout;
  final int? primarySheetRowNumber;
  final String? primaryExercise;
}

class WorkoutTrackerApp extends StatelessWidget {
  const WorkoutTrackerApp({
    required this.validationService,
    this.exerciseAuthoringService,
    this.accountSession,
    this.appStateStore,
    this.initialSpreadsheetText = '',
    this.initialSelectedSpreadsheet,
    this.spreadsheetPicker,
    this.spreadsheetOpener = const UrlLauncherSpreadsheetOpener(),
    super.key,
  });

  final SpreadsheetValidationService validationService;
  final ExerciseAuthoringService? exerciseAuthoringService;
  final GoogleAccountSession? accountSession;
  final AppStateStore? appStateStore;
  final String initialSpreadsheetText;
  final SelectedSpreadsheet? initialSelectedSpreadsheet;
  final SpreadsheetPicker? spreadsheetPicker;
  final SpreadsheetOpener spreadsheetOpener;

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
        exerciseAuthoringService: exerciseAuthoringService,
        accountSession: accountSession,
        appStateStore: appStateStore,
        initialSpreadsheetText: initialSpreadsheetText,
        initialSelectedSpreadsheet: initialSelectedSpreadsheet,
        spreadsheetPicker: spreadsheetPicker,
        spreadsheetOpener: spreadsheetOpener,
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

class _SelectedSpreadsheetChooser extends StatelessWidget {
  const _SelectedSpreadsheetChooser({
    required this.selectedSpreadsheet,
    required this.availability,
    required this.isBusy,
    this.accountSession,
    required this.onChooseSpreadsheet,
    required this.onCreateSpreadsheet,
  });

  final SelectedSpreadsheet? selectedSpreadsheet;
  final SpreadsheetPickerAvailability availability;
  final bool isBusy;
  final GoogleAccountSession? accountSession;
  final Future<void> Function() onChooseSpreadsheet;
  final Future<void> Function() onCreateSpreadsheet;

  @override
  Widget build(BuildContext context) {
    final selected = selectedSpreadsheet;
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.table_chart_outlined, color: colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    selected?.displayLabel ?? 'No workout sheet selected',
                    key: const ValueKey('selected-spreadsheet-label'),
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                if (accountSession != null) ...[
                  const SizedBox(width: 8),
                  _GoogleAccountMenu(accountSession: accountSession!),
                ],
              ],
            ),
            if (selected?.accountEmail != null) ...[
              const SizedBox(height: 4),
              Text(
                selected!.accountEmail!,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  key: const ValueKey('choose-google-spreadsheet'),
                  onPressed: isBusy || !availability.canChoose
                      ? null
                      : onChooseSpreadsheet,
                  icon: const Icon(Icons.drive_folder_upload_outlined),
                  label: const Text('Choose from Google Drive'),
                ),
                OutlinedButton.icon(
                  key: const ValueKey('create-google-spreadsheet'),
                  onPressed: isBusy || !availability.canCreate
                      ? null
                      : onCreateSpreadsheet,
                  icon: const Icon(Icons.add_to_drive_outlined),
                  label: const Text('Create in Google Drive'),
                ),
              ],
            ),
            if (availability.summary case final String summary) ...[
              const SizedBox(height: 8),
              Text(
                summary,
                key: const ValueKey('spreadsheet-picker-availability'),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SpreadsheetTextFallback extends StatelessWidget {
  const _SpreadsheetTextFallback({
    required this.controller,
    required this.isBusy,
    required this.onChanged,
    required this.onSubmitted,
    required this.onValidate,
    this.accountSession,
  });

  final TextEditingController controller;
  final bool isBusy;
  final VoidCallback onChanged;
  final VoidCallback onSubmitted;
  final Future<void> Function() onValidate;
  final GoogleAccountSession? accountSession;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextField(
                key: const ValueKey('spreadsheet-selection-input'),
                controller: controller,
                decoration: const InputDecoration(
                  labelText: 'Paste Google Sheets URL or ID',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.table_chart_outlined),
                ),
                onChanged: (_) => onChanged(),
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => onSubmitted(),
              ),
            ),
            if (accountSession != null) ...[
              const SizedBox(width: 8),
              _GoogleAccountMenu(accountSession: accountSession!),
            ],
          ],
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          key: const ValueKey('validate-spreadsheet'),
          onPressed: isBusy ? null : onValidate,
          icon: isBusy
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.verified_outlined),
          label: const Text('Select'),
        ),
      ],
    );
  }
}

class SpreadsheetValidationShell extends StatefulWidget {
  const SpreadsheetValidationShell({
    required this.validationService,
    this.exerciseAuthoringService,
    this.accountSession,
    this.appStateStore,
    required this.initialSpreadsheetText,
    this.initialSelectedSpreadsheet,
    this.spreadsheetPicker,
    required this.spreadsheetOpener,
    super.key,
  });

  final SpreadsheetValidationService validationService;
  final ExerciseAuthoringService? exerciseAuthoringService;
  final GoogleAccountSession? accountSession;
  final AppStateStore? appStateStore;
  final String initialSpreadsheetText;
  final SelectedSpreadsheet? initialSelectedSpreadsheet;
  final SpreadsheetPicker? spreadsheetPicker;
  final SpreadsheetOpener spreadsheetOpener;

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
  SelectedSpreadsheet? _selectedSpreadsheet;
  _WorkoutTrackerScreen _screen = _WorkoutTrackerScreen.sheetSelection;
  _WorkoutTrackerScreen _exerciseAddReturnScreen =
      _WorkoutTrackerScreen.exercisePicker;
  _AddExercisePlacementIntent? _addExercisePlacementIntent;

  @override
  void initState() {
    super.initState();
    _controller = WorkoutTrackerController(
      validationService: widget.validationService,
      exerciseAuthoringService: widget.exerciseAuthoringService,
    );
    _selectedSpreadsheet = widget.initialSelectedSpreadsheet;
    _spreadsheetController = TextEditingController(
      text:
          widget.initialSelectedSpreadsheet?.spreadsheetId ??
          widget.initialSpreadsheetText,
    );
    _spreadsheetController.addListener(_persistSpreadsheetText);
    _newHistoryBlockController = TextEditingController();
    unawaited(_restoreStartupState());
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

  Future<void> _restoreStartupState() async {
    await _restoreAccount();
    await _restoreSpreadsheetSelection();
  }

  Future<void> _restoreSpreadsheetSelection() async {
    SelectedSpreadsheet? savedSelection;
    WorkoutSelectionState? savedWorkoutSelection;
    String? savedText;
    try {
      savedSelection = await widget.appStateStore?.readSelectedSpreadsheet();
      savedWorkoutSelection = await widget.appStateStore
          ?.readWorkoutSelection();
      savedText = await widget.appStateStore?.readSpreadsheetText();
    } on Object {
      return;
    }
    if (!mounted) {
      return;
    }
    if (savedSelection != null) {
      setState(() {
        _selectedSpreadsheet = savedSelection;
        _spreadsheetController.text = savedSelection!.spreadsheetId;
      });
      await _validateSelectedSpreadsheet();
      _restoreWorkoutSelection(savedWorkoutSelection);
      return;
    }
    if (savedText != null && savedText != _spreadsheetController.text) {
      _spreadsheetController.text = savedText;
    }
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
    final selectedSpreadsheet = _selectedSpreadsheet;
    final selected = selectedSpreadsheet == null
        ? await _controller.validateSpreadsheetSelection(
            _spreadsheetController.text,
          )
        : await _controller.validateSelectedSpreadsheet(selectedSpreadsheet);
    final report = _controller.report;
    if (!mounted) {
      return;
    }
    setState(() {
      _screen = selected && report != null && !report.hasBlockingIssues
          ? _WorkoutTrackerScreen.workoutSetup
          : _WorkoutTrackerScreen.sheetSelection;
    });
  }

  Future<void> _chooseSpreadsheet() async {
    await _pickSpreadsheet((picker) => picker.chooseSpreadsheet());
  }

  Future<void> _createSpreadsheet() async {
    await _pickSpreadsheet((picker) => picker.createSpreadsheet());
  }

  Future<void> _pickSpreadsheet(
    Future<SelectedSpreadsheet?> Function(SpreadsheetPicker picker) action,
  ) async {
    final picker = widget.spreadsheetPicker;
    if (picker == null || _controller.isBusy) {
      return;
    }
    try {
      final selectedSpreadsheet = await action(picker);
      if (!mounted || selectedSpreadsheet == null) {
        return;
      }
      setState(() {
        _selectedSpreadsheet = selectedSpreadsheet;
        _spreadsheetController.text = selectedSpreadsheet.spreadsheetId;
      });
      try {
        await widget.appStateStore?.writeSelectedSpreadsheet(
          selectedSpreadsheet,
        );
      } on Object {
        // Selection still works for this session if persistence fails.
      }
      await _validateSelectedSpreadsheet();
    } on Object catch (error) {
      _controller.reportSpreadsheetSelectionFailure(error);
    }
  }

  void _usePastedSpreadsheetText() {
    setState(() {
      _selectedSpreadsheet = null;
    });
  }

  Future<void> _createHistoryBlock() async {
    final created = await _controller.createHistoryBlock(
      _newHistoryBlockController.text,
    );
    if (created && mounted) {
      _newHistoryBlockController.clear();
      _persistWorkoutSelection();
    }
  }

  Future<void> _repairUnambiguousFormulaIssues() async {
    final repaired = await _controller.repairUnambiguousFormulaIssues();
    final report = _controller.report;
    if (!mounted || !repaired) {
      return;
    }
    setState(() {
      _screen = report != null && !report.hasBlockingIssues
          ? _WorkoutTrackerScreen.workoutSetup
          : _WorkoutTrackerScreen.sheetSelection;
    });
  }

  Future<void> _repairFormulaIssue({
    required int activeSheetRowNumber,
    required int selectedExerciseSheetRowNumber,
  }) async {
    final repaired = await _controller.repairFormulaIssue(
      activeSheetRowNumber: activeSheetRowNumber,
      selectedExerciseSheetRowNumber: selectedExerciseSheetRowNumber,
    );
    final report = _controller.report;
    if (!mounted || !repaired) {
      return;
    }
    setState(() {
      _screen = report != null && !report.hasBlockingIssues
          ? _WorkoutTrackerScreen.workoutSetup
          : _WorkoutTrackerScreen.sheetSelection;
    });
  }

  Future<void> _openSelectedSpreadsheet() async {
    final report = _controller.report;
    if (report == null) {
      return;
    }
    try {
      await widget.spreadsheetOpener.openSpreadsheet(report.spreadsheetUrl);
    } on Object catch (error) {
      _controller.reportOpenSpreadsheetFailure(error);
    }
  }

  void _returnToSheetSelection() {
    _controller.closeExercise();
    _addExercisePlacementIntent = null;
    setState(() {
      _screen = _WorkoutTrackerScreen.sheetSelection;
    });
  }

  void _selectWorkoutSetup() {
    _addExercisePlacementIntent = null;
    setState(() {
      _screen = _WorkoutTrackerScreen.exercisePicker;
    });
  }

  void _returnToWorkoutSetup() {
    _controller.closeExercise();
    _addExercisePlacementIntent = null;
    setState(() {
      _screen = _WorkoutTrackerScreen.workoutSetup;
    });
  }

  void _openExercise(int primarySheetRowNumber) {
    _controller.openExercise(primarySheetRowNumber);
    setState(() {
      _screen = _WorkoutTrackerScreen.exerciseLogging;
    });
  }

  void _closeExercise() {
    _controller.closeExercise();
    setState(() {
      _screen = _WorkoutTrackerScreen.exercisePicker;
    });
  }

  void _openPrimaryExerciseAdd(String workout) {
    final returnScreen = _screen == _WorkoutTrackerScreen.workoutSetup
        ? _WorkoutTrackerScreen.workoutSetup
        : _WorkoutTrackerScreen.exercisePicker;
    _controller.closeExercise();
    setState(() {
      _exerciseAddReturnScreen = returnScreen;
      _addExercisePlacementIntent = _AddExercisePlacementIntent.primary(
        workout: workout,
      );
      _screen = _WorkoutTrackerScreen.addExercise;
    });
  }

  void _openBackupExerciseAdd(WorkoutOverviewSlot primarySlot) {
    final workout = _controller.workoutSetup?.selectedWorkout;
    if (workout == null) {
      return;
    }
    final returnScreen = _screen == _WorkoutTrackerScreen.workoutSetup
        ? _WorkoutTrackerScreen.workoutSetup
        : _WorkoutTrackerScreen.exercisePicker;
    _controller.closeExercise();
    setState(() {
      _exerciseAddReturnScreen = returnScreen;
      _addExercisePlacementIntent = _AddExercisePlacementIntent.backup(
        workout: workout,
        primarySheetRowNumber: primarySlot.sheetRowNumber,
        primaryExercise: primarySlot.exercise,
      );
      _screen = _WorkoutTrackerScreen.addExercise;
    });
  }

  void _closeExerciseAdd() {
    setState(() {
      _addExercisePlacementIntent = null;
      _screen = _exerciseAddReturnScreen;
    });
  }

  Future<void> _handleExerciseAddDraft(CanonicalExerciseDraft draft) async {
    final intent = _addExercisePlacementIntent;
    if (intent == null) {
      return;
    }
    final added = await _controller.addExerciseToWorkout(
      exercise: draft.toCanonicalExerciseDefinition(),
      placement: switch (intent.kind) {
        _ExercisePlacementKind.primary => ExercisePlacementTarget.primary(
          workout: intent.workout,
        ),
        _ExercisePlacementKind.backup => ExercisePlacementTarget.backup(
          primarySheetRowNumber: intent.primarySheetRowNumber!,
        ),
      },
    );
    if (!mounted || !added) {
      return;
    }
    _addExercisePlacementIntent = null;
    setState(() {
      _screen = _exerciseAddReturnScreen;
    });
  }

  void _selectWorkout(String? workout) {
    _controller.selectWorkout(workout);
    _persistWorkoutSelection();
    setState(() {
      _screen = _WorkoutTrackerScreen.workoutSetup;
    });
  }

  void _selectHistoryBlock(String? historyBlock) {
    _controller.selectHistoryBlock(historyBlock);
    _persistWorkoutSelection();
    setState(() {
      _screen = _WorkoutTrackerScreen.workoutSetup;
    });
  }

  void _restoreWorkoutSelection(WorkoutSelectionState? savedSelection) {
    final report = _controller.report;
    if (savedSelection == null ||
        report == null ||
        savedSelection.spreadsheetId != report.spreadsheetId) {
      return;
    }
    _controller.restoreWorkoutSelection(
      workout: savedSelection.workout,
      historyBlock: savedSelection.historyBlock,
    );
  }

  void _persistWorkoutSelection() {
    final store = widget.appStateStore;
    final report = _controller.report;
    final setup = _controller.workoutSetup;
    if (store == null || report == null || setup == null) {
      return;
    }
    unawaited(
      store
          .writeWorkoutSelection(
            WorkoutSelectionState(
              spreadsheetId: report.spreadsheetId,
              workout: setup.selectedWorkout,
              historyBlock: setup.selectedHistoryBlock,
            ),
          )
          .catchError((_) {}),
    );
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
            final showSheetSelection =
                _screen == _WorkoutTrackerScreen.sheetSelection ||
                report == null ||
                report.hasBlockingIssues;
            return ListView(
              padding: const EdgeInsets.all(24),
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 840),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (showSheetSelection) ...[
                        if (widget.spreadsheetPicker != null) ...[
                          _SelectedSpreadsheetChooser(
                            selectedSpreadsheet: _selectedSpreadsheet,
                            availability:
                                widget.spreadsheetPicker!.availability,
                            isBusy: isBusy,
                            accountSession: widget.accountSession,
                            onChooseSpreadsheet: _chooseSpreadsheet,
                            onCreateSpreadsheet: _createSpreadsheet,
                          ),
                        ] else
                          _SpreadsheetTextFallback(
                            controller: _spreadsheetController,
                            isBusy: isBusy,
                            accountSession: widget.accountSession,
                            onChanged: _usePastedSpreadsheetText,
                            onSubmitted: _validateSelectedSpreadsheet,
                            onValidate: _validateSelectedSpreadsheet,
                          ),
                        const SizedBox(height: 24),
                      ],
                      if (error != null) ...[
                        _IssuePanel(
                          icon: Icons.error_outline,
                          title: 'Connection or validation failed',
                          lines: [error],
                          tone: _IssueTone.error,
                        ),
                        const SizedBox(height: 16),
                      ],
                      if (showSheetSelection && report != null)
                        _ValidationSummary(
                          report: report,
                          onRepairUnambiguousFormulaIssues: isBusy
                              ? null
                              : _repairUnambiguousFormulaIssues,
                          onRepairFormulaIssue: isBusy
                              ? null
                              : _repairFormulaIssue,
                          onOpenSpreadsheet: isBusy
                              ? null
                              : _openSelectedSpreadsheet,
                        ),
                      if (!showSheetSelection)
                        _WorkoutAndHistorySelection(
                          setup: _controller.workoutSetup!,
                          screen: _screen,
                          newHistoryBlockController: _newHistoryBlockController,
                          onBackToSheetSelection: _returnToSheetSelection,
                          onSelectWorkoutSetup: _selectWorkoutSetup,
                          onBackToWorkoutSetup: _returnToWorkoutSetup,
                          onWorkoutChanged: _selectWorkout,
                          onHistoryBlockChanged: _selectHistoryBlock,
                          onOpenExercise: _openExercise,
                          onAddPrimaryExercise: _openPrimaryExerciseAdd,
                          onAddBackupExercise: _openBackupExerciseAdd,
                          addExercisePlacementIntent:
                              _addExercisePlacementIntent,
                          onCloseExerciseAdd: _closeExerciseAdd,
                          onSubmitExerciseAdd: _handleExerciseAddDraft,
                          onCloseExercise: _closeExercise,
                          onLoggingRowChanged: _controller.selectLoggingRow,
                          onApplyWritePlan:
                              _controller.applyActiveSheetWritePlan,
                          onCreateHistoryBlock: isBusy
                              ? null
                              : _createHistoryBlock,
                        ),
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
