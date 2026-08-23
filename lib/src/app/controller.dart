import 'package:flutter/foundation.dart';
import 'package:workout_tracker/contract.dart';

import 'validation.dart';
import 'selection.dart';

/// Owns the GUI-facing flow state derived from the latest validation report.
///
/// The Interface keeps spreadsheet validation, history-block creation, and
/// write-plan application behind one GUI-facing Module. Row selections are only
/// valid while [report] remains current, so the controller clears them whenever
/// workout or history selection changes or a new report is adopted.
class AppCtrl extends ChangeNotifier {
  AppCtrl({required this.svc});

  final WbkAccess svc;

  ValReport? _report;
  WbkSess? _sess;
  String? _error;
  String? _selectedWorkout;
  String? _selectedHistoryBlock;
  final List<String> _pendingWorkouts = [];
  int? _loggingPrimaryRow;
  int? _selectedLoggingRow;
  var _serviceActions = 0;
  var _mutationPending = false;
  ExeFormatImpact? _pendingFormatUpdate;
  int _validationEpoch = 0;
  bool _isDisposed = false;

  ValReport? get report => _report;

  String? get error => _error;

  void clearError() {
    if (_error == null) return;
    _error = null;
    notifyListeners();
  }

  bool get isBusy => _serviceActions > 0 || _mutationPending;

  ExeFormatImpact? get pendingFormatUpdate => _pendingFormatUpdate;

  WorkoutSetupReadModel? get workoutSetup {
    final report = _report;
    if (report == null) {
      return null;
    }
    if (report.hasBlockingIssues) {
      return null;
    }

    final activeSheet = report.activeSheet;
    final workouts = _workoutsFor(activeSheet);
    final historyBlocks = activeSheet.historyBlocks;
    final selectedWorkout = workouts.contains(_selectedWorkout)
        ? _selectedWorkout
        : workouts.firstOrNull;
    final selectedHistoryBlock =
        historyBlocks.any((block) => block.label == _selectedHistoryBlock)
        ? _selectedHistoryBlock
        : historyBlocks.firstOrNull?.label;
    final overview = selectedWorkout == null || selectedHistoryBlock == null
        ? null
        : activeSheet.buildWorkoutOverview(
            workout: selectedWorkout,
            blockLabel: selectedHistoryBlock,
          );

    return WorkoutSetupReadModel(
      activeSheet: activeSheet,
      workouts: workouts,
      historyBlocks: historyBlocks,
      selectedWorkout: selectedWorkout,
      selectedHistoryBlock: selectedHistoryBlock,
      overview: overview,
      progressByWorkout: {
        for (final workout in workouts)
          workout: _progressForWorkout(
            activeSheet: activeSheet,
            workout: workout,
            blockLabel: selectedHistoryBlock,
          ),
      },
      loggingTarget: _loggingTarget(
        overview: overview,
        selectedHistoryBlock: selectedHistoryBlock,
      ),
    );
  }

  Future<bool> validateSelection(String selection) async {
    final epoch = ++_validationEpoch;
    final spreadsheetId = sheetIdFromSelection(selection);
    if (spreadsheetId.isEmpty) {
      _report = null;
      _error = 'Enter a Google Sheets URL or spreadsheet ID.';
      notifyListeners();
      return false;
    }

    return _runServiceAction(
      clearReport: true,
      isCurrent: () => epoch == _validationEpoch,
      failurePrefix: 'Unable to validate spreadsheet',
      action: () async {
        final sess = svc.open(spreadsheetId);
        final report = await sess.read();
        if (epoch != _validationEpoch) return;
        _sess = sess;
        _adoptReport(report);
      },
    );
  }

  Future<bool> validateSelected(SelectedSheet selection) {
    final epoch = ++_validationEpoch;
    return _runServiceAction(
      clearReport: true,
      isCurrent: () => epoch == _validationEpoch,
      failurePrefix: 'Unable to validate spreadsheet',
      action: () async {
        final sess = svc.open(selection.id);
        final report = await sess.read();
        if (epoch != _validationEpoch) return;
        _sess = sess;
        _adoptReport(report);
      },
    );
  }

  void clearSelection() {
    _validationEpoch += 1;
    _report = null;
    _sess = null;
    _error = null;
    _selectedWorkout = null;
    _selectedHistoryBlock = null;
    _pendingWorkouts.clear();
    _pendingFormatUpdate = null;
    _clearLoggingSelection();
    notifyListeners();
  }

  Future<bool> createHistoryBlock(String label) async {
    final report = _report;
    final trimmedLabel = label.trim();
    if (report == null || trimmedLabel.isEmpty) {
      _error = 'Enter a visible history block label.';
      notifyListeners();
      return false;
    }
    if (report.activeSheet.historyBlocks.any(
      (block) => block.label == trimmedLabel,
    )) {
      _error = 'History block $trimmedLabel already exists.';
      notifyListeners();
      return false;
    }

    return _runMutation(
      failurePrefix: 'Unable to create history block',
      action: () async {
        final updatedReport = await _execute(NewHistoryCmd(trimmedLabel));
        _report = updatedReport;
        _error = null;
        _selectedHistoryBlock = trimmedLabel;
        if (!_workoutsFor(
          updatedReport.activeSheet,
        ).contains(_selectedWorkout)) {
          _selectedWorkout = _workoutsFor(
            updatedReport.activeSheet,
          ).firstOrNull;
        }
      },
    );
  }

  bool createWorkout(String label) {
    final report = _report;
    final trimmedLabel = label.trim();
    if (report == null || trimmedLabel.isEmpty) {
      _error = 'Enter a visible workout name.';
      notifyListeners();
      return false;
    }
    final workouts = _workoutsFor(report.activeSheet);
    if (workouts.contains(trimmedLabel)) {
      _error = 'Workout $trimmedLabel already exists.';
      notifyListeners();
      return false;
    }

    _pendingWorkouts.add(trimmedLabel);
    _selectedWorkout = trimmedLabel;
    _error = null;
    _clearLoggingSelection();
    notifyListeners();
    return true;
  }

  Future<bool> repairFormulas() async {
    final report = _report;
    if (report == null) {
      return false;
    }

    return _runMutation(
      failurePrefix: 'Unable to repair formulas',
      action: () async {
        _adoptReport(await _execute(const RepairAllCmd()));
      },
    );
  }

  Future<bool> repairFormulaIssue({
    required int activeSheetRowNumber,
    required int selectedRow,
  }) async {
    final report = _report;
    if (report == null) {
      return false;
    }

    return _runMutation(
      failurePrefix: 'Unable to repair formula',
      action: () async {
        _adoptReport(
          await _execute(
            RepairOneCmd(
              activeRow: activeSheetRowNumber,
              exerciseRow: selectedRow,
            ),
          ),
        );
      },
    );
  }

  Future<bool> execute(WbkCmd cmd) async {
    final report = _report;
    if (report == null) {
      return false;
    }

    return _runMutation(
      failurePrefix: 'Unable to save set',
      action: () async {
        _report = await _execute(cmd);
        _error = null;
      },
      rejection: () {
        final rejections = _report?.writeRejections ?? const [];
        return rejections.isEmpty
            ? null
            : rejections.map((item) => item.message).join(' ');
      },
    );
  }

  Future<bool> createExercise({required ExerciseDef exercise}) async {
    final report = _report;
    if (report == null) {
      _error = 'Validate a spreadsheet before creating exercises.';
      notifyListeners();
      return false;
    }

    return _runMutation(
      failurePrefix: 'Unable to create exercise',
      action: () async {
        _report = await _execute(CreateExeCmd(exercise));
        _error = null;
        _clearLoggingSelection();
      },
    );
  }

  Future<bool> updateExercise({
    required CanonicalExercise selectedExercise,
    required ExerciseDef exercise,
  }) async {
    final report = _report;
    if (report == null) {
      _error = 'Validate a spreadsheet before updating exercises.';
      notifyListeners();
      return false;
    }

    final updated = await _runMutation(
      failurePrefix: 'Unable to update exercise',
      action: () async {
        _report = await _execute(
          UpdateExeCmd(selected: selectedExercise, exercise: exercise),
        );
        _pendingFormatUpdate = _report?.exeFormatImpact;
        _error = null;
        _clearLoggingSelection();
      },
    );
    return updated && _pendingFormatUpdate == null;
  }

  Future<bool> confirmExerciseUpdate(
    Map<int, Map<String, String>> valuesByRow,
  ) async {
    final impact = _pendingFormatUpdate;
    if (impact == null) return false;
    return _runMutation(
      failurePrefix: 'Unable to update exercise',
      action: () async {
        _report = await _execute(
          ConfirmExeUpdateCmd(impact: impact, valuesByRow: valuesByRow),
        );
        if (_report!.writeRejections.isEmpty) {
          _pendingFormatUpdate = null;
          _error = null;
          _clearLoggingSelection();
        }
      },
      rejection: () {
        final rejections = _report?.writeRejections ?? const [];
        return rejections.isEmpty
            ? null
            : rejections.map((item) => item.message).join(' ');
      },
    );
  }

  void cancelExerciseUpdate() {
    _pendingFormatUpdate = null;
    _error = null;
    notifyListeners();
  }

  Future<bool> addExerciseToWorkout({
    required CanonicalExercise exercise,
    required WorkoutPlacementMetadata metadata,
    required ExercisePlacementTarget placement,
  }) async {
    final report = _report;
    if (report == null) {
      _error = 'Validate a spreadsheet before adding exercises.';
      notifyListeners();
      return false;
    }

    return _runMutation(
      failurePrefix: 'Unable to add exercise',
      action: () async {
        _report = await _execute(
          PlaceExeCmd(
            exercise: exercise,
            metadata: metadata,
            placement: placement,
          ),
        );
        _error = null;
        _prunePendingWorkouts(_report!.activeSheet);
        _selectedWorkout = placement.workout ?? _selectedWorkout;
        if (_selectedWorkout != null &&
            !_workoutsFor(_report!.activeSheet).contains(_selectedWorkout)) {
          _selectedWorkout = _workoutsFor(_report!.activeSheet).firstOrNull;
        }
        if (_selectedHistoryBlock != null &&
            !_report!.activeSheet.historyBlocks.any(
              (block) => block.label == _selectedHistoryBlock,
            )) {
          _selectedHistoryBlock =
              _report!.activeSheet.historyBlocks.firstOrNull?.label;
        }
        _clearLoggingSelection();
      },
    );
  }

  Future<bool> reorderExercises(ReorderIntent intent) async {
    final report = _report;
    if (report == null) {
      _error = 'Validate a spreadsheet before reordering exercises.';
      notifyListeners();
      return false;
    }

    return _runMutation(
      failurePrefix: 'Unable to reorder exercises',
      action: () async {
        _report = await _execute(ReorderExesCmd(intent));
        _error = null;
        _clearLoggingSelection();
      },
    );
  }

  Future<bool> reorderWorkoutExercises(ReorderIntent intent) async {
    final report = _report;
    final workout = workoutSetup?.selectedWorkout;
    if (report == null || workout == null) {
      _error = 'Select a workout before reordering workout exercises.';
      notifyListeners();
      return false;
    }

    return _runMutation(
      failurePrefix: 'Unable to reorder workout exercises',
      action: () async {
        _report = await _execute(
          ReorderWorkoutCmd(workout: workout, intent: intent),
        );
        _error = null;
        _clearLoggingSelection();
      },
    );
  }

  Future<bool> deleteWorkoutExercise({required int primaryRow}) async {
    final report = _report;
    final selectedWorkout = workoutSetup?.selectedWorkout;
    final selectedHistoryBlock = workoutSetup?.selectedHistoryBlock;
    if (report == null) {
      _error = 'Validate a spreadsheet before deleting exercises.';
      notifyListeners();
      return false;
    }

    return _runMutation(
      failurePrefix: 'Unable to delete exercise',
      action: () async {
        final deleteReport = await _execute(DeleteWorkoutExeCmd(primaryRow));
        if (deleteReport.writeRejections.isNotEmpty) {
          _error =
              'Unable to delete exercise: '
              '${deleteReport.writeRejections.map((rejection) => rejection.message).join(' ')}';
          return;
        }
        _report = deleteReport;
        _error = null;
        _prunePendingWorkouts(_report!.activeSheet);
        _retainWorkout(
          activeSheet: _report!.activeSheet,
          workout: selectedWorkout,
        );
        _selectedWorkout = _preservedWorkout(
          activeSheet: _report!.activeSheet,
          selectedWorkout: selectedWorkout,
        );
        _selectedHistoryBlock = _preservedHistoryBlock(
          activeSheet: _report!.activeSheet,
          selectedHistoryBlock: selectedHistoryBlock,
        );
        _clearLoggingSelection();
      },
    );
  }

  void selectWorkout(String? workout) {
    _selectedWorkout = workout;
    _clearLoggingSelection();
    notifyListeners();
  }

  void selectHistoryBlock(String? historyBlock) {
    _selectedHistoryBlock = historyBlock;
    _clearLoggingSelection();
    notifyListeners();
  }

  void restoreWorkoutSelection({
    required String? workout,
    required String? historyBlock,
  }) {
    _selectedWorkout = workout;
    _selectedHistoryBlock = historyBlock;
    _clearLoggingSelection();
    notifyListeners();
  }

  void openExercise(int primaryRow) {
    _loggingPrimaryRow = primaryRow;
    _selectedLoggingRow = primaryRow;
    notifyListeners();
  }

  void closeExercise() {
    _clearLoggingSelection();
    notifyListeners();
  }

  void selectLoggingRow(int sheetRowNumber) {
    _selectedLoggingRow = sheetRowNumber;
    notifyListeners();
  }

  void reportOpenFailure(Object error) {
    _error = _formatServiceFailure(
      failurePrefix: 'Unable to open spreadsheet',
      error: error,
    );
    notifyListeners();
  }

  void reportSelectionFailure(Object error) {
    _error = _formatServiceFailure(
      failurePrefix: 'Unable to choose spreadsheet',
      error: error,
    );
    notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  Future<bool> _runServiceAction({
    required Future<void> Function() action,
    required String failurePrefix,
    bool clearReport = false,
    bool Function()? isCurrent,
  }) async {
    final current = isCurrent ?? () => true;
    _serviceActions += 1;
    if (current()) {
      _error = null;
    }
    if (clearReport && current()) {
      _report = null;
    }
    notifyListeners();

    try {
      await action();
      return current();
    } on Object catch (error) {
      if (!current()) {
        return false;
      }
      if (clearReport) {
        _report = null;
      }
      _error = _formatServiceFailure(
        failurePrefix: failurePrefix,
        error: error,
      );
      return false;
    } finally {
      _serviceActions -= 1;
      if (!_isDisposed) {
        notifyListeners();
      }
    }
  }

  Future<bool> _runMutation({
    required Future<void> Function() action,
    required String failurePrefix,
    String? Function()? rejection,
  }) async {
    if (_mutationPending) return false;

    _mutationPending = true;
    _error = null;
    notifyListeners();

    try {
      await action();
      if (rejection?.call() case final message?) {
        _error = '$failurePrefix: $message';
        return false;
      }
      return true;
    } on Object catch (error) {
      _error = _formatServiceFailure(
        failurePrefix: failurePrefix,
        error: error,
      );
      return false;
    } finally {
      _mutationPending = false;
      if (!_isDisposed) {
        notifyListeners();
      }
    }
  }

  Future<ValReport> _execute(WbkCmd cmd) {
    final sess = _sess;
    if (sess == null) {
      throw StateError('Validate a spreadsheet before changing it.');
    }
    return sess.execute(cmd);
  }

  void _adoptReport(ValReport report) {
    _report = report;
    _error = null;
    _pendingWorkouts.clear();
    _pendingFormatUpdate = null;
    _selectedWorkout = report.activeSheet.selectableWorkouts.firstOrNull;
    _selectedHistoryBlock = report.activeSheet.historyBlocks.firstOrNull?.label;
    _clearLoggingSelection();
  }

  List<String> _workoutsFor(ParsedActiveSheet activeSheet) {
    final workouts = [...activeSheet.selectableWorkouts];
    for (final workout in _pendingWorkouts) {
      if (!workouts.contains(workout)) {
        workouts.add(workout);
      }
    }
    return List<String>.unmodifiable(workouts);
  }

  void _prunePendingWorkouts(ParsedActiveSheet activeSheet) {
    final durableWorkouts = activeSheet.selectableWorkouts;
    _pendingWorkouts.removeWhere(durableWorkouts.contains);
  }

  void _retainWorkout({
    required ParsedActiveSheet activeSheet,
    required String? workout,
  }) {
    if (workout != null &&
        !activeSheet.selectableWorkouts.contains(workout) &&
        !_pendingWorkouts.contains(workout)) {
      _pendingWorkouts.add(workout);
    }
  }

  String? _preservedWorkout({
    required ParsedActiveSheet activeSheet,
    required String? selectedWorkout,
  }) {
    final workouts = _workoutsFor(activeSheet);
    if (selectedWorkout != null && workouts.contains(selectedWorkout)) {
      return selectedWorkout;
    }
    return workouts.firstOrNull;
  }

  String? _preservedHistoryBlock({
    required ParsedActiveSheet activeSheet,
    required String? selectedHistoryBlock,
  }) {
    if (selectedHistoryBlock != null &&
        activeSheet.historyBlocks.any(
          (block) => block.label == selectedHistoryBlock,
        )) {
      return selectedHistoryBlock;
    }
    return activeSheet.historyBlocks.firstOrNull?.label;
  }

  void _clearLoggingSelection() {
    _loggingPrimaryRow = null;
    _selectedLoggingRow = null;
  }

  WorkoutLoggingTarget? _loggingTarget({
    required WorkoutOverview? overview,
    required String? selectedHistoryBlock,
  }) {
    final primaryRow = _loggingPrimaryRow;
    if (overview == null ||
        selectedHistoryBlock == null ||
        primaryRow == null) {
      return null;
    }

    WorkoutOverviewSlot? slot;
    for (final candidate in overview.slots) {
      if (candidate.sheetRowNumber == primaryRow) {
        slot = candidate;
        break;
      }
    }
    if (slot == null) {
      return null;
    }

    final requestedLoggingRow = _selectedLoggingRow ?? primaryRow;
    final selectedRow =
        requestedLoggingRow == primaryRow ||
            slot.backups.any(
              (backup) => backup.sheetRowNumber == requestedLoggingRow,
            )
        ? requestedLoggingRow
        : primaryRow;

    return WorkoutLoggingTarget(
      blockLabel: selectedHistoryBlock,
      primaryRow: primaryRow,
      selectedRow: selectedRow,
    );
  }

  static WorkoutSetupProgress _progressForWorkout({
    required ParsedActiveSheet activeSheet,
    required String workout,
    required String? blockLabel,
  }) {
    final overview = activeSheet.buildWorkoutOverview(
      workout: workout,
      blockLabel: blockLabel ?? '',
    );
    final done = blockLabel == null
        ? 0
        : overview.slots.where((slot) => slot.setCount > 0).length;
    return WorkoutSetupProgress(done: done, total: overview.slots.length);
  }

  static String _formatServiceFailure({
    required String failurePrefix,
    required Object error,
  }) {
    final message = error.toString();
    if (message.contains('Google Sheets API has not been used') &&
        message.contains('sheets.googleapis.com')) {
      final project = RegExp(
        r'project[ =]([A-Za-z0-9-]+)',
      ).firstMatch(message)?.group(1);
      final projectText = project == null
          ? 'this app\'s Google Cloud project'
          : 'Google Cloud project $project';
      final enableUrl = project == null
          ? 'https://console.cloud.google.com/apis/library/sheets.googleapis.com'
          : 'https://console.cloud.google.com/apis/library/'
                'sheets.googleapis.com?project=$project';
      return '$failurePrefix: Google Sheets API is disabled for $projectText. '
          'Enable the Google Sheets API, wait a few minutes for Google to '
          'propagate the change, then retry: $enableUrl';
    }
    return '$failurePrefix: $message';
  }
}

@immutable
class WorkoutSetupReadModel {
  WorkoutSetupReadModel({
    required this.activeSheet,
    required Iterable<String> workouts,
    required Iterable<HistoryBlock> historyBlocks,
    required this.selectedWorkout,
    required this.selectedHistoryBlock,
    required this.overview,
    required Map<String, WorkoutSetupProgress> progressByWorkout,
    required this.loggingTarget,
  }) : workouts = List<String>.unmodifiable(workouts),
       historyBlocks = List<HistoryBlock>.unmodifiable(historyBlocks),
       progressByWorkout = Map<String, WorkoutSetupProgress>.unmodifiable(
         progressByWorkout,
       );

  final ParsedActiveSheet activeSheet;
  final List<String> workouts;
  final List<HistoryBlock> historyBlocks;
  final String? selectedWorkout;
  final String? selectedHistoryBlock;
  final WorkoutOverview? overview;
  final Map<String, WorkoutSetupProgress> progressByWorkout;
  final WorkoutLoggingTarget? loggingTarget;
}

@immutable
class WorkoutSetupProgress {
  const WorkoutSetupProgress({required this.done, required this.total});

  final int done;
  final int total;

  String get label => '($done/$total started)';
}

@immutable
class WorkoutLoggingTarget {
  const WorkoutLoggingTarget({
    required this.blockLabel,
    required this.primaryRow,
    required this.selectedRow,
  });

  final String blockLabel;
  final int primaryRow;
  final int selectedRow;
}
