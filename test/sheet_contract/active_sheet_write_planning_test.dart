import 'package:flutter_test/flutter_test.dart';
import 'package:workout_tracker/set_notation.dart';
import 'package:workout_tracker/sheet_contract.dart';

import 'active_sheet_test_helpers.dart';

void main() {
  test('plans logging a new set and advances to the next position', () {
    final activeSheet = parseFixtureActiveSheet();

    final plan = activeSheet.planSetLoggingWrite(
      historyBlockLabel: 'Week 2',
      sheetRowNumber: 3,
      set: LoggedSet(
        result: WeightedReps(weight: '75', reps: '8'),
        rpe: '8',
      ),
    );

    expect(plan.cellUpdates, [
      CellUpdate(sheetRowNumber: 3, sheetColumnNumber: 11, value: '75x8@8'),
    ]);
    expect(
      plan.nextSetPosition,
      SetPosition(sheetRowNumber: 3, setNumber: 2, sheetColumnNumber: 12),
    );
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
        '',
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
      set: LoggedSet(
        result: WeightedReps(weight: '230', reps: '5'),
        rpe: '8',
      ),
    );
    final backupPlan = activeSheet.planSetLoggingWrite(
      historyBlockLabel: 'Session A',
      sheetRowNumber: 4,
      set: LoggedSet(
        result: WeightedReps(weight: '360', reps: '10'),
        rpe: '8',
      ),
    );

    expect(primaryPlan.cellUpdates, [
      CellUpdate(sheetRowNumber: 3, sheetColumnNumber: 12, value: '230x5@8'),
    ]);
    expect(backupPlan.cellUpdates, [
      CellUpdate(sheetRowNumber: 4, sheetColumnNumber: 11, value: '360x10@8'),
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
      set: LoggedSet(
        result: WeightedReps(weight: '160', reps: '6'),
        rpe: '8',
      ),
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
        set: LoggedSet(
          result: WeightedReps(weight: '230', reps: '5'),
          rpe: '8',
        ),
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
      set: LoggedSet(
        result: WeightedReps(weight: '225', reps: '5'),
        rpe: '8',
      ),
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
      set: LoggedSet(
        result: WeightedReps(weight: '230', reps: '5'),
        rpe: '8',
      ),
    );
    final editPlan = activeSheet.planSetEdit(
      historyBlockLabel: 'Session A',
      sheetRowNumber: 3,
      setNumber: 1,
      set: LoggedSet(
        result: WeightedReps(weight: '230', reps: '5'),
        rpe: '8',
      ),
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
}
