import 'package:flutter_test/flutter_test.dart';

import 'workout_sheet_fixtures.dart';

void main() {
  test('loads the local workbook fixture deterministically', () {
    final first = loadLocalWorkoutWorkbookFixture();
    final second = loadLocalWorkoutWorkbookFixture();

    expect(first.toSnapshot(), equals(second.toSnapshot()));
    expect(first.activeSheet.name, 'Active Workout');
    expect(first.exercisesSheet.name, 'Exercises');

    expect(
      first.activeSheet.rows.first,
      equals([
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
        'Week 2',
        '',
        'Week 1',
        '',
        '',
      ]),
    );
    expect(first.activeSheet.mergedFirstColumnRows, contains(2));
    expect(first.activeSheet.rows[1].first, isEmpty);

    final exerciseRows = first.activeSheet.rows.where(_isExerciseRow).toList();
    final legsRows = exerciseRows.where((row) => row[8] == 'Legs').toList();
    final upperRows = exerciseRows.where((row) => row[8] == 'Upper').toList();
    final defaultWorkoutRows = exerciseRows
        .where((row) => row[8].isEmpty)
        .toList();
    final backupRows = exerciseRows.where((row) => row[9] == 'TRUE').toList();

    expect(
      legsRows.where((row) => row[9] != 'TRUE'),
      hasLength(greaterThanOrEqualTo(2)),
    );
    expect(
      upperRows.where((row) => row[9] != 'TRUE'),
      hasLength(greaterThanOrEqualTo(2)),
    );
    expect(backupRows, isNotEmpty);
    expect(defaultWorkoutRows, isNotEmpty);
    expect(
      exerciseRows,
      anyElement(
        predicate<List<String>>(
          (row) => row[0] == 'Plank' && row[8] == 'Upper' && row[9] != 'TRUE',
          'contains Plank as a primary Upper row',
        ),
      ),
    );

    final exerciseLibraryNames = first.exercisesSheet.rows
        .skip(1)
        .map((row) => row.first)
        .toSet();
    expect(exerciseLibraryNames, containsAll(['Plank', 'Farmer Carry']));
    expect(
      exerciseRows.every((row) => exerciseLibraryNames.contains(row.first)),
      isTrue,
    );
  });

  test('names the writable development Google Sheet fixture', () {
    final first = writableDevelopmentSheetFixture();
    final second = writableDevelopmentSheetFixture();

    expect(first.toSnapshot(), equals(second.toSnapshot()));
    expect(first.name, 'WorkoutTracker development sheet');
    expect(first.isWritable, isTrue);
    expect(
      first.url,
      'https://docs.google.com/spreadsheets/d/'
      '1zQrmCYelrNqRMv4WtJcOrtezSxoaVniXzXi4XgKva_E/edit?gid=0#gid=0',
    );
  });
}

bool _isExerciseRow(List<String> row) =>
    row.length > 8 && row.first.isNotEmpty && row.first != 'Exercise';
