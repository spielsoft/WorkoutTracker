import 'package:googleapis/sheets/v4.dart' as sheets;
import 'package:workout_tracker/sheet_contract.dart';

class GoogleSheetsWriteAdapter {
  GoogleSheetsWriteAdapter({required this.client});

  final GoogleSheetsWriteClient client;

  Future<void> applyActiveSheetWritePlan({
    required String spreadsheetId,
    required ActiveSheetWritePlan plan,
  }) async {
    if (plan.columnInsertions.isEmpty && plan.cellUpdates.isEmpty) {
      return;
    }

    final activeSheet = await client.fetchActiveSheetTarget(spreadsheetId);
    final sortedInsertions = [...plan.columnInsertions]
      ..sort(
        (first, second) =>
            second.sheetColumnNumber.compareTo(first.sheetColumnNumber),
      );

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
        GoogleSheetsCellWrite(
          sheetRowNumber: update.sheetRowNumber,
          sheetColumnNumber: update.sheetColumnNumber,
          value: update.value,
        ),
    ];

    if (cells.isEmpty) {
      return;
    }

    await client.writeCells(
      spreadsheetId: spreadsheetId,
      sheetTitle: activeSheet.title,
      cells: cells,
    );
  }

  Iterable<GoogleSheetsCellWrite> _headerWritesForInsertion(
    HistoryColumnInsertion insertion,
  ) sync* {
    for (var offset = 0; offset < insertion.headers.length; offset += 1) {
      yield GoogleSheetsCellWrite(
        sheetRowNumber: 1,
        sheetColumnNumber: insertion.sheetColumnNumber + offset,
        value: insertion.headers[offset],
      );
    }
    for (var offset = 0; offset < insertion.setLabels.length; offset += 1) {
      yield GoogleSheetsCellWrite(
        sheetRowNumber: 2,
        sheetColumnNumber: insertion.sheetColumnNumber + offset,
        value: insertion.setLabels[offset],
      );
    }
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

  Future<void> writeCells({
    required String spreadsheetId,
    required String sheetTitle,
    required Iterable<GoogleSheetsCellWrite> cells,
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
  });

  final int sheetRowNumber;
  final int sheetColumnNumber;
  final String value;
}

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
  Future<void> writeCells({
    required String spreadsheetId,
    required String sheetTitle,
    required Iterable<GoogleSheetsCellWrite> cells,
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
        valueInputOption: 'USER_ENTERED',
      ),
      spreadsheetId,
      $fields: 'spreadsheetId,totalUpdatedCells',
    );
  }
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
