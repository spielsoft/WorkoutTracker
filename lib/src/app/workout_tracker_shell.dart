import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:workout_tracker/sheet_contract.dart';

import 'app_state_store.dart';
import 'exercise_logging_flow.dart';
import 'spreadsheet_validation.dart';
import 'workout_tracker_controller.dart';

part 'workout_tracker_shell_account.dart';
part 'workout_tracker_shell_workout.dart';
part 'workout_tracker_shell_logging.dart';
part 'workout_tracker_shell_validation.dart';

const _compactSegmentedButtonRadius = 8.0;

enum _WorkoutTrackerScreen {
  sheetSelection,
  workoutSetup,
  exercisePicker,
  exerciseLogging,
}

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
  _WorkoutTrackerScreen _screen = _WorkoutTrackerScreen.sheetSelection;

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
    final selected = await _controller.validateSpreadsheetSelection(
      _spreadsheetController.text,
    );
    final report = _controller.report;
    if (!mounted) {
      return;
    }
    setState(() {
      _screen =
          selected && report != null && !report.hasBlockingSchemaViolations
          ? _WorkoutTrackerScreen.workoutSetup
          : _WorkoutTrackerScreen.sheetSelection;
    });
  }

  Future<void> _createHistoryBlock() async {
    final created = await _controller.createHistoryBlock(
      _newHistoryBlockController.text,
    );
    if (created && mounted) {
      _newHistoryBlockController.clear();
    }
  }

  void _returnToSheetSelection() {
    _controller.closeExercise();
    setState(() {
      _screen = _WorkoutTrackerScreen.sheetSelection;
    });
  }

  void _selectWorkoutSetup() {
    setState(() {
      _screen = _WorkoutTrackerScreen.exercisePicker;
    });
  }

  void _returnToWorkoutSetup() {
    _controller.closeExercise();
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

  void _selectWorkout(String? workout) {
    _controller.selectWorkout(workout);
    setState(() {
      _screen = _WorkoutTrackerScreen.workoutSetup;
    });
  }

  void _selectHistoryBlock(String? historyBlock) {
    _controller.selectHistoryBlock(historyBlock);
    setState(() {
      _screen = _WorkoutTrackerScreen.workoutSetup;
    });
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
                report.hasBlockingSchemaViolations;
            return ListView(
              padding: const EdgeInsets.all(24),
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 840),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (showSheetSelection) ...[
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
                          label: const Text('Select'),
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
                        _ValidationSummary(report: report),
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
