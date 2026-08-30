part of '../active.dart';

class WorkoutSlot {
  WorkoutSlot({
    required this.sheetRowNumber,
    required this.exercise,
    required this.sets,
    required this.rest,
    required this.tempo,
    required Map<String, String> targetValues,
    required this.notes,
    required this.logFormat,
    required this.workout,
    required this.isBackup,
    Iterable<WorkoutSlot> backups = const [],
  }) : targetValues = Map<String, String>.unmodifiable(targetValues),
       backups = List<WorkoutSlot>.unmodifiable(backups);

  final int sheetRowNumber;
  final String exercise;
  final String sets;
  final String rest;
  final String tempo;
  final Map<String, String> targetValues;
  final String notes;
  final LogFormatParseResult logFormat;
  final String workout;
  final bool isBackup;
  final List<WorkoutSlot> backups;

  WorkoutSlot _withBackups(Iterable<WorkoutSlot> backups) {
    return WorkoutSlot(
      sheetRowNumber: sheetRowNumber,
      exercise: exercise,
      sets: sets,
      rest: rest,
      tempo: tempo,
      targetValues: targetValues,
      notes: notes,
      logFormat: logFormat,
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
            rest == other.rest &&
            tempo == other.tempo &&
            _stringMapEquals(targetValues, other.targetValues) &&
            notes == other.notes &&
            logFormat == other.logFormat &&
            workout == other.workout &&
            isBackup == other.isBackup &&
            _listEquals(backups, other.backups);
  }

  @override
  int get hashCode => Object.hash(
    sheetRowNumber,
    exercise,
    sets,
    rest,
    tempo,
    Object.hashAll(targetValues.entries),
    notes,
    logFormat,
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
        'rest: $rest, '
        'tempo: $tempo, '
        'targetValues: $targetValues, '
        'notes: $notes, '
        'logFormat: $logFormat, '
        'workout: $workout, '
        'isBackup: $isBackup, '
        'backups: $backups'
        ')';
  }
}

class _PrimarySlotBuilder {
  _PrimarySlotBuilder(this.primary);

  final WorkoutSlot primary;
  final List<WorkoutSlot> backups = [];

  WorkoutSlot toSlot() => primary._withBackups(backups);
}
