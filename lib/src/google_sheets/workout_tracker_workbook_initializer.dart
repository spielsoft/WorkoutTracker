import 'package:googleapis/sheets/v4.dart' as sheets;

import 'workout_tracker_workbook_initialization_plan.dart';
import 'workout_tracker_workbook_template.dart';

abstract interface class WorkoutTrackerWorkbookInitializer {
  Future<void> initializeWorkbook({
    required String spreadsheetId,
    required WorkoutTrackerWorkbook workbook,
  });
}

class GoogleApisWorkoutTrackerWorkbookInitializer
    implements WorkoutTrackerWorkbookInitializer {
  GoogleApisWorkoutTrackerWorkbookInitializer(this._api);

  final sheets.SheetsApi _api;
  final WorkoutTrackerWorkbookInitializationPlanner _planner =
      const WorkoutTrackerWorkbookInitializationPlanner();

  static const writeScopes = [sheets.SheetsApi.spreadsheetsScope];

  @override
  Future<void> initializeWorkbook({
    required String spreadsheetId,
    required WorkoutTrackerWorkbook workbook,
  }) async {
    final targets = await _ensureInitializationTargets(spreadsheetId, workbook);
    await _rewriteSheet(
      spreadsheetId: spreadsheetId,
      target: targets.exercisesSheet,
      tab: workbook.exercisesSheet,
      frozenRowCount: 1,
    );
    await _rewriteSheet(
      spreadsheetId: spreadsheetId,
      target: targets.activeSheet,
      tab: workbook.activeSheet,
      frozenRowCount: 2,
    );
  }

  Future<_InitializationTargets> _ensureInitializationTargets(
    String spreadsheetId,
    WorkoutTrackerWorkbook workbook,
  ) async {
    var shape = await _fetchSpreadsheetShape(spreadsheetId);
    if (shape.sheets.isEmpty) {
      throw StateError('Spreadsheet has no sheets.');
    }

    var activeSheet = shape.sheets.first;
    final requests = <sheets.Request>[];
    if (activeSheet.title != workbook.activeSheet.title &&
        !shape.hasSheetTitle(workbook.activeSheet.title)) {
      requests.add(
        sheets.Request(
          updateSheetProperties: sheets.UpdateSheetPropertiesRequest(
            properties: sheets.SheetProperties(
              sheetId: activeSheet.sheetId,
              title: workbook.activeSheet.title,
            ),
            fields: 'title',
          ),
        ),
      );
      activeSheet = _SheetShape(
        sheetId: activeSheet.sheetId,
        index: activeSheet.index,
        title: workbook.activeSheet.title,
      );
    }

    if (!shape.hasSheetTitle(workbook.exercisesSheet.title)) {
      requests.add(
        sheets.Request(
          addSheet: sheets.AddSheetRequest(
            properties: sheets.SheetProperties(
              title: workbook.exercisesSheet.title,
              gridProperties: sheets.GridProperties(
                rowCount: _planner.usableRowCount(workbook.exercisesSheet),
                columnCount: workbook.exercisesSheet.columnCount,
                frozenRowCount: 1,
              ),
            ),
          ),
        ),
      );
    }

    if (requests.isNotEmpty) {
      await _api.spreadsheets.batchUpdate(
        sheets.BatchUpdateSpreadsheetRequest(requests: requests),
        spreadsheetId,
        $fields: 'spreadsheetId,replies(addSheet(properties(sheetId)))',
      );
      shape = await _fetchSpreadsheetShape(spreadsheetId);
      activeSheet = shape.sheets.first;
    }

    final exercisesSheet = shape.sheetByTitle(workbook.exercisesSheet.title);
    if (exercisesSheet == null) {
      throw StateError('Exercises sheet could not be created.');
    }

    return _InitializationTargets(
      activeSheet: activeSheet,
      exercisesSheet: exercisesSheet,
    );
  }

  Future<void> _rewriteSheet({
    required String spreadsheetId,
    required _SheetShape target,
    required WorkoutTrackerWorkbookTab tab,
    required int frozenRowCount,
  }) async {
    await _api.spreadsheets.values.clear(
      sheets.ClearValuesRequest(),
      spreadsheetId,
      '${_quotedSheetTitle(target.title)}!A1:ZZ1000',
      $fields: 'spreadsheetId,clearedRange',
    );

    final plan = _planner.planTabRewrite(
      sheetId: target.sheetId,
      tab: tab,
      frozenRowCount: frozenRowCount,
    );

    await _api.spreadsheets.batchUpdate(
      sheets.BatchUpdateSpreadsheetRequest(requests: plan.requests),
      spreadsheetId,
      $fields: 'spreadsheetId',
    );
  }

  Future<_SpreadsheetShape> _fetchSpreadsheetShape(String spreadsheetId) async {
    final spreadsheet = await _api.spreadsheets.get(
      spreadsheetId,
      $fields: 'sheets(properties(sheetId,index,title,sheetType))',
    );
    final apiSheets = [...?spreadsheet.sheets]
      ..sort((left, right) {
        return (left.properties?.index ?? 0).compareTo(
          right.properties?.index ?? 0,
        );
      });

    return _SpreadsheetShape(
      sheets: [
        for (final sheet in apiSheets)
          if (sheet.properties?.sheetId != null)
            _SheetShape(
              sheetId: sheet.properties!.sheetId!,
              index: sheet.properties?.index ?? 0,
              title: sheet.properties?.title ?? '',
            ),
      ],
    );
  }
}

class _InitializationTargets {
  const _InitializationTargets({
    required this.activeSheet,
    required this.exercisesSheet,
  });

  final _SheetShape activeSheet;
  final _SheetShape exercisesSheet;
}

class _SpreadsheetShape {
  _SpreadsheetShape({required Iterable<_SheetShape> sheets})
    : sheets = List<_SheetShape>.unmodifiable(sheets);

  final List<_SheetShape> sheets;

  bool hasSheetTitle(String title) {
    return sheetByTitle(title) != null;
  }

  _SheetShape? sheetByTitle(String title) {
    for (final sheet in sheets) {
      if (sheet.title == title) {
        return sheet;
      }
    }
    return null;
  }
}

class _SheetShape {
  const _SheetShape({
    required this.sheetId,
    required this.index,
    required this.title,
  });

  final int sheetId;
  final int index;
  final String title;
}

String _quotedSheetTitle(String title) {
  return "'${title.replaceAll("'", "''")}'";
}
