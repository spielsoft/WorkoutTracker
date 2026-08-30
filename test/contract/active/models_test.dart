import 'package:flutter_test/flutter_test.dart';
import 'package:workout_tracker/contract.dart';

import 'helpers.dart';

void main() {
  test('builds logging context from the selected row-local contract', () {
    final sheet = parseActiveSheet(
      ActiveSheetInput(
        rows: [
          historyHeaderRow(['Week 1']),
          setLabelRow(['S1']),
          activeRow(
            'Squat',
            sets: '4',
            targets: 'x5@8',
            workout: 'Legs',
            history: const ['225x5@8'],
          ),
          activeRow(
            'Side Plank',
            sets: '2',
            tempo: 'hold',
            targets: '30@8',
            notes: 'Keep hips stacked.',
            logFormat: '{Seconds}@{RPE}',
            workout: 'Legs',
            isBackup: true,
            history: const ['30@8'],
          ),
        ],
      ),
    );

    final context = sheet.buildLoggingContext(
      primaryRow: 3,
      selectedRow: 4,
      blockLabel: 'Week 1',
    );
    expect(context.selectedChoice.exercise, 'Side Plank');
    expect(context.targets.sets, '2');
    expect(context.targets.tempo, 'hold');
    expect(context.targets.values, {'Seconds': '30', 'RPE': '8'});
    expect(context.notes, 'Keep hips stacked.');
    expect(context.selectedHistory.entries.single.rawValue, '30@8');
  });

  test('groups backups beneath their nearest primary in workout order', () {
    final sheet = parseActiveSheet(
      ActiveSheetInput(
        rows: [
          historyHeaderRow([]),
          setLabelRow([]),
          activeRow('Squat', workout: 'Legs'),
          activeRow('Leg Press', workout: 'Legs', isBackup: true),
          activeRow('Bench Press', workout: 'Upper'),
        ],
      ),
    );

    expect(sheet.selectableWorkouts, ['Legs', 'Upper']);
    final overview = sheet.buildWorkoutOverview(
      workout: 'Legs',
      blockLabel: '',
    );
    expect(overview.slots.single.exercise, 'Squat');
    expect(overview.slots.single.prescribedSets, '3');
    expect(overview.slots.single.backups.single.exercise, 'Leg Press');
  });

  test('binds each placement to the Exercises row its formula names', () {
    final sheet = _twinExerciseSheet(
      cellFormulas: [
        ..._exerciseBinding(sheetRowNumber: 3, exercisesRowNumber: 2),
        ..._exerciseBinding(sheetRowNumber: 4, exercisesRowNumber: 3),
      ],
    );

    final front = _timerContext(sheet, sheetRowNumber: 3);
    final side = _timerContext(sheet, sheetRowNumber: 4);

    expect(front.selectedChoice.canonicalRow, 2);
    expect(front.timerFields, ['Seconds']);
    expect(side.selectedChoice.canonicalRow, 3);
    expect(side.timerFields, [
      'Hold',
    ], reason: 'the twin name must not decide which row configures a timer');
    expect(
      sheet.healingIssues,
      isEmpty,
      reason: 'both formulas of each placement already name one row',
    );
  });

  test('an unreadable Exercises binding times nothing', () {
    for (final broken in const <(String, List<CellFormula>)>[
      ('no formula at all', []),
      (
        'a reference past the last Exercises row',
        [
          CellFormula(
            sheetRowNumber: 3,
            sheetColumnNumber: 1,
            formula: '=Exercises!A99',
          ),
        ],
      ),
      (
        'a reference to the header row',
        [
          CellFormula(
            sheetRowNumber: 3,
            sheetColumnNumber: 1,
            formula: '=Exercises!A1',
          ),
        ],
      ),
      (
        'a reference to another Exercises column',
        [
          CellFormula(
            sheetRowNumber: 3,
            sheetColumnNumber: 1,
            formula: '=Exercises!B2',
          ),
        ],
      ),
      (
        'a lookup rather than a direct reference',
        [
          CellFormula(
            sheetRowNumber: 3,
            sheetColumnNumber: 1,
            formula: '=VLOOKUP("Plank",Exercises!A:A,1,FALSE)',
          ),
        ],
      ),
    ]) {
      final (description, cellFormulas) = broken;
      final context = _timerContext(
        _twinExerciseSheet(cellFormulas: cellFormulas),
        sheetRowNumber: 3,
      );

      expect(context.selectedChoice.canonicalRow, isNull, reason: description);
      expect(
        context.timerFields,
        isEmpty,
        reason: 'a placement with $description guesses no timer configuration',
      );
    }
  });

  test('a placement bound to a blank Exercises row times nothing', () {
    final sheet = _twinExerciseSheet(
      cellFormulas: _exerciseBinding(sheetRowNumber: 3, exercisesRowNumber: 4),
      exercisesRows: [
        ..._twinExercisesRows,
        ['', '', '', '', '', '', '', '', "['Seconds']"],
      ],
    );

    final context = _timerContext(sheet, sheetRowNumber: 3);
    expect(context.selectedChoice.canonicalRow, isNull);
    expect(context.timerFields, isEmpty);
  });
}

/// Two canonical rows sharing one name, each timing a different field.
///
/// Duplicate names are permitted, so only the direct formula distinguishes
/// them. Row 2 is a front plank measured in `Seconds`; row 3 is a side plank
/// measured in `Hold`.
const _twinExercisesRows = [
  exercisesSheetColumns,
  [
    'Plank',
    'Front plank hold',
    '3',
    '45s',
    '',
    '',
    '{Seconds}s@{RPE}',
    '30s@8',
    "['Seconds']",
  ],
  [
    'Plank',
    'Side plank hold',
    '3',
    '45s',
    '',
    '',
    '{Hold}@{RPE}',
    '40@8',
    "['Hold']",
  ],
];

ParsedActiveSheet _twinExerciseSheet({
  Iterable<CellFormula> cellFormulas = const [],
  List<List<String>> exercisesRows = _twinExercisesRows,
}) {
  return parseActiveSheet(
    ActiveSheetInput(
      rows: [
        historyHeaderRow(['Week 1']),
        setLabelRow(['S1']),
        activeRow(
          'Plank',
          targets: '30s@8',
          logFormat: '{Seconds}s@{RPE}',
          workout: 'Core',
        ),
        activeRow(
          'Plank',
          targets: '40@8',
          logFormat: '{Hold}@{RPE}',
          workout: 'Core',
        ),
      ],
      exercisesRows: exercisesRows,
      cellFormulas: cellFormulas,
    ),
  );
}

ExerciseLoggingContext _timerContext(
  ParsedActiveSheet sheet, {
  required int sheetRowNumber,
}) {
  return sheet.buildLoggingContext(
    primaryRow: sheetRowNumber,
    selectedRow: sheetRowNumber,
    blockLabel: 'Week 1',
  );
}

List<CellFormula> _exerciseBinding({
  required int sheetRowNumber,
  required int exercisesRowNumber,
}) {
  return [
    CellFormula(
      sheetRowNumber: sheetRowNumber,
      sheetColumnNumber: 1,
      formula: '=Exercises!A$exercisesRowNumber',
    ),
    CellFormula(
      sheetRowNumber: sheetRowNumber,
      sheetColumnNumber: 7,
      formula: '=Exercises!G$exercisesRowNumber',
    ),
  ];
}
