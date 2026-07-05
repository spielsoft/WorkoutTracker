import 'package:workout_tracker/contract.dart';

import '../../fixtures/workbook.dart';

ParsedActiveSheet parseFixtureActiveSheet() {
  final workbook = loadLocalWorkoutWorkbookFixture();
  return parseActiveSheet(
    ActiveSheetInput(
      rows: workbook.activeSheet.rows,
      mergedFirstColumnRows: workbook.activeSheet.mergedFirstColumnRows,
    ),
  );
}

List<ReadableFixtureRow> appReadableFixtureRows(
  WorkoutWorkbookFixture workbook,
) {
  final readableRows = <ReadableFixtureRow>[];
  for (
    var rowIndex = 2;
    rowIndex < workbook.activeSheet.rows.length;
    rowIndex += 1
  ) {
    final sheetRowNumber = rowIndex + 1;
    final row = workbook.activeSheet.rows[rowIndex];
    if (workbook.activeSheet.mergedFirstColumnRows.contains(sheetRowNumber) ||
        row.length <= 8 ||
        row.first.isEmpty) {
      continue;
    }
    readableRows.add(
      ReadableFixtureRow(sheetRowNumber: sheetRowNumber, values: row),
    );
  }
  return readableRows;
}

List<String> historyHeaderRow(List<String> historyCells) {
  return [...activeSheetFixedColumns, ...historyCells];
}

List<String> setLabelRow(List<String> setLabels) {
  return [...List.filled(activeSheetFixedColumns.length, ''), ...setLabels];
}

class ReadableFixtureRow {
  const ReadableFixtureRow({
    required this.sheetRowNumber,
    required this.values,
  });

  final int sheetRowNumber;
  final List<String> values;
}
