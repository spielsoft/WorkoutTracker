import 'package:googleapis/sheets/v4.dart' as sheets;

import 'workbook_client.dart';
import 'workout_tracker_workbook_template.dart';

class WorkoutTrackerWorkbookTabRewritePlan {
  WorkoutTrackerWorkbookTabRewritePlan({
    required int sheetId,
    required WorkoutTrackerWorkbookTab tab,
    required int frozenRowCount,
  }) : operations = List<SheetsWorkbookOperation>.unmodifiable(
         _operationsForWorkbookInitialization(
           SheetsSheetIdentity(sheetId: sheetId, title: tab.title),
           tab.rows,
         ),
       ),
       requests = List<sheets.Request>.unmodifiable([
         sheets.Request(
           unmergeCells: sheets.UnmergeCellsRequest(
             range: sheets.GridRange(sheetId: sheetId),
           ),
         ),
         sheets.Request(
           updateSheetProperties: sheets.UpdateSheetPropertiesRequest(
             properties: sheets.SheetProperties(
               sheetId: sheetId,
               gridProperties: sheets.GridProperties(
                 rowCount: usableWorkbookRowCount(tab),
                 columnCount: tab.columnCount,
                 frozenRowCount: frozenRowCount,
               ),
             ),
             fields: 'gridProperties(rowCount,columnCount,frozenRowCount)',
           ),
         ),
         sheets.Request(
           repeatCell: sheets.RepeatCellRequest(
             range: sheets.GridRange(
               sheetId: sheetId,
               startRowIndex: 0,
               endRowIndex: usableWorkbookRowCount(tab),
               startColumnIndex: 0,
               endColumnIndex: tab.columnCount,
             ),
             cell: sheets.CellData(
               userEnteredFormat: sheets.CellFormat(
                 numberFormat: sheets.NumberFormat(type: 'TEXT'),
               ),
             ),
             fields: 'userEnteredFormat.numberFormat',
           ),
         ),
         sheets.Request(
           repeatCell: sheets.RepeatCellRequest(
             range: sheets.GridRange(
               sheetId: sheetId,
               startRowIndex: 0,
               endRowIndex: frozenRowCount,
             ),
             cell: sheets.CellData(
               userEnteredFormat: sheets.CellFormat(
                 textFormat: sheets.TextFormat(bold: true),
               ),
             ),
             fields: 'userEnteredFormat.textFormat.bold',
           ),
         ),
       ]);

  final List<sheets.Request> requests;
  final List<SheetsWorkbookOperation> operations;
}

int usableWorkbookRowCount(WorkoutTrackerWorkbookTab tab) {
  final minimumRows = tab.title == 'Exercises' ? 25 : 50;
  return tab.rows.length > minimumRows ? tab.rows.length : minimumRows;
}

List<SheetsWorkbookOperation> _operationsForWorkbookInitialization(
  SheetsSheetIdentity sheet,
  List<List<String>> rows,
) {
  return [
    for (var rowIndex = 0; rowIndex < rows.length; rowIndex += 1)
      for (
        var columnIndex = 0;
        columnIndex < rows[rowIndex].length;
        columnIndex += 1
      )
        if (rows[rowIndex][columnIndex].isNotEmpty)
          SheetsCellWrite(
            sheet: sheet,
            sheetRowNumber: rowIndex + 1,
            sheetColumnNumber: columnIndex + 1,
            value: rows[rowIndex][columnIndex],
            mode: _valueInputModeForWorkbookInitialization(
              rows[rowIndex][columnIndex],
            ),
          ),
  ];
}

SheetsValueInputMode _valueInputModeForWorkbookInitialization(String value) {
  if (value.startsWith('=')) {
    return SheetsValueInputMode.userEntered;
  }
  return SheetsValueInputMode.literalText;
}
