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
}
