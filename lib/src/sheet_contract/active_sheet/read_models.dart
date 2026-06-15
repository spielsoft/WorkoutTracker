part of '../active_sheet.dart';

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
  const ExerciseTargets({
    required this.sets,
    required this.reps,
    required this.rpe,
    required this.tempo,
  });

  final String sets;
  final String reps;
  final String rpe;
  final String tempo;
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
    required this.notation,
  });

  final int setNumber;
  final String setLabel;
  final int sheetColumnNumber;
  final String rawValue;
  final SetNotation notation;
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

  WorkoutOverview buildWorkoutOverview({
    required String workout,
    required String historyBlockLabel,
  }) {
    final block = sheet.selectHistoryBlock(historyBlockLabel);
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

  ExerciseLoggingContext buildExerciseLoggingContext({
    required int primarySheetRowNumber,
    required int selectedSheetRowNumber,
    required String historyBlockLabel,
  }) {
    final primary = sheet.primarySlots.firstWhere(
      (slot) => slot.sheetRowNumber == primarySheetRowNumber,
    );
    final choices = [primary, ...primary.backups];
    final selected = choices.firstWhere(
      (slot) => slot.sheetRowNumber == selectedSheetRowNumber,
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
        reps: selected.reps,
        rpe: selected.rpe,
        tempo: selected.tempo,
      ),
      selectedHistory: _rowHistoryBlock(
        label: historyBlockLabel,
        sheetRowNumber: selected.sheetRowNumber,
      ),
      recentHistoryBlocks: _recentRowHistoryBlocks(selected.sheetRowNumber),
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
          _historyEntry(block.setColumns[index], row, setNumber: index + 1),
      ],
    );
  }

  RowHistoryEntry _historyEntry(
    HistorySetColumn column,
    List<String> row, {
    required int setNumber,
  }) {
    final value = _cell(row, column.sheetColumnNumber - 1);
    return RowHistoryEntry(
      setNumber: setNumber,
      setLabel: column.label,
      sheetColumnNumber: column.sheetColumnNumber,
      rawValue: value,
      notation: parseSetNotation(value),
    );
  }

  List<RowHistoryBlock> _recentRowHistoryBlocks(int sheetRowNumber) {
    final row = sheet._sheetRow(sheetRowNumber);
    final blocks = <RowHistoryBlock>[];
    for (final block in sheet.historyBlocks) {
      if (!_hasHistoryInRow(row, block)) {
        continue;
      }
      blocks.add(
        _rowHistoryBlock(label: block.label, sheetRowNumber: sheetRowNumber),
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
