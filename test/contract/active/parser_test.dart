import 'package:flutter_test/flutter_test.dart';
import 'package:workout_tracker/contract.dart';

import '../../fixtures/workbook.dart';
import 'helpers.dart';

void main() {
  test('parses row-local log format metadata before workout columns', () {
    final activeSheet = parseActiveSheet(
      ActiveSheetInput(
        rows: [
          [
            'Exercise',
            'Sets',
            'Reps',
            'RPE',
            'Rest',
            'Tempo',
            'Notes',
            'Log Format',
            'Workout',
            'is_backup',
            'Session A',
          ],
          ['', '', '', '', '', '', '', '', '', '', 'S1'],
          [
            'Squat',
            '3',
            '5',
            '8',
            '3 min',
            '',
            'Stay braced.',
            '{Weight}[x]{Reps}[@]{RPE}',
            'Legs',
            '',
            '225x5@8',
          ],
          [
            'Leg Press',
            '3',
            '10',
            '8',
            '2 min',
            '',
            'Backup if racks are taken.',
            '',
            'Legs',
            'TRUE',
            '',
          ],
        ],
      ),
    );

    final primary = activeSheet.primarySlots.single;
    final backup = primary.backups.single;

    expect(activeSheet.schemaViolations, isEmpty);
    expect(
      activeSheet.historyBlocks.single.setColumns.single.sheetColumnNumber,
      11,
    );
    expect(activeSheet.selectableWorkouts, ['Legs']);
    expect(primary.workout, 'Legs');
    expect(primary.isBackup, isFalse);
    expect((primary.logFormat as ParsedLogFormat).fieldLabels, [
      'Weight',
      'Reps',
      'RPE',
    ]);
    expect(backup.workout, 'Legs');
    expect(backup.isBackup, isTrue);
    expect(backup.logFormat, parseLogFormat(defaultLogFormatText));
  });

  test('reports schema violations for invalid row-local log formats', () {
    final activeSheet = parseActiveSheet(
      ActiveSheetInput(
        rows: [
          historyHeaderRow(['Session A']),
          setLabelRow(['S1']),
          [
            'Squat',
            '3',
            '5',
            '8',
            '3 min',
            '',
            'Stay braced.',
            '{Weight[x]{Reps}',
            'Legs',
            '',
            '',
          ],
        ],
      ),
    );

    expect(activeSheet.slots.single.logFormat, isA<InvalidLogFormat>());
    expect(activeSheet.schemaViolations, [
      SchemaViolation(
        sheetRowNumber: 3,
        workout: 'Legs',
        message: 'Invalid Log Format: Field labels cannot contain brackets.',
      ),
    ]);
  });

  test('parses and validates trailing set labels after trimmed headers', () {
    final activeSheet = parseActiveSheet(
      ActiveSheetInput(
        rows: [
          [...activeSheetFixedColumns, 'Week 1'],
          [...List.filled(activeSheetFixedColumns.length, ''), 'S1', 'S2'],
          [
            'Bulgarian Split Squat',
            '3',
            '8/side',
            '8',
            '',
            '',
            '',
            defaultExerciseLogFormat,
            'Legs',
            '',
            '70x8@8',
            '75x8@8',
          ],
        ],
      ),
    );

    expect(activeSheet.schemaViolations, isEmpty);
    expect(activeSheet.historyBlocks.single.label, 'Week 1');
    expect(activeSheet.historyBlocks.single.setColumns, [
      const HistorySetColumn(label: 'S1', sheetColumnNumber: 11),
      const HistorySetColumn(label: 'S2', sheetColumnNumber: 12),
    ]);

    final malformedActiveSheet = parseActiveSheet(
      ActiveSheetInput(
        rows: [
          [...activeSheetFixedColumns, 'Week 1'],
          [...List.filled(activeSheetFixedColumns.length, ''), 'S1', 'S3'],
        ],
      ),
    );

    expect(
      malformedActiveSheet.schemaViolations,
      contains(
        const SchemaViolation(
          sheetRowNumber: 2,
          workout: defaultWorkoutName,
          message: 'History block Week 1 skips set label S2 before S3.',
        ),
      ),
    );
  });

  test('parses app-readable active sheet rows into ordered workout slots', () {
    final workbook = loadLocalWorkoutWorkbookFixture();
    final activeSheet = parseFixtureActiveSheet();
    final expectedReadableRows = appReadableFixtureRows(workbook);

    expect(
      activeSheet.slots.map((slot) => slot.exercise),
      expectedReadableRows.map((row) => row.values.first),
    );
    expect(
      activeSheet.slots.map((slot) => slot.sheetRowNumber),
      expectedReadableRows.map((row) => row.sheetRowNumber),
    );

    final firstReadableRow = expectedReadableRows.first;
    expect(
      activeSheet.slots.first,
      WorkoutSlot(
        sheetRowNumber: firstReadableRow.sheetRowNumber,
        exercise: firstReadableRow.values[0],
        sets: firstReadableRow.values[1],
        reps: firstReadableRow.values[2],
        rpe: firstReadableRow.values[3],
        rest: firstReadableRow.values[4],
        tempo: firstReadableRow.values[5],
        notes: firstReadableRow.values[6],
        logFormat: parseLogFormat(defaultLogFormatText),
        workout: firstReadableRow.values[8],
        isBackup: firstReadableRow.values[9] == 'TRUE',
      ),
    );
    expect(activeSheet.slots.any((slot) => slot.isBackup), isTrue);
    expect(
      activeSheet.slots.map((slot) => slot.isBackup),
      expectedReadableRows.map((row) => row.values[9] == 'TRUE'),
    );
    expect(
      activeSheet.slots.any((slot) => slot.workout == defaultWorkoutName),
      isTrue,
    );
  });

  test(
    'ignores merged first-column human rows even when they contain text',
    () {
      final activeSheet = parseActiveSheet(
        ActiveSheetInput(
          rows: [
            activeSheetFixedColumns,
            [
              'Leg Day',
              '',
              '',
              '',
              '',
              '',
              'Human section label spanning columns.',
              '',
              '',
              '',
            ],
            ['Squat', '3', '5', '8', '3 min', '', '', '', '', ''],
          ],
          mergedFirstColumnRows: {2},
        ),
      );

      expect(activeSheet.slots.map((slot) => slot.exercise), ['Squat']);
      expect(activeSheet.slots.single.sheetRowNumber, 3);
    },
  );

  test(
    'groups backup rows under the nearest preceding primary in a workout',
    () {
      final activeSheet = parseFixtureActiveSheet();

      expect(activeSheet.schemaViolations, isEmpty);
      expect(activeSheet.primarySlots.every((slot) => !slot.isBackup), isTrue);
      expect(
        activeSheet.primarySlots.where((slot) => slot.workout == 'Legs'),
        hasLength(greaterThanOrEqualTo(2)),
      );
      expect(
        activeSheet.primarySlots.where((slot) => slot.workout == 'Upper'),
        hasLength(greaterThanOrEqualTo(2)),
      );

      final multiBackupSlot = activeSheet.primarySlots.firstWhere(
        (slot) => slot.backups.length > 2,
      );
      expect(multiBackupSlot.backups.every((slot) => slot.isBackup), isTrue);
      expect(
        multiBackupSlot.backups.every(
          (slot) => slot.workout == multiBackupSlot.workout,
        ),
        isTrue,
      );
      expect(
        multiBackupSlot.backups.every(
          (slot) => slot.sheetRowNumber > multiBackupSlot.sheetRowNumber,
        ),
        isTrue,
      );

      final plankSlot = activeSheet.primarySlots.firstWhere(
        (slot) => slot.exercise == 'Plank',
      );
      expect(plankSlot.exercise, 'Plank');
      expect(plankSlot.workout, 'Upper');
      expect(plankSlot.isBackup, isFalse);

      final defaultSlot = activeSheet.primarySlots.firstWhere(
        (slot) => slot.workout == defaultWorkoutName,
      );
      expect(defaultSlot.workout, defaultWorkoutName);
      expect(defaultSlot.backups, isEmpty);
    },
  );

  test('does not attach backups across an intervening workout group', () {
    final activeSheet = parseActiveSheet(
      ActiveSheetInput(
        rows: [
          activeSheetFixedColumns,
          ['Squat', '3', '5', '8', '3 min', '', '', '', 'Legs', ''],
          ['Bench Press', '3', '8', '8', '2 min', '', '', '', 'Upper', ''],
          [
            'Reverse Lunge',
            '3',
            '10/side',
            '8',
            '90s',
            '',
            '',
            '',
            'Legs',
            'TRUE',
          ],
        ],
      ),
    );

    expect(activeSheet.primarySlots.first.exercise, 'Squat');
    expect(activeSheet.primarySlots.first.backups, isEmpty);
    expect(activeSheet.schemaViolations, [
      SchemaViolation(
        sheetRowNumber: 4,
        workout: 'Legs',
        message: 'Backup row has no preceding primary row in the same workout.',
      ),
    ]);
  });

  test('attaches backups to the nearest preceding primary in row order', () {
    final activeSheet = parseActiveSheet(
      ActiveSheetInput(
        rows: [
          activeSheetFixedColumns,
          ['Squat', '3', '5', '8', '3 min', '', '', '', 'Legs', ''],
          ['Deadlift', '3', '5', '8', '3 min', '', '', '', 'Legs', ''],
          ['Hip Thrust', '3', '10', '8', '2 min', '', '', '', 'Legs', 'TRUE'],
        ],
      ),
    );

    expect(activeSheet.schemaViolations, isEmpty);
    expect(activeSheet.primarySlots.map((slot) => slot.exercise), [
      'Squat',
      'Deadlift',
    ]);
    expect(activeSheet.primarySlots.first.backups, isEmpty);
    expect(activeSheet.primarySlots.last.backups.map((slot) => slot.exercise), [
      'Hip Thrust',
    ]);
  });

  test(
    'reports a schema violation when a workout starts with a backup row',
    () {
      final activeSheet = parseActiveSheet(
        ActiveSheetInput(
          rows: [
            activeSheetFixedColumns,
            ['Step-Up', '3', '10/side', '8', '90s', '', '', '', 'Legs', 'TRUE'],
            ['Squat', '3', '5', '8', '3 min', '', '', '', 'Legs', ''],
          ],
        ),
      );

      expect(activeSheet.primarySlots.map((slot) => slot.exercise), ['Squat']);
      expect(activeSheet.schemaViolations, [
        SchemaViolation(
          sheetRowNumber: 2,
          workout: 'Legs',
          message:
              'Backup row has no preceding primary row in the same workout.',
        ),
      ]);
    },
  );
}
