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

  String? get selectedWorkout => _selectedWorkout;

  String? get selectedHistoryBlock => _selectedHistoryBlock;

  int? get loggingPrimarySheetRowNumber => _loggingPrimarySheetRowNumber;

  int? get selectedLoggingSheetRowNumber => _selectedLoggingSheetRowNumber;

  bool get isBusy => _isBusy;

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

    return _runServiceAction(
      failurePrefix: 'Unable to create history block',
      action: () async {
        final updatedReport = await validationService.createHistoryBlock(
          spreadsheetId: report.spreadsheetId,
          label: trimmedLabel,
          activeSheet: report.activeSheet,
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
      _error = '$failurePrefix: $error';
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
}
