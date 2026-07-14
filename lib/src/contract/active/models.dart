part of '../active.dart';

class WorkoutOverview {
  WorkoutOverview({
    required this.workout,
    Iterable<WorkoutOverviewSlot> slots = const [],
  }) : slots = List<WorkoutOverviewSlot>.unmodifiable(slots);

  final String workout;
  final List<WorkoutOverviewSlot> slots;
}

class WorkoutOverviewSlot {
  WorkoutOverviewSlot({
    required this.sheetRowNumber,
    required this.exercise,
    required this.setCount,
    Iterable<WorkoutChoice> backups = const [],
  }) : backups = List<WorkoutChoice>.unmodifiable(backups);

  final int sheetRowNumber;
  final String exercise;
  final int setCount;
  final List<WorkoutChoice> backups;
}

class WorkoutChoice {
  const WorkoutChoice({
    required this.sheetRowNumber,
    required this.exercise,
    required this.isBackup,
    required this.logFormat,
  });

  final int sheetRowNumber;
  final String exercise;
  final bool isBackup;
  final LogFormatParseResult logFormat;
}

class CanonicalExercise {
  CanonicalExercise({
    required this.sheetRowNumber,
    required this.exercise,
    this.description = '',
    this.defaultSets = '',
    this.defaultRest = '',
    this.defaultTempo = '',
    this.notes = '',
    this.logFormat = defaultExerciseLogFormat,
    LogFormatParseResult? format,
    Map<String, String> defaultValues = const {},
  }) : format = format ?? parseLogFormat(logFormat),
       defaultValues = Map<String, String>.unmodifiable(defaultValues);

  final int sheetRowNumber;
  final String exercise;
  final String description;
  final String defaultSets;
  final String defaultRest;
  final String defaultTempo;
  final String notes;
  final String logFormat;
  final LogFormatParseResult format;
  final Map<String, String> defaultValues;

  String get displayName {
    final trimmed = exercise.trim();
    return trimmed.isEmpty ? 'Row $sheetRowNumber' : trimmed;
  }
}

class ExerciseLoggingContext {
  ExerciseLoggingContext({
    required this.selectedChoice,
    Iterable<WorkoutChoice> choices = const [],
    required this.notes,
    required this.rest,
    required this.logFormat,
    required this.targets,
    required this.selectedHistory,
    Iterable<RowHistoryBlock> recentHistoryBlocks = const [],
  }) : choices = List<WorkoutChoice>.unmodifiable(choices),
       recentHistoryBlocks = List<RowHistoryBlock>.unmodifiable(
         recentHistoryBlocks,
       );

  final WorkoutChoice selectedChoice;
  final List<WorkoutChoice> choices;
  final String notes;
  final String rest;
  final LogFormatParseResult logFormat;
  final ExerciseTargets targets;
  final RowHistoryBlock selectedHistory;
  final List<RowHistoryBlock> recentHistoryBlocks;
}

class ExerciseTargets {
  ExerciseTargets({
    required this.sets,
    required this.tempo,
    required Map<String, String> values,
  }) : values = Map<String, String>.unmodifiable(values);

  final String sets;
  final String tempo;
  final Map<String, String> values;
}

class RowHistoryBlock {
  RowHistoryBlock({
    required this.label,
    Iterable<RowHistoryEntry> entries = const [],
  }) : entries = List<RowHistoryEntry>.unmodifiable(entries);

  final String label;
  final List<RowHistoryEntry> entries;
}

class RowHistoryEntry {
  const RowHistoryEntry({
    required this.setNumber,
    required this.setLabel,
    required this.sheetColumnNumber,
    required this.rawValue,
    required this.logEntry,
  });

  final int setNumber;
  final String setLabel;
  final int sheetColumnNumber;
  final String rawValue;
  final LogEntry logEntry;
}

class _WorkoutReadModelBuilder {
  _WorkoutReadModelBuilder(this.sheet);

  final ParsedActiveSheet sheet;

  List<String> get selectableWorkouts {
    final workouts = <String>[];
    for (final slot in sheet.primarySlots) {
      if (!workouts.contains(slot.workout)) {
        workouts.add(slot.workout);
      }
    }
    return List<String>.unmodifiable(workouts);
  }

  List<CanonicalExercise> get canonicalExercises {
    final columns = sheet._exerciseColumns;
    if (columns == null || sheet._exercisesRows.length < 2) {
      return const [];
    }
    return [
      for (
        var rowIndex = 1;
        rowIndex < sheet._exercisesRows.length;
        rowIndex += 1
      )
        if (_cell(
          sheet._exercisesRows[rowIndex],
          columns.exercise,
        ).trim().isNotEmpty)
          CanonicalExercise(
            sheetRowNumber: rowIndex + 1,
            exercise: _cell(sheet._exercisesRows[rowIndex], columns.exercise),
            description: _cell(
              sheet._exercisesRows[rowIndex],
              columns.description,
            ),
            defaultSets: _cell(
              sheet._exercisesRows[rowIndex],
              columns.defaultSets,
            ),
            defaultRest: _cell(
              sheet._exercisesRows[rowIndex],
              columns.defaultRest,
            ),
            defaultTempo: _cell(
              sheet._exercisesRows[rowIndex],
              columns.defaultTempo,
            ),
            notes: _cell(sheet._exercisesRows[rowIndex], columns.notes),
            logFormat: _cell(sheet._exercisesRows[rowIndex], columns.logFormat),
            format: sheet._parseFormat(
              _cell(sheet._exercisesRows[rowIndex], columns.logFormat),
            ),
            defaultValues: _defaultValues(
              sheet._exercisesRows[rowIndex],
              columns,
              sheet._parseFormat,
            ),
          ),
    ];
  }

  WorkoutOverview buildWorkoutOverview({
    required String workout,
    required String blockLabel,
  }) {
    final block = sheet.selectHistoryBlock(blockLabel);
    return WorkoutOverview(
      workout: workout,
      slots: sheet.primarySlots
          .where((slot) => slot.workout == workout)
          .map(
            (slot) => WorkoutOverviewSlot(
              sheetRowNumber: slot.sheetRowNumber,
              exercise: slot.exercise,
              setCount: _setCountForSlot(slot, block),
              backups: slot.backups.map(_choiceForSlot),
            ),
          ),
    );
  }

  ExerciseLoggingContext buildLoggingContext({
    required int primaryRow,
    required int selectedRow,
    required String blockLabel,
  }) {
    final primary = sheet.primarySlots.firstWhere(
      (slot) => slot.sheetRowNumber == primaryRow,
    );
    final choices = [primary, ...primary.backups];
    final selected = choices.firstWhere(
      (slot) => slot.sheetRowNumber == selectedRow,
      orElse: () => primary,
    );

    return ExerciseLoggingContext(
      selectedChoice: _choiceForSlot(selected),
      choices: choices.map(_choiceForSlot),
      notes: selected.notes,
      rest: selected.rest,
      logFormat: selected.logFormat,
      targets: ExerciseTargets(
        sets: selected.sets,
        tempo: selected.tempo,
        values: selected.targetValues,
      ),
      selectedHistory: _rowHistoryBlock(
        label: blockLabel,
        sheetRowNumber: selected.sheetRowNumber,
        logFormat: selected.logFormat,
      ),
      recentHistoryBlocks: _recentRowHistoryBlocks(
        selected.sheetRowNumber,
        selected.logFormat,
      ),
    );
  }

  int _setCountForSlot(WorkoutSlot slot, HistoryBlock? block) {
    if (block == null) {
      return 0;
    }
    return _setCountForRow(slot.sheetRowNumber, block) +
        slot.backups.fold<int>(
          0,
          (count, backup) =>
              count + _setCountForRow(backup.sheetRowNumber, block),
        );
  }

  int _setCountForRow(int sheetRowNumber, HistoryBlock block) {
    final row = sheet._sheetRow(sheetRowNumber);
    return block.setColumns
        .where(
          (column) =>
              _cell(row, column.sheetColumnNumber - 1).trim().isNotEmpty,
        )
        .length;
  }

  RowHistoryBlock _rowHistoryBlock({
    required String label,
    required int sheetRowNumber,
    required LogFormatParseResult logFormat,
  }) {
    final block = sheet.selectHistoryBlock(label);
    if (block == null) {
      return RowHistoryBlock(label: label);
    }

    final row = sheet._sheetRow(sheetRowNumber);
    return RowHistoryBlock(
      label: block.label,
      entries: [
        for (var index = 0; index < block.setColumns.length; index += 1)
          _historyEntry(
            block.setColumns[index],
            row,
            logFormat: logFormat,
            setNumber: index + 1,
          ),
      ],
    );
  }

  RowHistoryEntry _historyEntry(
    HistorySetColumn column,
    List<String> row, {
    required LogFormatParseResult logFormat,
    required int setNumber,
  }) {
    final value = _cell(row, column.sheetColumnNumber - 1);
    return RowHistoryEntry(
      setNumber: setNumber,
      setLabel: column.label,
      sheetColumnNumber: column.sheetColumnNumber,
      rawValue: value,
      logEntry: logFormat is ParsedLogFormat
          ? parseLogEntry(logFormat, value)
          : RawLogEntry(value),
    );
  }

  List<RowHistoryBlock> _recentRowHistoryBlocks(
    int sheetRowNumber,
    LogFormatParseResult logFormat,
  ) {
    final row = sheet._sheetRow(sheetRowNumber);
    final blocks = <RowHistoryBlock>[];
    for (final block in sheet.historyBlocks) {
      if (!_hasHistoryInRow(row, block)) {
        continue;
      }
      blocks.add(
        _rowHistoryBlock(
          label: block.label,
          sheetRowNumber: sheetRowNumber,
          logFormat: logFormat,
        ),
      );
      if (blocks.length == 3) {
        break;
      }
    }
    return List<RowHistoryBlock>.unmodifiable(blocks);
  }

  bool _hasHistoryInRow(List<String> row, HistoryBlock block) {
    return block.setColumns.any(
      (column) => _cell(row, column.sheetColumnNumber - 1).trim().isNotEmpty,
    );
  }
}

Map<String, String> _defaultValues(
  List<String> row,
  _ExercisesColumnIndexes columns,
  LogFormatParseResult Function(String) parseFormat,
) {
  final parsed = parseFormat(_cell(row, columns.logFormat));
  if (parsed is! ParsedLogFormat) return const {};
  return parsed.parseValues(_cell(row, columns.defaultValues)) ?? const {};
}
