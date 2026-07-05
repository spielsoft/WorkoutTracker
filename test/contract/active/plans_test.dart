import 'package:flutter_test/flutter_test.dart';
import 'package:workout_tracker/contract.dart';

import 'helpers.dart';

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

      var primaryContext = activeSheet.buildLoggingContext(
        primarySheetRowNumber: 3,
        selectedSheetRowNumber: 3,
        historyBlockLabel: 'Session A',
      );
      var backupContext = activeSheet.buildLoggingContext(
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

      primaryContext = activeSheet.buildLoggingContext(
        primarySheetRowNumber: 3,
        selectedSheetRowNumber: 3,
        historyBlockLabel: 'Session A',
      );
      backupContext = activeSheet.buildLoggingContext(
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

  test('rejects new set saves if the row log format changed', () {
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

  test('rejects structured set edits if the row log format changed', () {
    final rows = [
      historyHeaderRow(['Session A']),
      setLabelRow(['S1']),
      ['Squat', '3', '5', '8', '3 min', '', '', '', 'Legs', '', '225x5@8'],
    ];
    final activeSheet = parseActiveSheet(ActiveSheetInput(rows: rows));

    final plan = activeSheet.planSetEdit(
      historyBlockLabel: 'Session A',
      sheetRowNumber: 3,
      setNumber: 1,
      fieldValues: const {'Weight': '230', 'Reps': '5', 'RPE': '8'},
    );

    final changedRows = rows.map((row) => [...row]).toList();
    changedRows[2][7] = '{Reps}[@]{RPE}';
    final changedSheet = parseActiveSheet(ActiveSheetInput(rows: changedRows));

    expect(plan.writeRejections(changedSheet), [
      const WriteRejection(
        'Cell row 3 column 8 no longer matches the visible value.',
      ),
    ]);
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

  test('rejects set clears if the row log format changed', () {
    final rows = [
      historyHeaderRow(['Session A']),
      setLabelRow(['S1']),
      ['Squat', '3', '5', '8', '3 min', '', '', '', 'Legs', '', '225x5@8'],
    ];
    final activeSheet = parseActiveSheet(ActiveSheetInput(rows: rows));

    final plan = activeSheet.planSetClear(
      historyBlockLabel: 'Session A',
      sheetRowNumber: 3,
      setNumber: 1,
    );

    final changedRows = rows.map((row) => [...row]).toList();
    changedRows[2][7] = '{Reps}[@]{RPE}';
    final changedSheet = parseActiveSheet(ActiveSheetInput(rows: changedRows));

    expect(plan.writeRejections(changedSheet), [
      const WriteRejection(
        'Cell row 3 column 8 no longer matches the visible value.',
      ),
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

  test('rejects logging with history growth when insertion point is stale', () {
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

    final changedRows = rows.map((row) => [...row]).toList();
    changedRows[0].add('Session B');
    changedRows[1].add('S1');
    changedRows[2].add('');
    final changedSheet = parseActiveSheet(ActiveSheetInput(rows: changedRows));

    expect(plan.writeRejections(changedSheet), [
      const WriteRejection(
        'History insertion point at column 12 no longer matches '
        'the visible sheet.',
      ),
    ]);
  });

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

  test('rejects raw set edits if the row log format changed', () {
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

    final changedRows = rows.map((row) => [...row]).toList();
    changedRows[2][7] = '{Note}';
    final changedSheet = parseActiveSheet(ActiveSheetInput(rows: changedRows));

    expect(plan.writeRejections(changedSheet), [
      const WriteRejection(
        'Cell row 3 column 8 no longer matches the visible value.',
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

    final plan = activeSheet.planCanonicalUpdate(
      selectedExercise: activeSheet.canonicalExercises.first,
      exercise: const ExerciseDef(
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

  test(
    'plans workout exercise reorder as metadata-preserving primary group moves',
    () {
      final rows = [
        historyHeaderRow(['Session A', '']),
        setLabelRow(['S1', 'S2']),
        [
          'Squat',
          '3',
          '5',
          '8',
          '3 min',
          'controlled',
          'primary notes',
          defaultExerciseLogFormat,
          'Legs',
          '',
          '225x5@8',
          '',
        ],
        [
          'Leg Press',
          '3',
          '12',
          '8',
          '2 min',
          '',
          'backup notes',
          '{Reps}[@]{RPE}',
          'Legs',
          'TRUE',
          '12@8',
          '',
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
          '',
        ],
        [
          'Chest Press',
          '3',
          '10',
          '8',
          '2 min',
          '',
          'upper backup',
          '{Reps}[@]{RPE}',
          'Upper',
          'TRUE',
          '10@8',
          '',
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
          '55x10@8',
        ],
      ];
      final activeSheet = parseActiveSheet(ActiveSheetInput(rows: rows));

      final plan = activeSheet.planExerciseReorder(
        workout: 'Legs',
        intent: const ReorderIntent(fromIndex: 0, toIndex: 1),
      );
      final previewRows = plan.previewRowsAfterApplying(rows);
      final reordered = parseActiveSheet(ActiveSheetInput(rows: previewRows));
      final overview = reordered.buildWorkoutOverview(
        workout: 'Legs',
        historyBlockLabel: 'Session A',
      );

      expect(overview.slots.map((slot) => slot.exercise), ['Lunge', 'Squat']);
      expect(overview.slots[1].backups.map((backup) => backup.exercise), [
        'Leg Press',
      ]);
      expect(reordered.primarySlots.map((slot) => slot.exercise), [
        'Lunge',
        'Bench Press',
        'Squat',
      ]);
      expect(
        reordered.primarySlots[1].backups.map((backup) => backup.exercise),
        ['Chest Press'],
      );

      final movedPrimary = reordered.buildLoggingContext(
        primarySheetRowNumber: 6,
        selectedSheetRowNumber: 6,
        historyBlockLabel: 'Session A',
      );
      final movedBackup = reordered.buildLoggingContext(
        primarySheetRowNumber: 6,
        selectedSheetRowNumber: 7,
        historyBlockLabel: 'Session A',
      );

      expect(movedPrimary.targets.sets, '3');
      expect(movedPrimary.targets.reps, '5');
      expect(movedPrimary.rest, '3 min');
      expect(movedPrimary.notes, 'primary notes');
      expect(movedPrimary.selectedHistory.entries.first.rawValue, '225x5@8');
      expect(movedBackup.targets.reps, '12');
      expect(movedBackup.rest, '2 min');
      expect(movedBackup.notes, 'backup notes');
      expect(movedBackup.selectedHistory.entries.first.rawValue, '12@8');
    },
  );

  test('rejects workout exercise reorder when source rows are stale', () {
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
        'primary notes',
        defaultExerciseLogFormat,
        'Legs',
        '',
        '225x5@8',
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
    final activeSheet = parseActiveSheet(ActiveSheetInput(rows: rows));

    final plan = activeSheet.planExerciseReorder(
      workout: 'Legs',
      intent: const ReorderIntent(fromIndex: 0, toIndex: 1),
    );
    final changedRows = rows.map((row) => [...row]).toList();
    changedRows[2][6] = 'manual sheet edit';
    final changedSheet = parseActiveSheet(ActiveSheetInput(rows: changedRows));

    expect(plan.writeRejections(changedSheet), [
      const WriteRejection(
        'Active sheet row 3 no longer matches the planned reorder.',
      ),
    ]);
  });

  test('preserves active-sheet formulas when reordering workout exercises', () {
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
        defaultExerciseLogFormat,
        'Legs',
        '',
        '',
      ],
      [
        'Lunge',
        '2',
        '10',
        '7',
        '90s',
        '',
        '',
        defaultExerciseLogFormat,
        'Legs',
        '',
        '',
      ],
    ];
    final activeSheet = parseActiveSheet(
      ActiveSheetInput(
        rows: rows,
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
          CellFormula(
            sheetRowNumber: 4,
            sheetColumnNumber: 1,
            formula: '=Exercises!A3',
          ),
          CellFormula(
            sheetRowNumber: 4,
            sheetColumnNumber: 8,
            formula: '=Exercises!I3',
          ),
        ],
      ),
    );

    final plan = activeSheet.planExerciseReorder(
      workout: 'Legs',
      intent: const ReorderIntent(fromIndex: 0, toIndex: 1),
    );

    expect(
      plan.cellUpdates.where(
        (update) => update.valueKind == CellUpdateValueKind.formula,
      ),
      [
        CellUpdate.formula(
          sheetRowNumber: 3,
          sheetColumnNumber: 1,
          value: '=Exercises!A3',
        ),
        CellUpdate.formula(
          sheetRowNumber: 3,
          sheetColumnNumber: 8,
          value: '=Exercises!I3',
        ),
        CellUpdate.formula(
          sheetRowNumber: 4,
          sheetColumnNumber: 1,
          value: '=Exercises!A2',
        ),
        CellUpdate.formula(
          sheetRowNumber: 4,
          sheetColumnNumber: 8,
          value: '=Exercises!I2',
        ),
      ],
    );
  });

  test('rejects workout exercise reorder when active formulas are stale', () {
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
        defaultExerciseLogFormat,
        'Legs',
        '',
        '',
      ],
      [
        'Lunge',
        '2',
        '10',
        '7',
        '90s',
        '',
        '',
        defaultExerciseLogFormat,
        'Legs',
        '',
        '',
      ],
    ];
    final activeSheet = parseActiveSheet(
      ActiveSheetInput(
        rows: rows,
        cellFormulas: const [
          CellFormula(
            sheetRowNumber: 3,
            sheetColumnNumber: 1,
            formula: '=Exercises!A2',
          ),
          CellFormula(
            sheetRowNumber: 4,
            sheetColumnNumber: 1,
            formula: '=Exercises!A3',
          ),
        ],
      ),
    );

    final plan = activeSheet.planExerciseReorder(
      workout: 'Legs',
      intent: const ReorderIntent(fromIndex: 0, toIndex: 1),
    );
    final changedSheet = parseActiveSheet(
      ActiveSheetInput(
        rows: rows,
        cellFormulas: const [
          CellFormula(
            sheetRowNumber: 3,
            sheetColumnNumber: 1,
            formula: '=Exercises!A4',
          ),
          CellFormula(
            sheetRowNumber: 4,
            sheetColumnNumber: 1,
            formula: '=Exercises!A3',
          ),
        ],
      ),
    );

    expect(plan.writeRejections(changedSheet), [
      const WriteRejection(
        'Formula row 3 column 1 no longer matches the planned reorder.',
      ),
    ]);
  });

  test('plans deleting a primary workout exercise with no backups', () {
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
        defaultExerciseLogFormat,
        'Legs',
        '',
        '225x5@8',
      ],
      [
        'Lunge',
        '2',
        '10',
        '7',
        '90s',
        '',
        '',
        defaultExerciseLogFormat,
        'Legs',
        '',
        '50x10@7',
      ],
    ];
    final activeSheet = parseActiveSheet(ActiveSheetInput(rows: rows));

    final plan = activeSheet.planDeletePrimary(primarySheetRowNumber: 3);

    expect(plan.rowDeletions, const [
      RowDeletion(sheetRowNumber: 3, rowCount: 1),
    ]);
    expect(plan.previewRowsAfterApplying(rows), [rows[0], rows[1], rows[3]]);
  });

  test(
    'plans deleting a primary workout exercise with one attached backup',
    () {
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
          'primary notes',
          defaultExerciseLogFormat,
          'Legs',
          '',
          '225x5@8',
          '',
        ],
        [
          'Leg Press',
          '3',
          '12',
          '8',
          '2 min',
          '',
          'backup notes',
          '{Reps}[@]{RPE}',
          'Legs',
          'TRUE',
          '12@8',
          '',
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
          '',
        ],
      ];
      final activeSheet = parseActiveSheet(ActiveSheetInput(rows: rows));

      final plan = activeSheet.planDeletePrimary(primarySheetRowNumber: 3);

      expect(plan.rowDeletions, const [
        RowDeletion(sheetRowNumber: 3, rowCount: 2),
      ]);
      expect(plan.previewRowsAfterApplying(rows), [rows[0], rows[1], rows[4]]);
    },
  );

  test('plans deleting a primary and backup around ignored human rows', () {
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
        'primary notes',
        defaultExerciseLogFormat,
        'Legs',
        '',
        '225x5@8',
        '',
      ],
      [
        '',
        '',
        '',
        '',
        '',
        '',
        'Coach note between primary and backup',
        '',
        '',
        '',
        '',
        '',
      ],
      [
        'Leg Press',
        '3',
        '12',
        '8',
        '2 min',
        '',
        'backup notes',
        '{Reps}[@]{RPE}',
        'Legs',
        'TRUE',
        '12@8',
        '',
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
        '',
      ],
    ];
    final activeSheet = parseActiveSheet(ActiveSheetInput(rows: rows));

    final plan = activeSheet.planDeletePrimary(primarySheetRowNumber: 3);

    expect(plan.rowDeletions, const [
      RowDeletion(sheetRowNumber: 3, rowCount: 1),
      RowDeletion(sheetRowNumber: 5, rowCount: 1),
    ]);
    expect(plan.previewRowsAfterApplying(rows), [
      rows[0],
      rows[1],
      rows[3],
      rows[5],
    ]);
  });

  test('plans deleting a primary workout exercise with multiple backups', () {
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
        'primary notes',
        defaultExerciseLogFormat,
        'Legs',
        '',
        '225x5@8',
        '',
      ],
      [
        'Leg Press',
        '3',
        '12',
        '8',
        '2 min',
        '',
        'backup notes',
        '{Reps}[@]{RPE}',
        'Legs',
        'TRUE',
        '12@8',
        '',
      ],
      [
        'Hack Squat',
        '3',
        '10',
        '8',
        '2 min',
        '',
        'second backup',
        '{Reps}[@]{RPE}',
        'Legs',
        'TRUE',
        '10@8',
        '',
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
        '',
      ],
      [
        'Chest Press',
        '3',
        '10',
        '8',
        '2 min',
        '',
        'upper backup',
        '{Reps}[@]{RPE}',
        'Upper',
        'TRUE',
        '10@8',
        '',
      ],
    ];
    final activeSheet = parseActiveSheet(ActiveSheetInput(rows: rows));

    final plan = activeSheet.planDeletePrimary(primarySheetRowNumber: 3);
    final previewRows = plan.previewRowsAfterApplying(rows);
    final previewSheet = parseActiveSheet(ActiveSheetInput(rows: previewRows));

    expect(plan.rowDeletions, const [
      RowDeletion(sheetRowNumber: 3, rowCount: 3),
    ]);
    expect(previewRows, [rows[0], rows[1], rows[5], rows[6]]);
    expect(previewSheet.primarySlots.map((slot) => slot.exercise), [
      'Bench Press',
    ]);
    expect(
      previewSheet.primarySlots.single.backups.map((slot) => slot.exercise),
      ['Chest Press'],
    );
  });

  test(
    'rejects deleting a primary workout exercise when backup group changed',
    () {
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
          '',
          '{Reps}[@]{RPE}',
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
          '',
          defaultExerciseLogFormat,
          'Legs',
          '',
          '50x10@7',
        ],
      ];
      final activeSheet = parseActiveSheet(ActiveSheetInput(rows: rows));
      final plan = activeSheet.planDeletePrimary(primarySheetRowNumber: 3);
      final changedRows = rows.map((row) => [...row]).toList();
      changedRows.insert(4, [
        'Hack Squat',
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
      ]);
      final changedSheet = parseActiveSheet(
        ActiveSheetInput(rows: changedRows),
      );

      expect(plan.writeRejections(changedSheet), [
        const WriteRejection(
          'Backup group for row 3 no longer matches the planned delete.',
        ),
      ]);
    },
  );

  test(
    'rejects deleting a primary workout exercise when primary row changed',
    () {
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
          defaultExerciseLogFormat,
          'Legs',
          '',
          '225x5@8',
        ],
      ];
      final activeSheet = parseActiveSheet(ActiveSheetInput(rows: rows));
      final plan = activeSheet.planDeletePrimary(primarySheetRowNumber: 3);

      for (final mutation in [
        (List<List<String>> changedRows) => changedRows[2][0] = 'Front Squat',
        (List<List<String>> changedRows) => changedRows[2][8] = 'Upper',
        (List<List<String>> changedRows) => changedRows[2][9] = 'TRUE',
      ]) {
        final changedRows = rows.map((row) => [...row]).toList();
        mutation(changedRows);
        final changedSheet = parseActiveSheet(
          ActiveSheetInput(rows: changedRows),
        );

        expect(plan.writeRejections(changedSheet), [
          const WriteRejection(
            'Row 3 no longer matches Squat in workout Legs.',
          ),
        ]);
      }
    },
  );

  test(
    'plans canonical exercise reorder as metadata-preserving row updates with formula repairs',
    () {
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
        [
          'Bench Press',
          '4',
          '6',
          '8',
          '3 min',
          '',
          '',
          '{Weight}[x]{Reps}[@]{RPE}',
          'Upper',
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
          'Use belt',
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
          'Pause reps',
          '{Weight}[x]{Reps}[@]{RPE}',
        ],
        [
          'Cable Row',
          'Seated cable row',
          '3',
          '12',
          '8',
          '90s',
          '',
          'Neutral grip',
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
            CellFormula(
              sheetRowNumber: 4,
              sheetColumnNumber: 1,
              formula: '=Exercises!A3',
            ),
            CellFormula(
              sheetRowNumber: 4,
              sheetColumnNumber: 8,
              formula: '=Exercises!I3',
            ),
          ],
          exercisesRows: exercisesRows,
        ),
      );

      final plan = activeSheet.planCanonicalReorder(
        ReorderIntent(fromIndex: 0, toIndex: 2),
      );

      expect(plan.rowAppends, isEmpty);
      expect(plan.rowUpdates.map((update) => update.sheetRowNumber), [2, 3, 4]);
      expect(plan.previewRowsAfterApplying(exercisesRows), [
        exercisesSheetColumns,
        [
          'Bench Press',
          'Competition bench',
          '4',
          '6',
          '8',
          '3 min',
          '',
          'Pause reps',
          '{Weight}[x]{Reps}[@]{RPE}',
        ],
        [
          'Cable Row',
          'Seated cable row',
          '3',
          '12',
          '8',
          '90s',
          '',
          'Neutral grip',
          '{Weight}[x]{Reps}[@]{RPE}',
        ],
        [
          'Squat',
          'Back squat',
          '3',
          '5',
          '8',
          '3 min',
          '',
          'Use belt',
          '{Weight}[x]{Reps}[@]{RPE}',
        ],
      ]);
      expect(plan.formulaUpdates, [
        CellUpdate.formula(
          sheetRowNumber: 3,
          sheetColumnNumber: 1,
          value: '=Exercises!A4',
        ),
        CellUpdate.formula(
          sheetRowNumber: 3,
          sheetColumnNumber: 8,
          value: '=Exercises!I4',
        ),
        CellUpdate.formula(
          sheetRowNumber: 4,
          sheetColumnNumber: 1,
          value: '=Exercises!A2',
        ),
        CellUpdate.formula(
          sheetRowNumber: 4,
          sheetColumnNumber: 8,
          value: '=Exercises!I2',
        ),
      ]);
    },
  );

  test('does not plan canonical exercise reorder writes for no-op moves', () {
    final activeSheet = parseActiveSheet(
      ActiveSheetInput(
        rows: [
          historyHeaderRow(['Session A']),
          setLabelRow(['S1']),
        ],
        exercisesRows: [
          exercisesSheetColumns,
          _canonicalExerciseRow('Squat'),
          _canonicalExerciseRow('Bench Press'),
        ],
      ),
    );

    final samePosition = activeSheet.planCanonicalReorder(
      const ReorderIntent(fromIndex: 1, toIndex: 1),
    );
    final outOfRange = activeSheet.planCanonicalReorder(
      const ReorderIntent(fromIndex: 2, toIndex: 0),
    );

    expect(samePosition.rowUpdates, isEmpty);
    expect(samePosition.formulaUpdates, isEmpty);
    expect(samePosition.expectations, isEmpty);
    expect(outOfRange.rowUpdates, isEmpty);
    expect(outOfRange.formulaUpdates, isEmpty);
    expect(outOfRange.expectations, isEmpty);
  });

  test('plans canonical exercise boundary moves', () {
    final exercisesRows = [
      exercisesSheetColumns,
      _canonicalExerciseRow('Squat'),
      _canonicalExerciseRow('Bench Press'),
      _canonicalExerciseRow('Cable Row'),
    ];
    final activeSheet = parseActiveSheet(
      ActiveSheetInput(
        rows: [
          historyHeaderRow(['Session A']),
          setLabelRow(['S1']),
        ],
        exercisesRows: exercisesRows,
      ),
    );

    final plan = activeSheet.planCanonicalReorder(
      const ReorderIntent(fromIndex: 2, toIndex: 0),
    );

    expect(plan.previewRowsAfterApplying(exercisesRows), [
      exercisesSheetColumns,
      _canonicalExerciseRow('Cable Row'),
      _canonicalExerciseRow('Squat'),
      _canonicalExerciseRow('Bench Press'),
    ]);
  });

  test('rejects canonical exercise reorder when source rows are stale', () {
    final exercisesRows = [
      exercisesSheetColumns,
      _canonicalExerciseRow('Squat'),
      _canonicalExerciseRow('Bench Press'),
      _canonicalExerciseRow('Cable Row'),
    ];
    final activeSheet = parseActiveSheet(
      ActiveSheetInput(
        rows: [
          historyHeaderRow(['Session A']),
          setLabelRow(['S1']),
        ],
        exercisesRows: exercisesRows,
      ),
    );
    final plan = activeSheet.planCanonicalReorder(
      const ReorderIntent(fromIndex: 0, toIndex: 2),
    );
    final changedSheet = parseActiveSheet(
      ActiveSheetInput(
        rows: [
          historyHeaderRow(['Session A']),
          setLabelRow(['S1']),
        ],
        exercisesRows: [
          exercisesSheetColumns,
          _canonicalExerciseRow('Squat', notes: 'Manual sheet edit'),
          _canonicalExerciseRow('Bench Press'),
          _canonicalExerciseRow('Cable Row'),
        ],
      ),
    );

    expect(plan.writeRejections(changedSheet), [
      const WriteRejection(
        'Exercises row 2 no longer matches the planned reorder.',
      ),
    ]);
  });

  test('rejects canonical exercise reorder when active formulas are stale', () {
    final exercisesRows = [
      exercisesSheetColumns,
      _canonicalExerciseRow('Squat'),
      _canonicalExerciseRow('Bench Press'),
      _canonicalExerciseRow('Cable Row'),
    ];
    final activeSheet = parseActiveSheet(
      ActiveSheetInput(
        rows: [
          historyHeaderRow(['Session A']),
          setLabelRow(['S1']),
          [
            'Squat',
            '3',
            '10',
            '8',
            '2 min',
            '',
            '',
            defaultExerciseLogFormat,
            'Legs',
            '',
            '',
          ],
        ],
        cellFormulas: const [
          CellFormula(
            sheetRowNumber: 3,
            sheetColumnNumber: 1,
            formula: '=Exercises!A2',
          ),
        ],
        exercisesRows: exercisesRows,
      ),
    );
    final plan = activeSheet.planCanonicalReorder(
      const ReorderIntent(fromIndex: 0, toIndex: 2),
    );
    final changedSheet = parseActiveSheet(
      ActiveSheetInput(
        rows: [
          historyHeaderRow(['Session A']),
          setLabelRow(['S1']),
          [
            'Squat',
            '3',
            '10',
            '8',
            '2 min',
            '',
            '',
            defaultExerciseLogFormat,
            'Legs',
            '',
            '',
          ],
        ],
        cellFormulas: const [
          CellFormula(
            sheetRowNumber: 3,
            sheetColumnNumber: 1,
            formula: '=Exercises!A3',
          ),
        ],
        exercisesRows: exercisesRows,
      ),
    );

    expect(plan.writeRejections(changedSheet), [
      const WriteRejection(
        'Formula row 3 column 1 no longer matches the planned reorder.',
      ),
    ]);
  });
}

List<String> _canonicalExerciseRow(
  String exercise, {
  String description = '',
  String defaultSets = '3',
  String defaultReps = '10',
  String defaultRpe = '8',
  String defaultRest = '2 min',
  String defaultTempo = '',
  String notes = '',
  String logFormat = defaultExerciseLogFormat,
}) {
  return [
    exercise,
    description,
    defaultSets,
    defaultReps,
    defaultRpe,
    defaultRest,
    defaultTempo,
    notes,
    logFormat,
  ];
}
