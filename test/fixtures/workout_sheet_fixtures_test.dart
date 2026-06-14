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
    expect(
      first.activeSheet.rows,
      anyElement(
        predicate<List<String>>(
          (row) => _startsWith(row, [
            'Bulgarian Split Squat',
            '3',
            '8/side',
            '8',
            '2 min',
            '3-1-1',
            'Use straps if grip limits load.',
            'Legs',
            '',
          ]),
          'contains a primary Legs row',
        ),
      ),
    );
    expect(
      first.activeSheet.rows,
      anyElement(
        predicate<List<String>>(
          (row) => _startsWith(row, [
            'Reverse Lunge',
            '3',
            '10/side',
            '8',
            '90s',
            '',
            'Backup if benches are taken.',
            'Legs',
            'TRUE',
          ]),
          'contains a backup Legs row',
        ),
      ),
    );
    expect(first.exercisesSheet.rows, hasLength(greaterThanOrEqualTo(4)));
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

bool _startsWith(List<String> row, List<String> prefix) {
  if (row.length < prefix.length) {
    return false;
  }

  for (var index = 0; index < prefix.length; index += 1) {
    if (row[index] != prefix[index]) {
      return false;
    }
  }

  return true;
}
