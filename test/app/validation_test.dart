import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:googleapis/sheets/v4.dart' as sheets;
import 'package:http/http.dart' as http;
import 'package:workout_tracker/sheets.dart';
import 'package:workout_tracker/contract.dart';
import 'package:workout_tracker/app.dart';

void main() {
  test(
    'Google-backed validation requests writable Sheets scope and keeps the client open while reading',
    () async {
      final gateway = _RecordingSignInAuthGateway();
      final rows = [
        [...activeSheetFixedColumns, 'Week 1'],
        [...List.filled(activeSheetFixedColumns.length, ''), 'S1'],
        ['Squat', '3', '3 min', '', 'x5@8', '', '', 'Legs', '', 'x', ''],
      ];
      final authClients = <_CloseTrackingAuthClient>[];
      final workbookClient = _CloseTrackingWorkbookClient(
        () => authClients.last,
        [_snapshot(rows)],
      );
      final service = SheetAccess(
        ScopedApiAccess(
          auth: gateway,
          authClientFactory: (_) {
            final client = _CloseTrackingAuthClient();
            authClients.add(client);
            return client;
          },
        ),
        clientFactory: (_) => workbookClient,
      );

      final report = await service.open('spreadsheet-id').read();

      expect(authClients, everyElement(hasClosedCleanly));
      expect(gateway.requestedScopes.single, [
        sheets.SheetsApi.spreadsheetsScope,
      ]);
      expect(report.activeSheet.primarySlots.single.exercise, 'Squat');
    },
  );

  test(
    'Google-backed writes refresh validation before closing the authorized client',
    () async {
      final gateway = _RecordingSignInAuthGateway();
      final activeRows = [
        [...activeSheetFixedColumns, 'Week 1'],
        [...List.filled(activeSheetFixedColumns.length, ''), 'S1'],
        ['Squat', '3', '3 min', '', 'x5@8', '', '', 'Legs', '', 'x', ''],
      ];
      final refreshedRows = [
        [...activeSheetFixedColumns, 'Week 1', 'Week 2'],
        [...List.filled(activeSheetFixedColumns.length, ''), 'S1', 'S1'],
        ['Squat', '3', '3 min', '', 'x5@8', '', '', 'Legs', '', 'x', '', ''],
      ];
      final authClients = <_CloseTrackingAuthClient>[];
      final workbookClient = _CloseTrackingWorkbookClient(
        () => authClients.last,
        [
          _snapshot(activeRows),
          _snapshot(activeRows),
          _snapshot(refreshedRows),
        ],
      );
      final service = SheetAccess(
        ScopedApiAccess(
          auth: gateway,
          authClientFactory: (_) {
            final client = _CloseTrackingAuthClient();
            authClients.add(client);
            return client;
          },
        ),
        clientFactory: (_) => workbookClient,
      );

      final sess = service.open('spreadsheet-id');
      await sess.read();
      final report = await sess.execute(const NewHistoryCmd('Week 2'));

      expect(authClients, everyElement(hasClosedCleanly));
      expect(
        gateway.requestedScopes,
        everyElement([sheets.SheetsApi.spreadsheetsScope]),
      );
      expect(workbookClient.operations, isNotEmpty);
      expect(report.activeSheet.historyBlocks.map((block) => block.label), [
        'Week 1',
        'Week 2',
      ]);
    },
  );

  test('rejects writes when workbook schema is invalid', () async {
    final readClient = _SequencedSpreadsheetClient([
      _workbookSnapshot(const [], const [exercisesSheetColumns]),
    ]);
    final writeClient = _RecordingWriteClient();
    final sess = _session(readClient, writeClient);

    final initial = await sess.read();
    final rejected = await sess.execute(const NewHistoryCmd('Week 1'));

    expect(initial.schemaViolations, isNotEmpty);
    expect(
      rejected.manualRepairItems.map((item) => item.problem),
      contains(
        'Workbook schema is invalid. No spreadsheet changes were applied.',
      ),
    );
    expect(writeClient.operations, isEmpty);
  });

  test(
    'logs five structured fields through the version 1.0 command flow',
    () async {
      const format = '({Height (in)}, {Weight (lbs)})x{Reps}@{RPE},{Pain}';
      final rows = [
        [...activeSheetFixedColumns, 'Week 1'],
        [...List.filled(activeSheetFixedColumns.length, ''), 'S1'],
        ['Step Up', '1', '', '', '(12, 15)x8@8,0', '', format, '', '', 'x', ''],
      ];
      final savedRows = [
        rows[0],
        rows[1],
        [...rows[2].take(10), '(14, 20)x9@7.5,1'],
      ];
      final exercises = [
        exercisesSheetColumns,
        ['Step Up', '', '1', '', '', '', format, '(12, 15)x8@8,0'],
      ];
      final reads = _SequencedSpreadsheetClient([
        _workbookSnapshot(rows, exercises),
        _workbookSnapshot(rows, exercises),
        _workbookSnapshot(savedRows, exercises),
      ]);
      final writes = _RecordingWriteClient();
      final sess = _session(reads, writes);

      await sess.read();
      final report = await sess.execute(
        SaveSetCmd(
          blockLabel: 'Week 1',
          sheetRow: 3,
          fields: const {
            'Height (in)': '14',
            'Weight (lbs)': '20',
            'Reps': '9',
            'RPE': '7.5',
            'Pain': '1',
          },
        ),
      );

      expect(report.schemaViolations, isEmpty);
      expect(
        writes.operations.whereType<SheetsCellWrite>().single.value,
        '(14, 20)x9@7.5,1',
      );
    },
  );

  test('malformed headers cannot apply active or Exercises writes', () async {
    final malformedWorkbooks = [
      _workbookSnapshot(
        const [
          ['Exercise', 'Reps', 'Sets'],
        ],
        const [exercisesSheetColumns],
      ),
      _workbookSnapshot(
        const [activeSheetFixedColumns],
        const [
          ['Description', 'Exercise'],
        ],
      ),
    ];

    for (final workbook in malformedWorkbooks) {
      final readClient = _SequencedSpreadsheetClient([workbook]);
      final writeClient = _RecordingWriteClient();
      final sess = _session(readClient, writeClient);

      await sess.read();
      await sess.execute(const NewHistoryCmd('Week 1'));
      await sess.execute(CreateExeCmd(ExerciseDef(exercise: 'Squat')));

      expect(writeClient.operations, isEmpty);
    }
  });

  test('rechecks schema immediately before applying a write', () async {
    final validRows = [
      [...activeSheetFixedColumns, 'Week 1'],
      [...List.filled(activeSheetFixedColumns.length, ''), 'S1'],
      ['Squat', '3', '3 min', '', 'x5@8', '', '', 'Legs', '', 'x', ''],
    ];
    final readClient = _SequencedSpreadsheetClient([
      _workbookSnapshot(validRows, const [exercisesSheetColumns]),
      _workbookSnapshot(validRows, const []),
    ]);
    final writeClient = _RecordingWriteClient();
    final sess = _session(readClient, writeClient);

    await sess.read();
    final rejected = await sess.execute(const NewHistoryCmd('Week 2'));

    expect(rejected.schemaViolations, isNotEmpty);
    expect(writeClient.operations, isEmpty);
  });

  test(
    'rejects a set write when the current row identity no longer matches the visible target',
    () async {
      final staleRows = [
        [...activeSheetFixedColumns, 'Week 1'],
        [...List.filled(activeSheetFixedColumns.length, ''), 'S1'],
        ['Squat', '3', '3 min', '', 'x5@8', '', '', 'Legs', '', 'x', ''],
      ];
      final changedRows = [
        [...activeSheetFixedColumns, 'Week 1'],
        [...List.filled(activeSheetFixedColumns.length, ''), 'S1'],
        ['Deadlift', '3', '5', '8', '3 min', '', '', '', 'Legs', '', ''],
      ];
      final readClient = _SequencedSpreadsheetClient([
        _snapshot(staleRows),
        _snapshot(changedRows),
      ]);
      final writeClient = _RecordingWriteClient();
      final service = _session(readClient, writeClient);

      await service.read();
      final rejected = await service.execute(
        SaveSetCmd(
          blockLabel: 'Week 1',
          sheetRow: 3,
          fields: const {'Weight': '225', 'Reps': '5', 'RPE': '8'},
        ),
      );

      expect(rejected.hasBlockingIssues, isTrue);
      expect(
        rejected.manualRepairItems.single.problem,
        contains('Row 3 no longer matches Squat'),
      );
      expect(writeClient.operations, isEmpty);
    },
  );

  test(
    'rejects a new set save when the visible empty target cell changed before apply',
    () async {
      final staleRows = [
        [...activeSheetFixedColumns, 'Week 1', ''],
        [...List.filled(activeSheetFixedColumns.length, ''), 'S1', 'S2'],
        [
          'Squat',
          '3',
          '5',
          '8',
          '3 min',
          '',
          '',
          '',
          'Legs',
          '',
          '225x5@8',
          '',
        ],
      ];
      final changedRows = [
        [...activeSheetFixedColumns, 'Week 1', ''],
        [...List.filled(activeSheetFixedColumns.length, ''), 'S1', 'S2'],
        [
          'Squat',
          '3',
          '5',
          '8',
          '3 min',
          '',
          '',
          '',
          'Legs',
          '',
          '225x5@8',
          '230x5@8',
        ],
      ];
      final readClient = _SequencedSpreadsheetClient([
        _snapshot(staleRows),
        _snapshot(changedRows),
      ]);
      final writeClient = _RecordingWriteClient();
      final service = _session(readClient, writeClient);

      await service.read();
      final rejected = await service.execute(
        SaveSetCmd(
          blockLabel: 'Week 1',
          sheetRow: 3,
          fields: const {'Weight': '230', 'Reps': '5', 'RPE': '8'},
        ),
      );

      expect(rejected.hasBlockingIssues, isTrue);
      expect(
        rejected.manualRepairItems.single.problem,
        contains('Cell row 3 column 12 no longer matches'),
      );
      expect(writeClient.operations, isEmpty);
    },
  );

  test(
    'rejects a set write when workout or backup state changed before apply',
    () async {
      final staleRows = [
        [...activeSheetFixedColumns, 'Week 1'],
        [...List.filled(activeSheetFixedColumns.length, ''), 'S1'],
        ['Squat', '3', '3 min', '', 'x5@8', '', '', 'Legs', '', 'x', ''],
      ];
      final changedRows = [
        [...activeSheetFixedColumns, 'Week 1'],
        [...List.filled(activeSheetFixedColumns.length, ''), 'S1'],
        ['Squat', '3', '5', '8', '3 min', '', '', '', 'Upper', '', ''],
      ];
      final readClient = _SequencedSpreadsheetClient([
        _snapshot(staleRows),
        _snapshot(changedRows),
      ]);
      final writeClient = _RecordingWriteClient();
      final service = _session(readClient, writeClient);

      await service.read();
      final rejected = await service.execute(
        SaveSetCmd(
          blockLabel: 'Week 1',
          sheetRow: 3,
          fields: const {'Weight': '225', 'Reps': '5', 'RPE': '8'},
        ),
      );

      expect(rejected.hasBlockingIssues, isTrue);
      expect(
        rejected.manualRepairItems.map((item) => item.problem),
        contains(contains('Row 3 no longer matches Squat')),
      );
      expect(writeClient.operations, isEmpty);
    },
  );

  test(
    'rejects a set write when the row Log Format changed before apply',
    () async {
      final staleRows = [
        [...activeSheetFixedColumns, 'Week 1'],
        [...List.filled(activeSheetFixedColumns.length, ''), 'S1'],
        ['Squat', '3', '3 min', '', 'x5@8', '', '', 'Legs', '', 'x', ''],
      ];
      final changedRows = [
        [...activeSheetFixedColumns, 'Week 1'],
        [...List.filled(activeSheetFixedColumns.length, ''), 'S1'],
        [
          'Squat',
          '3',
          '5',
          '8',
          '3 min',
          '',
          '',
          '{Reps}@{RPE}',
          'Legs',
          '',
          '',
        ],
      ];
      final readClient = _SequencedSpreadsheetClient([
        _snapshot(staleRows),
        _snapshot(changedRows),
      ]);
      final writeClient = _RecordingWriteClient();
      final service = _session(readClient, writeClient);

      await service.read();
      final rejected = await service.execute(
        SaveSetCmd(
          blockLabel: 'Week 1',
          sheetRow: 3,
          fields: const {'Weight': '225', 'Reps': '5', 'RPE': '8'},
        ),
      );

      expect(rejected.hasBlockingIssues, isTrue);
      expect(
        rejected.manualRepairItems.map((item) => item.problem),
        contains(contains('Cell row 3 column 7 no longer matches')),
      );
      expect(writeClient.operations, isEmpty);
    },
  );

  test(
    'rejects an edit or clear when the visible set column no longer exists',
    () async {
      final staleRows = [
        [...activeSheetFixedColumns, 'Week 1', ''],
        [...List.filled(activeSheetFixedColumns.length, ''), 'S1', 'S2'],
        [
          'Squat',
          '3',
          '5',
          '8',
          '3 min',
          '',
          '',
          '',
          'Legs',
          '',
          '225x5@8',
          '230x5@8',
        ],
      ];
      final changedRows = [
        [...activeSheetFixedColumns, 'Week 1'],
        [...List.filled(activeSheetFixedColumns.length, ''), 'S1'],
        ['Squat', '3', '3 min', '', 'x5@8', '', '', 'Legs', '', 'x', '225x5@8'],
      ];
      final readClient = _SequencedSpreadsheetClient([
        _snapshot(staleRows),
        _snapshot(changedRows),
      ]);
      final writeClient = _RecordingWriteClient();
      final service = _session(readClient, writeClient);

      await service.read();
      final rejected = await service.execute(
        const ClearSetCmd(blockLabel: 'Week 1', sheetRow: 3, setNumber: 2),
      );

      expect(rejected.hasBlockingIssues, isTrue);
      expect(
        rejected.manualRepairItems.map((item) => item.problem),
        contains(contains('Set column Week 1 S2 no longer exists')),
      );
      expect(writeClient.operations, isEmpty);
    },
  );

  test(
    'rejects history block insertion when the header insertion point changed before apply',
    () async {
      final staleRows = [
        [...activeSheetFixedColumns, 'Week 1'],
        [...List.filled(activeSheetFixedColumns.length, ''), 'S1'],
        ['Squat', '3', '3 min', '', 'x5@8', '', '', 'Legs', '', 'x', ''],
      ];
      final changedRows = [
        [...activeSheetFixedColumns, 'Unexpected', 'Week 1'],
        [...List.filled(activeSheetFixedColumns.length, ''), 'S1', 'S1'],
        ['Squat', '3', '3 min', '', 'x5@8', '', '', 'Legs', '', 'x', '', ''],
      ];
      final readClient = _SequencedSpreadsheetClient([
        _snapshot(staleRows),
        _snapshot(changedRows),
      ]);
      final writeClient = _RecordingWriteClient();
      final service = _session(readClient, writeClient);

      await service.read();
      final rejected = await service.execute(const NewHistoryCmd('Week 2'));

      expect(rejected.hasBlockingIssues, isTrue);
      expect(
        rejected.manualRepairItems.single.problem,
        contains('History insertion point at column 11 no longer matches'),
      );
      expect(writeClient.operations, isEmpty);
    },
  );

  test(
    'rejects history block growth when the selected block changed before apply',
    () async {
      final staleRows = [
        [...activeSheetFixedColumns, 'Week 1'],
        [...List.filled(activeSheetFixedColumns.length, ''), 'S1'],
        ['Squat', '3', '3 min', '', 'x5@8', '', '', 'Legs', '', 'x', '225x5@8'],
      ];
      final changedRows = [
        [...activeSheetFixedColumns, 'Renamed'],
        [...List.filled(activeSheetFixedColumns.length, ''), 'S1'],
        ['Squat', '3', '3 min', '', 'x5@8', '', '', 'Legs', '', 'x', '225x5@8'],
      ];
      final readClient = _SequencedSpreadsheetClient([
        _snapshot(staleRows),
        _snapshot(changedRows),
      ]);
      final writeClient = _RecordingWriteClient();
      final service = _session(readClient, writeClient);

      await service.read();
      final rejected = await service.execute(
        SaveSetCmd(
          blockLabel: 'Week 1',
          sheetRow: 3,
          fields: const {'Weight': '230', 'Reps': '5', 'RPE': '8'},
        ),
      );

      expect(rejected.hasBlockingIssues, isTrue);
      expect(
        rejected.manualRepairItems.map((item) => item.problem),
        contains(contains('Set column Week 1 S1 no longer exists')),
      );
      expect(writeClient.operations, isEmpty);
    },
  );

  test(
    'updates a canonical exercise row and rereads placements through that row',
    () async {
      final activeRows = [
        [...activeSheetFixedColumns, 'Week 1'],
        [...List.filled(activeSheetFixedColumns.length, ''), 'S1'],
        ['Squat', '3', '3 min', '', 'x5@8', '', '', 'Legs', '', 'x', ''],
      ];
      final updatedActiveRows = [
        [...activeSheetFixedColumns, 'Week 1'],
        [...List.filled(activeSheetFixedColumns.length, ''), 'S1'],
        ['High Bar Squat', '3', '5', '8', '3 min', '', '', '', 'Legs', '', ''],
      ];
      final exercisesRows = [
        exercisesSheetColumns,
        [
          'Squat',
          'Back squat',
          '3',
          '5',
          '8',
          '3 min',
          '',
          '',
          '{Weight}x{Reps}@{RPE}',
        ],
        [
          'Bench Press',
          'Competition bench',
          '4',
          '6',
          '8',
          '3 min',
          '',
          '',
          '{Weight}x{Reps}@{RPE}',
        ],
      ];
      final updatedExercisesRows = [
        exercisesSheetColumns,
        [
          'High Bar Squat',
          'High bar back squat',
          '3',
          '5',
          '8',
          '3 min',
          '',
          '',
          '{Weight}x{Reps}@{RPE}',
        ],
        exercisesRows[2],
      ];
      final readClient = _SequencedSpreadsheetClient([
        _workbookSnapshot(activeRows, exercisesRows),
        _workbookSnapshot(activeRows, exercisesRows),
        _workbookSnapshot(updatedActiveRows, updatedExercisesRows),
      ]);
      final writeClient = _RecordingWriteClient();
      final service = _session(readClient, writeClient);

      final report = await service.read();
      final updated = await service.execute(
        UpdateExeCmd(
          selected: report.activeSheet.canonicalExercises.first,
          exercise: ExerciseDef(
            exercise: 'High Bar Squat',
            description: 'High bar back squat',
            defaultSets: '3',
            defaultRest: '3 min',
            defaultValues: const {'Weight': '', 'Reps': '5', 'RPE': '8'},
            logFormat: '{Weight}x{Reps}@{RPE}',
          ),
        ),
      );

      expect(writeClient.operations, isNotEmpty);
      expect(
        updated.activeSheet.canonicalExercises.map(
          (exercise) => exercise.exercise,
        ),
        ['High Bar Squat', 'Bench Press'],
      );
      expect(
        updated.activeSheet.primarySlots.single.exercise,
        'High Bar Squat',
      );
    },
  );

  test(
    'reviews and atomically updates a placed format without rewriting history',
    () async {
      const oldFormat = '({Height (in)})x{Reps}@{RPE},{Pain}';
      const newFormat = '({Height (in)}, {Weight (lbs)})x{Reps}@{RPE},{Pain}';
      final activeRows = [
        [...activeSheetFixedColumns, 'Week 1'],
        [...List.filled(activeSheetFixedColumns.length, ''), 'S1'],
        [
          'DB Step-Up',
          '3',
          '2 min',
          '2-1-1',
          '(14)x10@7,0',
          '',
          oldFormat,
          'Legs',
          '',
          'x',
          '(12)x8@8,0',
        ],
      ];
      final updatedActiveRows = activeRows.map((row) => [...row]).toList()
        ..[2][4] = '(14, 20)x10@7,0'
        ..[2][6] = newFormat;
      final exerciseRows = [
        exercisesSheetColumns,
        ['DB Step-Up', '', '3', '2 min', '2-1-1', '', oldFormat, '(12)x8@8,0'],
      ];
      final updatedExerciseRows = [
        exercisesSheetColumns,
        [
          'DB Step-Up',
          '',
          '3',
          '2 min',
          '2-1-1',
          '',
          newFormat,
          '(12, 15)x8@8,0',
        ],
      ];
      const formulas = [
        SheetsCellFormula(
          sheetRowNumber: 3,
          sheetColumnNumber: 1,
          formula: '=Exercises!A2',
        ),
        SheetsCellFormula(
          sheetRowNumber: 3,
          sheetColumnNumber: 7,
          formula: '=Exercises!G2',
        ),
      ];
      final reads = _SequencedSpreadsheetClient([
        _workbookSnapshot(activeRows, exerciseRows, activeFormulas: formulas),
        _workbookSnapshot(activeRows, exerciseRows, activeFormulas: formulas),
        _workbookSnapshot(
          updatedActiveRows,
          updatedExerciseRows,
          activeFormulas: formulas,
        ),
      ]);
      final writes = _RecordingWriteClient();
      final sess = _session(reads, writes);
      final initial = await sess.read();
      final exercise = ExerciseDef(
        exercise: 'DB Step-Up',
        defaultSets: '3',
        defaultRest: '2 min',
        defaultTempo: '2-1-1',
        logFormat: newFormat,
        defaultValues: const {
          'Height (in)': '12',
          'Weight (lbs)': '15',
          'Reps': '8',
          'RPE': '8',
          'Pain': '0',
        },
      );

      final preview = await sess.execute(
        UpdateExeCmd(
          selected: initial.activeSheet.canonicalExercises.single,
          exercise: exercise,
        ),
      );

      expect(writes.operations, isEmpty);
      final impact = preview.exeFormatImpact!;
      expect(impact.rawHistoryCount, 1);
      final updated = await sess.execute(
        ConfirmExeUpdateCmd(
          impact: impact,
          valuesByRow: {
            3: {
              ...impact.placements.single.proposedValues,
              'Weight (lbs)': '20',
            },
          },
        ),
      );

      expect(writes.applyCount, 1);
      expect(
        writes.operations.whereType<SheetsCellWrite>().map(
          (write) => (write.sheet.title, write.sheetColumnNumber, write.value),
        ),
        containsAll([
          ('Exercises', 7, newFormat),
          ('Exercises', 8, '(12, 15)x8@8,0'),
          ('Active Workout', 5, '(14, 20)x10@7,0'),
        ]),
      );
      final context = updated.activeSheet.buildLoggingContext(
        primaryRow: 3,
        selectedRow: 3,
        blockLabel: 'Week 1',
      );
      expect(context.selectedHistory.entries.single.rawValue, '(12)x8@8,0');
      expect(
        context.selectedHistory.entries.single.logEntry,
        isA<RawLogEntry>(),
      );
    },
  );

  test(
    'uses the canonical path for a format change with no placements',
    () async {
      const oldFormat = '{Reps}@{RPE}';
      const newFormat = '{Reps}@{RPE},{Pain}';
      final activeRows = [activeSheetFixedColumns, List.filled(10, '')];
      final exerciseRows = [
        exercisesSheetColumns,
        ['Leg Extension', '', '3', '2 min', '2-1-1', '', oldFormat, '10@8'],
      ];
      final updatedExerciseRows = [
        exercisesSheetColumns,
        ['Leg Extension', '', '3', '2 min', '2-1-1', '', newFormat, '10@8,0'],
      ];
      final reads = _SequencedSpreadsheetClient([
        _workbookSnapshot(activeRows, exerciseRows),
        _workbookSnapshot(activeRows, exerciseRows),
        _workbookSnapshot(activeRows, updatedExerciseRows),
      ]);
      final writes = _RecordingWriteClient();
      final sess = _session(reads, writes);
      final initial = await sess.read();

      final updated = await sess.execute(
        UpdateExeCmd(
          selected: initial.activeSheet.canonicalExercises.single,
          exercise: ExerciseDef(
            exercise: 'Leg Extension',
            defaultSets: '3',
            defaultRest: '2 min',
            defaultTempo: '2-1-1',
            logFormat: newFormat,
            defaultValues: const {'Reps': '10', 'RPE': '8', 'Pain': '0'},
          ),
        ),
      );

      expect(updated.exeFormatImpact, isNull);
      expect(writes.applyCount, 1);
      expect(
        writes.operations.whereType<SheetsCellWrite>().map(
          (write) => write.sheet.title,
        ),
        everyElement('Exercises'),
      );
    },
  );

  test(
    'rejects a reviewed format update when placed Targets changed',
    () async {
      const oldFormat = '{Reps}@{RPE}';
      const newFormat = '{Reps}@{RPE},{Pain}';
      final activeRows = [
        [...activeSheetFixedColumns, 'Week 1'],
        [...List.filled(10, ''), 'S1'],
        [
          'Leg Extension',
          '3',
          '2 min',
          '',
          '10@8',
          '',
          oldFormat,
          'Legs',
          '',
          'x',
          '10@8',
        ],
      ];
      final changedRows = activeRows.map((row) => [...row]).toList()
        ..[2][4] = '12@9';
      final exerciseRows = [
        exercisesSheetColumns,
        ['Leg Extension', '', '3', '2 min', '', '', oldFormat, '10@8'],
      ];
      const formulas = [
        SheetsCellFormula(
          sheetRowNumber: 3,
          sheetColumnNumber: 1,
          formula: '=Exercises!A2',
        ),
        SheetsCellFormula(
          sheetRowNumber: 3,
          sheetColumnNumber: 7,
          formula: '=Exercises!G2',
        ),
      ];
      final reads = _SequencedSpreadsheetClient([
        _workbookSnapshot(activeRows, exerciseRows, activeFormulas: formulas),
        _workbookSnapshot(changedRows, exerciseRows, activeFormulas: formulas),
      ]);
      final writes = _RecordingWriteClient();
      final sess = _session(reads, writes);
      final initial = await sess.read();
      final preview = await sess.execute(
        UpdateExeCmd(
          selected: initial.activeSheet.canonicalExercises.single,
          exercise: ExerciseDef(
            exercise: 'Leg Extension',
            defaultSets: '3',
            defaultRest: '2 min',
            logFormat: newFormat,
            defaultValues: const {'Reps': '10', 'RPE': '8', 'Pain': '0'},
          ),
        ),
      );
      final impact = preview.exeFormatImpact!;

      final rejected = await sess.execute(
        ConfirmExeUpdateCmd(
          impact: impact,
          valuesByRow: {3: impact.placements.single.proposedValues},
        ),
      );

      expect(rejected.writeRejections, isNotEmpty);
      expect(writes.operations, isEmpty);
    },
  );

  test(
    'reorders canonical exercises and rereads workout references safely',
    () async {
      final activeRows = [
        [...activeSheetFixedColumns, 'Week 1'],
        [...List.filled(activeSheetFixedColumns.length, ''), 'S1'],
        ['Squat', '3', '3 min', '', 'x5@8', '', '', 'Legs', '', 'x', ''],
        ['Bench Press', '4', '6', '8', '3 min', '', '', '', 'Upper', '', ''],
      ];
      final updatedActiveRows = [
        [...activeSheetFixedColumns, 'Week 1'],
        [...List.filled(activeSheetFixedColumns.length, ''), 'S1'],
        ['Squat', '3', '3 min', '', 'x5@8', '', '', 'Legs', '', 'x', ''],
        ['Bench Press', '4', '6', '8', '3 min', '', '', '', 'Upper', '', ''],
      ];
      final exercisesRows = [
        exercisesSheetColumns,
        _exerciseRow('Squat', description: 'Back squat'),
        _exerciseRow('Bench Press', description: 'Competition bench'),
        _exerciseRow('Cable Row', description: 'Seated cable row'),
      ];
      final reorderedExercisesRows = [
        exercisesSheetColumns,
        _exerciseRow('Bench Press', description: 'Competition bench'),
        _exerciseRow('Cable Row', description: 'Seated cable row'),
        _exerciseRow('Squat', description: 'Back squat'),
      ];
      final readClient = _SequencedSpreadsheetClient([
        _workbookSnapshot(
          activeRows,
          exercisesRows,
          activeFormulas: const [
            SheetsCellFormula(
              sheetRowNumber: 3,
              sheetColumnNumber: 1,
              formula: '=Exercises!A2',
            ),
            SheetsCellFormula(
              sheetRowNumber: 4,
              sheetColumnNumber: 1,
              formula: '=Exercises!A3',
            ),
          ],
        ),
        _workbookSnapshot(
          activeRows,
          exercisesRows,
          activeFormulas: const [
            SheetsCellFormula(
              sheetRowNumber: 3,
              sheetColumnNumber: 1,
              formula: '=Exercises!A2',
            ),
            SheetsCellFormula(
              sheetRowNumber: 4,
              sheetColumnNumber: 1,
              formula: '=Exercises!A3',
            ),
          ],
        ),
        _workbookSnapshot(updatedActiveRows, reorderedExercisesRows),
      ]);
      final writeClient = _RecordingWriteClient();
      final service = _session(readClient, writeClient);

      await service.read();
      final reordered = await service.execute(
        const ReorderExesCmd(ReorderIntent(fromIndex: 0, toIndex: 2)),
      );

      expect(writeClient.operations, isNotEmpty);
      expect(
        reordered.activeSheet.canonicalExercises.map(
          (exercise) => exercise.exercise,
        ),
        ['Bench Press', 'Cable Row', 'Squat'],
      );
      expect(reordered.activeSheet.primarySlots.map((slot) => slot.exercise), [
        'Squat',
        'Bench Press',
      ]);
    },
  );

  test(
    'reorders workout exercises and rereads backup attachment safely',
    () async {
      final activeRows = [
        [...activeSheetFixedColumns, 'Week 1'],
        [...List.filled(activeSheetFixedColumns.length, ''), 'S1'],
        [
          'Squat',
          '3',
          '5',
          '8',
          '3 min',
          '',
          'primary notes',
          defaultExerciseLogFormat,
          'Legs',
          '',
          '225x5@8',
        ],
        [
          'Leg Press',
          '3',
          '12',
          '8',
          '2 min',
          '',
          'backup notes',
          '{Reps}@{RPE}',
          'Legs',
          'TRUE',
          '12@8',
        ],
        [
          'Bench Press',
          '4',
          '6',
          '8',
          '3 min',
          '',
          'upper notes',
          defaultExerciseLogFormat,
          'Upper',
          '',
          '185x6@8',
        ],
        [
          'Chest Press',
          '3',
          '10',
          '8',
          '2 min',
          '',
          'upper backup',
          '{Reps}@{RPE}',
          'Upper',
          'TRUE',
          '10@8',
        ],
        [
          'Lunge',
          '2',
          '10',
          '7',
          '90s',
          '',
          'single leg',
          defaultExerciseLogFormat,
          'Legs',
          '',
          '50x10@7',
        ],
      ];
      final reorderedActiveRows = [
        [...activeSheetFixedColumns, 'Week 1'],
        [...List.filled(activeSheetFixedColumns.length, ''), 'S1'],
        [
          'Lunge',
          '2',
          '10',
          '7',
          '90s',
          '',
          'single leg',
          defaultExerciseLogFormat,
          'Legs',
          '',
          '50x10@7',
        ],
        [
          'Bench Press',
          '4',
          '6',
          '8',
          '3 min',
          '',
          'upper notes',
          defaultExerciseLogFormat,
          'Upper',
          '',
          '185x6@8',
        ],
        [
          'Chest Press',
          '3',
          '10',
          '8',
          '2 min',
          '',
          'upper backup',
          '{Reps}@{RPE}',
          'Upper',
          'TRUE',
          '10@8',
        ],
        [
          'Squat',
          '3',
          '5',
          '8',
          '3 min',
          '',
          'primary notes',
          defaultExerciseLogFormat,
          'Legs',
          '',
          '225x5@8',
        ],
        [
          'Leg Press',
          '3',
          '12',
          '8',
          '2 min',
          '',
          'backup notes',
          '{Reps}@{RPE}',
          'Legs',
          'TRUE',
          '12@8',
        ],
      ];
      final exercisesRows = [
        exercisesSheetColumns,
        _exerciseRow('Squat', description: 'Back squat'),
        _exerciseRow('Leg Press', description: 'Machine press'),
        _exerciseRow('Bench Press', description: 'Competition bench'),
        _exerciseRow('Lunge', description: 'Single leg'),
      ];
      final readClient = _SequencedSpreadsheetClient([
        _workbookSnapshot(activeRows, exercisesRows),
        _workbookSnapshot(activeRows, exercisesRows),
        _workbookSnapshot(reorderedActiveRows, exercisesRows),
      ]);
      final writeClient = _RecordingWriteClient();
      final service = _session(readClient, writeClient);

      await service.read();
      final reordered = await service.execute(
        const ReorderWorkoutCmd(
          workout: 'Legs',
          intent: ReorderIntent(fromIndex: 0, toIndex: 1),
        ),
      );
      final overview = reordered.activeSheet.buildWorkoutOverview(
        workout: 'Legs',
        blockLabel: 'Week 1',
      );

      expect(writeClient.operations, isNotEmpty);
      expect(overview.slots.map((slot) => slot.exercise), ['Lunge', 'Squat']);
      expect(overview.slots[1].backups.map((backup) => backup.exercise), [
        'Leg Press',
      ]);
      expect(reordered.activeSheet.primarySlots.map((slot) => slot.exercise), [
        'Lunge',
        'Bench Press',
        'Squat',
      ]);
      expect(
        reordered.activeSheet.primarySlots[1].backups.map(
          (backup) => backup.exercise,
        ),
        ['Chest Press'],
      );
    },
  );

  test(
    'deletes a primary workout exercise with attached backups and returns a refreshed report',
    () async {
      final activeRows = [
        [...activeSheetFixedColumns, 'Week 1'],
        [...List.filled(activeSheetFixedColumns.length, ''), 'S1'],
        [
          'Squat',
          '3',
          '5',
          '8',
          '3 min',
          '',
          'primary notes',
          defaultExerciseLogFormat,
          'Legs',
          '',
          '225x5@8',
        ],
        [
          'Leg Press',
          '3',
          '12',
          '8',
          '2 min',
          '',
          'backup notes',
          '{Reps}@{RPE}',
          'Legs',
          'TRUE',
          '12@8',
        ],
        [
          'Lunge',
          '2',
          '10',
          '7',
          '90s',
          '',
          'single leg',
          defaultExerciseLogFormat,
          'Legs',
          '',
          '50x10@7',
        ],
      ];
      final deletedActiveRows = [
        [...activeSheetFixedColumns, 'Week 1'],
        [...List.filled(activeSheetFixedColumns.length, ''), 'S1'],
        [
          'Lunge',
          '2',
          '10',
          '7',
          '90s',
          '',
          'single leg',
          defaultExerciseLogFormat,
          'Legs',
          '',
          '50x10@7',
        ],
      ];
      final exercisesRows = [
        exercisesSheetColumns,
        _exerciseRow('Squat', description: 'Back squat'),
        _exerciseRow('Leg Press', description: 'Machine press'),
        _exerciseRow('Lunge', description: 'Single leg'),
      ];
      final readClient = _SequencedSpreadsheetClient([
        _workbookSnapshot(activeRows, exercisesRows),
        _workbookSnapshot(activeRows, exercisesRows),
        _workbookSnapshot(deletedActiveRows, exercisesRows),
      ]);
      final writeClient = _RecordingWriteClient();
      final service = _session(readClient, writeClient);

      await service.read();
      final deleted = await service.execute(const DeleteWorkoutExeCmd(3));
      final overview = deleted.activeSheet.buildWorkoutOverview(
        workout: 'Legs',
        blockLabel: 'Week 1',
      );

      final rowDeletions = writeClient.operations
          .whereType<SheetsRowDeletion>();
      expect(rowDeletions, hasLength(1));
      expect(rowDeletions.single.sheet.title, 'Active Workout');
      expect(rowDeletions.single.sheetRowNumber, 3);
      expect(rowDeletions.single.rowCount, 2);
      expect(overview.slots.map((slot) => slot.exercise), ['Lunge']);
      expect(deleted.activeSheet.selectableWorkouts, ['Legs']);
      expect(deleted.activeSheet.selectHistoryBlock('Week 1'), isNotNull);
      expect(
        deleted.activeSheet.canonicalExercises.map(
          (exercise) => exercise.exercise,
        ),
        ['Squat', 'Leg Press', 'Lunge'],
      );
    },
  );

  test(
    'rejects workout exercise deletion when the sheet changed after the UI snapshot',
    () async {
      final activeRows = [
        [...activeSheetFixedColumns, 'Week 1'],
        [...List.filled(activeSheetFixedColumns.length, ''), 'S1'],
        ['Squat', '3', '3 min', '', 'x5@8', '', '', 'Legs', '', 'x', ''],
        ['Leg Press', '3', '12', '8', '2 min', '', '', '', 'Legs', 'TRUE', ''],
      ];
      final changedRows = [
        [...activeSheetFixedColumns, 'Week 1'],
        [...List.filled(activeSheetFixedColumns.length, ''), 'S1'],
        ['Squat', '3', '3 min', '', 'x5@8', '', '', 'Legs', '', 'x', ''],
        ['Hack Squat', '3', '10', '8', '2 min', '', '', '', 'Legs', 'TRUE', ''],
      ];
      final exercisesRows = [
        exercisesSheetColumns,
        _exerciseRow('Squat', description: 'Back squat'),
        _exerciseRow('Leg Press', description: 'Machine press'),
      ];
      final readClient = _SequencedSpreadsheetClient([
        _workbookSnapshot(activeRows, exercisesRows),
        _workbookSnapshot(changedRows, exercisesRows),
      ]);
      final writeClient = _RecordingWriteClient();
      final service = _session(readClient, writeClient);

      await service.read();
      final rejected = await service.execute(const DeleteWorkoutExeCmd(3));

      expect(rejected.hasBlockingIssues, isTrue);
      expect(
        rejected.manualRepairItems.map((item) => item.problem),
        contains(
          contains(
            'Backup group for row 3 no longer matches the planned delete',
          ),
        ),
      );
      expect(writeClient.operations, isEmpty);
    },
  );

  test(
    'rejects canonical exercise reorder when the sheet changed after the UI snapshot',
    () async {
      final activeRows = [
        [...activeSheetFixedColumns, 'Week 1'],
        [...List.filled(activeSheetFixedColumns.length, ''), 'S1'],
      ];
      final staleExercisesRows = [
        exercisesSheetColumns,
        _exerciseRow('Squat', description: 'Back squat'),
        _exerciseRow('Bench Press', description: 'Competition bench'),
        _exerciseRow('Cable Row', description: 'Seated cable row'),
      ];
      final changedExercisesRows = [
        exercisesSheetColumns,
        _exerciseRow('Deadlift', description: 'Conventional deadlift'),
        _exerciseRow('Bench Press', description: 'Competition bench'),
        _exerciseRow('Cable Row', description: 'Seated cable row'),
      ];
      final readClient = _SequencedSpreadsheetClient([
        _workbookSnapshot(activeRows, staleExercisesRows),
        _workbookSnapshot(activeRows, changedExercisesRows),
      ]);
      final writeClient = _RecordingWriteClient();
      final service = _session(readClient, writeClient);

      await service.read();
      final rejected = await service.execute(
        const ReorderExesCmd(ReorderIntent(fromIndex: 0, toIndex: 2)),
      );

      expect(rejected.hasBlockingIssues, isTrue);
      expect(
        rejected.manualRepairItems.single.problem,
        contains('Exercises row 2 no longer matches the planned reorder'),
      );
      expect(writeClient.operations, isEmpty);
    },
  );

  test(
    'rejects workout placement when the selected canonical exercise row changed before apply',
    () async {
      final activeRows = [
        [...activeSheetFixedColumns, 'Week 1'],
        [...List.filled(activeSheetFixedColumns.length, ''), 'S1'],
      ];
      final staleExercisesRows = [
        exercisesSheetColumns,
        [
          'Squat',
          'Back squat',
          '3',
          '5',
          '8',
          '3 min',
          '',
          'Stay braced.',
          defaultExerciseLogFormat,
        ],
      ];
      final changedExercisesRows = [
        exercisesSheetColumns,
        [
          'Deadlift',
          'Conventional deadlift',
          '3',
          '5',
          '8',
          '3 min',
          '',
          'Push the floor away.',
          defaultExerciseLogFormat,
        ],
      ];
      final readClient = _SequencedSpreadsheetClient([
        _workbookSnapshot(activeRows, staleExercisesRows),
        _workbookSnapshot(activeRows, changedExercisesRows),
      ]);
      final writeClient = _RecordingWriteClient();
      final service = _session(readClient, writeClient);

      final report = await service.read();
      final selectedExercise = report.activeSheet.canonicalExercises.single;

      final rejected = await service.execute(
        PlaceExeCmd(
          exercise: selectedExercise,
          metadata: const WorkoutPlacementMetadata(),
          placement: const ExercisePlacementTarget.primary(workout: 'Legs'),
        ),
      );

      expect(rejected.hasBlockingIssues, isTrue);
      expect(
        rejected.manualRepairItems.single.problem,
        contains('Exercises row 2 no longer matches Squat'),
      );
      expect(writeClient.operations, isEmpty);
    },
  );
}

ValSess _session(
  SheetsWorkbookClient readClient,
  SheetsWorkbookClient writeClient,
) {
  return ValSess(
    sheetId: 'spreadsheet-id',
    io: AdapterWbkIo(
      sheetId: 'spreadsheet-id',
      readAdapter: SheetsReadAdapter(client: readClient),
      writeAdapter: SheetsWriteAdapter(client: writeClient),
    ),
  );
}

List<String> _exerciseRow(String exercise, {String description = ''}) {
  return [
    exercise,
    description,
    '3',
    '2 min',
    '2-1-1',
    '',
    defaultExerciseLogFormat,
    'x10@8',
  ];
}

SheetsWorkbookSnapshot _snapshot(List<List<String>> rows) {
  return SheetsWorkbookSnapshot(
    sheets: [
      SheetsGridSnapshot(
        sheet: const SheetsSheetIdentity(sheetId: 42, title: 'Active Workout'),
        rows: _fieldActiveRows(rows),
      ),
      SheetsGridSnapshot(
        sheet: const SheetsSheetIdentity(sheetId: 84, title: 'Exercises'),
        rows: const [exercisesSheetColumns],
      ),
    ],
  );
}

SheetsWorkbookSnapshot _workbookSnapshot(
  List<List<String>> activeRows,
  List<List<String>> exercisesRows, {
  Iterable<SheetsCellFormula> activeFormulas = const [],
}) {
  return SheetsWorkbookSnapshot(
    sheets: [
      SheetsGridSnapshot(
        sheet: const SheetsSheetIdentity(sheetId: 42, title: 'Active Workout'),
        rows: _fieldActiveRows(activeRows),
        cellFormulas: activeFormulas,
      ),
      SheetsGridSnapshot(
        sheet: const SheetsSheetIdentity(sheetId: 84, title: 'Exercises'),
        rows: _fieldExerciseRows(exercisesRows),
      ),
    ],
  );
}

List<List<String>> _fieldActiveRows(List<List<String>> rows) {
  if (rows.isEmpty ||
      rows.first.take(activeSheetFixedColumns.length).join('|') !=
          activeSheetFixedColumns.join('|')) {
    return rows;
  }
  return [
    for (var index = 0; index < rows.length; index += 1)
      if (index < 2 || rows[index].length > 9 && rows[index][9] == 'x')
        rows[index]
      else
        _fieldActiveRow(rows[index]),
  ];
}

List<String> _fieldActiveRow(List<String> source) {
  final row = [
    ...source,
    ...List.filled(source.length < 10 ? 10 - source.length : 0, ''),
  ];
  final formatText = row[7].trim().isEmpty ? defaultExerciseLogFormat : row[7];
  final format = parseLogFormat(formatText);
  final targets = format is ParsedLogFormat
      ? format.renderValues({
          for (final label in format.fieldLabels)
            label: switch (label) {
              'Reps' || 'Seconds' => row[2],
              'RPE' => row[3],
              _ => '',
            },
        })
      : '';
  return [
    row[0],
    row[1],
    row[4],
    row[5],
    targets,
    row[6],
    row[7],
    row[8],
    row[9],
    row[0].trim().isEmpty ? '' : 'x',
    ...source.skip(10),
  ];
}

List<List<String>> _fieldExerciseRows(List<List<String>> rows) {
  if (rows.isEmpty || rows.first.join('|') != exercisesSheetColumns.join('|')) {
    return rows;
  }
  return [
    rows.first,
    for (final source in rows.skip(1))
      if (source.length <= exercisesSheetColumns.length)
        source
      else
        [
          source[0],
          source[1],
          source[2],
          source[5],
          source[6],
          source[7],
          source[8],
          (parseLogFormat(source[8]) as ParsedLogFormat).renderValues({
            'Weight': '',
            'Reps': source[3],
            'RPE': source[4],
          }),
        ],
  ];
}

class _SequencedSpreadsheetClient implements SheetsWorkbookClient {
  _SequencedSpreadsheetClient(this.snapshots);

  final List<SheetsWorkbookSnapshot> snapshots;
  var _nextSnapshot = 0;

  @override
  Future<SheetsWorkbookMetadata> fetchMetadata(String spreadsheetId) async {
    final snapshot = _nextSnapshot < snapshots.length
        ? snapshots[_nextSnapshot]
        : snapshots.last;
    return _currentMetadata(snapshot.sheets.map((s) => s.sheet));
  }

  @override
  Future<SheetsWorkbookSnapshot> readGrids({
    required String spreadsheetId,
    required Iterable<SheetsGridRead> reads,
  }) async {
    if (_nextSnapshot >= snapshots.length) {
      return snapshots.last;
    }
    return snapshots[_nextSnapshot++];
  }

  @override
  Future<void> applyOperations({
    required String spreadsheetId,
    required Iterable<SheetsWorkbookOperation> operations,
  }) {
    throw UnimplementedError();
  }
}

class _RecordingWriteClient implements SheetsWorkbookClient {
  final operations = <SheetsWorkbookOperation>[];
  var applyCount = 0;

  @override
  Future<SheetsWorkbookMetadata> fetchMetadata(String spreadsheetId) async {
    return _currentMetadata(const [
      SheetsSheetIdentity(sheetId: 42, title: 'Active Workout'),
      SheetsSheetIdentity(sheetId: 84, title: 'Exercises'),
    ]);
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
    applyCount += 1;
    this.operations.addAll(operations);
  }
}

class _CloseTrackingWorkbookClient implements SheetsWorkbookClient {
  _CloseTrackingWorkbookClient(this.client, this.snapshots);

  final _CloseTrackingAuthClient Function() client;
  final List<SheetsWorkbookSnapshot> snapshots;
  final operations = <SheetsWorkbookOperation>[];
  var _nextSnapshot = 0;

  @override
  Future<SheetsWorkbookMetadata> fetchMetadata(String spreadsheetId) async {
    await _expectClientStillOpen();
    final snapshot = _nextSnapshot < snapshots.length
        ? snapshots[_nextSnapshot]
        : snapshots.last;
    return _currentMetadata(snapshot.sheets.map((sheet) => sheet.sheet));
  }

  @override
  Future<SheetsWorkbookSnapshot> readGrids({
    required String spreadsheetId,
    required Iterable<SheetsGridRead> reads,
  }) async {
    await _expectClientStillOpen();
    if (_nextSnapshot >= snapshots.length) {
      return snapshots.last;
    }
    return snapshots[_nextSnapshot++];
  }

  @override
  Future<void> applyOperations({
    required String spreadsheetId,
    required Iterable<SheetsWorkbookOperation> operations,
  }) async {
    await _expectClientStillOpen();
    this.operations.addAll(operations);
  }

  Future<void> _expectClientStillOpen() async {
    await Future<void>.delayed(Duration.zero);
    if (client().closed) {
      client().closedDuringAction = true;
    }
  }
}

SheetsWorkbookMetadata _currentMetadata(Iterable<SheetsSheetIdentity> sheets) {
  return SheetsWorkbookMetadata(
    sheets: sheets,
    developerMetadata: const [
      SheetsDeveloperMetadata(
        id: 1,
        key: workbookSchemaKey,
        value: workbookSchemaVersion,
      ),
    ],
  );
}

final hasClosedCleanly = isA<_CloseTrackingAuthClient>()
    .having(
      (client) => client.closedDuringAction,
      'closed during action',
      false,
    )
    .having((client) => client.closed, 'closed after action', true);

class _CloseTrackingAuthClient extends http.BaseClient {
  bool closed = false;
  bool closedDuringAction = false;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    throw UnimplementedError();
  }

  @override
  void close() {
    closed = true;
  }
}

class _RecordingSignInAuthGateway extends ChangeNotifier
    implements SignInAuthGateway {
  final List<List<String>> requestedScopes = [];

  @override
  GoogleAccountProfile? get currentAccount => null;

  @override
  Future<Map<String, String>?> authorizationHeaders(List<String> scopes) async {
    requestedScopes.add(scopes);
    return {'Authorization': 'Bearer test-token'};
  }

  @override
  Future<void> restoreAccount({List<String> scopes = const []}) async {}

  @override
  Future<bool> signIn({List<String> scopes = const []}) async => true;

  @override
  Future<void> signOut() async {}
}
