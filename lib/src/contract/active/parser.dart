part of '../active.dart';

ParsedActiveSheet parseActiveSheet(ActiveSheetInput sheet) {
  final parseFormat = sheet.schemaVersion == priorWbkVersion
      ? parseLegacyLogFormat
      : parseLogFormat;
  final versionViolations = _versionViolations(sheet);
  final validateExercises =
      sheet.validateWorkbook || sheet.exercisesRows.isNotEmpty;
  final exerciseHeaderViolations = validateExercises
      ? _exerciseColumnViolations(sheet)
      : const <SchemaViolation>[];
  final exerciseColumns = validateExercises && exerciseHeaderViolations.isEmpty
      ? _ExercisesColumnIndexes.fromHeader(sheet.exercisesRows.first)
      : null;
  final exerciseViolations = [
    ...exerciseHeaderViolations,
    if (exerciseColumns != null)
      ..._exerciseValueViolations(
        sheet.exercisesRows,
        exerciseColumns,
        parseFormat,
      ),
  ];
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
        ...versionViolations,
      ],
      exerciseColumns: exerciseColumns,
      columns: null,
      rows: sheet.rows,
      exercisesRows: sheet.exercisesRows,
      cellFormulas: sheet.cellFormulas,
      parseFormat: parseFormat,
    );
  }

  final fixedViolations = _fixedColumnViolations(sheet.rows.first);
  final schemaViolations = <SchemaViolation>[
    ...versionViolations,
    ...fixedViolations,
    ...exerciseViolations,
    ..._historyBlockViolations(
      header: sheet.rows.first,
      setHeader: sheet.rows.length > 1 ? sheet.rows[1] : const [],
      firstHistoryColumn: activeSheetFixedColumns.length,
    ),
  ];
  if (fixedViolations.isNotEmpty) {
    return ParsedActiveSheet._(
      slots: const [],
      schemaViolations: schemaViolations,
      exerciseColumns: exerciseColumns,
      columns: null,
      rows: sheet.rows,
      exercisesRows: sheet.exercisesRows,
      cellFormulas: sheet.cellFormulas,
      parseFormat: parseFormat,
    );
  }

  final columns = _FixedColumnIndexes.fromHeader(sheet.rows.first);
  final historyBlocks = _discoverHistoryBlocks(
    header: sheet.rows.first,
    setHeader: sheet.rows.length > 1 ? sheet.rows[1] : const [],
    firstHistoryColumn: columns.isExercise + 1,
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
    final logFormat = parseFormat(_logFormatCell(row, columns));
    final targetValues = logFormat is ParsedLogFormat
        ? logFormat.parseValues(_cell(row, columns.targets))
        : null;
    final slot = WorkoutSlot(
      sheetRowNumber: sheetRowNumber,
      exercise: exercise,
      sets: _cell(row, columns.sets),
      rest: _cell(row, columns.rest),
      tempo: _cell(row, columns.tempo),
      targetValues: targetValues ?? const {},
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
    if (logFormat is ParsedLogFormat && targetValues == null) {
      schemaViolations.add(
        SchemaViolation(
          sheetRowNumber: slot.sheetRowNumber,
          workout: slot.workout,
          message: 'Targets do not match Log Format.',
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
    columns: columns,
    rows: sheet.rows,
    exercisesRows: sheet.exercisesRows,
    cellFormulas: sheet.cellFormulas,
    parseFormat: parseFormat,
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
  final required = _exercisesColumnsFor(sheet.schemaVersion);
  final violations = <SchemaViolation>[];
  for (var i = 0; i < required.length; i += 1) {
    final expected = required[i];
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
  for (var i = required.length; i < header.length; i += 1) {
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

List<SchemaViolation> _exerciseValueViolations(
  List<List<String>> rows,
  _ExercisesColumnIndexes columns,
  LogFormatParseResult Function(String) parseFormat,
) {
  final violations = <SchemaViolation>[];
  for (var index = 1; index < rows.length; index += 1) {
    final row = rows[index];
    if (_cell(row, columns.exercise).trim().isEmpty) continue;
    final format = parseFormat(_cell(row, columns.logFormat));
    if (format case InvalidLogFormat(:final errors)) {
      violations.add(
        SchemaViolation(
          sheetRowNumber: index + 1,
          workout: defaultWorkoutName,
          message: 'Exercises Log Format is invalid: ${errors.join(' ')}',
        ),
      );
      continue;
    }
    if (format is ParsedLogFormat &&
        format.parseValues(_cell(row, columns.defaultValues)) == null) {
      violations.add(
        SchemaViolation(
          sheetRowNumber: index + 1,
          workout: defaultWorkoutName,
          message: 'Exercises Default Values do not match Log Format.',
        ),
      );
    }
    if (_timerFieldsMessage(row, columns, format) case final message?) {
      violations.add(
        SchemaViolation(
          sheetRowNumber: index + 1,
          workout: defaultWorkoutName,
          message: message,
        ),
      );
    }
  }
  return violations;
}

String? _timerFieldsMessage(
  List<String> row,
  _ExercisesColumnIndexes columns,
  LogFormatParseResult format,
) {
  final column = columns.timerFields;
  if (column == null) {
    return null;
  }
  final labels = _parseTimerFields(_cell(row, column));
  if (labels == null) {
    return 'Exercises Timer Fields is not a list of quoted labels.';
  }
  if (labels.toSet().length != labels.length) {
    return 'Exercises Timer Fields repeats a label.';
  }
  if (format is ParsedLogFormat &&
      labels.any((label) => !format.fieldLabels.contains(label))) {
    return 'Exercises Timer Fields do not match Log Format.';
  }
  return null;
}

List<SchemaViolation> _versionViolations(ActiveSheetInput sheet) {
  if (!sheet.validateWorkbook) return const [];
  return wbkVersionViolations(sheet.schemaVersion);
}

/// Schema violations caused solely by a workbook's declared version.
///
/// The app reads [currentWbkVersion] and routes [priorWbkVersion] to its
/// format conversion. Every other declared version is rejected, including the
/// [convertedWbkVersion] that conversion produces, because that result has no
/// `Timer Fields` column and only its owner can add one.
List<SchemaViolation> wbkVersionViolations(String? version) {
  if (version == null) {
    return const [
      SchemaViolation(
        sheetRowNumber: 1,
        workout: defaultWorkoutName,
        message: 'Workbook schema version metadata is missing.',
      ),
    ];
  }
  if (version != priorWbkVersion && version != currentWbkVersion) {
    return [
      SchemaViolation(
        sheetRowNumber: 1,
        workout: defaultWorkoutName,
        message: 'Workbook schema version "$version" is unsupported.',
      ),
    ];
  }
  return const [];
}

/// The Exercises columns a workbook declaring [schemaVersion] must have.
List<String> _exercisesColumnsFor(String? schemaVersion) {
  return schemaVersion == currentWbkVersion
      ? exercisesSheetColumns
      : priorExercisesSheetColumns;
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
    required this.rest,
    required this.tempo,
    required this.targets,
    required this.notes,
    required this.logFormat,
    required this.workout,
    required this.isBackup,
    required this.isExercise,
  });

  factory _FixedColumnIndexes.fromHeader(List<String> header) {
    final indexes = <String, int>{};
    for (var index = 0; index < header.length; index += 1) {
      indexes[header[index]] = index;
    }

    return _FixedColumnIndexes(
      exercise: indexes['Exercise']!,
      sets: indexes['Sets']!,
      rest: indexes['Rest']!,
      tempo: indexes['Tempo']!,
      targets: indexes['Targets']!,
      notes: indexes['Notes']!,
      logFormat: indexes['Log Format']!,
      workout: indexes['Workout']!,
      isBackup: indexes['is_backup']!,
      isExercise: indexes['is_exercise']!,
    );
  }

  final int exercise;
  final int sets;
  final int rest;
  final int tempo;
  final int targets;
  final int notes;
  final int logFormat;
  final int workout;
  final int isBackup;
  final int isExercise;
}

String _logFormatCell(List<String> row, _FixedColumnIndexes columns) {
  return _cell(row, columns.logFormat);
}

class _ExercisesColumnIndexes {
  const _ExercisesColumnIndexes({
    required this.exercise,
    required this.description,
    required this.defaultSets,
    required this.defaultRest,
    required this.defaultTempo,
    required this.notes,
    required this.logFormat,
    required this.defaultValues,
    required this.timerFields,
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
      defaultRest: indexes['Default Rest']!,
      defaultTempo: indexes['Default Tempo']!,
      notes: indexes['Notes']!,
      logFormat: indexes['Log Format']!,
      defaultValues: indexes['Default Values']!,
      timerFields: indexes[timerFieldsColumn],
    );
  }

  final int exercise;
  final int description;
  final int defaultSets;
  final int defaultRest;
  final int defaultTempo;
  final int notes;
  final int logFormat;
  final int defaultValues;

  /// Null for the pre-1.1 Exercises contract, which has no timer column.
  final int? timerFields;
}
