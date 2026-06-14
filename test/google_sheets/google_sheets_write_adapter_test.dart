import 'package:flutter_test/flutter_test.dart';
import 'package:workout_tracker/google_sheets.dart';
import 'package:workout_tracker/sheet_contract.dart';

void main() {
  test(
    'applies planned active-sheet insertions and updates without touching Exercises',
    () async {
      final client = _FakeGoogleSheetsWriteClient(
        GoogleSheetsActiveSheetTarget(sheetId: 42, title: 'Active Workout'),
      );
      final adapter = GoogleSheetsWriteAdapter(client: client);

      await adapter.applyActiveSheetWritePlan(
        spreadsheetId: 'spreadsheet-id',
        plan: ActiveSheetWritePlan(
          columnInsertions: [
            HistoryColumnInsertion(
              sheetColumnNumber: 10,
              headers: const ['Session A'],
              setLabels: const ['S1'],
            ),
          ],
          cellUpdates: const [
            CellUpdate(
              sheetRowNumber: 3,
              sheetColumnNumber: 10,
              value: '225x5@8',
            ),
            CellUpdate(
              sheetRowNumber: 4,
              sheetColumnNumber: 1,
              value: '=Exercises!A2',
            ),
          ],
        ),
      );

      expect(client.fetchedSpreadsheetIds, ['spreadsheet-id']);
      expect(client.insertions, [
        _InsertedColumns(
          spreadsheetId: 'spreadsheet-id',
          sheetId: 42,
          sheetColumnNumber: 10,
          columnCount: 1,
        ),
      ]);
      expect(client.writes, [
        _CellWrite(
          spreadsheetId: 'spreadsheet-id',
          sheetTitle: 'Active Workout',
          sheetRowNumber: 1,
          sheetColumnNumber: 10,
          value: 'Session A',
        ),
        _CellWrite(
          spreadsheetId: 'spreadsheet-id',
          sheetTitle: 'Active Workout',
          sheetRowNumber: 2,
          sheetColumnNumber: 10,
          value: 'S1',
        ),
        _CellWrite(
          spreadsheetId: 'spreadsheet-id',
          sheetTitle: 'Active Workout',
          sheetRowNumber: 3,
          sheetColumnNumber: 10,
          value: '225x5@8',
        ),
        _CellWrite(
          spreadsheetId: 'spreadsheet-id',
          sheetTitle: 'Active Workout',
          sheetRowNumber: 4,
          sheetColumnNumber: 1,
          value: '=Exercises!A2',
        ),
      ]);
    },
  );
}

class _FakeGoogleSheetsWriteClient implements GoogleSheetsWriteClient {
  _FakeGoogleSheetsWriteClient(this.target);

  final GoogleSheetsActiveSheetTarget target;
  final List<String> fetchedSpreadsheetIds = [];
  final List<_InsertedColumns> insertions = [];
  final List<_CellWrite> writes = [];

  @override
  Future<GoogleSheetsActiveSheetTarget> fetchActiveSheetTarget(
    String spreadsheetId,
  ) async {
    fetchedSpreadsheetIds.add(spreadsheetId);
    return target;
  }

  @override
  Future<void> insertColumns({
    required String spreadsheetId,
    required int sheetId,
    required int sheetColumnNumber,
    required int columnCount,
  }) async {
    insertions.add(
      _InsertedColumns(
        spreadsheetId: spreadsheetId,
        sheetId: sheetId,
        sheetColumnNumber: sheetColumnNumber,
        columnCount: columnCount,
      ),
    );
  }

  @override
  Future<void> writeCells({
    required String spreadsheetId,
    required String sheetTitle,
    required Iterable<GoogleSheetsCellWrite> cells,
  }) async {
    writes.addAll(
      cells.map(
        (cell) => _CellWrite(
          spreadsheetId: spreadsheetId,
          sheetTitle: sheetTitle,
          sheetRowNumber: cell.sheetRowNumber,
          sheetColumnNumber: cell.sheetColumnNumber,
          value: cell.value,
        ),
      ),
    );
  }
}

class _InsertedColumns {
  const _InsertedColumns({
    required this.spreadsheetId,
    required this.sheetId,
    required this.sheetColumnNumber,
    required this.columnCount,
  });

  final String spreadsheetId;
  final int sheetId;
  final int sheetColumnNumber;
  final int columnCount;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is _InsertedColumns &&
            spreadsheetId == other.spreadsheetId &&
            sheetId == other.sheetId &&
            sheetColumnNumber == other.sheetColumnNumber &&
            columnCount == other.columnCount;
  }

  @override
  int get hashCode {
    return Object.hash(spreadsheetId, sheetId, sheetColumnNumber, columnCount);
  }

  @override
  String toString() {
    return '_InsertedColumns('
        'spreadsheetId: $spreadsheetId, '
        'sheetId: $sheetId, '
        'sheetColumnNumber: $sheetColumnNumber, '
        'columnCount: $columnCount'
        ')';
  }
}

class _CellWrite {
  const _CellWrite({
    required this.spreadsheetId,
    required this.sheetTitle,
    required this.sheetRowNumber,
    required this.sheetColumnNumber,
    required this.value,
  });

  final String spreadsheetId;
  final String sheetTitle;
  final int sheetRowNumber;
  final int sheetColumnNumber;
  final String value;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is _CellWrite &&
            spreadsheetId == other.spreadsheetId &&
            sheetTitle == other.sheetTitle &&
            sheetRowNumber == other.sheetRowNumber &&
            sheetColumnNumber == other.sheetColumnNumber &&
            value == other.value;
  }

  @override
  int get hashCode {
    return Object.hash(
      spreadsheetId,
      sheetTitle,
      sheetRowNumber,
      sheetColumnNumber,
      value,
    );
  }

  @override
  String toString() {
    return '_CellWrite('
        'spreadsheetId: $spreadsheetId, '
        'sheetTitle: $sheetTitle, '
        'sheetRowNumber: $sheetRowNumber, '
        'sheetColumnNumber: $sheetColumnNumber, '
        'value: $value'
        ')';
  }
}
