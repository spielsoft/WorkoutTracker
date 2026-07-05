import 'package:workout_tracker/sheet_contract.dart';

import 'workbook_client.dart';

class SheetsWriteAdapter {
  SheetsWriteAdapter({required this.client});

  final SheetsWorkbookClient client;

  Future<void> applyActiveSheetWritePlan({
    required String spreadsheetId,
    required ActiveSheetWritePlan plan,
  }) async {
    if (plan.columnInsertions.isEmpty &&
        plan.rowInsertions.isEmpty &&
        plan.rowDeletions.isEmpty &&
        plan.cellUpdates.isEmpty) {
      return;
    }

    final activeSheet = await _activeSheet(spreadsheetId);
    final operations = <SheetsWorkbookOperation>[
      for (final insertion in _sortedRowInsertions(plan.rowInsertions))
        SheetsRowInsertion(
          sheet: activeSheet,
          sheetRowNumber: insertion.sheetRowNumber,
          rowCount: insertion.rowCount,
        ),
      for (final deletion in _sortedRowDeletions(plan.rowDeletions))
        SheetsRowDeletion(
          sheet: activeSheet,
          sheetRowNumber: deletion.sheetRowNumber,
          rowCount: deletion.rowCount,
        ),
      for (final insertion in _sortedColumnInsertions(plan.columnInsertions))
        SheetsColumnInsertion(
          sheet: activeSheet,
          sheetColumnNumber: insertion.sheetColumnNumber,
          columnCount: insertion.setLabels.length,
        ),
      for (final insertion in plan.columnInsertions)
        ..._headerWrites(activeSheet, insertion),
      for (final update in plan.cellUpdates)
        if (update.value.isNotEmpty)
          SheetsCellWrite(
            sheet: activeSheet,
            sheetRowNumber: update.sheetRowNumber,
            sheetColumnNumber: update.sheetColumnNumber,
            value: update.value,
            mode: _modeForCellUpdate(update),
          ),
      for (final update in plan.cellUpdates)
        if (update.value.isEmpty &&
            update.valueKind == CellUpdateValueKind.literalText)
          SheetsCellClear(
            sheet: activeSheet,
            sheetRowNumber: update.sheetRowNumber,
            sheetColumnNumber: update.sheetColumnNumber,
          ),
    ];

    await client.applyOperations(
      spreadsheetId: spreadsheetId,
      operations: operations,
    );
  }

  Future<void> applyExercisesPlan({
    required String spreadsheetId,
    required ExercisesWritePlan plan,
  }) async {
    if (plan.rowAppends.isEmpty &&
        plan.rowUpdates.isEmpty &&
        plan.activeSheetFormulaUpdates.isEmpty) {
      return;
    }

    final metadata = await client.fetchMetadata(spreadsheetId);
    final exercisesSheet = _requiredSheet(metadata, 'Exercises');
    final operations = <SheetsWorkbookOperation>[
      for (final append in _sortedRowAppends(plan.rowAppends))
        SheetsRowInsertion(
          sheet: exercisesSheet,
          sheetRowNumber: append.sheetRowNumber,
          rowCount: 1,
        ),
      ..._rowUpdateWrites(exercisesSheet, plan.rowUpdates),
      ..._rowAppendWrites(exercisesSheet, plan.rowAppends),
    ];

    if (plan.activeSheetFormulaUpdates.isNotEmpty) {
      final activeSheet = _requiredActiveSheet(metadata);
      operations.addAll([
        for (final update in plan.activeSheetFormulaUpdates)
          SheetsCellWrite(
            sheet: activeSheet,
            sheetRowNumber: update.sheetRowNumber,
            sheetColumnNumber: update.sheetColumnNumber,
            value: update.value,
            mode: SheetsValueInputMode.userEntered,
          ),
      ]);
    }

    await client.applyOperations(
      spreadsheetId: spreadsheetId,
      operations: operations,
    );
  }

  Future<SheetsSheetIdentity> _activeSheet(String spreadsheetId) async {
    final metadata = await client.fetchMetadata(spreadsheetId);
    return _requiredActiveSheet(metadata);
  }

  Iterable<SheetsCellWrite> _headerWrites(
    SheetsSheetIdentity sheet,
    HistoryColumnInsertion insertion,
  ) sync* {
    for (var offset = 0; offset < insertion.headers.length; offset += 1) {
      yield SheetsCellWrite(
        sheet: sheet,
        sheetRowNumber: 1,
        sheetColumnNumber: insertion.sheetColumnNumber + offset,
        value: insertion.headers[offset],
        mode: SheetsValueInputMode.literalText,
      );
    }
    for (var offset = 0; offset < insertion.setLabels.length; offset += 1) {
      yield SheetsCellWrite(
        sheet: sheet,
        sheetRowNumber: 2,
        sheetColumnNumber: insertion.sheetColumnNumber + offset,
        value: insertion.setLabels[offset],
        mode: SheetsValueInputMode.literalText,
      );
    }
  }

  Iterable<SheetsCellWrite> _rowUpdateWrites(
    SheetsSheetIdentity sheet,
    Iterable<ExercisesRowUpdate> rows,
  ) sync* {
    for (final row in rows) {
      for (var index = 0; index < row.values.length; index += 1) {
        yield SheetsCellWrite(
          sheet: sheet,
          sheetRowNumber: row.sheetRowNumber,
          sheetColumnNumber: index + 1,
          value: row.values[index],
          mode: SheetsValueInputMode.literalText,
        );
      }
    }
  }

  Iterable<SheetsCellWrite> _rowAppendWrites(
    SheetsSheetIdentity sheet,
    Iterable<ExercisesRowAppend> rows,
  ) sync* {
    for (final row in rows) {
      for (var index = 0; index < row.values.length; index += 1) {
        yield SheetsCellWrite(
          sheet: sheet,
          sheetRowNumber: row.sheetRowNumber,
          sheetColumnNumber: index + 1,
          value: row.values[index],
          mode: SheetsValueInputMode.literalText,
        );
      }
    }
  }

  SheetsValueInputMode _modeForCellUpdate(CellUpdate update) {
    return switch (update.valueKind) {
      CellUpdateValueKind.literalText => SheetsValueInputMode.literalText,
      CellUpdateValueKind.formula => SheetsValueInputMode.userEntered,
    };
  }
}

List<ActiveSheetRowInsertion> _sortedRowInsertions(
  List<ActiveSheetRowInsertion> rowInsertions,
) {
  return [...rowInsertions]..sort(
    (first, second) => second.sheetRowNumber.compareTo(first.sheetRowNumber),
  );
}

List<ActiveSheetRowDeletion> _sortedRowDeletions(
  List<ActiveSheetRowDeletion> rowDeletions,
) {
  return [...rowDeletions]..sort(
    (first, second) => second.sheetRowNumber.compareTo(first.sheetRowNumber),
  );
}

List<HistoryColumnInsertion> _sortedColumnInsertions(
  List<HistoryColumnInsertion> columnInsertions,
) {
  return [...columnInsertions]..sort(
    (first, second) =>
        second.sheetColumnNumber.compareTo(first.sheetColumnNumber),
  );
}

List<ExercisesRowAppend> _sortedRowAppends(
  List<ExercisesRowAppend> rowAppends,
) {
  return [...rowAppends]..sort(
    (first, second) => second.sheetRowNumber.compareTo(first.sheetRowNumber),
  );
}

SheetsSheetIdentity _requiredActiveSheet(SheetsWorkbookMetadata metadata) {
  if (metadata.sheets.isEmpty) {
    throw StateError('Spreadsheet has no sheets.');
  }
  return metadata.sheets.first;
}

SheetsSheetIdentity _requiredSheet(
  SheetsWorkbookMetadata metadata,
  String title,
) {
  final sheet = metadata.sheetByTitle(title);
  if (sheet == null) {
    throw StateError('$title sheet is missing a sheet ID.');
  }
  return sheet;
}
