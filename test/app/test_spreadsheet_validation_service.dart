import 'package:workout_tracker/sheet_contract.dart';
import 'package:workout_tracker/workout_tracker_app.dart';

class TestSpreadsheetValidationService implements WorkbookService {
  TestSpreadsheetValidationService(ParsedActiveSheet activeSheet)
    : _activeSheet = activeSheet,
      _rows = null;

  TestSpreadsheetValidationService.fromRows(List<List<String>> rows)
    : _activeSheet = parseActiveSheet(ActiveSheetInput(rows: rows)),
      _rows = rows.map((row) => row.toList()).toList();

  ParsedActiveSheet _activeSheet;
  List<List<String>>? _rows;

  final spreadsheetIds = <String>[];
  final appliedPlans = <ActiveSheetWritePlan>[];

  ParsedActiveSheet get activeSheet => _activeSheet;

  @override
  Future<ValidationReport> validateSpreadsheet(String spreadsheetId) async {
    spreadsheetIds.add(spreadsheetId);
    return _report(spreadsheetId);
  }

  @override
  Future<ValidationReport> applyWritePlan({
    required String spreadsheetId,
    required ParsedActiveSheet activeSheet,
    required ActiveSheetWritePlan plan,
  }) async {
    final writeRejections = plan.writeRejections(_activeSheet);
    if (writeRejections.isNotEmpty) {
      return ValidationReport(
        spreadsheetId: spreadsheetId,
        activeSheet: _activeSheet,
        writeRejections: writeRejections,
      );
    }
    appliedPlans.add(plan);
    _applyPlan(plan);
    return _report(spreadsheetId);
  }

  @override
  Future<ValidationReport> createExercise({
    required String spreadsheetId,
    required ParsedActiveSheet activeSheet,
    required ExerciseDef exercise,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<ValidationReport> updateExercise({
    required String spreadsheetId,
    required ParsedActiveSheet activeSheet,
    required CanonicalExercise selectedExercise,
    required ExerciseDef exercise,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<ValidationReport> addExerciseToWorkout({
    required String spreadsheetId,
    required ParsedActiveSheet activeSheet,
    required CanonicalExercise exercise,
    required WorkoutPlacementMetadata metadata,
    required ExercisePlacementTarget placement,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<ValidationReport> reorderExercises({
    required String spreadsheetId,
    required ParsedActiveSheet activeSheet,
    required ReorderIntent intent,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<ValidationReport> reorderWorkoutExercises({
    required String spreadsheetId,
    required ParsedActiveSheet activeSheet,
    required String workout,
    required ReorderIntent intent,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<ValidationReport> deleteWorkoutExercise({
    required String spreadsheetId,
    required ParsedActiveSheet activeSheet,
    required int primarySheetRowNumber,
  }) {
    return applyWritePlan(
      spreadsheetId: spreadsheetId,
      activeSheet: activeSheet,
      plan: activeSheet.planDeletePrimary(
        primarySheetRowNumber: primarySheetRowNumber,
      ),
    );
  }

  void _applyPlan(ActiveSheetWritePlan plan) {
    final rows = _rows;
    if (rows == null) {
      return;
    }
    final previewRows = plan.previewRowsAfterApplying(rows);
    _rows = previewRows.map((row) => row.toList()).toList();
    _activeSheet = parseActiveSheet(ActiveSheetInput(rows: _rows!));
  }

  ValidationReport _report(String spreadsheetId) {
    return ValidationReport(
      spreadsheetId: spreadsheetId,
      activeSheet: _activeSheet,
    );
  }
}
