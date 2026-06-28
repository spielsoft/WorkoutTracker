import 'package:googleapis/sheets/v4.dart' as sheets;
import 'package:workout_tracker/sheet_contract.dart';

class GoogleSheetsReadAdapter {
  GoogleSheetsReadAdapter({required this.client});

  final GoogleSheetsSpreadsheetClient client;

  Future<ActiveSheetInput> readActiveSheetInput(String spreadsheetId) async {
    final metadata = await client.fetchSpreadsheetMetadata(spreadsheetId);
    if (metadata.sheets.isEmpty) {
      throw StateError('Spreadsheet has no sheets.');
    }

    final activeSheetMetadata = metadata.sheets.first;
    final workbook = await client.fetchSpreadsheetGridData(
      spreadsheetId,
      ranges: [
        _quotedSheetTitle(activeSheetMetadata.title),
        if (metadata.hasSheet('Exercises')) _quotedSheetTitle('Exercises'),
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
      exercisesRows: workbook.exercisesSheet?.rows ?? const [],
      mergedFirstColumnRows: activeSheet.mergedFirstColumnRows,
    );
  }

  Future<ParsedActiveSheet> readParsedActiveSheet(String spreadsheetId) async {
    return parseActiveSheet(await readActiveSheetInput(spreadsheetId));
  }
}

abstract interface class GoogleSheetsSpreadsheetClient {
  Future<GoogleSpreadsheetMetadata> fetchSpreadsheetMetadata(
    String spreadsheetId,
  );

  Future<GoogleSpreadsheetSnapshot> fetchSpreadsheetGridData(
    String spreadsheetId, {
    required Iterable<String> ranges,
  });
}

class GoogleSpreadsheetMetadata {
  GoogleSpreadsheetMetadata({required Iterable<GoogleSheetMetadata> sheets})
    : sheets = List<GoogleSheetMetadata>.unmodifiable(sheets);

  final List<GoogleSheetMetadata> sheets;

  bool hasSheet(String title) {
    return sheets.any((sheet) => sheet.title == title);
  }
}

class GoogleSheetMetadata {
  const GoogleSheetMetadata({required this.title});

  final String title;
}

class GoogleSpreadsheetSnapshot {
  GoogleSpreadsheetSnapshot({required Iterable<GoogleSheetSnapshot> sheets})
    : sheets = List<GoogleSheetSnapshot>.unmodifiable(sheets);

  final List<GoogleSheetSnapshot> sheets;

  GoogleSheetSnapshot? get exercisesSheet {
    for (final sheet in sheets) {
      if (sheet.title == 'Exercises') {
        return sheet;
      }
    }
    return null;
  }
}

class GoogleSheetSnapshot {
  GoogleSheetSnapshot({
    required this.title,
    required Iterable<Iterable<String>> rows,
    Iterable<GoogleSheetCellFormula> cellFormulas = const [],
    Set<int> mergedFirstColumnRows = const {},
  }) : rows = List<List<String>>.unmodifiable(
         rows.map((row) => List<String>.unmodifiable(row)),
       ),
       cellFormulas = List<GoogleSheetCellFormula>.unmodifiable(cellFormulas),
       mergedFirstColumnRows = Set<int>.unmodifiable(mergedFirstColumnRows);

  final String title;
  final List<List<String>> rows;
  final List<GoogleSheetCellFormula> cellFormulas;
  final Set<int> mergedFirstColumnRows;
}

class GoogleSheetCellFormula {
  const GoogleSheetCellFormula({
    required this.sheetRowNumber,
    required this.sheetColumnNumber,
    required this.formula,
  });

  final int sheetRowNumber;
  final int sheetColumnNumber;
  final String formula;
}

class GoogleApisSheetsSpreadsheetClient
    implements GoogleSheetsSpreadsheetClient {
  GoogleApisSheetsSpreadsheetClient(this._api);

  final sheets.SheetsApi _api;

  @override
  Future<GoogleSpreadsheetMetadata> fetchSpreadsheetMetadata(
    String spreadsheetId,
  ) async {
    final spreadsheet = await _api.spreadsheets.get(
      spreadsheetId,
      $fields: 'sheets(properties(index,title,sheetType))',
    );
    final apiSheets = _sortedApiSheets(spreadsheet);
    if (apiSheets.isEmpty) {
      throw StateError('Spreadsheet has no sheets.');
    }

    return GoogleSpreadsheetMetadata(
      sheets: apiSheets.map(
        (sheet) => GoogleSheetMetadata(title: sheet.properties?.title ?? ''),
      ),
    );
  }

  @override
  Future<GoogleSpreadsheetSnapshot> fetchSpreadsheetGridData(
    String spreadsheetId, {
    required Iterable<String> ranges,
  }) async {
    final spreadsheet = await _api.spreadsheets.get(
      spreadsheetId,
      includeGridData: true,
      ranges: ranges.toList(),
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

    final apiSheets = _sortedApiSheets(spreadsheet);

    return GoogleSpreadsheetSnapshot(
      sheets: apiSheets.map(_sheetSnapshotFromApiSheet),
    );
  }

  List<sheets.Sheet> _sortedApiSheets(sheets.Spreadsheet spreadsheet) {
    return [...?spreadsheet.sheets]..sort((left, right) {
      return (left.properties?.index ?? 0).compareTo(
        right.properties?.index ?? 0,
      );
    });
  }

  GoogleSheetSnapshot _sheetSnapshotFromApiSheet(sheets.Sheet apiSheet) {
    return GoogleSheetSnapshot(
      title: apiSheet.properties?.title ?? '',
      rows: _rowsFromGridData(apiSheet.data ?? const []),
      cellFormulas: _formulasFromGridData(apiSheet.data ?? const []),
      mergedFirstColumnRows: _mergedFirstColumnRows(
        apiSheet.merges ?? const [],
      ),
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

  List<GoogleSheetCellFormula> _formulasFromGridData(
    List<sheets.GridData> gridData,
  ) {
    final formulas = <GoogleSheetCellFormula>[];
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
            GoogleSheetCellFormula(
              sheetRowNumber: startRow + rowOffset + 1,
              sheetColumnNumber: startColumn + columnOffset + 1,
              formula: formula,
            ),
          );
        }
      }
    }
    return List<GoogleSheetCellFormula>.unmodifiable(formulas);
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
}

String _quotedSheetTitle(String title) {
  return "'${title.replaceAll("'", "''")}'";
}
