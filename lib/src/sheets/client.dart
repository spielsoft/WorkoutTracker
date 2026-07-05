import 'package:googleapis/sheets/v4.dart' as sheets;

abstract interface class SheetsWorkbookClient {
  Future<SheetsWorkbookMetadata> fetchMetadata(String spreadsheetId);

  Future<SheetsWorkbookSnapshot> readGrids({
    required String spreadsheetId,
    required Iterable<SheetsGridRead> reads,
  });

  Future<void> applyOperations({
    required String spreadsheetId,
    required Iterable<SheetsWorkbookOperation> operations,
  });
}

class SheetsSheetIdentity {
  const SheetsSheetIdentity({required this.sheetId, required this.title});

  final int sheetId;
  final String title;
}

class SheetsWorkbookMetadata {
  SheetsWorkbookMetadata({required Iterable<SheetsSheetIdentity> sheets})
    : sheets = List<SheetsSheetIdentity>.unmodifiable(sheets);

  final List<SheetsSheetIdentity> sheets;

  SheetsSheetIdentity? sheetByTitle(String title) {
    for (final sheet in sheets) {
      if (sheet.title == title) {
        return sheet;
      }
    }
    return null;
  }
}

class SheetsGridRead {
  const SheetsGridRead({
    required this.sheet,
    this.startRowNumber,
    this.endRowNumber,
    this.startColumnNumber,
    this.endColumnNumber,
  });

  final SheetsSheetIdentity sheet;
  final int? startRowNumber;
  final int? endRowNumber;
  final int? startColumnNumber;
  final int? endColumnNumber;
}

class SheetsWorkbookSnapshot {
  SheetsWorkbookSnapshot({required Iterable<SheetsGridSnapshot> sheets})
    : sheets = List<SheetsGridSnapshot>.unmodifiable(sheets);

  final List<SheetsGridSnapshot> sheets;
}

class SheetsGridSnapshot {
  SheetsGridSnapshot({
    required this.sheet,
    required Iterable<Iterable<String>> rows,
    Iterable<SheetsCellFormula> cellFormulas = const [],
    Set<int> mergedFirstColumnRows = const {},
  }) : rows = List<List<String>>.unmodifiable(
         rows.map((row) => List<String>.unmodifiable(row)),
       ),
       cellFormulas = List<SheetsCellFormula>.unmodifiable(cellFormulas),
       mergedFirstColumnRows = Set<int>.unmodifiable(mergedFirstColumnRows);

  final SheetsSheetIdentity sheet;
  final List<List<String>> rows;
  final List<SheetsCellFormula> cellFormulas;
  final Set<int> mergedFirstColumnRows;
}

class SheetsCellFormula {
  const SheetsCellFormula({
    required this.sheetRowNumber,
    required this.sheetColumnNumber,
    required this.formula,
  });

  final int sheetRowNumber;
  final int sheetColumnNumber;
  final String formula;
}

sealed class SheetsWorkbookOperation {
  const SheetsWorkbookOperation({required this.sheet});

  final SheetsSheetIdentity sheet;
}

enum SheetsValueInputMode { literalText, userEntered }

class SheetsCellWrite extends SheetsWorkbookOperation {
  const SheetsCellWrite({
    required super.sheet,
    required this.sheetRowNumber,
    required this.sheetColumnNumber,
    required this.value,
    this.mode = SheetsValueInputMode.literalText,
  });

  final int sheetRowNumber;
  final int sheetColumnNumber;
  final String value;
  final SheetsValueInputMode mode;
}

class SheetsCellClear extends SheetsWorkbookOperation {
  const SheetsCellClear({
    required super.sheet,
    required this.sheetRowNumber,
    required this.sheetColumnNumber,
  });

  final int sheetRowNumber;
  final int sheetColumnNumber;
}

class SheetsRowInsertion extends SheetsWorkbookOperation {
  const SheetsRowInsertion({
    required super.sheet,
    required this.sheetRowNumber,
    required this.rowCount,
  });

  final int sheetRowNumber;
  final int rowCount;
}

class SheetsRowDeletion extends SheetsWorkbookOperation {
  const SheetsRowDeletion({
    required super.sheet,
    required this.sheetRowNumber,
    required this.rowCount,
  });

  final int sheetRowNumber;
  final int rowCount;
}

class SheetsRowMove extends SheetsWorkbookOperation {
  const SheetsRowMove({
    required super.sheet,
    required this.fromRow,
    required this.rowCount,
    required this.toRow,
  });

  final int fromRow;
  final int rowCount;
  final int toRow;
}

class SheetsColumnInsertion extends SheetsWorkbookOperation {
  const SheetsColumnInsertion({
    required super.sheet,
    required this.sheetColumnNumber,
    required this.columnCount,
  });

  final int sheetColumnNumber;
  final int columnCount;
}

class SheetsColumnDeletion extends SheetsWorkbookOperation {
  const SheetsColumnDeletion({
    required super.sheet,
    required this.sheetColumnNumber,
    required this.columnCount,
  });

  final int sheetColumnNumber;
  final int columnCount;
}

class SheetsColumnMove extends SheetsWorkbookOperation {
  const SheetsColumnMove({
    required super.sheet,
    required this.fromColumn,
    required this.columnCount,
    required this.toColumn,
  });

  final int fromColumn;
  final int columnCount;
  final int toColumn;
}

class GoogleApisWorkbookClient implements SheetsWorkbookClient {
  GoogleApisWorkbookClient(this._api);

  final sheets.SheetsApi _api;

  static const writeScopes = [sheets.SheetsApi.spreadsheetsScope];

  @override
  Future<SheetsWorkbookMetadata> fetchMetadata(String spreadsheetId) async {
    final spreadsheet = await _api.spreadsheets.get(
      spreadsheetId,
      $fields: 'sheets(properties(sheetId,index,title,sheetType))',
    );
    return SheetsWorkbookMetadata(sheets: _sheetIdentities(spreadsheet));
  }

  @override
  Future<SheetsWorkbookSnapshot> readGrids({
    required String spreadsheetId,
    required Iterable<SheetsGridRead> reads,
  }) async {
    final readList = reads.toList();
    final spreadsheet = await _api.spreadsheets.get(
      spreadsheetId,
      includeGridData: true,
      ranges: readList.map(_rangeForGridRead).toList(),
      $fields: [
        'sheets(',
        'properties(sheetId,index,title,sheetType),',
        'merges(startRowIndex,endRowIndex,startColumnIndex,endColumnIndex),',
        'data(startRow,startColumn,rowData(values(',
        'formattedValue,userEnteredValue',
        ')))',
        ')',
      ].join(),
    );

    return SheetsWorkbookSnapshot(
      sheets: _sortedApiSheets(spreadsheet).map(_sheetSnapshot),
    );
  }

  @override
  Future<void> applyOperations({
    required String spreadsheetId,
    required Iterable<SheetsWorkbookOperation> operations,
  }) async {
    final requests = <sheets.Request>[
      for (final operation in operations) _requestForOperation(operation),
    ];
    if (requests.isEmpty) {
      return;
    }

    await _api.spreadsheets.batchUpdate(
      sheets.BatchUpdateSpreadsheetRequest(requests: requests),
      spreadsheetId,
      $fields: 'spreadsheetId',
    );
  }
}

sheets.Request _requestForOperation(SheetsWorkbookOperation operation) {
  return switch (operation) {
    SheetsCellWrite() => _updateCellRequest(operation),
    SheetsCellClear() => _clearCellRequest(operation),
    SheetsRowInsertion() => _insertDimensionRequest(
      sheet: operation.sheet,
      dimension: 'ROWS',
      startNumber: operation.sheetRowNumber,
      count: operation.rowCount,
      inheritFromBefore: operation.sheetRowNumber > 1,
    ),
    SheetsRowDeletion() => _deleteDimensionRequest(
      sheet: operation.sheet,
      dimension: 'ROWS',
      startNumber: operation.sheetRowNumber,
      count: operation.rowCount,
    ),
    SheetsRowMove() => _moveDimensionRequest(
      sheet: operation.sheet,
      dimension: 'ROWS',
      startNumber: operation.fromRow,
      count: operation.rowCount,
      destinationNumber: operation.toRow,
    ),
    SheetsColumnInsertion() => _insertDimensionRequest(
      sheet: operation.sheet,
      dimension: 'COLUMNS',
      startNumber: operation.sheetColumnNumber,
      count: operation.columnCount,
      inheritFromBefore: true,
    ),
    SheetsColumnDeletion() => _deleteDimensionRequest(
      sheet: operation.sheet,
      dimension: 'COLUMNS',
      startNumber: operation.sheetColumnNumber,
      count: operation.columnCount,
    ),
    SheetsColumnMove() => _moveDimensionRequest(
      sheet: operation.sheet,
      dimension: 'COLUMNS',
      startNumber: operation.fromColumn,
      count: operation.columnCount,
      destinationNumber: operation.toColumn,
    ),
  };
}

sheets.Request _insertDimensionRequest({
  required SheetsSheetIdentity sheet,
  required String dimension,
  required int startNumber,
  required int count,
  required bool inheritFromBefore,
}) {
  return sheets.Request(
    insertDimension: sheets.InsertDimensionRequest(
      inheritFromBefore: inheritFromBefore,
      range: _dimensionRange(
        sheet: sheet,
        dimension: dimension,
        startNumber: startNumber,
        count: count,
      ),
    ),
  );
}

sheets.Request _deleteDimensionRequest({
  required SheetsSheetIdentity sheet,
  required String dimension,
  required int startNumber,
  required int count,
}) {
  return sheets.Request(
    deleteDimension: sheets.DeleteDimensionRequest(
      range: _dimensionRange(
        sheet: sheet,
        dimension: dimension,
        startNumber: startNumber,
        count: count,
      ),
    ),
  );
}

sheets.Request _moveDimensionRequest({
  required SheetsSheetIdentity sheet,
  required String dimension,
  required int startNumber,
  required int count,
  required int destinationNumber,
}) {
  return sheets.Request(
    moveDimension: sheets.MoveDimensionRequest(
      destinationIndex: destinationNumber - 1,
      source: _dimensionRange(
        sheet: sheet,
        dimension: dimension,
        startNumber: startNumber,
        count: count,
      ),
    ),
  );
}

sheets.DimensionRange _dimensionRange({
  required SheetsSheetIdentity sheet,
  required String dimension,
  required int startNumber,
  required int count,
}) {
  final startIndex = startNumber - 1;
  return sheets.DimensionRange(
    sheetId: sheet.sheetId,
    dimension: dimension,
    startIndex: startIndex,
    endIndex: startIndex + count,
  );
}

sheets.Request _updateCellRequest(SheetsCellWrite operation) {
  return sheets.Request(
    updateCells: sheets.UpdateCellsRequest(
      fields: 'userEnteredValue',
      range: _singleCellRange(
        sheet: operation.sheet,
        sheetRowNumber: operation.sheetRowNumber,
        sheetColumnNumber: operation.sheetColumnNumber,
      ),
      rows: [
        sheets.RowData(
          values: [
            sheets.CellData(
              userEnteredValue: switch (operation.mode) {
                SheetsValueInputMode.literalText => sheets.ExtendedValue(
                  stringValue: operation.value,
                ),
                SheetsValueInputMode.userEntered => sheets.ExtendedValue(
                  formulaValue: operation.value,
                ),
              },
            ),
          ],
        ),
      ],
    ),
  );
}

sheets.Request _clearCellRequest(SheetsCellClear operation) {
  return sheets.Request(
    updateCells: sheets.UpdateCellsRequest(
      fields: 'userEnteredValue',
      range: _singleCellRange(
        sheet: operation.sheet,
        sheetRowNumber: operation.sheetRowNumber,
        sheetColumnNumber: operation.sheetColumnNumber,
      ),
      rows: [
        sheets.RowData(values: [sheets.CellData()]),
      ],
    ),
  );
}

sheets.GridRange _singleCellRange({
  required SheetsSheetIdentity sheet,
  required int sheetRowNumber,
  required int sheetColumnNumber,
}) {
  final rowIndex = sheetRowNumber - 1;
  final columnIndex = sheetColumnNumber - 1;
  return sheets.GridRange(
    sheetId: sheet.sheetId,
    startRowIndex: rowIndex,
    endRowIndex: rowIndex + 1,
    startColumnIndex: columnIndex,
    endColumnIndex: columnIndex + 1,
  );
}

List<SheetsSheetIdentity> _sheetIdentities(sheets.Spreadsheet spreadsheet) {
  return [
    for (final sheet in _sortedApiSheets(spreadsheet))
      if (sheet.properties?.sheetId != null)
        SheetsSheetIdentity(
          sheetId: sheet.properties!.sheetId!,
          title: sheet.properties?.title ?? '',
        ),
  ];
}

List<sheets.Sheet> _sortedApiSheets(sheets.Spreadsheet spreadsheet) {
  return [...?spreadsheet.sheets]..sort((left, right) {
    return (left.properties?.index ?? 0).compareTo(
      right.properties?.index ?? 0,
    );
  });
}

SheetsGridSnapshot _sheetSnapshot(sheets.Sheet apiSheet) {
  final sheet = SheetsSheetIdentity(
    sheetId: apiSheet.properties?.sheetId ?? 0,
    title: apiSheet.properties?.title ?? '',
  );
  return SheetsGridSnapshot(
    sheet: sheet,
    rows: _rowsFromGridData(apiSheet.data ?? const []),
    cellFormulas: _formulasFromGridData(apiSheet.data ?? const []),
    mergedFirstColumnRows: _mergedFirstColumnRows(apiSheet.merges ?? const []),
  );
}

List<List<String>> _rowsFromGridData(List<sheets.GridData> gridData) {
  final rows = <int, List<String>>{};
  for (final grid in gridData) {
    final startRow = grid.startRow ?? 0;
    final startColumn = grid.startColumn ?? 0;
    final rowData = grid.rowData ?? const <sheets.RowData>[];
    for (var rowOffset = 0; rowOffset < rowData.length; rowOffset += 1) {
      final rowIndex = startRow + rowOffset;
      final row = rows.putIfAbsent(rowIndex, () => <String>[]);
      final values = rowData[rowOffset].values ?? const <sheets.CellData>[];
      for (
        var columnOffset = 0;
        columnOffset < values.length;
        columnOffset += 1
      ) {
        final columnIndex = startColumn + columnOffset;
        _ensureLength(row, columnIndex + 1);
        row[columnIndex] = values[columnOffset].formattedValue ?? '';
      }
    }
  }

  if (rows.isEmpty) {
    return const [];
  }

  final lastRowIndex = rows.keys.reduce((left, right) {
    return left > right ? left : right;
  });
  return [
    for (var rowIndex = 0; rowIndex <= lastRowIndex; rowIndex += 1)
      _trimTrailingEmptyCells(rows[rowIndex] ?? const []),
  ];
}

List<SheetsCellFormula> _formulasFromGridData(List<sheets.GridData> gridData) {
  final formulas = <SheetsCellFormula>[];
  for (final grid in gridData) {
    final startRow = grid.startRow ?? 0;
    final startColumn = grid.startColumn ?? 0;
    final rowData = grid.rowData ?? const <sheets.RowData>[];
    for (var rowOffset = 0; rowOffset < rowData.length; rowOffset += 1) {
      final values = rowData[rowOffset].values ?? const <sheets.CellData>[];
      for (
        var columnOffset = 0;
        columnOffset < values.length;
        columnOffset += 1
      ) {
        final formula =
            values[columnOffset].userEnteredValue?.formulaValue ?? '';
        if (formula.isEmpty) {
          continue;
        }
        formulas.add(
          SheetsCellFormula(
            sheetRowNumber: startRow + rowOffset + 1,
            sheetColumnNumber: startColumn + columnOffset + 1,
            formula: formula,
          ),
        );
      }
    }
  }
  return List<SheetsCellFormula>.unmodifiable(formulas);
}

Set<int> _mergedFirstColumnRows(List<sheets.GridRange> merges) {
  final rows = <int>{};
  for (final merge in merges) {
    final startColumn = merge.startColumnIndex ?? 0;
    final endColumn = merge.endColumnIndex ?? startColumn + 1;
    if (startColumn > 0 || endColumn <= 0) {
      continue;
    }

    final startRow = merge.startRowIndex ?? 0;
    final endRow = merge.endRowIndex ?? startRow + 1;
    for (var rowIndex = startRow; rowIndex < endRow; rowIndex += 1) {
      rows.add(rowIndex + 1);
    }
  }
  return Set<int>.unmodifiable(rows);
}

String _rangeForGridRead(SheetsGridRead read) {
  final startRow = read.startRowNumber;
  final endRow = read.endRowNumber;
  final startColumn = read.startColumnNumber;
  final endColumn = read.endColumnNumber;
  if (startRow == null &&
      endRow == null &&
      startColumn == null &&
      endColumn == null) {
    return _quotedSheetTitle(read.sheet.title);
  }

  final start =
      '${startColumn == null ? '' : _columnLetter(startColumn)}'
      '${startRow ?? ''}';
  final end =
      '${endColumn == null ? '' : _columnLetter(endColumn)}'
      '${endRow ?? ''}';
  return '${_quotedSheetTitle(read.sheet.title)}!$start:$end';
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

void _ensureLength(List<String> row, int length) {
  while (row.length < length) {
    row.add('');
  }
}

List<String> _trimTrailingEmptyCells(List<String> row) {
  var length = row.length;
  while (length > 0 && row[length - 1].isEmpty) {
    length -= 1;
  }
  return List<String>.unmodifiable(row.take(length));
}
