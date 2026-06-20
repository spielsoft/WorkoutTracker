import 'package:googleapis/sheets/v4.dart' as sheets;
import 'package:workout_tracker/sheet_contract.dart';

class GoogleSheetsWriteAdapter {
  GoogleSheetsWriteAdapter({required this.client});

  final GoogleSheetsWriteClient client;

  Future<void> applyActiveSheetWritePlan({
    required String spreadsheetId,
    required ActiveSheetWritePlan plan,
  }) async {
    if (plan.columnInsertions.isEmpty &&
        plan.rowInsertions.isEmpty &&
        plan.cellUpdates.isEmpty) {
      return;
    }

    final activeSheet = await client.fetchActiveSheetTarget(spreadsheetId);
    final sortedRowInsertions = [...plan.rowInsertions]
      ..sort(
        (first, second) =>
            second.sheetRowNumber.compareTo(first.sheetRowNumber),
      );
    final sortedInsertions = [...plan.columnInsertions]
      ..sort(
        (first, second) =>
            second.sheetColumnNumber.compareTo(first.sheetColumnNumber),
      );

    for (final insertion in sortedRowInsertions) {
      await client.insertRows(
        spreadsheetId: spreadsheetId,
        sheetId: activeSheet.sheetId,
        sheetRowNumber: insertion.sheetRowNumber,
        rowCount: insertion.rowCount,
      );
    }

    for (final insertion in sortedInsertions) {
      await client.insertColumns(
        spreadsheetId: spreadsheetId,
        sheetId: activeSheet.sheetId,
        sheetColumnNumber: insertion.sheetColumnNumber,
        columnCount: insertion.setLabels.length,
      );
    }

    final cells = <GoogleSheetsCellWrite>[
      for (final insertion in plan.columnInsertions)
        ..._headerWritesForInsertion(insertion),
      for (final update in plan.cellUpdates)
        if (update.value.isNotEmpty)
          GoogleSheetsCellWrite(
            sheetRowNumber: update.sheetRowNumber,
            sheetColumnNumber: update.sheetColumnNumber,
            value: update.value,
            mode: _modeForCellUpdate(update),
          ),
    ];
    final clears = <GoogleSheetsCellClear>[
      for (final update in plan.cellUpdates)
        if (update.value.isEmpty &&
            update.valueKind == CellUpdateValueKind.literalText)
          GoogleSheetsCellClear(
            sheetRowNumber: update.sheetRowNumber,
            sheetColumnNumber: update.sheetColumnNumber,
          ),
    ];

    if (cells.isEmpty && clears.isEmpty) {
      return;
    }

    final literalCells = cells
        .where((cell) => cell.mode == GoogleSheetsValueInputMode.literalText)
        .toList();
    final userEnteredCells = cells
        .where((cell) => cell.mode == GoogleSheetsValueInputMode.userEntered)
        .toList();

    if (literalCells.isNotEmpty) {
      await client.writeCells(
        spreadsheetId: spreadsheetId,
        sheetTitle: activeSheet.title,
        cells: literalCells,
        mode: GoogleSheetsValueInputMode.literalText,
      );
    }
    if (userEnteredCells.isNotEmpty) {
      await client.writeCells(
        spreadsheetId: spreadsheetId,
        sheetTitle: activeSheet.title,
        cells: userEnteredCells,
        mode: GoogleSheetsValueInputMode.userEntered,
      );
    }
    if (clears.isNotEmpty) {
      await client.clearCells(
        spreadsheetId: spreadsheetId,
        sheetTitle: activeSheet.title,
        cells: clears,
      );
    }
  }

  Future<void> applyExercisesWritePlan({
    required String spreadsheetId,
    required ExercisesWritePlan plan,
  }) async {
    final cells = <GoogleSheetsCellWrite>[
      for (final update in plan.rowUpdates)
        for (var index = 0; index < update.values.length; index += 1)
          GoogleSheetsCellWrite(
            sheetRowNumber: update.sheetRowNumber,
            sheetColumnNumber: index + 1,
            value: update.values[index],
            mode: GoogleSheetsValueInputMode.literalText,
          ),
      for (final append in plan.rowAppends)
        for (var index = 0; index < append.values.length; index += 1)
          GoogleSheetsCellWrite(
            sheetRowNumber: append.sheetRowNumber,
            sheetColumnNumber: index + 1,
            value: append.values[index],
            mode: GoogleSheetsValueInputMode.literalText,
          ),
    ];
    await client.writeCells(
      spreadsheetId: spreadsheetId,
      sheetTitle: 'Exercises',
      cells: cells,
      mode: GoogleSheetsValueInputMode.literalText,
    );
    if (plan.activeSheetFormulaUpdates.isNotEmpty) {
      final activeSheet = await client.fetchActiveSheetTarget(spreadsheetId);
      await client.writeCells(
        spreadsheetId: spreadsheetId,
        sheetTitle: activeSheet.title,
        cells: [
          for (final update in plan.activeSheetFormulaUpdates)
            GoogleSheetsCellWrite(
              sheetRowNumber: update.sheetRowNumber,
              sheetColumnNumber: update.sheetColumnNumber,
              value: update.value,
              mode: GoogleSheetsValueInputMode.userEntered,
            ),
        ],
        mode: GoogleSheetsValueInputMode.userEntered,
      );
    }
  }

  Iterable<GoogleSheetsCellWrite> _headerWritesForInsertion(
    HistoryColumnInsertion insertion,
  ) sync* {
    for (var offset = 0; offset < insertion.headers.length; offset += 1) {
      yield GoogleSheetsCellWrite(
        sheetRowNumber: 1,
        sheetColumnNumber: insertion.sheetColumnNumber + offset,
        value: insertion.headers[offset],
        mode: GoogleSheetsValueInputMode.literalText,
      );
    }
    for (var offset = 0; offset < insertion.setLabels.length; offset += 1) {
      yield GoogleSheetsCellWrite(
        sheetRowNumber: 2,
        sheetColumnNumber: insertion.sheetColumnNumber + offset,
        value: insertion.setLabels[offset],
        mode: GoogleSheetsValueInputMode.literalText,
      );
    }
  }

  GoogleSheetsValueInputMode _modeForCellUpdate(CellUpdate update) {
    return switch (update.valueKind) {
      CellUpdateValueKind.literalText => GoogleSheetsValueInputMode.literalText,
      CellUpdateValueKind.formula => GoogleSheetsValueInputMode.userEntered,
    };
  }
}

abstract interface class GoogleSheetsWriteClient {
  Future<GoogleSheetsActiveSheetTarget> fetchActiveSheetTarget(
    String spreadsheetId,
  );

  Future<void> insertColumns({
    required String spreadsheetId,
    required int sheetId,
    required int sheetColumnNumber,
    required int columnCount,
  });

  Future<void> insertRows({
    required String spreadsheetId,
    required int sheetId,
    required int sheetRowNumber,
    required int rowCount,
  });

  Future<void> writeCells({
    required String spreadsheetId,
    required String sheetTitle,
    required Iterable<GoogleSheetsCellWrite> cells,
    required GoogleSheetsValueInputMode mode,
  });

  Future<void> clearCells({
    required String spreadsheetId,
    required String sheetTitle,
    required Iterable<GoogleSheetsCellClear> cells,
  });
}

class GoogleSheetsActiveSheetTarget {
  const GoogleSheetsActiveSheetTarget({
    required this.sheetId,
    required this.title,
  });

  final int sheetId;
  final String title;
}

class GoogleSheetsCellWrite {
  const GoogleSheetsCellWrite({
    required this.sheetRowNumber,
    required this.sheetColumnNumber,
    required this.value,
    required this.mode,
  });

  final int sheetRowNumber;
  final int sheetColumnNumber;
  final String value;
  final GoogleSheetsValueInputMode mode;
}

class GoogleSheetsCellClear {
  const GoogleSheetsCellClear({
    required this.sheetRowNumber,
    required this.sheetColumnNumber,
  });

  final int sheetRowNumber;
  final int sheetColumnNumber;
}

enum GoogleSheetsValueInputMode { literalText, userEntered }

class GoogleApisSheetsWriteClient implements GoogleSheetsWriteClient {
  GoogleApisSheetsWriteClient(this._api);

  final sheets.SheetsApi _api;

  static const writeScopes = [sheets.SheetsApi.spreadsheetsScope];

  @override
  Future<GoogleSheetsActiveSheetTarget> fetchActiveSheetTarget(
    String spreadsheetId,
  ) async {
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
    if (apiSheets.isEmpty) {
      throw StateError('Spreadsheet has no sheets.');
    }

    final activeSheetProperties = apiSheets.first.properties;
    final activeSheetId = activeSheetProperties?.sheetId;
    if (activeSheetId == null) {
      throw StateError('Active sheet is missing a sheet ID.');
    }

    return GoogleSheetsActiveSheetTarget(
      sheetId: activeSheetId,
      title: activeSheetProperties?.title ?? '',
    );
  }

  @override
  Future<void> insertColumns({
    required String spreadsheetId,
    required int sheetId,
    required int sheetColumnNumber,
    required int columnCount,
  }) async {
    if (columnCount <= 0) {
      return;
    }

    final startIndex = sheetColumnNumber - 1;
    await _api.spreadsheets.batchUpdate(
      sheets.BatchUpdateSpreadsheetRequest(
        requests: [
          sheets.Request(
            insertDimension: sheets.InsertDimensionRequest(
              inheritFromBefore: true,
              range: sheets.DimensionRange(
                sheetId: sheetId,
                dimension: 'COLUMNS',
                startIndex: startIndex,
                endIndex: startIndex + columnCount,
              ),
            ),
          ),
        ],
      ),
      spreadsheetId,
      $fields: 'spreadsheetId',
    );
  }

  @override
  Future<void> insertRows({
    required String spreadsheetId,
    required int sheetId,
    required int sheetRowNumber,
    required int rowCount,
  }) async {
    if (rowCount <= 0) {
      return;
    }

    final startIndex = sheetRowNumber - 1;
    await _api.spreadsheets.batchUpdate(
      sheets.BatchUpdateSpreadsheetRequest(
        requests: [
          sheets.Request(
            insertDimension: sheets.InsertDimensionRequest(
              inheritFromBefore: startIndex > 0,
              range: sheets.DimensionRange(
                sheetId: sheetId,
                dimension: 'ROWS',
                startIndex: startIndex,
                endIndex: startIndex + rowCount,
              ),
            ),
          ),
        ],
      ),
      spreadsheetId,
      $fields: 'spreadsheetId',
    );
  }

  @override
  Future<void> writeCells({
    required String spreadsheetId,
    required String sheetTitle,
    required Iterable<GoogleSheetsCellWrite> cells,
    required GoogleSheetsValueInputMode mode,
  }) async {
    final valueRanges = [
      for (final cell in cells)
        sheets.ValueRange(
          range:
              '${_quotedSheetTitle(sheetTitle)}!'
              '${_cellReference(cell.sheetRowNumber, cell.sheetColumnNumber)}',
          values: [
            [cell.value],
          ],
        ),
    ];
    if (valueRanges.isEmpty) {
      return;
    }

    await _api.spreadsheets.values.batchUpdate(
      sheets.BatchUpdateValuesRequest(
        data: valueRanges,
        valueInputOption: _valueInputOption(mode),
      ),
      spreadsheetId,
      $fields: 'spreadsheetId,totalUpdatedCells',
    );
  }

  @override
  Future<void> clearCells({
    required String spreadsheetId,
    required String sheetTitle,
    required Iterable<GoogleSheetsCellClear> cells,
  }) async {
    final ranges = [
      for (final cell in cells)
        '${_quotedSheetTitle(sheetTitle)}!'
            '${_cellReference(cell.sheetRowNumber, cell.sheetColumnNumber)}',
    ];
    if (ranges.isEmpty) {
      return;
    }

    await _api.spreadsheets.values.batchClear(
      sheets.BatchClearValuesRequest(ranges: ranges),
      spreadsheetId,
      $fields: 'spreadsheetId,clearedRanges',
    );
  }
}

String _valueInputOption(GoogleSheetsValueInputMode mode) {
  return switch (mode) {
    GoogleSheetsValueInputMode.literalText => 'RAW',
    GoogleSheetsValueInputMode.userEntered => 'USER_ENTERED',
  };
}

String _cellReference(int sheetRowNumber, int sheetColumnNumber) {
  return '${_columnLetter(sheetColumnNumber)}$sheetRowNumber';
}

String _columnLetter(int oneBasedColumnNumber) {
  var columnNumber = oneBasedColumnNumber;
  var letters = '';
  while (columnNumber > 0) {
    final remainder = (columnNumber - 1) % 26;
    letters = String.fromCharCode(65 + remainder) + letters;
    columnNumber = (columnNumber - 1) ~/ 26;
  }
  return letters;
}

String _quotedSheetTitle(String title) {
  return "'${title.replaceAll("'", "''")}'";
}
