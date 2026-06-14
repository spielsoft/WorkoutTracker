class WorkoutWorkbookFixture {
  const WorkoutWorkbookFixture({
    required this.activeSheet,
    required this.exercisesSheet,
  });

  final SheetGridFixture activeSheet;
  final SheetGridFixture exercisesSheet;

  Map<String, Object> toSnapshot() => {
    'activeSheet': activeSheet.toSnapshot(),
    'exercisesSheet': exercisesSheet.toSnapshot(),
  };
}

class SheetGridFixture {
  SheetGridFixture({
    required this.name,
    required Iterable<Iterable<String>> rows,
    Set<int> mergedFirstColumnRows = const {},
  }) : rows = List<List<String>>.unmodifiable(
         rows.map((row) => List<String>.unmodifiable(row)),
       ),
       mergedFirstColumnRows = Set.unmodifiable(mergedFirstColumnRows);

  final String name;
  final List<List<String>> rows;

  /// 1-based sheet row numbers whose first display cell is merged for humans.
  final Set<int> mergedFirstColumnRows;

  Map<String, Object> toSnapshot() => {
    'name': name,
    'rows': rows,
    'mergedFirstColumnRows': mergedFirstColumnRows.toList()..sort(),
  };
}

class IntegrationSheetFixture {
  const IntegrationSheetFixture({
    required this.name,
    required this.url,
    required this.isWritable,
  });

  final String name;
  final String url;
  final bool isWritable;

  Map<String, Object> toSnapshot() => {
    'name': name,
    'url': url,
    'isWritable': isWritable,
  };
}

IntegrationSheetFixture writableDevelopmentSheetFixture() {
  return const IntegrationSheetFixture(
    name: 'WorkoutTracker development sheet',
    url:
        'https://docs.google.com/spreadsheets/d/'
        '1zQrmCYelrNqRMv4WtJcOrtezSxoaVniXzXi4XgKva_E/edit?gid=0#gid=0',
    isWritable: true,
  );
}

WorkoutWorkbookFixture loadLocalWorkoutWorkbookFixture() {
  return WorkoutWorkbookFixture(
    activeSheet: SheetGridFixture(
      name: 'Active Workout',
      mergedFirstColumnRows: {2},
      rows: [
        [
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
        ],
        ['', '', '', '', '', '', '', '', '', 'S1', 'S2', 'S1', 'S2', 'S3'],
        [
          'Bulgarian Split Squat',
          '3',
          '8/side',
          '8',
          '2 min',
          '3-1-1',
          'Use straps if grip limits load.',
          'Legs',
          '',
          '',
          '',
          '70x8@8',
          '70x8@8',
          '',
        ],
        [
          'Reverse Lunge',
          '3',
          '10/side',
          '8',
          '90s',
          '',
          'Backup if benches are taken.',
          'Legs',
          'TRUE',
          '',
          '',
          '',
          '',
          '',
        ],
        [
          '',
          'Upper body notes',
          '',
          '',
          '',
          '',
          'Human section row ignored by the app.',
          '',
          '',
          '',
          '',
          '',
          '',
          '',
        ],
        [
          'Bench Press',
          '4',
          '6',
          '8',
          '3 min',
          '',
          'Pause the first rep.',
          'Upper',
          '',
          '155x6@8',
          '',
          '150x6@8',
          '150x6@8',
          '150x5@9',
        ],
        [
          'Push-Up',
          '4',
          'AMRAP',
          '8',
          '2 min',
          '',
          'Backup if benches are full.',
          'Upper',
          'TRUE',
          '',
          '',
          '',
          '',
          '',
        ],
        [
          'Plank',
          '3',
          '45s',
          '8',
          '60s',
          '',
          'Default workout row with blank Workout.',
          '',
          '',
          '45s@8',
          '',
          '40s@8',
          '',
          '',
        ],
      ],
    ),
    exercisesSheet: SheetGridFixture(
      name: 'Exercises',
      rows: [
        [
          'Exercise',
          'Description',
          'Default Sets',
          'Default Reps',
          'Default RPE',
          'Default Rest',
          'Default Tempo',
          'Notes',
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
        ],
        [
          'Plank',
          'Front plank hold',
          '3',
          '45s',
          '8',
          '60s',
          '',
          'Default workout row with blank Workout.',
        ],
      ],
    ),
  );
}
