part of '../active.dart';

ParsedActiveSheet parseActiveSheet(ActiveSheetInput sheet) {
  final validateExercises =
      sheet.validateWorkbook || sheet.exercisesRows.isNotEmpty;
  final exerciseViolations = validateExercises
      ? _exerciseColumnViolations(sheet)
      : const <SchemaViolation>[];
  final exerciseColumns = validateExercises && exerciseViolations.isEmpty
      ? _ExercisesColumnIndexes.fromHeader(sheet.exercisesRows.first)
      : null;
  if (sheet.rows.isEmpty) {
    return ParsedActiveSheet._(
      slots: const [],
      schemaViolations: [
        const SchemaViolation(
          sheetRowNumber: 1,
          workout: defaultWorkoutName,
          message: 'The active sheet is empty and has no header row.',
        ),
        ...exerciseViolations,
      ],
      exerciseColumns: exerciseColumns,
      rows: sheet.rows,
      exercisesRows: sheet.exercisesRows,
      cellFormulas: sheet.cellFormulas,
    );
  }

  final columns = _FixedColumnIndexes.fromHeader(sheet.rows.first);
  final schemaViolations = <SchemaViolation>[
    ..._fixedColumnViolations(sheet.rows.first),
    ...exerciseViolations,
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
    healingIssues: exerciseColumns == null
        ? const []
        : _healingIssues(sheet, columns),
    exerciseFormulaColumns: exerciseColumns == null
        ? const {}
        : {
            for (final formulaColumn in _formulaDrivenColumns(
              columns,
              exerciseColumns,
            ))
              formulaColumn.activeColumnName:
                  formulaColumn.exerciseColumnIndex + 1,
          },
    exerciseColumns: exerciseColumns,
    rows: sheet.rows,
    exercisesRows: sheet.exercisesRows,
    cellFormulas: sheet.cellFormulas,
  );
}

List<SchemaViolation> _exerciseColumnViolations(ActiveSheetInput sheet) {
  if (!sheet.hasExercisesSheet) {
    return const [
      SchemaViolation(
        sheetRowNumber: 1,
        workout: defaultWorkoutName,
        message: 'The Exercises tab is missing.',
      ),
    ];
  }
  if (sheet.exercisesRows.isEmpty) {
    return const [
      SchemaViolation(
        sheetRowNumber: 1,
        workout: defaultWorkoutName,
        message: 'The Exercises tab is empty and has no header row.',
      ),
    ];
  }

  final header = sheet.exercisesRows.first;
  final violations = <SchemaViolation>[];
  for (var i = 0; i < exercisesSheetColumns.length; i += 1) {
    final expected = exercisesSheetColumns[i];
    if (_cell(header, i) == expected) {
      continue;
    }
    violations.add(
      SchemaViolation(
        sheetRowNumber: 1,
        workout: defaultWorkoutName,
        message: 'Exercises column ${i + 1} must be "$expected".',
      ),
    );
  }
  for (var i = exercisesSheetColumns.length; i < header.length; i += 1) {
    if (_cell(header, i).trim().isEmpty) {
      continue;
    }
    violations.add(
      SchemaViolation(
        sheetRowNumber: 1,
        workout: defaultWorkoutName,
        message: 'Exercises has an unsupported column "${header[i]}".',
      ),
    );
  }
  return violations;
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
  final builders = <_BlockValidationBuilder>[];
  final historyWidth = _historyHeaderWidth(
    header: header,
    setHeader: setHeader,
  );

  for (
    var columnIndex = firstHistoryColumn;
    columnIndex < historyWidth;
    columnIndex += 1
  ) {
    final blockLabel = _cell(header, columnIndex).trim();
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
      builders.add(_BlockValidationBuilder(blockLabel));
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

class _BlockValidationBuilder {
  _BlockValidationBuilder(this.label);

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
      exercise: indexes['Exercise']!,
      description: indexes['Description']!,
      defaultSets: indexes['Default Sets']!,
      defaultReps: indexes['Default Reps']!,
      defaultRpe: indexes['Default RPE']!,
      defaultRest: indexes['Default Rest']!,
      defaultTempo: indexes['Default Tempo']!,
      notes: indexes['Notes']!,
      logFormat: indexes['Log Format']!,
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
  final int logFormat;
}
