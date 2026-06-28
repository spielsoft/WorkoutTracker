import 'package:workout_tracker/sheet_contract.dart';

class WorkoutTrackerWorkbook {
  WorkoutTrackerWorkbook({
    required this.activeSheet,
    required this.exercisesSheet,
  });

  final WorkoutTrackerWorkbookTab activeSheet;
  final WorkoutTrackerWorkbookTab exercisesSheet;
}

class WorkoutTrackerWorkbookTab {
  WorkoutTrackerWorkbookTab({
    required this.title,
    required Iterable<Iterable<String>> rows,
  }) : rows = List<List<String>>.unmodifiable(
         rows.map((row) => List<String>.unmodifiable(row)),
       );

  final String title;
  final List<List<String>> rows;

  int get columnCount {
    var maxColumns = 0;
    for (final row in rows) {
      if (row.length > maxColumns) {
        maxColumns = row.length;
      }
    }
    return maxColumns;
  }
}

WorkoutTrackerWorkbook workoutTrackerWorkbookTemplate() {
  final exercisesSheet = WorkoutTrackerWorkbookTab(
    title: 'Exercises',
    rows: _exerciseRows,
  );
  return WorkoutTrackerWorkbook(
    activeSheet: WorkoutTrackerWorkbookTab(
      title: 'Active Workout',
      rows: const [activeSheetFixedColumns],
    ),
    exercisesSheet: exercisesSheet,
  );
}

const _exerciseRows = [
  [
    'Exercise',
    'Description',
    'Default Sets',
    'Default Reps',
    'Default RPE',
    'Default Rest',
    'Default Tempo',
    'Notes',
    'Log Format',
  ],
  [
    'Bulgarian Split Squat',
    'Rear-foot elevated split squat',
    '3',
    '8/side',
    '8',
    '2 min',
    '3-1-1',
    'Use straps if grip limits load.',
    '{Weight}[x]{Reps}[@]{RPE}',
  ],
  [
    'Reverse Lunge',
    'Dumbbell reverse lunge',
    '3',
    '10/side',
    '8',
    '90s',
    '',
    'Backup if benches are taken.',
    '{Weight}[x]{Reps}[@]{RPE}[,]{Pain}',
  ],
  [
    'Step-Up',
    'Dumbbell step-up',
    '3',
    '10/side',
    '8',
    '90s',
    '3-1-1',
    'Backup if split squat stations are crowded.',
    '{Height}[x]{Reps}[@]{RPE}',
  ],
  [
    'Leg Press',
    'Machine leg press',
    '3',
    '10',
    '8',
    '2 min',
    '',
    'Backup when unilateral work is not available.',
    '{Weight}[x]{Reps}[@]{RPE}',
  ],
  [
    'Romanian Deadlift',
    'Barbell Romanian deadlift',
    '3',
    '8',
    '8',
    '2 min',
    '2-1-1',
    'Hinge at the hips and keep lats tight.',
    '{Weight}[x]{Reps}[@]{RPE}',
  ],
  [
    'Dumbbell RDL',
    'Dumbbell Romanian deadlift',
    '3',
    '10',
    '8',
    '90s',
    '',
    'Backup hinge if racks are unavailable.',
    '{Weight}[x]{Reps}[@]{RPE}',
  ],
  [
    'Hamstring Curl',
    'Seated or lying hamstring curl',
    '3',
    '12',
    '8',
    '90s',
    '',
    'Backup hinge pattern with less setup.',
    '{Reps}[@]{RPE}',
  ],
  [
    'Standing Calf Raise',
    'Standing calf raise',
    '3',
    '12-15',
    '9',
    '60s',
    '2-1-1',
    'Pause at the bottom and top.',
    '{Weight}[x]{Reps}[@]{RPE}',
  ],
  [
    'Seated Calf Raise',
    'Seated calf raise',
    '3',
    '12-15',
    '9',
    '60s',
    '2-1-1',
    'Backup calf raise station.',
    '{Weight}[x]{Reps}[@]{RPE}',
  ],
  [
    'Bench Press',
    'Barbell bench press',
    '4',
    '6',
    '8',
    '3 min',
    '',
    'Pause the first rep.',
    '{Weight}[x]{Reps}[@]{RPE}',
  ],
  [
    'Push-Up',
    'Bodyweight push-up',
    '4',
    'AMRAP',
    '8',
    '2 min',
    '',
    'Backup if benches are full.',
    '{Reps}[@]{RPE}',
  ],
  [
    'Dumbbell Floor Press',
    'Dumbbell floor press',
    '4',
    '8',
    '8',
    '2 min',
    '',
    'Backup if benches are full.',
    '{Weight}[x]{Reps}[@]{RPE}',
  ],
  [
    'Machine Chest Press',
    'Machine chest press',
    '4',
    '8',
    '8',
    '2 min',
    '',
    'Backup if free-weight pressing is busy.',
    '{Weight}[x]{Reps}[@]{RPE}',
  ],
  [
    'Plank',
    'Front plank hold',
    '3',
    '45s',
    '8',
    '60s',
    '',
    'Brace hard and keep hips level.',
    '{Seconds}[s@]{RPE}',
  ],
  [
    'Dead Bug',
    'Dead bug core drill',
    '3',
    '10/side',
    '7',
    '45s',
    '',
    'Backup core drill if planks are uncomfortable.',
    '{Reps}[@]{RPE}',
  ],
  [
    'Side Plank',
    'Side plank hold',
    '3',
    '30s/side',
    '8',
    '45s',
    '',
    'Backup anti-lateral-flexion core drill.',
    '{Seconds}[s@]{RPE}',
  ],
  [
    'Seated Cable Row',
    'Seated cable row',
    '3',
    '10',
    '8',
    '90s',
    '',
    'Pull elbows toward hips.',
    '{Weight}[x]{Reps}[@]{RPE}',
  ],
  [
    'Chest-Supported Row',
    'Chest-supported dumbbell row',
    '3',
    '10',
    '8',
    '90s',
    '',
    'Backup row if cable station is busy.',
    '{Weight}[x]{Reps}[@]{RPE}',
  ],
  [
    'Lat Pulldown',
    'Cable lat pulldown',
    '3',
    '10',
    '8',
    '90s',
    '',
    'Backup vertical pull option.',
    '{Weight}[x]{Reps}[@]{RPE}',
  ],
  [
    'Farmer Carry',
    'Loaded carry',
    '3',
    '40m',
    '8',
    '60s',
    '',
    'Default workout row with blank Workout.',
    '{Weight}[x]{Distance}[@]{RPE}',
  ],
];
