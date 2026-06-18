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

  test(
    'routes user text as literals, formula repairs as formulas, and clears separately',
    () async {
      final client = _FakeGoogleSheetsWriteClient(
        GoogleSheetsActiveSheetTarget(sheetId: 42, title: 'Active Workout'),
      );
      final adapter = GoogleSheetsWriteAdapter(client: client);
      final activeSheet = parseActiveSheet(
        ActiveSheetInput(
          rows: const [
            [
              'Exercise',
              'Sets',
              'Reps',
              'RPE',
              'Rest',
              'Tempo',
              'Notes',
              'Log Format',
              'Workout',
              'is_backup',
              'Week 1',
              '',
            ],
            ['', '', '', '', '', '', '', '', '', '', 'S1', 'S2'],
            [
              'Squat',
              '3',
              '5',
              '8',
              '3 min',
              '',
              '',
              '{Formula}',
              'Legs',
              '',
              '',
              '=manual note',
            ],
          ],
          cellFormulas: const [
            CellFormula(
              sheetRowNumber: 3,
              sheetColumnNumber: 2,
              formula: '=Exercises!C2',
            ),
            CellFormula(
              sheetRowNumber: 3,
              sheetColumnNumber: 3,
              formula: '=Exercises!D2',
            ),
            CellFormula(
              sheetRowNumber: 3,
              sheetColumnNumber: 4,
              formula: '=Exercises!E2',
            ),
            CellFormula(
              sheetRowNumber: 3,
              sheetColumnNumber: 5,
              formula: '=Exercises!F2',
            ),
            CellFormula(
              sheetRowNumber: 3,
              sheetColumnNumber: 6,
              formula: '=Exercises!G2',
            ),
            CellFormula(
              sheetRowNumber: 3,
              sheetColumnNumber: 7,
              formula: '=Exercises!H2',
            ),
            CellFormula(
              sheetRowNumber: 3,
              sheetColumnNumber: 8,
              formula: '=Exercises!I2',
            ),
          ],
          exercisesRows: const [
            [
              'Exercise',
              'Description',
              'Default Sets',
              'Default Reps',
              'Default RPE',
              'Default Rest',
              'Default Tempo',
              'Notes',
              'Log Format',
            ],
            [
              'Squat',
              'Back squat',
              '3',
              '5',
              '8',
              '3 min',
              '',
              '',
              '{Formula}',
            ],
          ],
        ),
      );

      final structuredSetPlan = activeSheet.planSetLoggingWrite(
        historyBlockLabel: 'Week 1',
        sheetRowNumber: 3,
        fieldValues: const {'Formula': '=1+1'},
      );
      final rawSetPlan = activeSheet.planRawSetEdit(
        historyBlockLabel: 'Week 1',
        sheetRowNumber: 3,
        setNumber: 2,
        rawText: '=manual note',
      );
      final newHistoryBlockPlan = activeSheet.planNewHistoryBlock(
        label: '=Training Week',
      );
      final formulaRepairPlan = activeSheet.planFormulaHealing(
        activeSheetRowNumber: 3,
      );
      final clearPlan = activeSheet.planSetClear(
        historyBlockLabel: 'Week 1',
        sheetRowNumber: 3,
        setNumber: 2,
      );

      await adapter.applyActiveSheetWritePlan(
        spreadsheetId: 'spreadsheet-id',
        plan: ActiveSheetWritePlan(
          columnInsertions: newHistoryBlockPlan.columnInsertions,
          cellUpdates: [
            ...structuredSetPlan.cellUpdates,
            ...rawSetPlan.cellUpdates,
            ...formulaRepairPlan.cellUpdates,
            ...clearPlan.cellUpdates,
          ],
        ),
      );

      expect(client.insertions, [
        _InsertedColumns(
          spreadsheetId: 'spreadsheet-id',
          sheetId: 42,
          sheetColumnNumber: 11,
          columnCount: 1,
        ),
      ]);
      expect(client.writeBatches, [
        _WriteBatch(
          mode: GoogleSheetsValueInputMode.literalText,
          writes: const [
            _CellWrite(
              spreadsheetId: 'spreadsheet-id',
              sheetTitle: 'Active Workout',
              sheetRowNumber: 1,
              sheetColumnNumber: 11,
              value: '=Training Week',
            ),
            _CellWrite(
              spreadsheetId: 'spreadsheet-id',
              sheetTitle: 'Active Workout',
              sheetRowNumber: 2,
              sheetColumnNumber: 11,
              value: 'S1',
            ),
            _CellWrite(
              spreadsheetId: 'spreadsheet-id',
              sheetTitle: 'Active Workout',
              sheetRowNumber: 3,
              sheetColumnNumber: 11,
              value: '=1+1',
            ),
            _CellWrite(
              spreadsheetId: 'spreadsheet-id',
              sheetTitle: 'Active Workout',
              sheetRowNumber: 3,
              sheetColumnNumber: 12,
              value: '=manual note',
            ),
          ],
        ),
        _WriteBatch(
          mode: GoogleSheetsValueInputMode.userEntered,
          writes: const [
            _CellWrite(
              spreadsheetId: 'spreadsheet-id',
              sheetTitle: 'Active Workout',
              sheetRowNumber: 3,
              sheetColumnNumber: 1,
              value: '=Exercises!A2',
            ),
          ],
        ),
      ]);
      expect(client.clears, const [
        _CellClear(
          spreadsheetId: 'spreadsheet-id',
          sheetTitle: 'Active Workout',
          sheetRowNumber: 3,
          sheetColumnNumber: 12,
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
  final List<_WriteBatch> writeBatches = [];
  final List<_CellClear> clears = [];

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
    required GoogleSheetsValueInputMode mode,
  }) async {
    final cellWrites = cells
        .map(
          (cell) => _CellWrite(
            spreadsheetId: spreadsheetId,
            sheetTitle: sheetTitle,
            sheetRowNumber: cell.sheetRowNumber,
            sheetColumnNumber: cell.sheetColumnNumber,
            value: cell.value,
          ),
        )
        .toList();
    writes.addAll(cellWrites);
    writeBatches.add(_WriteBatch(mode: mode, writes: cellWrites));
  }

  @override
  Future<void> clearCells({
    required String spreadsheetId,
    required String sheetTitle,
    required Iterable<GoogleSheetsCellClear> cells,
  }) async {
    clears.addAll(
      cells.map(
        (cell) => _CellClear(
          spreadsheetId: spreadsheetId,
          sheetTitle: sheetTitle,
          sheetRowNumber: cell.sheetRowNumber,
          sheetColumnNumber: cell.sheetColumnNumber,
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

class _WriteBatch {
  const _WriteBatch({required this.mode, required this.writes});

  final GoogleSheetsValueInputMode mode;
  final List<_CellWrite> writes;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is _WriteBatch &&
            mode == other.mode &&
            _listEquals(writes, other.writes);
  }

  @override
  int get hashCode => Object.hash(mode, Object.hashAll(writes));

  @override
  String toString() {
    return '_WriteBatch(mode: $mode, writes: $writes)';
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

class _CellClear {
  const _CellClear({
    required this.spreadsheetId,
    required this.sheetTitle,
    required this.sheetRowNumber,
    required this.sheetColumnNumber,
  });

  final String spreadsheetId;
  final String sheetTitle;
  final int sheetRowNumber;
  final int sheetColumnNumber;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is _CellClear &&
            spreadsheetId == other.spreadsheetId &&
            sheetTitle == other.sheetTitle &&
            sheetRowNumber == other.sheetRowNumber &&
            sheetColumnNumber == other.sheetColumnNumber;
  }

  @override
  int get hashCode {
    return Object.hash(
      spreadsheetId,
      sheetTitle,
      sheetRowNumber,
      sheetColumnNumber,
    );
  }

  @override
  String toString() {
    return '_CellClear('
        'spreadsheetId: $spreadsheetId, '
        'sheetTitle: $sheetTitle, '
        'sheetRowNumber: $sheetRowNumber, '
        'sheetColumnNumber: $sheetColumnNumber'
        ')';
  }
}

bool _listEquals<T>(List<T> left, List<T> right) {
  if (left.length != right.length) {
    return false;
  }
  for (var index = 0; index < left.length; index += 1) {
    if (left[index] != right[index]) {
      return false;
    }
  }
  return true;
}
