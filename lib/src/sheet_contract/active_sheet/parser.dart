part of '../active_sheet.dart';

ParsedActiveSheet parseActiveSheet(ActiveSheetInput sheet) {
  if (sheet.rows.isEmpty) {
    return ParsedActiveSheet._(slots: const []);
  }

  final columns = _FixedColumnIndexes.fromHeader(sheet.rows.first);
  final schemaViolations = <SchemaViolation>[
    ..._fixedColumnViolations(sheet.rows.first),
    ..._historyBlockViolations(
      header: sheet.rows.first,
      setHeader: sheet.rows.length > 1 ? sheet.rows[1] : const [],
      firstHistoryColumn: columns.isBackup + 1,
    ),
  ];
  final historyBlocks = _discoverHistoryBlocks(
    header: sheet.rows.first,
    setHeader: sheet.rows.length > 1 ? sheet.rows[1] : const [],
    firstHistoryColumn: columns.isBackup + 1,
  );
  final slots = <WorkoutSlot>[];
  final primarySlotBuilders = <_PrimarySlotBuilder>[];
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
    final logFormat = parseLogFormat(_logFormatCell(row, columns));
    final slot = WorkoutSlot(
      sheetRowNumber: sheetRowNumber,
      exercise: exercise,
      sets: _cell(row, columns.sets),
      reps: _cell(row, columns.reps),
      rpe: _cell(row, columns.rpe),
      rest: _cell(row, columns.rest),
      tempo: _cell(row, columns.tempo),
      notes: _cell(row, columns.notes),
      logFormat: logFormat,
      workout: workout.isEmpty ? defaultWorkoutName : workout,
      isBackup: _isTrue(_cell(row, columns.isBackup)),
    );
    slots.add(slot);

    if (logFormat case InvalidLogFormat(:final errors)) {
      schemaViolations.add(
        SchemaViolation(
          sheetRowNumber: slot.sheetRowNumber,
          workout: slot.workout,
          message: 'Invalid Log Format: ${errors.join(' ')}',
        ),
      );
    }

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

  return ParsedActiveSheet._(
    slots: slots,
    historyBlocks: historyBlocks,
    primarySlots: primarySlotBuilders.map((builder) => builder.toSlot()),
    schemaViolations: schemaViolations,
    formulaHealingIssues: _formulaHealingIssues(sheet, columns),
    formulaExerciseColumnNumbers: sheet.exercisesRows.isEmpty
        ? const {}
        : {
            for (final formulaColumn in _formulaDrivenColumns(
              columns,
              _ExercisesColumnIndexes.fromHeader(sheet.exercisesRows.first),
            ))
              formulaColumn.activeColumnName:
                  formulaColumn.exercisesSheetColumnIndex + 1,
          },
    rows: sheet.rows,
    exercisesRows: sheet.exercisesRows,
    cellFormulas: sheet.cellFormulas,
  );
}

List<SchemaViolation> _fixedColumnViolations(List<String> header) {
  final violations = <SchemaViolation>[];
  for (var index = 0; index < activeSheetFixedColumns.length; index += 1) {
    if (_cell(header, index) == activeSheetFixedColumns[index]) {
      continue;
    }
    violations.add(
      SchemaViolation(
        sheetRowNumber: 1,
        workout: defaultWorkoutName,
        message:
            'Fixed column ${index + 1} must be '
            '"${activeSheetFixedColumns[index]}".',
      ),
    );
  }
  return violations;
}

List<SchemaViolation> _historyBlockViolations({
  required List<String> header,
  required List<String> setHeader,
  required int firstHistoryColumn,
}) {
  final violations = <SchemaViolation>[];
  final seenBlockLabels = <String>{};
  final builders = <_HistoryBlockValidationBuilder>[];

  for (
    var columnIndex = firstHistoryColumn;
    columnIndex < header.length;
    columnIndex += 1
  ) {
    final blockLabel = header[columnIndex].trim();
    if (blockLabel.isNotEmpty) {
      if (!seenBlockLabels.add(blockLabel)) {
        violations.add(
          SchemaViolation(
            sheetRowNumber: 1,
            workout: defaultWorkoutName,
            message: 'Duplicate history block label: $blockLabel.',
          ),
        );
      }
      builders.add(_HistoryBlockValidationBuilder(blockLabel));
    }

    final setLabel = _cell(setHeader, columnIndex).trim();
    if (setLabel.isEmpty) {
      continue;
    }
    if (builders.isEmpty) {
      violations.add(
        SchemaViolation(
          sheetRowNumber: 2,
          workout: defaultWorkoutName,
          message: 'History set column $setLabel has no history block label.',
        ),
      );
      continue;
    }
    builders.last.setLabels.add(setLabel);
  }

  for (final builder in builders) {
    if (builder.setLabels.isEmpty) {
      violations.add(
        SchemaViolation(
          sheetRowNumber: 1,
          workout: defaultWorkoutName,
          message: 'History block ${builder.label} has no set columns.',
        ),
      );
      continue;
    }

    for (var index = 0; index < builder.setLabels.length; index += 1) {
      final expected = 'S${index + 1}';
      final actual = builder.setLabels[index];
      if (actual != expected) {
        violations.add(
          SchemaViolation(
            sheetRowNumber: 2,
            workout: defaultWorkoutName,
            message:
                'History block ${builder.label} skips set label '
                '$expected before $actual.',
          ),
        );
        break;
      }
    }
  }

  return violations;
}

class _HistoryBlockValidationBuilder {
  _HistoryBlockValidationBuilder(this.label);

  final String label;
  final List<String> setLabels = [];
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

class _FixedColumnIndexes {
  const _FixedColumnIndexes({
    required this.exercise,
    required this.sets,
    required this.reps,
    required this.rpe,
    required this.rest,
    required this.tempo,
    required this.notes,
    required this.logFormat,
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
      logFormat: indexes['Log Format'],
      workout:
          indexes['Workout'] ?? (indexes.containsKey('Log Format') ? 8 : 7),
      isBackup:
          indexes['is_backup'] ?? (indexes.containsKey('Log Format') ? 9 : 8),
    );
  }

  final int exercise;
  final int sets;
  final int reps;
  final int rpe;
  final int rest;
  final int tempo;
  final int notes;
  final int? logFormat;
  final int workout;
  final int isBackup;
}

String _logFormatCell(List<String> row, _FixedColumnIndexes columns) {
  final logFormatColumn = columns.logFormat;
  if (logFormatColumn == null) {
    return '';
  }
  return _cell(row, logFormatColumn);
}

class _ExercisesColumnIndexes {
  const _ExercisesColumnIndexes({
    required this.exercise,
    required this.description,
    required this.defaultSets,
    required this.defaultReps,
    required this.defaultRpe,
    required this.defaultRest,
    required this.defaultTempo,
    required this.notes,
    required this.logFormat,
  });

  factory _ExercisesColumnIndexes.fromHeader(List<String> header) {
    final indexes = <String, int>{};
    for (var index = 0; index < header.length; index += 1) {
      indexes[header[index]] = index;
    }

    return _ExercisesColumnIndexes(
      exercise: indexes['Exercise'] ?? 0,
      description: indexes['Description'] ?? 1,
      defaultSets: indexes['Default Sets'] ?? 2,
      defaultReps: indexes['Default Reps'] ?? 3,
      defaultRpe: indexes['Default RPE'] ?? 4,
      defaultRest: indexes['Default Rest'] ?? 5,
      defaultTempo: indexes['Default Tempo'] ?? 6,
      notes: indexes['Notes'] ?? 7,
      logFormat: indexes['Log Format'],
    );
  }

  final int exercise;
  final int description;
  final int defaultSets;
  final int defaultReps;
  final int defaultRpe;
  final int defaultRest;
  final int defaultTempo;
  final int notes;
  final int? logFormat;
}
