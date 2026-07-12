import 'package:flutter_test/flutter_test.dart';
import 'package:workout_tracker/contract.dart';

void main() {
  final exercise = CanonicalExercise(sheetRowNumber: 2, exercise: 'Squat');

  test('malformed active headers cannot produce workbook writes', () {
    final sheet = parseActiveSheet(
      ActiveSheetInput(
        rows: const [
          [
            'Exercise',
            'Reps',
            'Sets',
            'RPE',
            'Rest',
            'Tempo',
            'Notes',
            'Log Format',
            'Workout',
            'is_backup',
            'Week 1',
          ],
          ['', '', '', '', '', '', '', '', '', '', 'S1'],
          ['Squat', '5', '3', '8', '', '', '', '', 'Legs', '', '225x5@8'],
        ],
        exercisesRows: const [
          exercisesSheetColumns,
          ['Squat', '', '3', '5', '8', '', '', '', defaultExerciseLogFormat],
        ],
      ),
    );

    expect(sheet.schemaViolations, isNotEmpty);
    expect(sheet.slots, isEmpty);
    expect(sheet.historyBlocks, isEmpty);
    _expectNoPlans(sheet, exercise);
  });

  test('malformed Exercises headers cannot produce workbook writes', () {
    final sheet = parseActiveSheet(
      ActiveSheetInput(
        rows: const [
          [...activeSheetFixedColumns, 'Week 1'],
          ['', '', '', '', '', '', '', '', '', '', 'S1'],
          ['Squat', '3', '5', '8', '', '', '', '', 'Legs', '', '225x5@8'],
        ],
        exercisesRows: const [
          [
            'Description',
            'Exercise',
            'Default Sets',
            'Default Reps',
            'Default RPE',
            'Default Rest',
            'Default Tempo',
            'Notes',
            'Log Format',
          ],
          ['', 'Squat', '3', '5', '8', '', '', '', defaultExerciseLogFormat],
        ],
      ),
    );

    expect(sheet.schemaViolations, isNotEmpty);
    _expectNoPlans(sheet, exercise);
  });
}

void _expectNoPlans(ParsedActiveSheet sheet, CanonicalExercise exercise) {
  final activePlans = [
    sheet.planNewHistoryBlock(label: 'Week 2'),
    sheet.planHistoryBlockGrowth(label: 'Week 1', throughSetNumber: 2),
    sheet.planSetLoggingWrite(
      blockLabel: 'Week 1',
      sheetRowNumber: 3,
      fieldValues: const {'Weight': '230', 'Reps': '5', 'RPE': '8'},
    ),
    sheet.planSetEdit(
      blockLabel: 'Week 1',
      sheetRowNumber: 3,
      setNumber: 1,
      fieldValues: const {'Weight': '230', 'Reps': '5', 'RPE': '8'},
    ),
    sheet.planRawSetEdit(
      blockLabel: 'Week 1',
      sheetRowNumber: 3,
      setNumber: 1,
      rawText: 'manual',
    ),
    sheet.planSetClear(blockLabel: 'Week 1', sheetRowNumber: 3, setNumber: 1),
    sheet.planExerciseReorder(
      workout: 'Legs',
      intent: const ReorderIntent(fromIndex: 0, toIndex: 1),
    ),
    sheet.planPrimaryPlacement(exercise: exercise, workout: 'Legs'),
    sheet.planBackupPlacement(primaryRow: 3, exercise: exercise),
    sheet.planDeletePrimary(primaryRow: 3),
    sheet.planFormulaHealing(activeSheetRowNumber: 3),
    sheet.planFormulaRepair(),
  ];
  for (final plan in activePlans) {
    expect(plan.columnInsertions, isEmpty);
    expect(plan.rowInsertions, isEmpty);
    expect(plan.rowDeletions, isEmpty);
    expect(plan.cellUpdates, isEmpty);
  }

  final exercisePlans = [
    sheet.planCanonicalAppend(ExerciseDef(exercise: 'Deadlift')),
    sheet.planCanonicalUpdate(
      selectedExercise: exercise,
      exercise: ExerciseDef(exercise: 'Deadlift'),
    ),
    sheet.planCanonicalReorder(const ReorderIntent(fromIndex: 0, toIndex: 1)),
  ];
  for (final plan in exercisePlans) {
    expect(plan.rowAppends, isEmpty);
    expect(plan.rowUpdates, isEmpty);
    expect(plan.formulaUpdates, isEmpty);
  }
}
