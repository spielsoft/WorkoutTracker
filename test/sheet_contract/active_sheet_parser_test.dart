import 'package:flutter_test/flutter_test.dart';
import 'package:workout_tracker/sheet_contract.dart';

import '../fixtures/workout_sheet_fixtures.dart';

void main() {
  test('parses app-readable active sheet rows into ordered workout slots', () {
    final workbook = loadLocalWorkoutWorkbookFixture();

    final activeSheet = parseActiveSheet(
      ActiveSheetInput(
        rows: workbook.activeSheet.rows,
        mergedFirstColumnRows: workbook.activeSheet.mergedFirstColumnRows,
      ),
    );

    expect(activeSheet.slots.map((slot) => slot.exercise), [
      'Bulgarian Split Squat',
      'Reverse Lunge',
      'Bench Press',
      'Push-Up',
      'Plank',
    ]);
    expect(activeSheet.slots.map((slot) => slot.sheetRowNumber), [
      3,
      4,
      6,
      7,
      8,
    ]);

    expect(
      activeSheet.slots.first,
      WorkoutSlot(
        sheetRowNumber: 3,
        exercise: 'Bulgarian Split Squat',
        sets: '3',
        reps: '8/side',
        rpe: '8',
        rest: '2 min',
        tempo: '3-1-1',
        notes: 'Use straps if grip limits load.',
        workout: 'Legs',
        isBackup: false,
      ),
    );
    expect(activeSheet.slots[1].isBackup, isTrue);
    expect(activeSheet.slots[3].isBackup, isTrue);
    expect(activeSheet.slots.last.workout, defaultWorkoutName);
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
}
