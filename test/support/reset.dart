import 'package:workout_tracker/sheets.dart';
import 'package:workout_tracker/contract.dart';

const workoutTrackerDevelopmentSpreadsheetId =
    '1zQrmCYelrNqRMv4WtJcOrtezSxoaVniXzXi4XgKva_E';

class DevelopmentSheetResetHarness {
  DevelopmentSheetResetHarness({required this.initializer});

  final WbkInit initializer;

  Future<void> reset({
    String spreadsheetId = workoutTrackerDevelopmentSpreadsheetId,
  }) async {
    if (spreadsheetId != workoutTrackerDevelopmentSpreadsheetId) {
      throw ArgumentError.value(
        spreadsheetId,
        'spreadsheetId',
        'Development sheet reset is limited to the known development spreadsheet.',
      );
    }

    try {
      await initializer.initializeWorkbook(
        spreadsheetId: spreadsheetId,
        workbook: _developmentFixture(),
      );
    } on Object catch (error) {
      throw DevelopmentSheetResetFailure(error);
    }
  }
}

Wbk _developmentFixture() {
  return Wbk(
    activeSheet: WbkTab(
      title: 'Active Workout',
      rows: [
        [...activeSheetFixedColumns, 'Week 1'],
        [...List.filled(activeSheetFixedColumns.length, ''), 'S1'],
        [
          '=Exercises!A2',
          '3',
          '2 min',
          '2-1-1',
          'x8@8',
          'Live logging fixture.',
          '=Exercises!G2',
          'Legs',
          '',
          'x',
          '',
        ],
      ],
    ),
    exercisesSheet: WbkTab(
      title: 'Exercises',
      rows: [
        exercisesSheetColumns,
        [
          'Bulgarian Split Squat',
          'Live logging fixture exercise.',
          '3',
          '2 min',
          '2-1-1',
          '',
          '{Weight}x{Reps}@{RPE}',
          'x8@8',
          '',
        ],
      ],
    ),
  );
}

final class DevelopmentSheetResetFailure implements Exception {
  const DevelopmentSheetResetFailure(this.cause);

  final Object cause;

  @override
  String toString() => 'Development sheet reset failed: $cause';
}
