part of '../active.dart';

class ActiveSheetWritePlan {
  ActiveSheetWritePlan({
    Iterable<HistoryColumnInsertion> columnInsertions = const [],
    Iterable<RowInsertion> rowInsertions = const [],
    Iterable<RowDeletion> rowDeletions = const [],
    Iterable<CellUpdate> cellUpdates = const [],
    Iterable<WriteExpct> expectations = const [],
    this.nextSetPosition,
  }) : columnInsertions = List<HistoryColumnInsertion>.unmodifiable(
         columnInsertions,
       ),
       rowInsertions = List<RowInsertion>.unmodifiable(rowInsertions),
       rowDeletions = List<RowDeletion>.unmodifiable(rowDeletions),
       cellUpdates = List<CellUpdate>.unmodifiable(cellUpdates),
       expectations = List<WriteExpct>.unmodifiable(expectations);

  final List<HistoryColumnInsertion> columnInsertions;
  final List<RowInsertion> rowInsertions;
  final List<RowDeletion> rowDeletions;
  final List<CellUpdate> cellUpdates;
  final List<WriteExpct> expectations;
  final SetPosition? nextSetPosition;

  List<WriteRejection> writeRejections(ParsedActiveSheet sheet) {
    return [
      for (final expectation in expectations)
        ...expectation.writeRejections(sheet),
    ];
  }

  bool retainsLoggedSetWrite(ParsedActiveSheet sheet) {
    final next = nextSetPosition;
    if (next == null) {
      return true;
    }
    final savedSetNumber = next.setNumber - 1;
    if (savedSetNumber < 1) {
      return true;
    }
    for (final update in cellUpdates) {
      if (update.sheetRowNumber == next.sheetRowNumber &&
          update.valueKind == CellUpdateValueKind.literalText) {
        return _cell(
              sheet._sheetRow(update.sheetRowNumber),
              update.sheetColumnNumber - 1,
            ).trim() ==
            update.value.trim();
      }
    }
    return false;
  }

  List<List<String>> previewRowsAfterApplying(Iterable<Iterable<String>> rows) {
    return _PlanPreview.active(this, rows);
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is ActiveSheetWritePlan &&
            _listEquals(columnInsertions, other.columnInsertions) &&
            _listEquals(rowInsertions, other.rowInsertions) &&
            _listEquals(rowDeletions, other.rowDeletions) &&
            _listEquals(cellUpdates, other.cellUpdates) &&
            _listEquals(expectations, other.expectations) &&
            nextSetPosition == other.nextSetPosition;
  }

  @override
  int get hashCode => Object.hash(
    Object.hashAll(columnInsertions),
    Object.hashAll(rowInsertions),
    Object.hashAll(rowDeletions),
    Object.hashAll(cellUpdates),
    Object.hashAll(expectations),
    nextSetPosition,
  );

  @override
  String toString() {
    return 'ActiveSheetWritePlan('
        'columnInsertions: $columnInsertions, '
        'rowInsertions: $rowInsertions, '
        'rowDeletions: $rowDeletions, '
        'cellUpdates: $cellUpdates, '
        'expectations: $expectations, '
        'nextSetPosition: $nextSetPosition'
        ')';
  }
}

class SetPosition {
  const SetPosition({
    required this.sheetRowNumber,
    required this.setNumber,
    required this.sheetColumnNumber,
  });

  final int sheetRowNumber;
  final int setNumber;
  final int? sheetColumnNumber;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is SetPosition &&
            sheetRowNumber == other.sheetRowNumber &&
            setNumber == other.setNumber &&
            sheetColumnNumber == other.sheetColumnNumber;
  }

  @override
  int get hashCode => Object.hash(sheetRowNumber, setNumber, sheetColumnNumber);

  @override
  String toString() {
    return 'SetPosition('
        'sheetRowNumber: $sheetRowNumber, '
        'setNumber: $setNumber, '
        'sheetColumnNumber: $sheetColumnNumber'
        ')';
  }
}

class ExerciseDef {
  const ExerciseDef({
    required this.exercise,
    this.description = '',
    this.defaultSets = '',
    this.defaultReps = '',
    this.defaultRpe = '',
    this.defaultRest = '',
    this.defaultTempo = '',
    this.notes = '',
    this.logFormat = defaultExerciseLogFormat,
  });

  final String exercise;
  final String description;
  final String defaultSets;
  final String defaultReps;
  final String defaultRpe;
  final String defaultRest;
  final String defaultTempo;
  final String notes;
  final String logFormat;

  String get resolvedLogFormat {
    return logFormat.trim().isEmpty ? defaultExerciseLogFormat : logFormat;
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is ExerciseDef &&
            exercise == other.exercise &&
            description == other.description &&
            defaultSets == other.defaultSets &&
            defaultReps == other.defaultReps &&
            defaultRpe == other.defaultRpe &&
            defaultRest == other.defaultRest &&
            defaultTempo == other.defaultTempo &&
            notes == other.notes &&
            logFormat == other.logFormat;
  }

  @override
  int get hashCode {
    return Object.hash(
      exercise,
      description,
      defaultSets,
      defaultReps,
      defaultRpe,
      defaultRest,
      defaultTempo,
      notes,
      logFormat,
    );
  }

  @override
  String toString() {
    return 'ExerciseDef('
        'exercise: $exercise, '
        'description: $description, '
        'defaultSets: $defaultSets, '
        'defaultReps: $defaultReps, '
        'defaultRpe: $defaultRpe, '
        'defaultRest: $defaultRest, '
        'defaultTempo: $defaultTempo, '
        'notes: $notes, '
        'logFormat: $logFormat'
        ')';
  }
}

class ReorderIntent {
  const ReorderIntent({required this.fromIndex, required this.toIndex});

  final int fromIndex;
  final int toIndex;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is ReorderIntent &&
            fromIndex == other.fromIndex &&
            toIndex == other.toIndex;
  }

  @override
  int get hashCode => Object.hash(fromIndex, toIndex);

  @override
  String toString() {
    return 'ReorderIntent(fromIndex: $fromIndex, toIndex: $toIndex)';
  }
}

class WorkoutPlacementMetadata {
  const WorkoutPlacementMetadata({
    this.sets = '',
    this.reps = '',
    this.rpe = '',
    this.rest = '',
    this.tempo = '',
    this.notes = '',
  });

  final String sets;
  final String reps;
  final String rpe;
  final String rest;
  final String tempo;
  final String notes;
}

class ExercisesWritePlan {
  ExercisesWritePlan({
    Iterable<ExercisesRowAppend> rowAppends = const [],
    Iterable<ExercisesRowUpdate> rowUpdates = const [],
    Iterable<CellUpdate> formulaUpdates = const [],
    Iterable<WriteExpct> expectations = const [],
  }) : rowAppends = List<ExercisesRowAppend>.unmodifiable(rowAppends),
       rowUpdates = List<ExercisesRowUpdate>.unmodifiable(rowUpdates),
       formulaUpdates = List<CellUpdate>.unmodifiable(formulaUpdates),
       expectations = List<WriteExpct>.unmodifiable(expectations);

  final List<ExercisesRowAppend> rowAppends;
  final List<ExercisesRowUpdate> rowUpdates;
  final List<CellUpdate> formulaUpdates;
  final List<WriteExpct> expectations;

  List<WriteRejection> writeRejections(ParsedActiveSheet sheet) {
    return [
      for (final expectation in expectations)
        ...expectation.writeRejections(sheet),
    ];
  }

  List<List<String>> previewRowsAfterApplying(Iterable<Iterable<String>> rows) {
    return _PlanPreview.exercises(this, rows);
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is ExercisesWritePlan &&
            _listEquals(rowAppends, other.rowAppends) &&
            _listEquals(rowUpdates, other.rowUpdates) &&
            _listEquals(formulaUpdates, other.formulaUpdates) &&
            _listEquals(expectations, other.expectations);
  }

  @override
  int get hashCode => Object.hash(
    Object.hashAll(rowAppends),
    Object.hashAll(rowUpdates),
    Object.hashAll(formulaUpdates),
    Object.hashAll(expectations),
  );

  @override
  String toString() {
    return 'ExercisesWritePlan('
        'rowAppends: $rowAppends, '
        'rowUpdates: $rowUpdates, '
        'formulaUpdates: $formulaUpdates, '
        'expectations: $expectations'
        ')';
  }
}

class ExercisesRowAppend {
  ExercisesRowAppend({
    required this.sheetRowNumber,
    required Iterable<String> values,
  }) : values = List<String>.unmodifiable(values);

  final int sheetRowNumber;
  final List<String> values;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is ExercisesRowAppend &&
            sheetRowNumber == other.sheetRowNumber &&
            _listEquals(values, other.values);
  }

  @override
  int get hashCode => Object.hash(sheetRowNumber, Object.hashAll(values));

  @override
  String toString() {
    return 'ExercisesRowAppend('
        'sheetRowNumber: $sheetRowNumber, '
        'values: $values'
        ')';
  }
}

class ExercisesRowUpdate {
  ExercisesRowUpdate({
    required this.sheetRowNumber,
    required Iterable<String> values,
  }) : values = List<String>.unmodifiable(values);

  final int sheetRowNumber;
  final List<String> values;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is ExercisesRowUpdate &&
            sheetRowNumber == other.sheetRowNumber &&
            _listEquals(values, other.values);
  }

  @override
  int get hashCode => Object.hash(sheetRowNumber, Object.hashAll(values));

  @override
  String toString() {
    return 'ExercisesRowUpdate('
        'sheetRowNumber: $sheetRowNumber, '
        'values: $values'
        ')';
  }
}

class RowInsertion {
  const RowInsertion({
    required this.sheetRowNumber,
    this.rowCount = 1,
    this.cellCount = 0,
  });

  final int sheetRowNumber;
  final int rowCount;
  final int cellCount;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is RowInsertion &&
            sheetRowNumber == other.sheetRowNumber &&
            rowCount == other.rowCount &&
            cellCount == other.cellCount;
  }

  @override
  int get hashCode => Object.hash(sheetRowNumber, rowCount, cellCount);

  @override
  String toString() {
    return 'RowInsertion('
        'sheetRowNumber: $sheetRowNumber, '
        'rowCount: $rowCount, '
        'cellCount: $cellCount'
        ')';
  }
}

class RowDeletion {
  const RowDeletion({required this.sheetRowNumber, this.rowCount = 1});

  final int sheetRowNumber;
  final int rowCount;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is RowDeletion &&
            sheetRowNumber == other.sheetRowNumber &&
            rowCount == other.rowCount;
  }

  @override
  int get hashCode => Object.hash(sheetRowNumber, rowCount);

  @override
  String toString() {
    return 'RowDeletion('
        'sheetRowNumber: $sheetRowNumber, '
        'rowCount: $rowCount'
        ')';
  }
}

class CellUpdate {
  const CellUpdate({
    required this.sheetRowNumber,
    required this.sheetColumnNumber,
    required this.value,
    this.valueKind = CellUpdateValueKind.literalText,
  });

  const CellUpdate.formula({
    required this.sheetRowNumber,
    required this.sheetColumnNumber,
    required this.value,
  }) : valueKind = CellUpdateValueKind.formula;

  final int sheetRowNumber;
  final int sheetColumnNumber;
  final String value;
  final CellUpdateValueKind valueKind;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is CellUpdate &&
            sheetRowNumber == other.sheetRowNumber &&
            sheetColumnNumber == other.sheetColumnNumber &&
            value == other.value &&
            valueKind == other.valueKind;
  }

  @override
  int get hashCode {
    return Object.hash(sheetRowNumber, sheetColumnNumber, value, valueKind);
  }

  @override
  String toString() {
    return 'CellUpdate('
        'sheetRowNumber: $sheetRowNumber, '
        'sheetColumnNumber: $sheetColumnNumber, '
        'value: $value, '
        'valueKind: $valueKind'
        ')';
  }
}

enum CellUpdateValueKind { literalText, formula }

class HistoryColumnInsertion {
  HistoryColumnInsertion({
    required this.sheetColumnNumber,
    required Iterable<String> headers,
    required Iterable<String> setLabels,
  }) : headers = List<String>.unmodifiable(headers),
       setLabels = List<String>.unmodifiable(setLabels);

  final int sheetColumnNumber;
  final List<String> headers;
  final List<String> setLabels;

  List<String> _valuesForRow(int zeroBasedRowIndex) {
    if (zeroBasedRowIndex == 0) {
      return headers;
    }
    if (zeroBasedRowIndex == 1) {
      return setLabels;
    }
    return List.filled(setLabels.length, '');
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is HistoryColumnInsertion &&
            sheetColumnNumber == other.sheetColumnNumber &&
            _listEquals(headers, other.headers) &&
            _listEquals(setLabels, other.setLabels);
  }

  @override
  int get hashCode => Object.hash(
    sheetColumnNumber,
    Object.hashAll(headers),
    Object.hashAll(setLabels),
  );

  @override
  String toString() {
    return 'HistoryColumnInsertion('
        'sheetColumnNumber: $sheetColumnNumber, '
        'headers: $headers, '
        'setLabels: $setLabels'
        ')';
  }
}
