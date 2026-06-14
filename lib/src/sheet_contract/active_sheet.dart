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
  ParsedActiveSheet({
    required Iterable<WorkoutSlot> slots,
    Iterable<WorkoutSlot> primarySlots = const [],
    Iterable<SchemaViolation> schemaViolations = const [],
  }) : slots = List<WorkoutSlot>.unmodifiable(slots),
       primarySlots = List<WorkoutSlot>.unmodifiable(primarySlots),
       schemaViolations = List<SchemaViolation>.unmodifiable(schemaViolations);

  final List<WorkoutSlot> slots;
  final List<WorkoutSlot> primarySlots;
  final List<SchemaViolation> schemaViolations;
}

class SchemaViolation {
  const SchemaViolation({
    required this.sheetRowNumber,
    required this.workout,
    required this.message,
  });

  final int sheetRowNumber;
  final String workout;
  final String message;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is SchemaViolation &&
            sheetRowNumber == other.sheetRowNumber &&
            workout == other.workout &&
            message == other.message;
  }

  @override
  int get hashCode => Object.hash(sheetRowNumber, workout, message);

  @override
  String toString() {
    return 'SchemaViolation('
        'sheetRowNumber: $sheetRowNumber, '
        'workout: $workout, '
        'message: $message'
        ')';
  }
}

class WorkoutSlot {
  WorkoutSlot({
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
    Iterable<WorkoutSlot> backups = const [],
  }) : backups = List<WorkoutSlot>.unmodifiable(backups);

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
  final List<WorkoutSlot> backups;

  WorkoutSlot _withBackups(Iterable<WorkoutSlot> backups) {
    return WorkoutSlot(
      sheetRowNumber: sheetRowNumber,
      exercise: exercise,
      sets: sets,
      reps: reps,
      rpe: rpe,
      rest: rest,
      tempo: tempo,
      notes: notes,
      workout: workout,
      isBackup: isBackup,
      backups: backups,
    );
  }

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
            isBackup == other.isBackup &&
            _listEquals(backups, other.backups);
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
    Object.hashAll(backups),
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
        'isBackup: $isBackup, '
        'backups: $backups'
        ')';
  }
}

ParsedActiveSheet parseActiveSheet(ActiveSheetInput sheet) {
  if (sheet.rows.isEmpty) {
    return ParsedActiveSheet(slots: const []);
  }

  final columns = _FixedColumnIndexes.fromHeader(sheet.rows.first);
  final slots = <WorkoutSlot>[];
  final primarySlotBuilders = <_PrimarySlotBuilder>[];
  final schemaViolations = <SchemaViolation>[];
  _PrimarySlotBuilder? currentPrimary;

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
    final slot = WorkoutSlot(
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
    );
    slots.add(slot);

    if (slot.isBackup) {
      final owner = currentPrimary?.primary.workout == slot.workout
          ? currentPrimary
          : null;
      if (owner == null) {
        schemaViolations.add(
          SchemaViolation(
            sheetRowNumber: slot.sheetRowNumber,
            workout: slot.workout,
            message:
                'Backup row has no preceding primary row in the same workout.',
          ),
        );
      } else {
        owner.backups.add(slot);
      }
      continue;
    }

    final builder = _PrimarySlotBuilder(slot);
    primarySlotBuilders.add(builder);
    currentPrimary = builder;
  }

  return ParsedActiveSheet(
    slots: slots,
    primarySlots: primarySlotBuilders.map((builder) => builder.toSlot()),
    schemaViolations: schemaViolations,
  );
}

class _PrimarySlotBuilder {
  _PrimarySlotBuilder(this.primary);

  final WorkoutSlot primary;
  final List<WorkoutSlot> backups = [];

  WorkoutSlot toSlot() => primary._withBackups(backups);
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

bool _listEquals<T>(List<T> first, List<T> second) {
  if (first.length != second.length) {
    return false;
  }

  for (var index = 0; index < first.length; index += 1) {
    if (first[index] != second[index]) {
      return false;
    }
  }
  return true;
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
