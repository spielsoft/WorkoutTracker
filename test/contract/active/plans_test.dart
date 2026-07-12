import 'package:flutter_test/flutter_test.dart';
import 'package:workout_tracker/contract.dart';

import 'helpers.dart';

void main() {
  test('logs a structured set without changing existing raw history', () {
    final rows = [
      historyHeaderRow(['Week 1', '']),
      setLabelRow(['S1', 'S2']),
      activeRow(
        'Squat',
        targets: 'x5@8',
        history: const ['worked up, knee felt odd', ''],
      ),
    ];
    final sheet = parseActiveSheet(ActiveSheetInput(rows: rows));

    final plan = sheet.planSetLoggingWrite(
      blockLabel: 'Week 1',
      sheetRowNumber: 3,
      fieldValues: const {'Weight': '225', 'Reps': '5', 'RPE': '8'},
    );
    final preview = plan.previewRowsAfterApplying(rows);

    expect(plan.cellUpdates.single.value, '225x5@8');
    expect(preview[2].skip(activeSheetFixedColumns.length), [
      'worked up, knee felt odd',
      '225x5@8',
    ]);
  });

  test('copies editable dynamic targets when placing an exercise', () {
    final sheet = parseActiveSheet(
      ActiveSheetInput(
        rows: [historyHeaderRow([]), setLabelRow([])],
        exercisesRows: [
          exercisesSheetColumns,
          _exerciseRow(
            'Side Plank',
            format: '{Seconds}[@]{RPE}',
            values: const {'Seconds': '30', 'RPE': '8'},
          ),
        ],
      ),
    );
    final exercise = sheet.canonicalExercises.single;

    final plan = sheet.planPrimaryPlacement(
      exercise: exercise,
      workout: 'Core',
      metadata: const WorkoutPlacementMetadata(
        sets: '2',
        rest: '45s',
        tempo: 'hold',
        targetValues: {'Seconds': '45', 'RPE': '9'},
      ),
    );
    expect(
      plan.cellUpdates,
      containsAll([
        const CellUpdate(
          sheetRowNumber: 3,
          sheetColumnNumber: 4,
          value: 'hold',
        ),
        const CellUpdate(
          sheetRowNumber: 3,
          sheetColumnNumber: 5,
          value: '45@9',
        ),
        const CellUpdate(sheetRowNumber: 3, sheetColumnNumber: 10, value: 'x'),
      ]),
    );
  });

  test('rejects a set write when the row format changes after planning', () {
    final rows = [
      historyHeaderRow(['Week 1']),
      setLabelRow(['S1']),
      activeRow('Squat', targets: 'x5@8', history: const ['']),
    ];
    final sheet = parseActiveSheet(ActiveSheetInput(rows: rows));
    final plan = sheet.planSetLoggingWrite(
      blockLabel: 'Week 1',
      sheetRowNumber: 3,
      fieldValues: const {'Weight': '225', 'Reps': '5', 'RPE': '8'},
    );
    final changed = [
      ...rows.map((row) => [...row]),
    ];
    changed[2][6] = '{Reps}[@]{RPE}';
    changed[2][4] = '5@8';

    expect(
      plan.writeRejections(parseActiveSheet(ActiveSheetInput(rows: changed))),
      isNotEmpty,
    );
  });

  test('canonical exercise defaults round-trip through append planning', () {
    final sheet = parseActiveSheet(
      ActiveSheetInput(
        rows: [historyHeaderRow([]), setLabelRow([])],
        exercisesRows: const [exercisesSheetColumns],
      ),
    );
    final plan = sheet.planCanonicalAppend(
      ExerciseDef(
        exercise: 'Copenhagen Side Plank',
        defaultSets: '3',
        defaultRest: '45s',
        defaultTempo: 'hold',
        logFormat: '{Seconds}[@]{RPE}',
        defaultValues: const {'Seconds': '30', 'RPE': '8'},
      ),
    );
    final reread = parseActiveSheet(
      ActiveSheetInput(
        rows: [historyHeaderRow([]), setLabelRow([])],
        exercisesRows: plan.previewRowsAfterApplying(const [
          exercisesSheetColumns,
        ]),
      ),
    );

    expect(reread.schemaViolations, isEmpty);
    expect(reread.canonicalExercises.single.defaultValues, {
      'Seconds': '30',
      'RPE': '8',
    });
  });
}

List<String> _exerciseRow(
  String name, {
  String format = defaultExerciseLogFormat,
  Map<String, String> values = const {},
}) {
  final parsed = parseLogFormat(format) as ParsedLogFormat;
  return [
    name,
    '',
    '3',
    '2 min',
    '2-1-1',
    '',
    format,
    parsed.renderValues(values),
  ];
}
