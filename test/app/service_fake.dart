import 'package:workout_tracker/contract.dart';
import 'package:workout_tracker/app.dart';

class TestValSvc implements WbkSvc {
  TestValSvc(ParsedActiveSheet activeSheet)
    : _activeSheet = activeSheet,
      _rows = null;

  TestValSvc.fromRows(List<List<String>> rows)
    : _activeSheet = parseActiveSheet(ActiveSheetInput(rows: rows)),
      _rows = rows.map((row) => row.toList()).toList();

  ParsedActiveSheet _activeSheet;
  List<List<String>>? _rows;

  final spreadsheetIds = <String>[];
  final appliedPlans = <ActiveSheetWritePlan>[];

  ParsedActiveSheet get activeSheet => _activeSheet;

  @override
  Future<ValReport> validateSheet(String spreadsheetId) async {
    spreadsheetIds.add(spreadsheetId);
    return _report(spreadsheetId);
  }

  @override
  Future<ValReport> applyWritePlan({
    required String spreadsheetId,
    required ParsedActiveSheet activeSheet,
    required ActiveSheetWritePlan plan,
  }) async {
    final writeRejections = plan.writeRejections(_activeSheet);
    if (writeRejections.isNotEmpty) {
      return ValReport(
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
  Future<ValReport> createExercise({
    required String spreadsheetId,
    required ParsedActiveSheet activeSheet,
    required ExerciseDef exercise,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<ValReport> updateExercise({
    required String spreadsheetId,
    required ParsedActiveSheet activeSheet,
    required CanonicalExercise selectedExercise,
    required ExerciseDef exercise,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<ValReport> addExerciseToWorkout({
    required String spreadsheetId,
    required ParsedActiveSheet activeSheet,
    required CanonicalExercise exercise,
    required WorkoutPlacementMetadata metadata,
    required ExercisePlacementTarget placement,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<ValReport> reorderExercises({
    required String spreadsheetId,
    required ParsedActiveSheet activeSheet,
    required ReorderIntent intent,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<ValReport> reorderWorkoutExercises({
    required String spreadsheetId,
    required ParsedActiveSheet activeSheet,
    required String workout,
    required ReorderIntent intent,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<ValReport> deleteWorkoutExercise({
    required String spreadsheetId,
    required ParsedActiveSheet activeSheet,
    required int primaryRow,
  }) {
    return applyWritePlan(
      spreadsheetId: spreadsheetId,
      activeSheet: activeSheet,
      plan: activeSheet.planDeletePrimary(primaryRow: primaryRow),
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

  ValReport _report(String spreadsheetId) {
    return ValReport(spreadsheetId: spreadsheetId, activeSheet: _activeSheet);
  }
}
