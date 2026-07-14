import 'package:flutter_test/flutter_test.dart';
import 'package:workout_tracker/contract.dart';

import 'helpers.dart';

void main() {
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
  ];
}
