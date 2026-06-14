import 'package:flutter_test/flutter_test.dart';
import 'package:workout_tracker/google_sheets.dart';
import 'package:workout_tracker/sheet_contract.dart';

void main() {
  test(
    'resets only the known development spreadsheet to a deterministic fixture',
    () async {
      final client = _FakeDevelopmentSheetResetClient();
      final harness = DevelopmentSheetResetHarness(client: client);

      await harness.reset();

      expect(client.resetSpreadsheetIds, [
        workoutTrackerDevelopmentSpreadsheetId,
      ]);
      final fixture = client.fixtures.single;
      expect(fixture.activeSheet.title, 'Active Workout');
      expect(fixture.exercisesSheet.title, 'Exercises');

      final activeRows = fixture.activeSheet.rows;
      expect(
        activeRows.first.take(activeSheetFixedColumns.length),
        activeSheetFixedColumns,
      );
      expect(activeRows[0].skip(activeSheetFixedColumns.length), [
        'Week 2',
        '',
        'Week 1',
      ]);
      expect(activeRows[1].skip(activeSheetFixedColumns.length), [
        'S1',
        'S2',
        'S1',
      ]);
      expect(activeRows.any((row) => row[7] == 'Legs'), isTrue);
      expect(
        activeRows.any((row) => row[7].isEmpty && row[0].startsWith('=')),
        isTrue,
      );
      expect(activeRows.any((row) => row[8] == 'TRUE'), isTrue);

      final firstExerciseFormulaRow = activeRows.firstWhere(
        (row) => row.first == '=Exercises!A2',
      );
      expect(firstExerciseFormulaRow.take(7), [
        '=Exercises!A2',
        '=Exercises!C2',
        '=Exercises!D2',
        '=Exercises!E2',
        '=Exercises!F2',
        '=Exercises!G2',
        '=Exercises!H2',
      ]);

      final exercisesRows = fixture.exercisesSheet.rows;
      expect(exercisesRows.first, [
        'Exercise',
        'Description',
        'Default Sets',
        'Default Reps',
        'Default RPE',
        'Default Rest',
        'Default Tempo',
        'Notes',
      ]);
      expect(exercisesRows.map((row) => row.first), contains('Reverse Lunge'));
    },
  );

  test('rejects non-development spreadsheet IDs by default', () async {
    final harness = DevelopmentSheetResetHarness(
      client: _FakeDevelopmentSheetResetClient(),
    );

    expect(
      () => harness.reset(spreadsheetId: 'unrelated-spreadsheet'),
      throwsArgumentError,
    );
  });
}

class _FakeDevelopmentSheetResetClient implements DevelopmentSheetResetClient {
  final resetSpreadsheetIds = <String>[];
  final fixtures = <DevelopmentSheetResetFixture>[];

  @override
  Future<void> resetSpreadsheet({
    required String spreadsheetId,
    required DevelopmentSheetResetFixture fixture,
  }) async {
    resetSpreadsheetIds.add(spreadsheetId);
    fixtures.add(fixture);
  }
}
