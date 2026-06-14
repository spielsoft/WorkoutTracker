const defaultWorkoutName = 'Default';

const activeSheetFixedColumns = [
  'Exercise',
  'Sets',
  'Reps',
  'RPE',
  'Rest',
  'Tempo',
  'Notes',
  'Workout',
  'is_backup',
];

class ActiveSheetInput {
  ActiveSheetInput({
    required Iterable<Iterable<String>> rows,
    Set<int> mergedFirstColumnRows = const {},
  }) : rows = List<List<String>>.unmodifiable(
         rows.map((row) => List<String>.unmodifiable(row)),
       ),
       mergedFirstColumnRows = Set.unmodifiable(mergedFirstColumnRows);

  final List<List<String>> rows;

  /// 1-based sheet row numbers whose first display cell is merged for humans.
  final Set<int> mergedFirstColumnRows;
}

class ParsedActiveSheet {
  ParsedActiveSheet({required Iterable<WorkoutSlot> slots})
    : slots = List<WorkoutSlot>.unmodifiable(slots);

  final List<WorkoutSlot> slots;
}

class WorkoutSlot {
  const WorkoutSlot({
    required this.sheetRowNumber,
    required this.exercise,
    required this.sets,
    required this.reps,
    required this.rpe,
    required this.rest,
    required this.tempo,
    required this.notes,
    required this.workout,
    required this.isBackup,
  });

  final int sheetRowNumber;
  final String exercise;
  final String sets;
  final String reps;
  final String rpe;
  final String rest;
  final String tempo;
  final String notes;
  final String workout;
  final bool isBackup;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is WorkoutSlot &&
            sheetRowNumber == other.sheetRowNumber &&
            exercise == other.exercise &&
            sets == other.sets &&
            reps == other.reps &&
            rpe == other.rpe &&
            rest == other.rest &&
            tempo == other.tempo &&
            notes == other.notes &&
            workout == other.workout &&
            isBackup == other.isBackup;
  }

  @override
  int get hashCode => Object.hash(
    sheetRowNumber,
    exercise,
    sets,
    reps,
    rpe,
    rest,
    tempo,
    notes,
    workout,
    isBackup,
  );

  @override
  String toString() {
    return 'WorkoutSlot('
        'sheetRowNumber: $sheetRowNumber, '
        'exercise: $exercise, '
        'sets: $sets, '
        'reps: $reps, '
        'rpe: $rpe, '
        'rest: $rest, '
        'tempo: $tempo, '
        'notes: $notes, '
        'workout: $workout, '
        'isBackup: $isBackup'
        ')';
  }
}

ParsedActiveSheet parseActiveSheet(ActiveSheetInput sheet) {
  if (sheet.rows.isEmpty) {
    return ParsedActiveSheet(slots: const []);
  }

  final columns = _FixedColumnIndexes.fromHeader(sheet.rows.first);
  final slots = <WorkoutSlot>[];

  for (var rowIndex = 1; rowIndex < sheet.rows.length; rowIndex += 1) {
    final sheetRowNumber = rowIndex + 1;
    if (sheet.mergedFirstColumnRows.contains(sheetRowNumber)) {
      continue;
    }

    final row = sheet.rows[rowIndex];
    final exercise = _cell(row, columns.exercise);
    if (exercise.trim().isEmpty) {
      continue;
    }

    final workout = _cell(row, columns.workout).trim();
    slots.add(
      WorkoutSlot(
        sheetRowNumber: sheetRowNumber,
        exercise: exercise,
        sets: _cell(row, columns.sets),
        reps: _cell(row, columns.reps),
        rpe: _cell(row, columns.rpe),
        rest: _cell(row, columns.rest),
        tempo: _cell(row, columns.tempo),
        notes: _cell(row, columns.notes),
        workout: workout.isEmpty ? defaultWorkoutName : workout,
        isBackup: _isTrue(_cell(row, columns.isBackup)),
      ),
    );
  }

  return ParsedActiveSheet(slots: slots);
}

String _cell(List<String> row, int index) {
  if (index < 0 || index >= row.length) {
    return '';
  }
  return row[index];
}

bool _isTrue(String value) {
  return value.trim().toLowerCase() == 'true';
}

class _FixedColumnIndexes {
  const _FixedColumnIndexes({
    required this.exercise,
    required this.sets,
    required this.reps,
    required this.rpe,
    required this.rest,
    required this.tempo,
    required this.notes,
    required this.workout,
    required this.isBackup,
  });

  factory _FixedColumnIndexes.fromHeader(List<String> header) {
    final indexes = <String, int>{};
    for (var index = 0; index < header.length; index += 1) {
      indexes[header[index]] = index;
    }

    return _FixedColumnIndexes(
      exercise: indexes['Exercise'] ?? 0,
      sets: indexes['Sets'] ?? 1,
      reps: indexes['Reps'] ?? 2,
      rpe: indexes['RPE'] ?? 3,
      rest: indexes['Rest'] ?? 4,
      tempo: indexes['Tempo'] ?? 5,
      notes: indexes['Notes'] ?? 6,
      workout: indexes['Workout'] ?? 7,
      isBackup: indexes['is_backup'] ?? 8,
    );
  }

  final int exercise;
  final int sets;
  final int reps;
  final int rpe;
  final int rest;
  final int tempo;
  final int notes;
  final int workout;
  final int isBackup;
}
