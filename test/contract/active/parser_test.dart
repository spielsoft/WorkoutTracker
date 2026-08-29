import 'package:flutter_test/flutter_test.dart';
import 'package:workout_tracker/contract.dart';

import 'helpers.dart';

void main() {
  test('reads a schema 1.1 timed field into the canonical read model', () {
    final sheet = parseActiveSheet(
      ActiveSheetInput(
        rows: [historyHeaderRow([]), setLabelRow([])],
        exercisesRows: [
          exercisesSheetColumns,
          exerciseRow(
            'Side Plank',
            format: '{Seconds}s@{RPE}',
            defaultValues: const {'Seconds': '30', 'RPE': '8'},
            timerFields: "['Seconds']",
          ),
        ],
        validateWorkbook: true,
      ),
    );

    expect(sheet.schemaViolations, isEmpty);
    expect(sheet.canonicalExercises.single.timerFields, ['Seconds']);
  });

  test('requires Timer Fields after Default Values in schema 1.1', () {
    expect(exercisesSheetColumns, [
      'Exercise',
      'Description',
      'Default Sets',
      'Default Rest',
      'Default Tempo',
      'Notes',
      'Log Format',
      'Default Values',
      'Timer Fields',
    ]);
    expect(activeSheetFixedColumns, [
      'Exercise',
      'Sets',
      'Rest',
      'Tempo',
      'Targets',
      'Notes',
      'Log Format',
      'Workout',
      'is_backup',
      'is_exercise',
    ]);

    final missing = parseActiveSheet(
      ActiveSheetInput(
        rows: [historyHeaderRow([]), setLabelRow([])],
        exercisesRows: [
          exercisesSheetColumns.take(8).toList(),
          exerciseRow('Squat'),
        ],
        validateWorkbook: true,
      ),
    );

    expect(
      missing.schemaViolations.map((violation) => violation.message),
      contains('Exercises column 9 must be "Timer Fields".'),
    );
  });

  test('parses blank Timer Fields as an empty immutable collection', () {
    for (final cell in ['', '   ', '[]']) {
      final sheet = parseActiveSheet(
        ActiveSheetInput(
          rows: [historyHeaderRow([]), setLabelRow([])],
          exercisesRows: [
            exercisesSheetColumns,
            exerciseRow(
              'Side Plank',
              format: '{Seconds}s@{RPE}',
              timerFields: cell,
            ),
          ],
          validateWorkbook: true,
        ),
      );

      expect(sheet.schemaViolations, isEmpty, reason: cell);
      final timerFields = sheet.canonicalExercises.single.timerFields;
      expect(timerFields, isEmpty, reason: cell);
      expect(() => timerFields.add('Seconds'), throwsUnsupportedError);
    }
  });

  test('reads Timer Fields labels in Log Format declaration order', () {
    final sheet = parseActiveSheet(
      ActiveSheetInput(
        rows: [historyHeaderRow([]), setLabelRow([])],
        exercisesRows: [
          exercisesSheetColumns,
          exerciseRow(
            'DB Step-Up',
            format: '({Height (in)}, {Weight (lbs)})x{Reps}@{RPE}',
            timerFields: "['RPE', 'Height (in)']",
          ),
        ],
        validateWorkbook: true,
      ),
    );

    expect(sheet.schemaViolations, isEmpty);
    expect(sheet.canonicalExercises.single.timerFields, ['Height (in)', 'RPE']);
  });

  test('blocks malformed, duplicate, or undeclared Timer Fields', () {
    for (final cell in [
      'Seconds',
      "['Seconds'",
      "[Seconds]",
      "['Seconds', 'Seconds']",
      "['Hold']",
      "[' Seconds']",
    ]) {
      final sheet = parseActiveSheet(
        ActiveSheetInput(
          rows: [historyHeaderRow([]), setLabelRow([])],
          exercisesRows: [
            exercisesSheetColumns,
            exerciseRow(
              'Side Plank',
              format: '{Seconds}s@{RPE}',
              timerFields: cell,
            ),
          ],
          validateWorkbook: true,
        ),
      );

      expect(sheet.schemaViolations, isNotEmpty, reason: cell);
      expect(
        sheet.planCanonicalAppend(ExerciseDef(exercise: 'Squat')).rowAppends,
        isEmpty,
        reason: cell,
      );
    }
  });

  test('accepts schema 1.1, rejects 1.0, and still parses 0.9', () {
    String? versionMessage(String? version) {
      final sheet = parseActiveSheet(
        ActiveSheetInput(
          rows: [historyHeaderRow([]), setLabelRow([])],
          exercisesRows: [
            if (version == '1.1')
              exercisesSheetColumns
            else
              exercisesSheetColumns.take(8).toList(),
          ],
          validateWorkbook: true,
          schemaVersion: version,
        ),
      );
      return sheet.schemaViolations.isEmpty
          ? null
          : sheet.schemaViolations.single.message;
    }

    expect(versionMessage('1.1'), isNull);
    expect(versionMessage('0.9'), isNull);
    expect(
      versionMessage('1.0'),
      'Workbook schema version "1.0" is unsupported.',
    );
    expect(
      versionMessage(null),
      'Workbook schema version metadata is missing.',
    );
  });

  test('parses format-driven targets and preserves raw history', () {
    final sheet = parseActiveSheet(
      ActiveSheetInput(
        rows: [
          historyHeaderRow(['Week 1', '']),
          setLabelRow(['S1', 'S2']),
          activeRow(
            'Squat',
            targets: 'x5@8',
            workout: 'Legs',
            history: const ['225x5@8', 'notes from paper'],
          ),
          activeRow(
            'Side Plank',
            targets: '30@8',
            logFormat: '{Seconds}@{RPE}',
            workout: 'Core',
          ),
        ],
      ),
    );

    expect(sheet.schemaViolations, isEmpty);
    expect(sheet.slots.first.targetValues, {
      'Weight': '',
      'Reps': '5',
      'RPE': '8',
    });
    expect(sheet.slots.last.targetValues, {'Seconds': '30', 'RPE': '8'});
    final history = sheet
        .buildLoggingContext(
          primaryRow: 3,
          selectedRow: 3,
          blockLabel: 'Week 1',
        )
        .selectedHistory;
    expect(history.entries.first.logEntry, isA<FormattedLogEntry>());
    expect(history.entries.last.logEntry, isA<RawLogEntry>());
    expect(history.entries.last.rawValue, 'notes from paper');
  });

  test('rejects targets that do not match their row format', () {
    final sheet = parseActiveSheet(
      ActiveSheetInput(
        rows: [
          historyHeaderRow([]),
          setLabelRow([]),
          activeRow(
            'Side Plank',
            targets: 'not structured',
            logFormat: '{Seconds}@{RPE}',
          ),
        ],
      ),
    );

    expect(
      sheet.schemaViolations.map((violation) => violation.message),
      contains('Targets do not match Log Format.'),
    );
  });

  test('validates the exact Exercises contract and dynamic defaults', () {
    final valid = parseActiveSheet(
      ActiveSheetInput(
        rows: [historyHeaderRow([]), setLabelRow([])],
        exercisesRows: [
          exercisesSheetColumns,
          exerciseRow(
            'Squat',
            defaultValues: const {'Weight': '', 'Reps': '5', 'RPE': '8'},
          ),
        ],
        validateWorkbook: true,
      ),
    );
    expect(valid.schemaViolations, isEmpty);
    expect(valid.canonicalExercises.single.defaultValues['Weight'], '');
    expect(valid.canonicalExercises.single.defaultValues['Reps'], '5');

    final malformed = parseActiveSheet(
      ActiveSheetInput(
        rows: [historyHeaderRow([]), setLabelRow([])],
        exercisesRows: const [
          ['Exercise', 'Default Reps', 'Log Format'],
        ],
        validateWorkbook: true,
      ),
    );
    expect(malformed.schemaViolations, isNotEmpty);
  });
}

List<String> exerciseRow(
  String name, {
  String format = defaultExerciseLogFormat,
  Map<String, String> defaultValues = const {},
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
    parsed.renderValues(defaultValues),
    timerFields,
  ];
}
