import 'package:workout_tracker/contract.dart';

import 'client.dart';

class SheetsReadAdapter {
  SheetsReadAdapter({required this.client});

  final SheetsWorkbookClient client;

  Future<ActiveSheetInput> readActiveSheetInput(String spreadsheetId) async {
    final metadata = await client.fetchMetadata(spreadsheetId);
    if (metadata.sheets.isEmpty) {
      throw StateError('Spreadsheet has no sheets.');
    }

    final activeSheetMetadata = metadata.sheets.first;
    final exercisesSheetMetadata = metadata.sheetByTitle('Exercises');
    final workbook = await client.readGrids(
      spreadsheetId: spreadsheetId,
      reads: [
        SheetsGridRead(sheet: activeSheetMetadata),
        if (exercisesSheetMetadata != null)
          SheetsGridRead(sheet: exercisesSheetMetadata),
      ],
    );
    final activeSheet = workbook.sheets.first;
    return ActiveSheetInput(
      rows: activeSheet.rows,
      cellFormulas: activeSheet.cellFormulas.map(
        (formula) => CellFormula(
          sheetRowNumber: formula.sheetRowNumber,
          sheetColumnNumber: formula.sheetColumnNumber,
          formula: formula.formula,
        ),
      ),
      exercisesRows: _sheetByTitle(workbook, 'Exercises')?.rows ?? const [],
      hasExercisesSheet: exercisesSheetMetadata != null,
      validateWorkbook: true,
      schemaVersion: metadata.metadataByKey(workbookSchemaKey)?.value,
      mergedFirstColumnRows: activeSheet.mergedFirstColumnRows,
    );
  }

  Future<ParsedActiveSheet> readParsedActiveSheet(String spreadsheetId) async {
    return parseActiveSheet(await readActiveSheetInput(spreadsheetId));
  }
}

SheetsGridSnapshot? _sheetByTitle(
  SheetsWorkbookSnapshot workbook,
  String title,
) {
  for (final sheet in workbook.sheets) {
    if (sheet.sheet.title == title) {
      return sheet;
    }
  }
  return null;
}
