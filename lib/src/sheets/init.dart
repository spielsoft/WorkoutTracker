import 'package:googleapis/sheets/v4.dart' as sheets;

import 'client.dart';
import 'init_plan.dart';
import 'template.dart';

abstract interface class WbkInit {
  Future<void> initializeWorkbook({
    required String spreadsheetId,
    required Wbk workbook,
  });
}

class GoogleApisWbkInit implements WbkInit {
  GoogleApisWbkInit(this._api, {SheetsWorkbookClient? workbookClient})
    : _workbookClient = workbookClient ?? GoogleApisWbkClient(_api);

  final sheets.SheetsApi _api;
  final SheetsWorkbookClient _workbookClient;

  static const writeScopes = [sheets.SheetsApi.spreadsheetsScope];

  @override
  Future<void> initializeWorkbook({
    required String spreadsheetId,
    required Wbk workbook,
  }) async {
    final targets = await _ensureTargets(spreadsheetId, workbook);
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
    await _workbookClient.applyOperations(
      spreadsheetId: spreadsheetId,
      operations: [
        SheetsMetadataWrite(
          sheet: SheetsSheetIdentity(
            sheetId: targets.activeSheet.sheetId,
            title: targets.activeSheet.title,
          ),
          key: workbookSchemaKey,
          value: workbookSchemaVersion,
          metadataId: targets.schemaMetadataId,
        ),
      ],
    );
  }

  Future<_InitTargets> _ensureTargets(
    String spreadsheetId,
    Wbk workbook,
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
                rowCount: usableRowCount(workbook.exercisesSheet),
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

    return _InitTargets(
      activeSheet: activeSheet,
      exercisesSheet: exercisesSheet,
      schemaMetadataId: shape.schemaMetadataId,
    );
  }

  Future<void> _rewriteSheet({
    required String spreadsheetId,
    required _SheetShape target,
    required WbkTab tab,
    required int frozenRowCount,
  }) async {
    await _api.spreadsheets.values.clear(
      sheets.ClearValuesRequest(),
      spreadsheetId,
      '${_quotedSheetTitle(target.title)}!A1:ZZ1000',
      $fields: 'spreadsheetId,clearedRange',
    );

    final plan = WbkTabPlan(
      sheetId: target.sheetId,
      tab: tab,
      frozenRowCount: frozenRowCount,
    );

    await _api.spreadsheets.batchUpdate(
      sheets.BatchUpdateSpreadsheetRequest(requests: plan.requests),
      spreadsheetId,
      $fields: 'spreadsheetId',
    );
    await _workbookClient.applyOperations(
      spreadsheetId: spreadsheetId,
      operations: plan.operations,
    );
  }

  Future<_SpreadsheetShape> _fetchSpreadsheetShape(String spreadsheetId) async {
    final metadata = await _workbookClient.fetchMetadata(spreadsheetId);
    return _SpreadsheetShape(
      sheets: [
        for (final sheet in metadata.sheets)
          _SheetShape(sheetId: sheet.sheetId, title: sheet.title),
      ],
      schemaMetadataId: metadata.metadataByKey(workbookSchemaKey)?.id,
    );
  }
}

class _InitTargets {
  const _InitTargets({
    required this.activeSheet,
    required this.exercisesSheet,
    required this.schemaMetadataId,
  });

  final _SheetShape activeSheet;
  final _SheetShape exercisesSheet;
  final int? schemaMetadataId;
}

class _SpreadsheetShape {
  _SpreadsheetShape({
    required Iterable<_SheetShape> sheets,
    required this.schemaMetadataId,
  }) : sheets = List<_SheetShape>.unmodifiable(sheets);

  final List<_SheetShape> sheets;
  final int? schemaMetadataId;

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
  const _SheetShape({required this.sheetId, required this.title});

  final int sheetId;
  final String title;
}

String _quotedSheetTitle(String title) {
  return "'${title.replaceAll("'", "''")}'";
}
