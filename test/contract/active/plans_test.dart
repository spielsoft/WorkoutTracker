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
            format: '{Seconds}@{RPE}',
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
    changed[2][6] = '{Reps}@{RPE}';
    changed[2][4] = '5@8';

    expect(
      plan.writeRejections(parseActiveSheet(ActiveSheetInput(rows: changed))),
      isNotEmpty,
    );
  });

  test('canonical create and update write Timer Fields only', () {
    final activeRows = [
      historyHeaderRow(['Week 1']),
      setLabelRow(['S1']),
      activeRow(
        'Side Plank',
        targets: '30s@8',
        logFormat: '{Seconds}s@{RPE}',
        history: const ['25s@8'],
      ),
    ];
    final exercisesRows = [
      exercisesSheetColumns,
      _exerciseRow(
        'Side Plank',
        format: '{Seconds}s@{RPE}',
        values: const {'Seconds': '30', 'RPE': '8'},
      ),
    ];
    final sheet = parseActiveSheet(
      ActiveSheetInput(
        rows: activeRows,
        exercisesRows: exercisesRows,
        validateWorkbook: true,
      ),
    );
    final timed = ExerciseDef(
      exercise: 'Side Plank',
      defaultSets: '3',
      defaultRest: '45s',
      defaultTempo: 'hold',
      logFormat: '{Seconds}s@{RPE}',
      defaultValues: const {'Seconds': '30', 'RPE': '8'},
      timerFields: const ['RPE', 'Seconds'],
    );

    final created = sheet.planCanonicalAppend(timed).previewRowsAfterApplying([
      exercisesSheetColumns,
    ]);
    expect(created[1], hasLength(exercisesSheetColumns.length));
    expect(created[1].last, "['Seconds', 'RPE']");

    final update = sheet.planCanonicalUpdate(
      selectedExercise: sheet.canonicalExercises.single,
      exercise: timed,
    );
    final updatedRows = update.previewRowsAfterApplying(exercisesRows);
    final reread = parseActiveSheet(
      ActiveSheetInput(
        rows: activeRows,
        exercisesRows: updatedRows,
        validateWorkbook: true,
      ),
    );

    expect(reread.schemaViolations, isEmpty);
    expect(reread.canonicalExercises.single.timerFields, ['Seconds', 'RPE']);
    expect(update.formulaUpdates, isEmpty);
    expect(
      sheet.inspectFormatUpdate(
        selectedExercise: sheet.canonicalExercises.single,
        exercise: timed,
      ),
      isNull,
    );
    expect(reread.slots.single.targetValues, {'Seconds': '30', 'RPE': '8'});
    expect(
      reread
          .buildLoggingContext(
            primaryRow: 3,
            selectedRow: 3,
            blockLabel: 'Week 1',
          )
          .selectedHistory
          .entries
          .single
          .rawValue,
      '25s@8',
    );
  });

  test('drops Timer Fields labels the Log Format no longer declares', () {
    final sheet = parseActiveSheet(
      ActiveSheetInput(
        rows: [historyHeaderRow([]), setLabelRow([])],
        exercisesRows: const [exercisesSheetColumns],
        validateWorkbook: true,
      ),
    );

    final rows = sheet
        .planCanonicalAppend(
          ExerciseDef(
            exercise: 'Side Plank',
            logFormat: '{Reps}@{RPE}',
            timerFields: const ['Seconds', 'RPE'],
          ),
        )
        .previewRowsAfterApplying([exercisesSheetColumns]);

    expect(rows[1].last, "['RPE']");
    expect(
      parseActiveSheet(
        ActiveSheetInput(
          rows: [historyHeaderRow([]), setLabelRow([])],
          exercisesRows: rows,
          validateWorkbook: true,
        ),
      ).schemaViolations,
      isEmpty,
    );
  });

  test('every awkward Log Format label round-trips through Timer Fields', () {
    const awkwardLabels = [
      'Seconds',
      "Athlete's Hold",
      r'Back\Slash',
      r"It\'s Timed",
      'Hold, Seconds',
      'Hold [left]',
      ' Padded Hold ',
      'Sekundenhalt ⏱ é',
      '保持 🏋 秒',
    ];

    for (final label in awkwardLabels) {
      final format = '{$label}s@{RPE}';
      final sheet = parseActiveSheet(
        ActiveSheetInput(
          rows: [historyHeaderRow([]), setLabelRow([])],
          exercisesRows: const [exercisesSheetColumns],
          validateWorkbook: true,
        ),
      );
      final written = sheet
          .planCanonicalAppend(
            ExerciseDef(
              exercise: 'Timed Hold',
              logFormat: format,
              timerFields: [label, 'RPE'],
            ),
          )
          .previewRowsAfterApplying([exercisesSheetColumns]);
      final reread = parseActiveSheet(
        ActiveSheetInput(
          rows: [historyHeaderRow([]), setLabelRow([])],
          exercisesRows: written,
          validateWorkbook: true,
        ),
      );

      expect(reread.schemaViolations, isEmpty, reason: label);
      expect(reread.canonicalExercises.single.timerFields, [
        label,
        'RPE',
      ], reason: label);
    }
  });

  test('an ordinary label still renders as a plain quoted list', () {
    final sheet = parseActiveSheet(
      ActiveSheetInput(
        rows: [historyHeaderRow([]), setLabelRow([])],
        exercisesRows: const [exercisesSheetColumns],
        validateWorkbook: true,
      ),
    );

    final written = sheet
        .planCanonicalAppend(
          ExerciseDef(
            exercise: 'Side Plank',
            logFormat: '{Seconds}s@{RPE}',
            timerFields: const ['Seconds'],
          ),
        )
        .previewRowsAfterApplying([exercisesSheetColumns]);

    expect(written[1].last, "['Seconds']");
  });

  test('an apostrophe label survives canonical create, update, and reread', () {
    const label = "Athlete's Hold";
    const format = "{Athlete's Hold}s@{RPE}";
    final activeRows = [
      historyHeaderRow(['Week 1']),
      setLabelRow(['S1']),
      activeRow(
        'Wall Sit',
        targets: '30s@8',
        logFormat: format,
        history: const ['25s@8'],
      ),
    ];
    final exercisesRows = [
      exercisesSheetColumns,
      _exerciseRow(
        'Wall Sit',
        format: format,
        values: const {label: '30', 'RPE': '8'},
      ),
    ];
    final sheet = parseActiveSheet(
      ActiveSheetInput(
        rows: activeRows,
        exercisesRows: exercisesRows,
        validateWorkbook: true,
      ),
    );
    expect(sheet.schemaViolations, isEmpty);

    final timed = ExerciseDef(
      exercise: 'Wall Sit',
      defaultSets: '3',
      defaultRest: '45s',
      defaultTempo: 'hold',
      logFormat: format,
      defaultValues: const {label: '30', 'RPE': '8'},
      timerFields: const [label],
    );

    final created = sheet.planCanonicalAppend(timed).previewRowsAfterApplying([
      exercisesSheetColumns,
    ]);
    expect(created[1].last, r"['Athlete\'s Hold']");

    final createdReread = parseActiveSheet(
      ActiveSheetInput(
        rows: [historyHeaderRow([]), setLabelRow([])],
        exercisesRows: created,
        validateWorkbook: true,
      ),
    );
    expect(createdReread.schemaViolations, isEmpty);
    expect(createdReread.canonicalExercises.single.timerFields, [label]);

    final update = sheet.planCanonicalUpdate(
      selectedExercise: sheet.canonicalExercises.single,
      exercise: timed,
    );
    final updatedReread = parseActiveSheet(
      ActiveSheetInput(
        rows: activeRows,
        exercisesRows: update.previewRowsAfterApplying(exercisesRows),
        validateWorkbook: true,
      ),
    );

    expect(updatedReread.schemaViolations, isEmpty);
    expect(updatedReread.canonicalExercises.single.timerFields, [label]);
    expect(updatedReread.slots.single.targetValues, {label: '30', 'RPE': '8'});
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
        logFormat: '{Seconds}@{RPE}',
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
  String timerFields = '',
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
    timerFields,
  ];
}
