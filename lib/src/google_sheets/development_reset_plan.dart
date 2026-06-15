import 'package:googleapis/sheets/v4.dart' as sheets;

import 'development_reset_fixture.dart';

class DevelopmentSheetResetPlanner {
  const DevelopmentSheetResetPlanner();

  int usableRowCount(DevelopmentSheetResetTab tab) {
    return _usableResetRowCount(tab);
  }

  DevelopmentSheetResetTabRewritePlan planTabRewrite({
    required int sheetId,
    required DevelopmentSheetResetTab tab,
    required int frozenRowCount,
  }) {
    return DevelopmentSheetResetTabRewritePlan(
      sheetId: sheetId,
      tab: tab,
      frozenRowCount: frozenRowCount,
    );
  }
}

class DevelopmentSheetResetTabRewritePlan {
  DevelopmentSheetResetTabRewritePlan({
    required int sheetId,
    required DevelopmentSheetResetTab tab,
    required int frozenRowCount,
  }) : requests = List<sheets.Request>.unmodifiable([
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
                 rowCount: _usableResetRowCount(tab),
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
               endRowIndex: _usableResetRowCount(tab),
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
         sheets.Request(
           updateCells: sheets.UpdateCellsRequest(
             start: sheets.GridCoordinate(
               sheetId: sheetId,
               rowIndex: 0,
               columnIndex: 0,
             ),
             rows: _rowDataForReset(tab.rows),
             fields: 'userEnteredValue',
           ),
         ),
       ]);

  final List<sheets.Request> requests;
}

int _usableResetRowCount(DevelopmentSheetResetTab tab) {
  final minimumRows = tab.title == 'Exercises' ? 25 : 50;
  return tab.rows.length > minimumRows ? tab.rows.length : minimumRows;
}

List<sheets.RowData> _rowDataForReset(List<List<String>> rows) {
  return [
    for (final row in rows)
      sheets.RowData(
        values: [
          for (final value in row)
            sheets.CellData(userEnteredValue: _extendedValueForReset(value)),
        ],
      ),
  ];
}

sheets.ExtendedValue? _extendedValueForReset(String value) {
  if (value.isEmpty) {
    return null;
  }
  if (value.startsWith('=')) {
    return sheets.ExtendedValue(formulaValue: value);
  }
  return sheets.ExtendedValue(stringValue: value);
}
