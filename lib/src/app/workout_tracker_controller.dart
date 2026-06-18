import 'package:flutter/foundation.dart';
import 'package:workout_tracker/sheet_contract.dart';

import 'spreadsheet_validation.dart';

/// Owns the GUI-facing flow state derived from the latest validation report.
///
/// The Interface keeps spreadsheet validation, history-block creation, and
/// write-plan application behind one GUI-facing Module. Row selections are only
/// valid while [report] remains current, so the controller clears them whenever
/// workout or history selection changes or a new report is adopted.
class WorkoutTrackerController extends ChangeNotifier {
  WorkoutTrackerController({required this.validationService});

  final SpreadsheetValidationService validationService;

  SpreadsheetValidationReport? _report;
  String? _error;
  String? _selectedWorkout;
  String? _selectedHistoryBlock;
  int? _loggingPrimarySheetRowNumber;
  int? _selectedLoggingSheetRowNumber;
  bool _isBusy = false;
  bool _isDisposed = false;

  SpreadsheetValidationReport? get report => _report;

  String? get error => _error;

  bool get isBusy => _isBusy;

  WorkoutSetupReadModel? get workoutSetup {
    final report = _report;
    if (report == null) {
      return null;
    }
    if (report.hasBlockingIssues) {
      return null;
    }

    final activeSheet = report.activeSheet;
    final workouts = activeSheet.selectableWorkouts;
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
            historyBlockLabel: selectedHistoryBlock,
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
            historyBlockLabel: selectedHistoryBlock,
          ),
      },
      loggingTarget: _loggingTargetForOverview(
        overview: overview,
        selectedHistoryBlock: selectedHistoryBlock,
      ),
    );
  }

  Future<bool> validateSpreadsheetSelection(String selection) async {
    final spreadsheetId = spreadsheetIdFromSelection(selection);
    if (spreadsheetId.isEmpty) {
      _report = null;
      _error = 'Enter a Google Sheets URL or spreadsheet ID.';
      notifyListeners();
      return false;
    }

    return _runServiceAction(
      clearReport: true,
      failurePrefix: 'Unable to validate spreadsheet',
      action: () async {
        final report = await validationService.validateSpreadsheet(
          spreadsheetId,
        );
        _adoptReport(report);
      },
    );
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

    return _runServiceAction(
      failurePrefix: 'Unable to create history block',
      action: () async {
        final updatedReport = await validationService.applyActiveSheetWritePlan(
          spreadsheetId: report.spreadsheetId,
          activeSheet: report.activeSheet,
          plan: report.activeSheet.planNewHistoryBlock(label: trimmedLabel),
        );
        _report = updatedReport;
        _error = null;
        _selectedHistoryBlock = trimmedLabel;
        if (!updatedReport.activeSheet.selectableWorkouts.contains(
          _selectedWorkout,
        )) {
          _selectedWorkout =
              updatedReport.activeSheet.selectableWorkouts.firstOrNull;
        }
      },
    );
  }

  Future<bool> repairUnambiguousFormulaIssues() async {
    final report = _report;
    if (report == null) {
      return false;
    }

    return _runServiceAction(
      failurePrefix: 'Unable to repair formulas',
      action: () async {
        _adoptReport(
          await validationService.applyActiveSheetWritePlan(
            spreadsheetId: report.spreadsheetId,
            activeSheet: report.activeSheet,
            plan: report.activeSheet.planUnambiguousFormulaHealing(),
          ),
        );
      },
    );
  }

  Future<bool> repairFormulaIssue({
    required int activeSheetRowNumber,
    required int selectedExerciseSheetRowNumber,
  }) async {
    final report = _report;
    if (report == null) {
      return false;
    }

    return _runServiceAction(
      failurePrefix: 'Unable to repair formula',
      action: () async {
        _adoptReport(
          await validationService.applyActiveSheetWritePlan(
            spreadsheetId: report.spreadsheetId,
            activeSheet: report.activeSheet,
            plan: report.activeSheet.planFormulaHealing(
              activeSheetRowNumber: activeSheetRowNumber,
              selectedExerciseSheetRowNumber: selectedExerciseSheetRowNumber,
            ),
          ),
        );
      },
    );
  }

  Future<bool> applyActiveSheetWritePlan(ActiveSheetWritePlan plan) async {
    final report = _report;
    if (report == null) {
      return false;
    }

    return _runServiceAction(
      failurePrefix: 'Unable to save set',
      action: () async {
        _report = await validationService.applyActiveSheetWritePlan(
          spreadsheetId: report.spreadsheetId,
          activeSheet: report.activeSheet,
          plan: plan,
        );
        _error = null;
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

  void openExercise(int primarySheetRowNumber) {
    _loggingPrimarySheetRowNumber = primarySheetRowNumber;
    _selectedLoggingSheetRowNumber = primarySheetRowNumber;
    notifyListeners();
  }

  void closeExercise() {
    _clearLoggingSelection();
    notifyListeners();
  }

  void selectLoggingRow(int sheetRowNumber) {
    _selectedLoggingSheetRowNumber = sheetRowNumber;
    notifyListeners();
  }

  void reportOpenSpreadsheetFailure(Object error) {
    _error = _formatServiceFailure(
      failurePrefix: 'Unable to open spreadsheet',
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
  }) async {
    _isBusy = true;
    _error = null;
    if (clearReport) {
      _report = null;
    }
    notifyListeners();

    try {
      await action();
      return true;
    } on Object catch (error) {
      if (clearReport) {
        _report = null;
      }
      _error = _formatServiceFailure(
        failurePrefix: failurePrefix,
        error: error,
      );
      return false;
    } finally {
      _isBusy = false;
      if (!_isDisposed) {
        notifyListeners();
      }
    }
  }

  void _adoptReport(SpreadsheetValidationReport report) {
    _report = report;
    _error = null;
    _selectedWorkout = report.activeSheet.selectableWorkouts.firstOrNull;
    _selectedHistoryBlock = report.activeSheet.historyBlocks.firstOrNull?.label;
    _clearLoggingSelection();
  }

  void _clearLoggingSelection() {
    _loggingPrimarySheetRowNumber = null;
    _selectedLoggingSheetRowNumber = null;
  }

  WorkoutLoggingTarget? _loggingTargetForOverview({
    required WorkoutOverview? overview,
    required String? selectedHistoryBlock,
  }) {
    final primarySheetRowNumber = _loggingPrimarySheetRowNumber;
    if (overview == null ||
        selectedHistoryBlock == null ||
        primarySheetRowNumber == null) {
      return null;
    }

    WorkoutOverviewSlot? slot;
    for (final candidate in overview.slots) {
      if (candidate.sheetRowNumber == primarySheetRowNumber) {
        slot = candidate;
        break;
      }
    }
    if (slot == null) {
      return null;
    }

    final requestedLoggingRow =
        _selectedLoggingSheetRowNumber ?? primarySheetRowNumber;
    final selectedSheetRowNumber =
        requestedLoggingRow == primarySheetRowNumber ||
            slot.backups.any(
              (backup) => backup.sheetRowNumber == requestedLoggingRow,
            )
        ? requestedLoggingRow
        : primarySheetRowNumber;

    return WorkoutLoggingTarget(
      historyBlockLabel: selectedHistoryBlock,
      primarySheetRowNumber: primarySheetRowNumber,
      selectedSheetRowNumber: selectedSheetRowNumber,
    );
  }

  static WorkoutSetupProgress _progressForWorkout({
    required ParsedActiveSheet activeSheet,
    required String workout,
    required String? historyBlockLabel,
  }) {
    final overview = activeSheet.buildWorkoutOverview(
      workout: workout,
      historyBlockLabel: historyBlockLabel ?? '',
    );
    final done = historyBlockLabel == null
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

  String get label => '($done/$total done)';
}

@immutable
class WorkoutLoggingTarget {
  const WorkoutLoggingTarget({
    required this.historyBlockLabel,
    required this.primarySheetRowNumber,
    required this.selectedSheetRowNumber,
  });

  final String historyBlockLabel;
  final int primarySheetRowNumber;
  final int selectedSheetRowNumber;
}
