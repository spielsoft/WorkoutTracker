import 'package:flutter_test/flutter_test.dart';
import 'package:workout_tracker/sheet_contract.dart';

import '../fixtures/workout_sheet_fixtures.dart';
import 'active_sheet_test_helpers.dart';

void main() {
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
        workout: firstReadableRow.values[7],
        isBackup: firstReadableRow.values[8] == 'TRUE',
      ),
    );
    expect(activeSheet.slots.any((slot) => slot.isBackup), isTrue);
    expect(
      activeSheet.slots.map((slot) => slot.isBackup),
      expectedReadableRows.map((row) => row.values[8] == 'TRUE'),
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
            ],
            ['Squat', '3', '5', '8', '3 min', '', '', '', ''],
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
          ['Squat', '3', '5', '8', '3 min', '', '', 'Legs', ''],
          ['Bench Press', '3', '8', '8', '2 min', '', '', 'Upper', ''],
          ['Reverse Lunge', '3', '10/side', '8', '90s', '', '', 'Legs', 'TRUE'],
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
          ['Squat', '3', '5', '8', '3 min', '', '', 'Legs', ''],
          ['Deadlift', '3', '5', '8', '3 min', '', '', 'Legs', ''],
          ['Hip Thrust', '3', '10', '8', '2 min', '', '', 'Legs', 'TRUE'],
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
            ['Step-Up', '3', '10/side', '8', '90s', '', '', 'Legs', 'TRUE'],
            ['Squat', '3', '5', '8', '3 min', '', '', 'Legs', ''],
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
