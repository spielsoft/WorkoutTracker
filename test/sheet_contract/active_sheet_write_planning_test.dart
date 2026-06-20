import 'package:flutter_test/flutter_test.dart';
import 'package:workout_tracker/sheet_contract.dart';

import 'active_sheet_test_helpers.dart';

void main() {
  test('plans logging a new set and advances to the next position', () {
    final activeSheet = parseFixtureActiveSheet();

    final plan = activeSheet.planSetLoggingWrite(
      historyBlockLabel: 'Week 2',
      sheetRowNumber: 3,
      fieldValues: const {'Weight': '150', 'Reps': '10', 'RPE': '8'},
    );

    expect(plan.cellUpdates, [
      CellUpdate(sheetRowNumber: 3, sheetColumnNumber: 11, value: '150x10@8'),
    ]);
    expect(
      plan.nextSetPosition,
      SetPosition(sheetRowNumber: 3, setNumber: 2, sheetColumnNumber: 12),
    );
  });

  test('renders surrounding literals when a formatted field is blank', () {
    final rows = [
      historyHeaderRow(['Session A']),
      setLabelRow(['S1']),
      [
        'Squat',
        '3',
        '5',
        '8',
        '3 min',
        '',
        '',
        '{Weight}[x]{Reps}[@]{RPE}[,]{Pain}',
        'Legs',
        '',
        '',
      ],
    ];
    final activeSheet = parseActiveSheet(ActiveSheetInput(rows: rows));

    final plan = activeSheet.planSetLoggingWrite(
      historyBlockLabel: 'Session A',
      sheetRowNumber: 3,
      fieldValues: const {
        'Weight': '150',
        'Reps': '10',
        'RPE': '8',
        'Pain': '',
      },
    );

    expect(plan.cellUpdates, [
      CellUpdate(sheetRowNumber: 3, sheetColumnNumber: 11, value: '150x10@8,'),
    ]);
  });

  test('plans primary and backup set entries against their selected rows', () {
    final rows = [
      historyHeaderRow(['Session A', '']),
      setLabelRow(['S1', 'S2']),
      ['Squat', '3', '5', '8', '3 min', '', '', '', 'Legs', '', '225x5@8', ''],
      [
        'Leg Press',
        '3',
        '10',
        '8',
        '2 min',
        '',
        '',
        '{Reps}[@]{RPE}',
        'Legs',
        'TRUE',
        '',
        '',
      ],
    ];
    final activeSheet = parseActiveSheet(ActiveSheetInput(rows: rows));

    final primaryPlan = activeSheet.planSetLoggingWrite(
      historyBlockLabel: 'Session A',
      sheetRowNumber: 3,
      fieldValues: const {'Weight': '230', 'Reps': '5', 'RPE': '8'},
    );
    final backupPlan = activeSheet.planSetLoggingWrite(
      historyBlockLabel: 'Session A',
      sheetRowNumber: 4,
      fieldValues: const {'Reps': '10', 'RPE': '8'},
    );

    expect(primaryPlan.cellUpdates, [
      CellUpdate(sheetRowNumber: 3, sheetColumnNumber: 12, value: '230x5@8'),
    ]);
    expect(backupPlan.cellUpdates, [
      CellUpdate(sheetRowNumber: 4, sheetColumnNumber: 11, value: '10@8'),
    ]);
    expect(
      backupPlan
          .previewRowsAfterApplying(rows)[2]
          .skip(activeSheetFixedColumns.length),
      ['225x5@8', ''],
    );
  });

  test(
    'primary and backup rows keep different row-local formats through reparse',
    () {
      final rows = [
        historyHeaderRow(['Session A', '']),
        setLabelRow(['S1', 'S2']),
        ['Squat', '3', '5', '8', '3 min', '', '', '', 'Legs', '', '', ''],
        [
          'Hamstring Curl',
          '3',
          '12',
          '8',
          '90s',
          '',
          '',
          '{Reps}[@]{RPE}',
          'Legs',
          'TRUE',
          '',
          '',
        ],
      ];
      var activeSheet = parseActiveSheet(ActiveSheetInput(rows: rows));

      var primaryContext = activeSheet.buildExerciseLoggingContext(
        primarySheetRowNumber: 3,
        selectedSheetRowNumber: 3,
        historyBlockLabel: 'Session A',
      );
      var backupContext = activeSheet.buildExerciseLoggingContext(
        primarySheetRowNumber: 3,
        selectedSheetRowNumber: 4,
        historyBlockLabel: 'Session A',
      );

      expect(
        primaryContext.logFormat,
        isA<ParsedLogFormat>().having(
          (format) => format.fieldLabels,
          'field labels',
          ['Weight', 'Reps', 'RPE'],
        ),
      );
      expect(
        backupContext.logFormat,
        isA<ParsedLogFormat>().having(
          (format) => format.fieldLabels,
          'field labels',
          ['Reps', 'RPE'],
        ),
      );

      final primaryPlan = activeSheet.planSetLoggingWrite(
        historyBlockLabel: 'Session A',
        sheetRowNumber: primaryContext.selectedChoice.sheetRowNumber,
        fieldValues: const {'Weight': '225', 'Reps': '5', 'RPE': '8'},
      );
      var previewRows = primaryPlan.previewRowsAfterApplying(rows);
      activeSheet = parseActiveSheet(ActiveSheetInput(rows: previewRows));

      final backupPlan = activeSheet.planSetLoggingWrite(
        historyBlockLabel: 'Session A',
        sheetRowNumber: backupContext.selectedChoice.sheetRowNumber,
        fieldValues: const {'Reps': '12', 'RPE': '8'},
      );
      previewRows = backupPlan.previewRowsAfterApplying(previewRows);
      activeSheet = parseActiveSheet(ActiveSheetInput(rows: previewRows));

      primaryContext = activeSheet.buildExerciseLoggingContext(
        primarySheetRowNumber: 3,
        selectedSheetRowNumber: 3,
        historyBlockLabel: 'Session A',
      );
      backupContext = activeSheet.buildExerciseLoggingContext(
        primarySheetRowNumber: 3,
        selectedSheetRowNumber: 4,
        historyBlockLabel: 'Session A',
      );

      expect(primaryContext.selectedHistory.entries.first.rawValue, '225x5@8');
      expect(backupContext.selectedHistory.entries.first.rawValue, '12@8');
      expect(
        backupContext.selectedHistory.entries.first.logEntry,
        isA<FormattedLogEntry>().having(
          (entry) => entry.fieldValues,
          'field values',
          {'Reps': '12', 'RPE': '8'},
        ),
      );
    },
  );

  test('plans editing an existing set cell', () {
    final activeSheet = parseFixtureActiveSheet();

    final plan = activeSheet.planSetEdit(
      historyBlockLabel: 'Week 2',
      sheetRowNumber: 6,
      setNumber: 1,
      fieldValues: const {'Weight': '160', 'Reps': '6', 'RPE': '8'},
    );

    expect(plan.cellUpdates, [
      CellUpdate(sheetRowNumber: 6, sheetColumnNumber: 11, value: '160x6@8'),
    ]);
  });

  test('rejects structured set writes if the row log format changed', () {
    final rows = [
      historyHeaderRow(['Session A']),
      setLabelRow(['S1']),
      ['Squat', '3', '5', '8', '3 min', '', '', '', 'Legs', '', ''],
    ];
    final activeSheet = parseActiveSheet(ActiveSheetInput(rows: rows));

    final plan = activeSheet.planSetLoggingWrite(
      historyBlockLabel: 'Session A',
      sheetRowNumber: 3,
      fieldValues: const {'Weight': '225', 'Reps': '5', 'RPE': '8'},
    );

    final changedRows = rows.map((row) => [...row]).toList();
    changedRows[2][7] = '{Reps}[@]{RPE}';
    final changedSheet = parseActiveSheet(ActiveSheetInput(rows: changedRows));

    expect(plan.writeRejections(changedSheet), isNotEmpty);
  });

  test('plans clearing an existing set cell', () {
    final activeSheet = parseFixtureActiveSheet();

    final plan = activeSheet.planSetClear(
      historyBlockLabel: 'Week 2',
      sheetRowNumber: 6,
      setNumber: 1,
    );

    expect(plan.cellUpdates, [
      CellUpdate(sheetRowNumber: 6, sheetColumnNumber: 11, value: ''),
    ]);
  });

  test(
    'plans history block growth when logging beyond existing set columns',
    () {
      final rows = [
        historyHeaderRow(['Session A']),
        setLabelRow(['S1']),
        ['Squat', '3', '5', '8', '3 min', '', '', '', 'Legs', '', '225x5@8'],
      ];
      final activeSheet = parseActiveSheet(ActiveSheetInput(rows: rows));

      final plan = activeSheet.planSetLoggingWrite(
        historyBlockLabel: 'Session A',
        sheetRowNumber: 3,
        fieldValues: const {'Weight': '230', 'Reps': '5', 'RPE': '8'},
      );

      expect(plan.columnInsertions, [
        HistoryColumnInsertion(
          sheetColumnNumber: 12,
          headers: const [''],
          setLabels: const ['S2'],
        ),
      ]);
      expect(plan.cellUpdates, [
        CellUpdate(sheetRowNumber: 3, sheetColumnNumber: 12, value: '230x5@8'),
      ]);
      expect(
        plan
            .previewRowsAfterApplying(rows)[2]
            .skip(activeSheetFixedColumns.length),
        ['225x5@8', '230x5@8'],
      );
    },
  );

  test('preserves raw unparseable existing data when logging a new set', () {
    final rows = [
      historyHeaderRow(['Session A', '']),
      setLabelRow(['S1', 'S2']),
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
        'worked up, knee felt odd',
        '',
      ],
    ];
    final activeSheet = parseActiveSheet(ActiveSheetInput(rows: rows));

    final plan = activeSheet.planSetLoggingWrite(
      historyBlockLabel: 'Session A',
      sheetRowNumber: 3,
      fieldValues: const {'Weight': '225', 'Reps': '5', 'RPE': '8'},
    );

    expect(plan.cellUpdates, [
      CellUpdate(sheetRowNumber: 3, sheetColumnNumber: 12, value: '225x5@8'),
    ]);
    expect(
      plan
          .previewRowsAfterApplying(rows)[2]
          .skip(activeSheetFixedColumns.length),
      ['worked up, knee felt odd', '225x5@8'],
    );
  });

  test('does not plan set writes for rows outside parsed exercise slots', () {
    final rows = [
      historyHeaderRow(['Session A']),
      setLabelRow(['S1']),
      [
        '',
        'Human section row ignored by the app.',
        '',
        '',
        '',
        '',
        '',
        '',
        '',
        '',
        '',
      ],
      ['Squat', '3', '5', '8', '3 min', '', '', '', 'Legs', '', '225x5@8'],
    ];
    final activeSheet = parseActiveSheet(ActiveSheetInput(rows: rows));

    final loggingPlan = activeSheet.planSetLoggingWrite(
      historyBlockLabel: 'Session A',
      sheetRowNumber: 99,
      fieldValues: const {'Weight': '230', 'Reps': '5', 'RPE': '8'},
    );
    final editPlan = activeSheet.planSetEdit(
      historyBlockLabel: 'Session A',
      sheetRowNumber: 3,
      setNumber: 1,
      fieldValues: const {'Weight': '230', 'Reps': '5', 'RPE': '8'},
    );
    final clearPlan = activeSheet.planSetClear(
      historyBlockLabel: 'Session A',
      sheetRowNumber: 1,
      setNumber: 1,
    );

    expect(loggingPlan.cellUpdates, isEmpty);
    expect(loggingPlan.columnInsertions, isEmpty);
    expect(loggingPlan.nextSetPosition, isNull);
    expect(editPlan.cellUpdates, isEmpty);
    expect(clearPlan.cellUpdates, isEmpty);
  });

  test('plans raw edits for unparseable set cells', () {
    final rows = [
      historyHeaderRow(['Session A']),
      setLabelRow(['S1']),
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
        'worked up, knee felt odd',
      ],
    ];
    final activeSheet = parseActiveSheet(ActiveSheetInput(rows: rows));

    final plan = activeSheet.planRawSetEdit(
      historyBlockLabel: 'Session A',
      sheetRowNumber: 3,
      setNumber: 1,
      rawText: 'worked up, knee felt better',
    );

    expect(plan.cellUpdates, [
      CellUpdate(
        sheetRowNumber: 3,
        sheetColumnNumber: 11,
        value: 'worked up, knee felt better',
      ),
    ]);
  });

  test('plans canonical exercise edits as an in-place row update', () {
    final activeRows = [
      historyHeaderRow(['Session A']),
      setLabelRow(['S1']),
      [
        'Squat',
        '3',
        '5',
        '8',
        '3 min',
        '',
        '',
        '{Weight}[x]{Reps}[@]{RPE}',
        'Legs',
        '',
        '',
      ],
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
        '{Weight}[x]{Reps}[@]{RPE}',
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
        '{Weight}[x]{Reps}[@]{RPE}',
      ],
    ];
    final activeSheet = parseActiveSheet(
      ActiveSheetInput(
        rows: activeRows,
        cellFormulas: const [
          CellFormula(
            sheetRowNumber: 3,
            sheetColumnNumber: 1,
            formula: '=Exercises!A2',
          ),
          CellFormula(
            sheetRowNumber: 3,
            sheetColumnNumber: 8,
            formula: '=Exercises!I2',
          ),
        ],
        exercisesRows: exercisesRows,
      ),
    );

    final plan = activeSheet.planCanonicalExerciseUpdate(
      selectedExercise: activeSheet.canonicalExercises.first,
      exercise: const CanonicalExerciseDefinition(
        exercise: 'High Bar Squat',
        description: 'High bar back squat',
        defaultSets: '3',
        defaultReps: '5',
        defaultRpe: '8',
        defaultRest: '3 min',
        logFormat: '{Weight}[x]{Reps}[@]{RPE}',
      ),
    );

    expect(plan.rowAppends, isEmpty);
    expect(plan.rowUpdates.single.sheetRowNumber, 2);
    expect(plan.previewRowsAfterApplying(exercisesRows), [
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
        '{Weight}[x]{Reps}[@]{RPE}',
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
        '{Weight}[x]{Reps}[@]{RPE}',
      ],
    ]);
  });
}
