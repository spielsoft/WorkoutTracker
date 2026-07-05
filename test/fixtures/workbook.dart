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
    Iterable<SheetCellFormulaFixture> cellFormulas = const [],
    Set<int> mergedFirstColumnRows = const {},
  }) : rows = List<List<String>>.unmodifiable(
         rows.map((row) => List<String>.unmodifiable(row)),
       ),
       cellFormulas = List<SheetCellFormulaFixture>.unmodifiable(cellFormulas),
       mergedFirstColumnRows = Set.unmodifiable(mergedFirstColumnRows);

  final String name;
  final List<List<String>> rows;
  final List<SheetCellFormulaFixture> cellFormulas;

  /// 1-based sheet row numbers whose first display cell is merged for humans.
  final Set<int> mergedFirstColumnRows;

  Map<String, Object> toSnapshot() => {
    'name': name,
    'rows': rows,
    'cellFormulas': cellFormulas
        .map((formula) => formula.toSnapshot())
        .toList(),
    'mergedFirstColumnRows': mergedFirstColumnRows.toList()..sort(),
  };
}

class SheetCellFormulaFixture {
  const SheetCellFormulaFixture({
    required this.sheetRowNumber,
    required this.sheetColumnNumber,
    required this.formula,
  });

  final int sheetRowNumber;
  final int sheetColumnNumber;
  final String formula;

  Map<String, Object> toSnapshot() => {
    'sheetRowNumber': sheetRowNumber,
    'sheetColumnNumber': sheetColumnNumber,
    'formula': formula,
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

WorkoutWorkbookFixture loadFixedColumnDamageFixture() {
  return WorkoutWorkbookFixture(
    activeSheet: SheetGridFixture(
      name: 'Active Workout',
      rows: [
        [
          'Exercise Name',
          'Sets',
          'Reps',
          'RPE',
          'Rest',
          'Tempo',
          'Notes',
          'Format',
          'Workout',
          'is_backup',
          'Week 1',
        ],
        ['', '', '', '', '', '', '', '', '', '', 'S1'],
        [
          'Squat',
          '3',
          '5',
          '8',
          '3 min',
          '',
          'Stay braced.',
          '',
          'Legs',
          '',
          '',
        ],
      ],
    ),
    exercisesSheet: _minimalExercisesSheet(),
  );
}

WorkoutWorkbookFixture loadMalformedHistoryDamageFixture() {
  return WorkoutWorkbookFixture(
    activeSheet: SheetGridFixture(
      name: 'Active Workout',
      rows: [
        [
          ...activeSheetFixedColumnsForFixtures,
          '',
          'Week 1',
          '',
          'Week 1',
          'Empty Block',
        ],
        ['', '', '', '', '', '', '', '', '', '', 'S1', 'S1', 'S3', 'S1', ''],
        ['Squat', '3', '5', '8', '3 min', '', 'Stay braced.', '', 'Legs', ''],
      ],
    ),
    exercisesSheet: _minimalExercisesSheet(),
  );
}

WorkoutWorkbookFixture loadInvalidLogFormatDamageFixture() {
  return WorkoutWorkbookFixture(
    activeSheet: SheetGridFixture(
      name: 'Active Workout',
      rows: [
        [...activeSheetFixedColumnsForFixtures, 'Week 1'],
        ['', '', '', '', '', '', '', '', '', '', 'S1'],
        [
          'Squat',
          '3',
          '5',
          '8',
          '3 min',
          '',
          'Stay braced.',
          '{Weight[x]{Reps}',
          'Legs',
          '',
          '',
        ],
      ],
    ),
    exercisesSheet: _minimalExercisesSheet(),
  );
}

WorkoutWorkbookFixture loadBackupGroupingDamageFixture() {
  return WorkoutWorkbookFixture(
    activeSheet: SheetGridFixture(
      name: 'Active Workout',
      rows: [
        [...activeSheetFixedColumnsForFixtures, 'Week 1'],
        ['', '', '', '', '', '', '', '', '', '', 'S1'],
        [
          'Reverse Lunge',
          '3',
          '10/side',
          '8',
          '90s',
          '',
          'Backup before a primary row.',
          '',
          'Legs',
          'TRUE',
          '',
        ],
        ['Squat', '3', '5', '8', '3 min', '', 'Stay braced.', '', 'Legs', ''],
      ],
    ),
    exercisesSheet: _minimalExercisesSheet(),
  );
}

WorkoutWorkbookFixture loadFormulaDamageFixture() {
  return WorkoutWorkbookFixture(
    activeSheet: SheetGridFixture(
      name: 'Active Workout',
      rows: [
        [...activeSheetFixedColumnsForFixtures, 'Week 1'],
        ['', '', '', '', '', '', '', '', '', '', 'S1'],
        [
          'Squat',
          '3',
          '5',
          '8',
          '3 min',
          '',
          'Stay braced.',
          '{Weight}[x]{Reps}[@]{RPE}',
          'Legs',
          '',
          '',
        ],
      ],
      cellFormulas: [
        SheetCellFormulaFixture(
          sheetRowNumber: 3,
          sheetColumnNumber: 2,
          formula: '=Exercises!C2',
        ),
        SheetCellFormulaFixture(
          sheetRowNumber: 3,
          sheetColumnNumber: 3,
          formula: '=Exercises!D2',
        ),
        SheetCellFormulaFixture(
          sheetRowNumber: 3,
          sheetColumnNumber: 4,
          formula: '=Exercises!E2',
        ),
        SheetCellFormulaFixture(
          sheetRowNumber: 3,
          sheetColumnNumber: 5,
          formula: '=Exercises!F2',
        ),
        SheetCellFormulaFixture(
          sheetRowNumber: 3,
          sheetColumnNumber: 6,
          formula: '=Exercises!G2',
        ),
        SheetCellFormulaFixture(
          sheetRowNumber: 3,
          sheetColumnNumber: 7,
          formula: '=Exercises!H2',
        ),
        SheetCellFormulaFixture(
          sheetRowNumber: 3,
          sheetColumnNumber: 8,
          formula: '=Exercises!I99',
        ),
      ],
    ),
    exercisesSheet: _minimalExercisesSheet(),
  );
}

WorkoutWorkbookFixture loadAmbiguousFormulaRepairDamageFixture() {
  return WorkoutWorkbookFixture(
    activeSheet: SheetGridFixture(
      name: 'Active Workout',
      rows: [
        [...activeSheetFixedColumnsForFixtures, 'Week 1'],
        ['', '', '', '', '', '', '', '', '', '', 'S1'],
        [
          'Squat',
          '3',
          '5',
          '8',
          '3 min',
          '',
          'Stay braced.',
          '{Weight}[x]{Reps}[@]{RPE}',
          'Legs',
          '',
          '',
        ],
      ],
      cellFormulas: _formulaDrivenCellsForActiveRow(
        rowNumber: 3,
        exercisesRowNumber: 2,
        omittedColumns: {1},
      ),
    ),
    exercisesSheet: _minimalExercisesSheet(
      rows: const [
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
          'Squat',
          'Back squat',
          '3',
          '5',
          '8',
          '3 min',
          '',
          'Stay braced.',
          '{Weight}[x]{Reps}[@]{RPE}',
        ],
        [
          'Squat',
          'Safety-bar squat',
          '3',
          '5',
          '8',
          '3 min',
          '',
          'Stay tall.',
          '{Reps}[@]{RPE}',
        ],
      ],
    ),
  );
}

WorkoutWorkbookFixture loadNoExactMatchFormulaRepairDamageFixture() {
  return WorkoutWorkbookFixture(
    activeSheet: SheetGridFixture(
      name: 'Active Workout',
      rows: [
        [...activeSheetFixedColumnsForFixtures, 'Week 1'],
        ['', '', '', '', '', '', '', '', '', '', 'S1'],
        [
          'Front Squat',
          '3',
          '5',
          '8',
          '3 min',
          '',
          'Stay upright.',
          '{Weight}[x]{Reps}[@]{RPE}',
          'Legs',
          '',
          '',
        ],
      ],
      cellFormulas: _formulaDrivenCellsForActiveRow(
        rowNumber: 3,
        exercisesRowNumber: 2,
        omittedColumns: {1},
      ),
    ),
    exercisesSheet: _minimalExercisesSheet(),
  );
}

const activeSheetFixedColumnsForFixtures = [
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
];

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
          'Log Format',
          'Workout',
          'is_backup',
          'Week 2',
          '',
          'Week 1',
          '',
          '',
        ],
        ['', '', '', '', '', '', '', '', '', '', 'S1', 'S2', 'S1', 'S2', 'S3'],
        [
          'Bulgarian Split Squat',
          '3',
          '8/side',
          '8',
          '2 min',
          '3-1-1',
          'Use straps if grip limits load.',
          '',
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
          '',
          'Legs',
          'TRUE',
          '',
          '',
          '',
          '',
          '',
        ],
        [
          'Step-Up',
          '3',
          '10/side',
          '8',
          '90s',
          '3-1-1',
          'Backup if split squat stations are crowded.',
          '',
          'Legs',
          'TRUE',
          '',
          '',
          '24x10@7',
          '',
          '',
        ],
        [
          'Leg Press',
          '3',
          '10',
          '8',
          '2 min',
          '',
          'Backup when unilateral work is not available.',
          '',
          'Legs',
          'TRUE',
          '',
          '',
          '220x10@8',
          '',
          '',
        ],
        [
          'Romanian Deadlift',
          '3',
          '8',
          '8',
          '2 min',
          '2-1-1',
          'Hinge at the hips and keep lats tight.',
          '',
          'Legs',
          '',
          '155x8@8',
          '',
          '150x8@7',
          '150x8@8',
          '',
        ],
        [
          'Dumbbell RDL',
          '3',
          '10',
          '8',
          '90s',
          '',
          'Backup hinge if racks are unavailable.',
          '',
          'Legs',
          'TRUE',
          '',
          '',
          '',
          '',
          '',
        ],
        [
          'Hamstring Curl',
          '3',
          '12',
          '8',
          '90s',
          '',
          'Backup hinge pattern with less setup.',
          '',
          'Legs',
          'TRUE',
          '',
          '',
          '',
          '',
          '',
        ],
        [
          'Standing Calf Raise',
          '3',
          '12-15',
          '9',
          '60s',
          '2-1-1',
          'Pause at the bottom and top.',
          '',
          'Legs',
          '',
          '',
          '',
          '145x15@8',
          '',
          '',
        ],
        [
          'Seated Calf Raise',
          '3',
          '12-15',
          '9',
          '60s',
          '2-1-1',
          'Backup calf raise station.',
          '',
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
          '',
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
          '',
          'Upper',
          'TRUE',
          '',
          '',
          '',
          '',
          '',
        ],
        [
          'Dumbbell Floor Press',
          '4',
          '8',
          '8',
          '2 min',
          '',
          'Backup if benches are full.',
          '',
          'Upper',
          'TRUE',
          '',
          '',
          '',
          '',
          '',
        ],
        [
          'Machine Chest Press',
          '4',
          '8',
          '8',
          '2 min',
          '',
          'Backup if free-weight pressing is busy.',
          '',
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
          'Brace hard and keep hips level.',
          '',
          'Upper',
          '',
          '45s@8',
          '',
          '40s@8',
          '',
          '',
        ],
        [
          'Dead Bug',
          '3',
          '10/side',
          '7',
          '45s',
          '',
          'Backup core drill if planks are uncomfortable.',
          '',
          'Upper',
          'TRUE',
          '',
          '',
          '',
          '',
          '',
        ],
        [
          'Side Plank',
          '3',
          '30s/side',
          '8',
          '45s',
          '',
          'Backup anti-lateral-flexion core drill.',
          '',
          'Upper',
          'TRUE',
          '',
          '',
          '',
          '',
          '',
        ],
        [
          'Seated Cable Row',
          '3',
          '10',
          '8',
          '90s',
          '',
          'Pull elbows toward hips.',
          '',
          'Upper',
          '',
          '105x10@8',
          '',
          '100x10@8',
          '',
          '',
        ],
        [
          'Chest-Supported Row',
          '3',
          '10',
          '8',
          '90s',
          '',
          'Backup row if cable station is busy.',
          '',
          'Upper',
          'TRUE',
          '',
          '',
          '',
          '',
          '',
        ],
        [
          'Lat Pulldown',
          '3',
          '10',
          '8',
          '90s',
          '',
          'Backup vertical pull option.',
          '',
          'Upper',
          'TRUE',
          '',
          '',
          '',
          '',
          '',
        ],
        [
          'Farmer Carry',
          '3',
          '40m',
          '8',
          '60s',
          '',
          'Default workout row with blank Workout.',
          '',
          '',
          '',
          '',
          '',
          '50x40m@8',
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
          'Brace hard and keep hips level.',
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
        ],
      ],
    ),
  );
}

SheetGridFixture _minimalExercisesSheet({
  Iterable<Iterable<String>> rows = const [
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
      'Squat',
      'Back squat',
      '3',
      '5',
      '8',
      '3 min',
      '',
      'Stay braced.',
      '{Weight}[x]{Reps}[@]{RPE}',
    ],
  ],
}) {
  return SheetGridFixture(name: 'Exercises', rows: rows);
}

List<SheetCellFormulaFixture> _formulaDrivenCellsForActiveRow({
  required int rowNumber,
  required int exercisesRowNumber,
  Set<int> omittedColumns = const {},
}) {
  final exercisesColumnsByActiveColumn = {
    1: 'A',
    2: 'C',
    3: 'D',
    4: 'E',
    5: 'F',
    6: 'G',
    7: 'H',
    8: 'I',
  };

  return [
    for (final entry in exercisesColumnsByActiveColumn.entries)
      if (!omittedColumns.contains(entry.key))
        SheetCellFormulaFixture(
          sheetRowNumber: rowNumber,
          sheetColumnNumber: entry.key,
          formula: '=Exercises!${entry.value}$exercisesRowNumber',
        ),
  ];
}
