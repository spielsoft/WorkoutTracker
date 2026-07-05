import 'package:flutter_test/flutter_test.dart';
import 'package:workout_tracker/google_sheets.dart';
import 'package:workout_tracker/sheet_contract.dart';

void main() {
  test(
    'applies planned active-sheet insertions and updates without touching Exercises',
    () async {
      final client = _FakeSheetsWorkbookClient(
        const SheetsSheetIdentity(sheetId: 42, title: 'Active Workout'),
      );
      final adapter = SheetsWriteAdapter(client: client);

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
      expect(client.writes, isEmpty);
      expect(client.structuralBatches, [
        _StructuralBatch(
          spreadsheetId: 'spreadsheet-id',
          sheetId: 42,
          sheetTitle: 'Active Workout',
          rowInsertions: const [],
          columnInsertions: const [
            _InsertedColumns(
              spreadsheetId: 'spreadsheet-id',
              sheetId: 42,
              sheetColumnNumber: 10,
              columnCount: 1,
            ),
          ],
          writes: const [
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
          ],
          clears: const [],
        ),
      ]);
    },
  );

  test(
    'routes user text as literals, formula repairs as formulas, and clears separately',
    () async {
      final client = _FakeSheetsWorkbookClient(
        const SheetsSheetIdentity(sheetId: 42, title: 'Active Workout'),
      );
      final adapter = SheetsWriteAdapter(client: client);
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

      expect(client.writeBatches, isEmpty);
      expect(client.structuralBatches, [
        _StructuralBatch(
          spreadsheetId: 'spreadsheet-id',
          sheetId: 42,
          sheetTitle: 'Active Workout',
          rowInsertions: const [],
          columnInsertions: const [
            _InsertedColumns(
              spreadsheetId: 'spreadsheet-id',
              sheetId: 42,
              sheetColumnNumber: 11,
              columnCount: 1,
            ),
          ],
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
            _CellWrite(
              spreadsheetId: 'spreadsheet-id',
              sheetTitle: 'Active Workout',
              sheetRowNumber: 3,
              sheetColumnNumber: 1,
              value: '=Exercises!A2',
              mode: SheetsValueInputMode.userEntered,
            ),
          ],
          clears: const [
            _CellClear(
              spreadsheetId: 'spreadsheet-id',
              sheetTitle: 'Active Workout',
              sheetRowNumber: 3,
              sheetColumnNumber: 12,
            ),
          ],
        ),
      ]);
      expect(client.clears, isEmpty);
    },
  );

  test(
    'applies structural active-sheet writes as one batch so failures do not continue with partial calls',
    () async {
      final client = _FakeSheetsWorkbookClient(
        const SheetsSheetIdentity(sheetId: 42, title: 'Active Workout'),
      )..failStructuralBatch = true;
      final adapter = SheetsWriteAdapter(client: client);

      await expectLater(
        adapter.applyActiveSheetWritePlan(
          spreadsheetId: 'spreadsheet-id',
          plan: ActiveSheetWritePlan(
            columnInsertions: [
              HistoryColumnInsertion(
                sheetColumnNumber: 11,
                headers: const ['Week 2'],
                setLabels: const ['S1'],
              ),
            ],
            cellUpdates: const [
              CellUpdate(
                sheetRowNumber: 3,
                sheetColumnNumber: 11,
                value: '225x5@8',
              ),
            ],
          ),
        ),
        throwsA(isA<StateError>()),
      );

      expect(client.structuralBatches, [
        _StructuralBatch(
          spreadsheetId: 'spreadsheet-id',
          sheetId: 42,
          sheetTitle: 'Active Workout',
          columnInsertions: const [
            _InsertedColumns(
              spreadsheetId: 'spreadsheet-id',
              sheetId: 42,
              sheetColumnNumber: 11,
              columnCount: 1,
            ),
          ],
          rowInsertions: const [],
          writes: const [
            _CellWrite(
              spreadsheetId: 'spreadsheet-id',
              sheetTitle: 'Active Workout',
              sheetRowNumber: 1,
              sheetColumnNumber: 11,
              value: 'Week 2',
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
              value: '225x5@8',
            ),
          ],
          clears: const [],
        ),
      ]);
      expect(client.writeBatches, isEmpty);
      expect(client.clears, isEmpty);
    },
  );

  test(
    'applies planned active-sheet row deletions to the active sheet',
    () async {
      final client = _FakeSheetsWorkbookClient(
        const SheetsSheetIdentity(sheetId: 42, title: 'Active Workout'),
      );
      final adapter = SheetsWriteAdapter(client: client);

      await adapter.applyActiveSheetWritePlan(
        spreadsheetId: 'spreadsheet-id',
        plan: ActiveSheetWritePlan(
          rowDeletions: const [
            ActiveSheetRowDeletion(sheetRowNumber: 3, rowCount: 2),
          ],
        ),
      );

      expect(client.fetchedSpreadsheetIds, ['spreadsheet-id']);
      expect(client.structuralBatches, [
        _StructuralBatch(
          spreadsheetId: 'spreadsheet-id',
          sheetId: 42,
          sheetTitle: 'Active Workout',
          rowInsertions: const [],
          rowDeletions: const [
            _DeletedRows(
              spreadsheetId: 'spreadsheet-id',
              sheetId: 42,
              sheetRowNumber: 3,
              rowCount: 2,
            ),
          ],
          columnInsertions: const [],
          writes: const [],
          clears: const [],
        ),
      ]);
    },
  );

  test(
    'applies planned Exercises row updates without inserting rows',
    () async {
      final client = _FakeSheetsWorkbookClient(
        const SheetsSheetIdentity(sheetId: 42, title: 'Active Workout'),
      );
      final adapter = SheetsWriteAdapter(client: client);

      await adapter.applyExercisesPlan(
        spreadsheetId: 'spreadsheet-id',
        plan: ExercisesWritePlan(
          rowUpdates: [
            ExercisesRowUpdate(
              sheetRowNumber: 2,
              values: const [
                'High Bar Squat',
                'High bar back squat',
                '3',
                '5',
                '8',
                '3 min',
                '',
                '',
                '{Weight}[x]{Reps}[@]{RPE}',
              ],
            ),
          ],
        ),
      );

      expect(client.writeBatches, [
        _WriteBatch(
          mode: SheetsValueInputMode.literalText,
          writes: const [
            _CellWrite(
              spreadsheetId: 'spreadsheet-id',
              sheetTitle: 'Exercises',
              sheetRowNumber: 2,
              sheetColumnNumber: 1,
              value: 'High Bar Squat',
            ),
            _CellWrite(
              spreadsheetId: 'spreadsheet-id',
              sheetTitle: 'Exercises',
              sheetRowNumber: 2,
              sheetColumnNumber: 2,
              value: 'High bar back squat',
            ),
            _CellWrite(
              spreadsheetId: 'spreadsheet-id',
              sheetTitle: 'Exercises',
              sheetRowNumber: 2,
              sheetColumnNumber: 3,
              value: '3',
            ),
            _CellWrite(
              spreadsheetId: 'spreadsheet-id',
              sheetTitle: 'Exercises',
              sheetRowNumber: 2,
              sheetColumnNumber: 4,
              value: '5',
            ),
            _CellWrite(
              spreadsheetId: 'spreadsheet-id',
              sheetTitle: 'Exercises',
              sheetRowNumber: 2,
              sheetColumnNumber: 5,
              value: '8',
            ),
            _CellWrite(
              spreadsheetId: 'spreadsheet-id',
              sheetTitle: 'Exercises',
              sheetRowNumber: 2,
              sheetColumnNumber: 6,
              value: '3 min',
            ),
            _CellWrite(
              spreadsheetId: 'spreadsheet-id',
              sheetTitle: 'Exercises',
              sheetRowNumber: 2,
              sheetColumnNumber: 7,
              value: '',
            ),
            _CellWrite(
              spreadsheetId: 'spreadsheet-id',
              sheetTitle: 'Exercises',
              sheetRowNumber: 2,
              sheetColumnNumber: 8,
              value: '',
            ),
            _CellWrite(
              spreadsheetId: 'spreadsheet-id',
              sheetTitle: 'Exercises',
              sheetRowNumber: 2,
              sheetColumnNumber: 9,
              value: '{Weight}[x]{Reps}[@]{RPE}',
            ),
          ],
        ),
      ]);
    },
  );

  test(
    'applies planned Exercises row appends to the Exercises sheet',
    () async {
      final client = _FakeSheetsWorkbookClient(
        const SheetsSheetIdentity(sheetId: 42, title: 'Active Workout'),
        sheetTargets: const {
          'Exercises': SheetsSheetIdentity(sheetId: 84, title: 'Exercises'),
        },
      );
      final adapter = SheetsWriteAdapter(client: client);

      await adapter.applyExercisesPlan(
        spreadsheetId: 'spreadsheet-id',
        plan: ExercisesWritePlan(
          rowAppends: [
            ExercisesRowAppend(
              sheetRowNumber: 2,
              values: const [
                'A New Movement',
                'Freshly added exercise',
                '3',
                '10',
                '8',
                '2 min',
                '',
                '',
                '{Weight}[x]{Reps}[@]{RPE}',
              ],
            ),
          ],
        ),
      );

      expect(client.writeBatches, isEmpty);
      expect(client.structuralBatches, [
        _StructuralBatch(
          spreadsheetId: 'spreadsheet-id',
          sheetId: 84,
          sheetTitle: 'Exercises',
          rowInsertions: const [
            _InsertedRows(
              spreadsheetId: 'spreadsheet-id',
              sheetId: 84,
              sheetRowNumber: 2,
              rowCount: 1,
            ),
          ],
          columnInsertions: const [],
          writes: const [
            _CellWrite(
              spreadsheetId: 'spreadsheet-id',
              sheetTitle: 'Exercises',
              sheetRowNumber: 2,
              sheetColumnNumber: 1,
              value: 'A New Movement',
            ),
            _CellWrite(
              spreadsheetId: 'spreadsheet-id',
              sheetTitle: 'Exercises',
              sheetRowNumber: 2,
              sheetColumnNumber: 2,
              value: 'Freshly added exercise',
            ),
            _CellWrite(
              spreadsheetId: 'spreadsheet-id',
              sheetTitle: 'Exercises',
              sheetRowNumber: 2,
              sheetColumnNumber: 3,
              value: '3',
            ),
            _CellWrite(
              spreadsheetId: 'spreadsheet-id',
              sheetTitle: 'Exercises',
              sheetRowNumber: 2,
              sheetColumnNumber: 4,
              value: '10',
            ),
            _CellWrite(
              spreadsheetId: 'spreadsheet-id',
              sheetTitle: 'Exercises',
              sheetRowNumber: 2,
              sheetColumnNumber: 5,
              value: '8',
            ),
            _CellWrite(
              spreadsheetId: 'spreadsheet-id',
              sheetTitle: 'Exercises',
              sheetRowNumber: 2,
              sheetColumnNumber: 6,
              value: '2 min',
            ),
            _CellWrite(
              spreadsheetId: 'spreadsheet-id',
              sheetTitle: 'Exercises',
              sheetRowNumber: 2,
              sheetColumnNumber: 7,
              value: '',
            ),
            _CellWrite(
              spreadsheetId: 'spreadsheet-id',
              sheetTitle: 'Exercises',
              sheetRowNumber: 2,
              sheetColumnNumber: 8,
              value: '',
            ),
            _CellWrite(
              spreadsheetId: 'spreadsheet-id',
              sheetTitle: 'Exercises',
              sheetRowNumber: 2,
              sheetColumnNumber: 9,
              value: '{Weight}[x]{Reps}[@]{RPE}',
            ),
          ],
          clears: const [],
        ),
      ]);
    },
  );

  test(
    'applies planned active formula repairs after Exercises row updates',
    () async {
      final client = _FakeSheetsWorkbookClient(
        const SheetsSheetIdentity(sheetId: 42, title: 'Active Workout'),
      );
      final adapter = SheetsWriteAdapter(client: client);

      await adapter.applyExercisesPlan(
        spreadsheetId: 'spreadsheet-id',
        plan: ExercisesWritePlan(
          rowUpdates: [
            ExercisesRowUpdate(
              sheetRowNumber: 2,
              values: const [
                'Bench Press',
                'Competition bench',
                '4',
                '6',
                '8',
                '3 min',
                '',
                '',
                '{Weight}[x]{Reps}[@]{RPE}',
              ],
            ),
          ],
          activeSheetFormulaUpdates: const [
            CellUpdate.formula(
              sheetRowNumber: 3,
              sheetColumnNumber: 1,
              value: '=Exercises!A4',
            ),
          ],
        ),
      );

      expect(
        client.writeBatches.last,
        const _WriteBatch(
          mode: SheetsValueInputMode.userEntered,
          writes: [
            _CellWrite(
              spreadsheetId: 'spreadsheet-id',
              sheetTitle: 'Active Workout',
              sheetRowNumber: 3,
              sheetColumnNumber: 1,
              value: '=Exercises!A4',
              mode: SheetsValueInputMode.userEntered,
            ),
          ],
        ),
      );
    },
  );
}

class _FakeSheetsWorkbookClient implements SheetsWorkbookClient {
  _FakeSheetsWorkbookClient(this.target, {this.sheetTargets = const {}});

  final SheetsSheetIdentity target;
  final Map<String, SheetsSheetIdentity> sheetTargets;
  final List<String> fetchedSpreadsheetIds = [];
  final List<_CellWrite> writes = [];
  final List<_WriteBatch> writeBatches = [];
  final List<_CellClear> clears = [];
  final List<_StructuralBatch> structuralBatches = [];
  var failStructuralBatch = false;

  @override
  Future<SheetsWorkbookMetadata> fetchMetadata(String spreadsheetId) async {
    fetchedSpreadsheetIds.add(spreadsheetId);
    return SheetsWorkbookMetadata(
      sheets: [
        target,
        sheetTargets['Exercises'] ??
            const SheetsSheetIdentity(sheetId: 84, title: 'Exercises'),
        for (final entry in sheetTargets.entries)
          if (entry.key != 'Exercises') entry.value,
      ],
    );
  }

  @override
  Future<SheetsWorkbookSnapshot> readGrids({
    required String spreadsheetId,
    required Iterable<SheetsGridRead> reads,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> applyOperations({
    required String spreadsheetId,
    required Iterable<SheetsWorkbookOperation> operations,
  }) async {
    final operationList = operations.toList();
    final hasStructuralOperations = operationList.any(
      (operation) =>
          operation is SheetsRowInsertion ||
          operation is SheetsColumnInsertion ||
          operation is SheetsRowDeletion ||
          operation is SheetsColumnDeletion ||
          operation is SheetsRowMove ||
          operation is SheetsColumnMove,
    );
    if (hasStructuralOperations) {
      final batchSheet = operationList.first.sheet;
      structuralBatches.add(
        _StructuralBatch(
          spreadsheetId: spreadsheetId,
          sheetId: batchSheet.sheetId,
          sheetTitle: batchSheet.title,
          rowInsertions: [
            for (final operation in operationList)
              if (operation is SheetsRowInsertion)
                _InsertedRows(
                  spreadsheetId: spreadsheetId,
                  sheetId: operation.sheet.sheetId,
                  sheetRowNumber: operation.sheetRowNumber,
                  rowCount: operation.rowCount,
                ),
          ],
          rowDeletions: [
            for (final operation in operationList)
              if (operation is SheetsRowDeletion)
                _DeletedRows(
                  spreadsheetId: spreadsheetId,
                  sheetId: operation.sheet.sheetId,
                  sheetRowNumber: operation.sheetRowNumber,
                  rowCount: operation.rowCount,
                ),
          ],
          columnInsertions: [
            for (final operation in operationList)
              if (operation is SheetsColumnInsertion)
                _InsertedColumns(
                  spreadsheetId: spreadsheetId,
                  sheetId: operation.sheet.sheetId,
                  sheetColumnNumber: operation.sheetColumnNumber,
                  columnCount: operation.columnCount,
                ),
          ],
          writes: [
            for (final operation in operationList)
              if (operation is SheetsCellWrite)
                _CellWrite(
                  spreadsheetId: spreadsheetId,
                  sheetTitle: operation.sheet.title,
                  sheetRowNumber: operation.sheetRowNumber,
                  sheetColumnNumber: operation.sheetColumnNumber,
                  value: operation.value,
                  mode: operation.mode,
                ),
          ],
          clears: [
            for (final operation in operationList)
              if (operation is SheetsCellClear)
                _CellClear(
                  spreadsheetId: spreadsheetId,
                  sheetTitle: operation.sheet.title,
                  sheetRowNumber: operation.sheetRowNumber,
                  sheetColumnNumber: operation.sheetColumnNumber,
                ),
          ],
        ),
      );
      if (failStructuralBatch) {
        throw StateError('structural batch failed');
      }
      return;
    }

    final writesByMode = <SheetsValueInputMode, List<_CellWrite>>{};
    for (final operation in operationList) {
      if (operation is SheetsCellWrite) {
        final cell = _CellWrite(
          spreadsheetId: spreadsheetId,
          sheetTitle: operation.sheet.title,
          sheetRowNumber: operation.sheetRowNumber,
          sheetColumnNumber: operation.sheetColumnNumber,
          value: operation.value,
          mode: operation.mode,
        );
        writes.add(cell);
        writesByMode.putIfAbsent(operation.mode, () => []).add(cell);
      } else if (operation is SheetsCellClear) {
        clears.add(
          _CellClear(
            spreadsheetId: spreadsheetId,
            sheetTitle: operation.sheet.title,
            sheetRowNumber: operation.sheetRowNumber,
            sheetColumnNumber: operation.sheetColumnNumber,
          ),
        );
      }
    }
    for (final entry in writesByMode.entries) {
      writeBatches.add(_WriteBatch(mode: entry.key, writes: entry.value));
    }
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

class _InsertedRows {
  const _InsertedRows({
    required this.spreadsheetId,
    required this.sheetId,
    required this.sheetRowNumber,
    required this.rowCount,
  });

  final String spreadsheetId;
  final int sheetId;
  final int sheetRowNumber;
  final int rowCount;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is _InsertedRows &&
            spreadsheetId == other.spreadsheetId &&
            sheetId == other.sheetId &&
            sheetRowNumber == other.sheetRowNumber &&
            rowCount == other.rowCount;
  }

  @override
  int get hashCode {
    return Object.hash(spreadsheetId, sheetId, sheetRowNumber, rowCount);
  }

  @override
  String toString() {
    return '_InsertedRows('
        'spreadsheetId: $spreadsheetId, '
        'sheetId: $sheetId, '
        'sheetRowNumber: $sheetRowNumber, '
        'rowCount: $rowCount'
        ')';
  }
}

class _DeletedRows {
  const _DeletedRows({
    required this.spreadsheetId,
    required this.sheetId,
    required this.sheetRowNumber,
    required this.rowCount,
  });

  final String spreadsheetId;
  final int sheetId;
  final int sheetRowNumber;
  final int rowCount;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is _DeletedRows &&
            spreadsheetId == other.spreadsheetId &&
            sheetId == other.sheetId &&
            sheetRowNumber == other.sheetRowNumber &&
            rowCount == other.rowCount;
  }

  @override
  int get hashCode {
    return Object.hash(spreadsheetId, sheetId, sheetRowNumber, rowCount);
  }

  @override
  String toString() {
    return '_DeletedRows('
        'spreadsheetId: $spreadsheetId, '
        'sheetId: $sheetId, '
        'sheetRowNumber: $sheetRowNumber, '
        'rowCount: $rowCount'
        ')';
  }
}

class _StructuralBatch {
  const _StructuralBatch({
    required this.spreadsheetId,
    required this.sheetId,
    required this.sheetTitle,
    required this.rowInsertions,
    this.rowDeletions = const [],
    required this.columnInsertions,
    required this.writes,
    required this.clears,
  });

  final String spreadsheetId;
  final int sheetId;
  final String sheetTitle;
  final List<_InsertedRows> rowInsertions;
  final List<_DeletedRows> rowDeletions;
  final List<_InsertedColumns> columnInsertions;
  final List<_CellWrite> writes;
  final List<_CellClear> clears;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is _StructuralBatch &&
            spreadsheetId == other.spreadsheetId &&
            sheetId == other.sheetId &&
            sheetTitle == other.sheetTitle &&
            _listEquals(rowInsertions, other.rowInsertions) &&
            _listEquals(rowDeletions, other.rowDeletions) &&
            _listEquals(columnInsertions, other.columnInsertions) &&
            _listEquals(writes, other.writes) &&
            _listEquals(clears, other.clears);
  }

  @override
  int get hashCode {
    return Object.hash(
      spreadsheetId,
      sheetId,
      sheetTitle,
      Object.hashAll(rowInsertions),
      Object.hashAll(rowDeletions),
      Object.hashAll(columnInsertions),
      Object.hashAll(writes),
      Object.hashAll(clears),
    );
  }

  @override
  String toString() {
    return '_StructuralBatch('
        'spreadsheetId: $spreadsheetId, '
        'sheetId: $sheetId, '
        'sheetTitle: $sheetTitle, '
        'rowInsertions: $rowInsertions, '
        'rowDeletions: $rowDeletions, '
        'columnInsertions: $columnInsertions, '
        'writes: $writes, '
        'clears: $clears'
        ')';
  }
}

class _WriteBatch {
  const _WriteBatch({required this.mode, required this.writes});

  final SheetsValueInputMode mode;
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
    this.mode = SheetsValueInputMode.literalText,
  });

  final String spreadsheetId;
  final String sheetTitle;
  final int sheetRowNumber;
  final int sheetColumnNumber;
  final String value;
  final SheetsValueInputMode mode;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is _CellWrite &&
            spreadsheetId == other.spreadsheetId &&
            sheetTitle == other.sheetTitle &&
            sheetRowNumber == other.sheetRowNumber &&
            sheetColumnNumber == other.sheetColumnNumber &&
            value == other.value &&
            mode == other.mode;
  }

  @override
  int get hashCode {
    return Object.hash(
      spreadsheetId,
      sheetTitle,
      sheetRowNumber,
      sheetColumnNumber,
      value,
      mode,
    );
  }

  @override
  String toString() {
    return '_CellWrite('
        'spreadsheetId: $spreadsheetId, '
        'sheetTitle: $sheetTitle, '
        'sheetRowNumber: $sheetRowNumber, '
        'sheetColumnNumber: $sheetColumnNumber, '
        'value: $value, '
        'mode: $mode'
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
