import 'package:workout_tracker/sheet_contract.dart';
import 'package:workout_tracker/workout_tracker_app.dart';

class TestSpreadsheetValidationService implements SpreadsheetValidationService {
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
  Future<SpreadsheetValidationReport> validateSpreadsheet(
    String spreadsheetId,
  ) async {
    spreadsheetIds.add(spreadsheetId);
    return _report(spreadsheetId);
  }

  @override
  Future<SpreadsheetValidationReport> applyActiveSheetWritePlan({
    required String spreadsheetId,
    required ParsedActiveSheet activeSheet,
    required ActiveSheetWritePlan plan,
  }) async {
    appliedPlans.add(plan);
    _applyPlan(plan);
    return _report(spreadsheetId);
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

  SpreadsheetValidationReport _report(String spreadsheetId) {
    return SpreadsheetValidationReport(
      spreadsheetId: spreadsheetId,
      activeSheet: _activeSheet,
    );
  }
}
