import 'package:flutter_test/flutter_test.dart';
import 'package:workout_tracker/google_sheets.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'seeds app-created workbooks from editable default exercises JSON',
    () async {
      expect(defaultExerciseDefaultsAsset, endsWith('default_exercises.json'));

      final workbook = await loadWorkoutTrackerWorkbookTemplate();
      final exerciseRows = workbook.exercisesSheet.rows.skip(1).toList();
      final rowsByName = {for (final row in exerciseRows) row.first: row};

      expect(rowsByName, contains('Smith Machine Reverse Lunge'));
      expect(rowsByName, contains('DB Reverse Lunge'));
      expect(rowsByName, contains('Lateral Step-Down'));
      expect(rowsByName, contains('Cable Face Pull'));
      expect(rowsByName, contains('Cable Dorsiflexion'));
      expect(rowsByName, contains('Bench Row'));
      expect(rowsByName, contains('Squat'));
      expect(rowsByName, contains('DB Flat Bench Press'));
      expect(rowsByName, contains('Box Jump'));
      expect(rowsByName, contains('Dips'));
      expect(rowsByName, contains('Side Plank'));
      expect(rowsByName, isNot(contains('Deep Squat')));
      expect(rowsByName, isNot(contains('DB Bench Press')));

      expect(rowsByName['Smith Machine Reverse Lunge'], [
        'Smith Machine Reverse Lunge',
        'Smith machine reverse lunge',
        '3',
        '8-10/leg',
        '8',
        '90s',
        '',
        'Keep front shin vertical to minimize knee shear.',
        '{Weight}[x]{Reps}[@]{RPE}[,]{Pain}',
      ]);
      expect(rowsByName['Lateral Step-Down'], [
        'Lateral Step-Down',
        'Eccentric lateral step-down',
        '3',
        '8/leg',
        '7',
        '60s',
        '3-1-1',
        'Do not drop; keep knee aligned over toe.',
        '{Height}[x]{Reps}[@]{RPE}[,]{Pain}',
      ]);
      expect(rowsByName['Bench Row'], [
        'Bench Row',
        'Bench-supported dumbbell row',
        '3',
        '8-10',
        '8',
        '90s',
        '2-1-1',
        'Fall upper-body row variation logged as bench rows.',
        '{Weight}[x]{Reps}[@]{RPE}',
      ]);
      expect(rowsByName['Squat'], [
        'Squat',
        'Squat',
        '3',
        '5-6',
        '8',
        '3m',
        '3-1-1',
        'Squat pattern from fall and winter programs.',
        '{Weight}[x]{Reps}[@]{RPE}[,]{Pain}',
      ]);
      expect(rowsByName['DB Flat Bench Press'], [
        'DB Flat Bench Press',
        'Dumbbell flat bench press',
        '3',
        '8-12',
        '8',
        '90s',
        '',
        'Tuck elbows to 45 degrees and press in a slight arc.',
        '{Weight}[x]{Reps}[@]{RPE}',
      ]);
      expect(rowsByName['Dips']?[8], '{Reps}[@]{RPE}');
      expect(rowsByName['Side Plank']?[8], '{Seconds}[s@]{RPE}');
    },
  );
}
