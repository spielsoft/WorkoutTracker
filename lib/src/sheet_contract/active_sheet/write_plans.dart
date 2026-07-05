part of '../active_sheet.dart';

class ActiveSheetWritePlan {
  ActiveSheetWritePlan({
    Iterable<HistoryColumnInsertion> columnInsertions = const [],
    Iterable<RowInsertion> rowInsertions = const [],
    Iterable<RowDeletion> rowDeletions = const [],
    Iterable<CellUpdate> cellUpdates = const [],
    Iterable<WriteExpectation> expectations = const [],
    this.nextSetPosition,
  }) : columnInsertions = List<HistoryColumnInsertion>.unmodifiable(
         columnInsertions,
       ),
       rowInsertions = List<RowInsertion>.unmodifiable(rowInsertions),
       rowDeletions = List<RowDeletion>.unmodifiable(rowDeletions),
       cellUpdates = List<CellUpdate>.unmodifiable(cellUpdates),
       expectations = List<WriteExpectation>.unmodifiable(expectations);

  final List<HistoryColumnInsertion> columnInsertions;
  final List<RowInsertion> rowInsertions;
  final List<RowDeletion> rowDeletions;
  final List<CellUpdate> cellUpdates;
  final List<WriteExpectation> expectations;
  final SetPosition? nextSetPosition;

  List<WriteRejection> writeRejections(ParsedActiveSheet sheet) {
    return [
      for (final expectation in expectations)
        ...expectation.writeRejections(sheet),
    ];
  }

  List<List<String>> previewRowsAfterApplying(Iterable<Iterable<String>> rows) {
    final preview = rows.map((row) => row.toList()).toList();
    final sortedRowInsertions = [...rowInsertions]
      ..sort(
        (first, second) =>
            second.sheetRowNumber.compareTo(first.sheetRowNumber),
      );
    final sortedInsertions = [...columnInsertions]
      ..sort(
        (first, second) =>
            second.sheetColumnNumber.compareTo(first.sheetColumnNumber),
      );
    final sortedRowDeletions = [...rowDeletions]
      ..sort(
        (first, second) =>
            second.sheetRowNumber.compareTo(first.sheetRowNumber),
      );
    if (sortedInsertions.isNotEmpty) {
      while (preview.length < 2) {
        preview.add([]);
      }
    }

    for (final insertion in sortedRowInsertions) {
      final rowIndex = insertion.sheetRowNumber - 1;
      if (rowIndex < 0) {
        continue;
      }
      final insertedRows = List.generate(
        insertion.rowCount,
        (_) => List.filled(insertion.cellCount, ''),
      );
      if (rowIndex >= preview.length) {
        while (preview.length < rowIndex) {
          preview.add([]);
        }
        preview.addAll(insertedRows);
      } else {
        preview.insertAll(rowIndex, insertedRows);
      }
    }

    for (final insertion in sortedInsertions) {
      final columnIndex = insertion.sheetColumnNumber - 1;
      for (var rowIndex = 0; rowIndex < preview.length; rowIndex += 1) {
        final insertedValues = insertion._valuesForRow(rowIndex);
        final row = preview[rowIndex];
        while (row.length < columnIndex) {
          row.add('');
        }
        row.insertAll(columnIndex, insertedValues);
      }
    }

    for (final update in cellUpdates) {
      final rowIndex = update.sheetRowNumber - 1;
      final columnIndex = update.sheetColumnNumber - 1;
      if (rowIndex < 0) {
        continue;
      }
      while (preview.length <= rowIndex) {
        preview.add([]);
      }
      final row = preview[rowIndex];
      while (row.length <= columnIndex) {
        row.add('');
      }
      row[columnIndex] = update.value;
    }

    for (final deletion in sortedRowDeletions) {
      final rowIndex = deletion.sheetRowNumber - 1;
      if (rowIndex < 0 || rowIndex >= preview.length) {
        continue;
      }
      final endIndex = rowIndex + deletion.rowCount;
      preview.removeRange(
        rowIndex,
        endIndex > preview.length ? preview.length : endIndex,
      );
    }

    return preview.map((row) => List<String>.unmodifiable(row)).toList();
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

abstract class WriteExpectation {
  const WriteExpectation();

  List<WriteRejection> writeRejections(ParsedActiveSheet sheet);
}

class WriteRejection {
  const WriteRejection(this.message);

  final String message;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is WriteRejection && message == other.message;
  }

  @override
  int get hashCode => message.hashCode;

  @override
  String toString() {
    return 'WriteRejection(message: $message)';
  }
}

class ExercisesRowExpectation extends WriteExpectation {
  ExercisesRowExpectation({
    required this.sheetRowNumber,
    required Iterable<String> expectedValues,
  }) : expectedValues = List<String>.unmodifiable(expectedValues);

  final int sheetRowNumber;
  final List<String> expectedValues;

  @override
  List<WriteRejection> writeRejections(ParsedActiveSheet sheet) {
    final rowIndex = sheetRowNumber - 1;
    if (rowIndex >= 0 &&
        rowIndex < sheet._exercisesRows.length &&
        _listEquals(sheet._exercisesRows[rowIndex], expectedValues)) {
      return const [];
    }
    return [
      WriteRejection(
        'Exercises row $sheetRowNumber no longer matches the planned reorder.',
      ),
    ];
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is ExercisesRowExpectation &&
            sheetRowNumber == other.sheetRowNumber &&
            _listEquals(expectedValues, other.expectedValues);
  }

  @override
  int get hashCode =>
      Object.hash(sheetRowNumber, Object.hashAll(expectedValues));

  @override
  String toString() {
    return 'ExercisesRowExpectation('
        'sheetRowNumber: $sheetRowNumber, '
        'expectedValues: $expectedValues'
        ')';
  }
}

class RowExpectation extends WriteExpectation {
  const RowExpectation({
    required this.sheetRowNumber,
    required this.exercise,
    required this.workout,
    required this.isBackup,
  });

  final int sheetRowNumber;
  final String exercise;
  final String workout;
  final bool isBackup;

  @override
  List<WriteRejection> writeRejections(ParsedActiveSheet sheet) {
    final slot = _slotForRow(sheet, sheetRowNumber);
    if (slot != null &&
        slot.exercise == exercise &&
        slot.workout == workout &&
        slot.isBackup == isBackup) {
      return const [];
    }
    return [
      WriteRejection(
        'Row $sheetRowNumber no longer matches $exercise '
        'in workout $workout.',
      ),
    ];
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is RowExpectation &&
            sheetRowNumber == other.sheetRowNumber &&
            exercise == other.exercise &&
            workout == other.workout &&
            isBackup == other.isBackup;
  }

  @override
  int get hashCode {
    return Object.hash(sheetRowNumber, exercise, workout, isBackup);
  }

  @override
  String toString() {
    return 'RowExpectation('
        'sheetRowNumber: $sheetRowNumber, '
        'exercise: $exercise, '
        'workout: $workout, '
        'isBackup: $isBackup'
        ')';
  }
}

class RowValuesExpectation extends WriteExpectation {
  RowValuesExpectation({
    required this.sheetRowNumber,
    required Iterable<String> expectedValues,
  }) : expectedValues = List<String>.unmodifiable(expectedValues);

  final int sheetRowNumber;
  final List<String> expectedValues;

  @override
  List<WriteRejection> writeRejections(ParsedActiveSheet sheet) {
    final rowIndex = sheetRowNumber - 1;
    if (rowIndex >= 0 &&
        rowIndex < sheet._rows.length &&
        _listEquals(sheet._rows[rowIndex], expectedValues)) {
      return const [];
    }
    return [
      WriteRejection(
        'Active sheet row $sheetRowNumber no longer matches the planned '
        'reorder.',
      ),
    ];
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is RowValuesExpectation &&
            sheetRowNumber == other.sheetRowNumber &&
            _listEquals(expectedValues, other.expectedValues);
  }

  @override
  int get hashCode {
    return Object.hash(sheetRowNumber, Object.hashAll(expectedValues));
  }

  @override
  String toString() {
    return 'RowValuesExpectation('
        'sheetRowNumber: $sheetRowNumber, '
        'expectedValues: $expectedValues'
        ')';
  }
}

class BackupGroupExpectation extends WriteExpectation {
  BackupGroupExpectation({
    required this.primarySheetRowNumber,
    required Iterable<RowExpectation> expectedBackups,
  }) : expectedBackups = List<RowExpectation>.unmodifiable(expectedBackups);

  final int primarySheetRowNumber;
  final List<RowExpectation> expectedBackups;

  @override
  List<WriteRejection> writeRejections(ParsedActiveSheet sheet) {
    WorkoutSlot? primary;
    for (final slot in sheet.primarySlots) {
      if (slot.sheetRowNumber == primarySheetRowNumber) {
        primary = slot;
        break;
      }
    }
    final actualBackups = [
      if (primary != null)
        for (final backup in primary.backups)
          RowExpectation(
            sheetRowNumber: backup.sheetRowNumber,
            exercise: backup.exercise,
            workout: backup.workout,
            isBackup: backup.isBackup,
          ),
    ];
    if (_listEquals(actualBackups, expectedBackups)) {
      return const [];
    }
    return [
      WriteRejection(
        'Backup group for row $primarySheetRowNumber no longer matches '
        'the planned delete.',
      ),
    ];
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is BackupGroupExpectation &&
            primarySheetRowNumber == other.primarySheetRowNumber &&
            _listEquals(expectedBackups, other.expectedBackups);
  }

  @override
  int get hashCode {
    return Object.hash(primarySheetRowNumber, Object.hashAll(expectedBackups));
  }

  @override
  String toString() {
    return 'BackupGroupExpectation('
        'primarySheetRowNumber: $primarySheetRowNumber, '
        'expectedBackups: $expectedBackups'
        ')';
  }
}

class RepairRowExpectation extends WriteExpectation {
  RepairRowExpectation({
    required this.sheetRowNumber,
    required Iterable<String> expectedValues,
  }) : expectedValues = List<String>.unmodifiable(expectedValues);

  final int sheetRowNumber;
  final List<String> expectedValues;

  @override
  List<WriteRejection> writeRejections(ParsedActiveSheet sheet) {
    final rowIndex = sheetRowNumber - 1;
    if (rowIndex >= 0 &&
        rowIndex < sheet._rows.length &&
        _listEquals(sheet._rows[rowIndex], expectedValues)) {
      return const [];
    }
    return [
      WriteRejection(
        'The active sheet changed after validation. Revalidate before '
        'repairing formulas for row $sheetRowNumber.',
      ),
    ];
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is RepairRowExpectation &&
            sheetRowNumber == other.sheetRowNumber &&
            _listEquals(expectedValues, other.expectedValues);
  }

  @override
  int get hashCode {
    return Object.hash(sheetRowNumber, Object.hashAll(expectedValues));
  }

  @override
  String toString() {
    return 'RepairRowExpectation('
        'sheetRowNumber: $sheetRowNumber, '
        'expectedValues: $expectedValues'
        ')';
  }
}

class CellExpectation extends WriteExpectation {
  const CellExpectation({
    required this.sheetRowNumber,
    required this.sheetColumnNumber,
    required this.expectedValue,
  });

  final int sheetRowNumber;
  final int sheetColumnNumber;
  final String expectedValue;

  @override
  List<WriteRejection> writeRejections(ParsedActiveSheet sheet) {
    final actualValue = _cell(
      sheet._sheetRow(sheetRowNumber),
      sheetColumnNumber - 1,
    );
    if (actualValue == expectedValue) {
      return const [];
    }
    return [
      WriteRejection(
        'Cell row $sheetRowNumber column $sheetColumnNumber no longer matches '
        'the visible value.',
      ),
    ];
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is CellExpectation &&
            sheetRowNumber == other.sheetRowNumber &&
            sheetColumnNumber == other.sheetColumnNumber &&
            expectedValue == other.expectedValue;
  }

  @override
  int get hashCode {
    return Object.hash(sheetRowNumber, sheetColumnNumber, expectedValue);
  }

  @override
  String toString() {
    return 'CellExpectation('
        'sheetRowNumber: $sheetRowNumber, '
        'sheetColumnNumber: $sheetColumnNumber, '
        'expectedValue: $expectedValue'
        ')';
  }
}

class FormulaExpectation extends WriteExpectation {
  const FormulaExpectation({
    required this.sheetRowNumber,
    required this.sheetColumnNumber,
    required this.expectedFormula,
  });

  final int sheetRowNumber;
  final int sheetColumnNumber;
  final String expectedFormula;

  @override
  List<WriteRejection> writeRejections(ParsedActiveSheet sheet) {
    for (final formula in sheet._cellFormulas) {
      if (formula.sheetRowNumber == sheetRowNumber &&
          formula.sheetColumnNumber == sheetColumnNumber &&
          formula.formula == expectedFormula) {
        return const [];
      }
    }
    return [
      WriteRejection(
        'Formula row $sheetRowNumber column $sheetColumnNumber no longer '
        'matches the planned reorder.',
      ),
    ];
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is FormulaExpectation &&
            sheetRowNumber == other.sheetRowNumber &&
            sheetColumnNumber == other.sheetColumnNumber &&
            expectedFormula == other.expectedFormula;
  }

  @override
  int get hashCode {
    return Object.hash(sheetRowNumber, sheetColumnNumber, expectedFormula);
  }

  @override
  String toString() {
    return 'FormulaExpectation('
        'sheetRowNumber: $sheetRowNumber, '
        'sheetColumnNumber: $sheetColumnNumber, '
        'expectedFormula: $expectedFormula'
        ')';
  }
}

class SetColumnExpectation extends WriteExpectation {
  const SetColumnExpectation({
    required this.historyBlockLabel,
    required this.setNumber,
    required this.sheetColumnNumber,
    required this.setLabel,
  });

  final String historyBlockLabel;
  final int setNumber;
  final int sheetColumnNumber;
  final String setLabel;

  @override
  List<WriteRejection> writeRejections(ParsedActiveSheet sheet) {
    final block = sheet.selectHistoryBlock(historyBlockLabel);
    final column =
        block == null || setNumber < 1 || setNumber > block.setColumns.length
        ? null
        : block.setColumns[setNumber - 1];
    if (column != null &&
        column.sheetColumnNumber == sheetColumnNumber &&
        column.label == setLabel) {
      return const [];
    }
    return [
      WriteRejection(
        'Set column $historyBlockLabel S$setNumber no longer exists at '
        'column $sheetColumnNumber.',
      ),
    ];
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is SetColumnExpectation &&
            historyBlockLabel == other.historyBlockLabel &&
            setNumber == other.setNumber &&
            sheetColumnNumber == other.sheetColumnNumber &&
            setLabel == other.setLabel;
  }

  @override
  int get hashCode {
    return Object.hash(
      historyBlockLabel,
      setNumber,
      sheetColumnNumber,
      setLabel,
    );
  }

  @override
  String toString() {
    return 'SetColumnExpectation('
        'historyBlockLabel: $historyBlockLabel, '
        'setNumber: $setNumber, '
        'sheetColumnNumber: $sheetColumnNumber, '
        'setLabel: $setLabel'
        ')';
  }
}

class InsertionPointExpectation extends WriteExpectation {
  const InsertionPointExpectation({
    required this.sheetColumnNumber,
    required this.expectedHeaderValue,
    required this.expectedSetLabel,
  });

  final int sheetColumnNumber;
  final String expectedHeaderValue;
  final String expectedSetLabel;

  @override
  List<WriteRejection> writeRejections(ParsedActiveSheet sheet) {
    final header = sheet._sheetRow(1);
    final setHeader = sheet._sheetRow(2);
    for (var index = 0; index < activeSheetFixedColumns.length; index += 1) {
      if (_cell(header, index) != activeSheetFixedColumns[index]) {
        return [_rejection()];
      }
    }
    if (_cell(header, sheetColumnNumber - 1) == expectedHeaderValue &&
        _cell(setHeader, sheetColumnNumber - 1) == expectedSetLabel) {
      return const [];
    }
    return [_rejection()];
  }

  WriteRejection _rejection() {
    return WriteRejection(
      'History insertion point at column $sheetColumnNumber no longer matches '
      'the visible sheet.',
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is InsertionPointExpectation &&
            sheetColumnNumber == other.sheetColumnNumber &&
            expectedHeaderValue == other.expectedHeaderValue &&
            expectedSetLabel == other.expectedSetLabel;
  }

  @override
  int get hashCode {
    return Object.hash(
      sheetColumnNumber,
      expectedHeaderValue,
      expectedSetLabel,
    );
  }

  @override
  String toString() {
    return 'InsertionPointExpectation('
        'sheetColumnNumber: $sheetColumnNumber, '
        'expectedHeaderValue: $expectedHeaderValue, '
        'expectedSetLabel: $expectedSetLabel'
        ')';
  }
}

class RowInsertExpectation extends WriteExpectation {
  RowInsertExpectation({
    required this.sheetRowNumber,
    Iterable<String>? expectedRowAtInsertionPoint,
  }) : expectedRowAtInsertionPoint = expectedRowAtInsertionPoint == null
           ? null
           : List<String>.unmodifiable(expectedRowAtInsertionPoint);

  final int sheetRowNumber;
  final List<String>? expectedRowAtInsertionPoint;

  @override
  List<WriteRejection> writeRejections(ParsedActiveSheet sheet) {
    final rowIndex = sheetRowNumber - 1;
    final expectedRow = expectedRowAtInsertionPoint;
    if (expectedRow == null) {
      if (rowIndex == sheet._rows.length) {
        return const [];
      }
      return [_rejection()];
    }
    if (rowIndex >= 0 &&
        rowIndex < sheet._rows.length &&
        _listEquals(sheet._rows[rowIndex], expectedRow)) {
      return const [];
    }
    return [_rejection()];
  }

  WriteRejection _rejection() {
    return WriteRejection(
      'Row insertion point at row $sheetRowNumber no longer matches '
      'the visible sheet.',
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is RowInsertExpectation &&
            sheetRowNumber == other.sheetRowNumber &&
            _nullableListEquals(
              expectedRowAtInsertionPoint,
              other.expectedRowAtInsertionPoint,
            );
  }

  @override
  int get hashCode {
    return Object.hash(
      sheetRowNumber,
      expectedRowAtInsertionPoint == null
          ? null
          : Object.hashAll(expectedRowAtInsertionPoint!),
    );
  }

  @override
  String toString() {
    return 'RowInsertExpectation('
        'sheetRowNumber: $sheetRowNumber, '
        'expectedRowAtInsertionPoint: $expectedRowAtInsertionPoint'
        ')';
  }
}

WorkoutSlot? _slotForRow(ParsedActiveSheet sheet, int sheetRowNumber) {
  for (final slot in sheet.slots) {
    if (slot.sheetRowNumber == sheetRowNumber) {
      return slot;
    }
  }
  return null;
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
    Iterable<CellUpdate> activeSheetFormulaUpdates = const [],
    Iterable<WriteExpectation> expectations = const [],
  }) : rowAppends = List<ExercisesRowAppend>.unmodifiable(rowAppends),
       rowUpdates = List<ExercisesRowUpdate>.unmodifiable(rowUpdates),
       activeSheetFormulaUpdates = List<CellUpdate>.unmodifiable(
         activeSheetFormulaUpdates,
       ),
       expectations = List<WriteExpectation>.unmodifiable(expectations);

  final List<ExercisesRowAppend> rowAppends;
  final List<ExercisesRowUpdate> rowUpdates;
  final List<CellUpdate> activeSheetFormulaUpdates;
  final List<WriteExpectation> expectations;

  List<WriteRejection> writeRejections(ParsedActiveSheet sheet) {
    return [
      for (final expectation in expectations)
        ...expectation.writeRejections(sheet),
    ];
  }

  List<List<String>> previewRowsAfterApplying(Iterable<Iterable<String>> rows) {
    final preview = rows.map((row) => row.toList()).toList();
    for (final update in rowUpdates) {
      final rowIndex = update.sheetRowNumber - 1;
      if (rowIndex >= 0 && rowIndex < preview.length) {
        preview[rowIndex] = update.values.toList();
      }
    }
    for (final append in rowAppends) {
      final rowIndex = append.sheetRowNumber - 1;
      while (preview.length < rowIndex) {
        preview.add([]);
      }
      if (rowIndex == preview.length) {
        preview.add(append.values.toList());
      } else {
        preview.insert(rowIndex, append.values.toList());
      }
    }
    return preview.map((row) => List<String>.unmodifiable(row)).toList();
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is ExercisesWritePlan &&
            _listEquals(rowAppends, other.rowAppends) &&
            _listEquals(rowUpdates, other.rowUpdates) &&
            _listEquals(
              activeSheetFormulaUpdates,
              other.activeSheetFormulaUpdates,
            ) &&
            _listEquals(expectations, other.expectations);
  }

  @override
  int get hashCode => Object.hash(
    Object.hashAll(rowAppends),
    Object.hashAll(rowUpdates),
    Object.hashAll(activeSheetFormulaUpdates),
    Object.hashAll(expectations),
  );

  @override
  String toString() {
    return 'ExercisesWritePlan('
        'rowAppends: $rowAppends, '
        'rowUpdates: $rowUpdates, '
        'activeSheetFormulaUpdates: $activeSheetFormulaUpdates, '
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

class _WritePlanner {
  _WritePlanner(ParsedActiveSheet sheet)
    : _context = _WritePlanningContext(sheet);

  final _WritePlanningContext _context;

  late final _HistoryBlockWritePlanner _historyBlocks =
      _HistoryBlockWritePlanner(_context);
  late final _CanonicalExerciseWritePlanner _canonicalExercises =
      _CanonicalExerciseWritePlanner(_context);
  late final _WorkoutRowWritePlanner _workoutRows = _WorkoutRowWritePlanner(
    _context,
  );
  late final _SetWritePlanner _sets = _SetWritePlanner(
    context: _context,
    historyBlocks: _historyBlocks,
  );

  ActiveSheetWritePlan planNewHistoryBlock({required String label}) {
    return _historyBlocks.planNewHistoryBlock(label: label);
  }

  ActiveSheetWritePlan planHistoryBlockGrowth({
    required String label,
    required int throughSetNumber,
  }) {
    return _historyBlocks.planHistoryBlockGrowth(
      label: label,
      throughSetNumber: throughSetNumber,
    );
  }

  ExercisesWritePlan planCanonicalAppend(ExerciseDef exercise) {
    return _canonicalExercises.planCanonicalAppend(exercise);
  }

  ExercisesWritePlan planCanonicalUpdate({
    required CanonicalExercise selectedExercise,
    required ExerciseDef exercise,
  }) {
    return _canonicalExercises.planCanonicalUpdate(
      selectedExercise: selectedExercise,
      exercise: exercise,
    );
  }

  ExercisesWritePlan planCanonicalReorder(ReorderIntent intent) {
    return _canonicalExercises.planCanonicalReorder(intent);
  }

  ActiveSheetWritePlan planExerciseReorder({
    required String workout,
    required ReorderIntent intent,
  }) {
    return _workoutRows.planExerciseReorder(workout: workout, intent: intent);
  }

  ActiveSheetWritePlan planPrimaryPlacement({
    required CanonicalExercise exercise,
    required String workout,
    WorkoutPlacementMetadata metadata = const WorkoutPlacementMetadata(),
  }) {
    return _workoutRows.planPrimaryPlacement(
      exercise: exercise,
      workout: workout,
      metadata: metadata,
    );
  }

  ActiveSheetWritePlan planBackupPlacement({
    required int primarySheetRowNumber,
    required CanonicalExercise exercise,
    WorkoutPlacementMetadata metadata = const WorkoutPlacementMetadata(),
  }) {
    return _workoutRows.planBackupPlacement(
      primarySheetRowNumber: primarySheetRowNumber,
      exercise: exercise,
      metadata: metadata,
    );
  }

  ActiveSheetWritePlan planPrimaryExerciseDeletion({
    required int primarySheetRowNumber,
  }) {
    return _workoutRows.planPrimaryExerciseDeletion(
      primarySheetRowNumber: primarySheetRowNumber,
    );
  }

  ActiveSheetWritePlan planSetLoggingWrite({
    required String historyBlockLabel,
    required int sheetRowNumber,
    required Map<String, String> fieldValues,
  }) {
    return _sets.planSetLoggingWrite(
      historyBlockLabel: historyBlockLabel,
      sheetRowNumber: sheetRowNumber,
      fieldValues: fieldValues,
    );
  }

  ActiveSheetWritePlan planSetEdit({
    required String historyBlockLabel,
    required int sheetRowNumber,
    required int setNumber,
    required Map<String, String> fieldValues,
  }) {
    return _sets.planSetEdit(
      historyBlockLabel: historyBlockLabel,
      sheetRowNumber: sheetRowNumber,
      setNumber: setNumber,
      fieldValues: fieldValues,
    );
  }

  ActiveSheetWritePlan planRawSetEdit({
    required String historyBlockLabel,
    required int sheetRowNumber,
    required int setNumber,
    required String rawText,
  }) {
    return _sets.planRawSetEdit(
      historyBlockLabel: historyBlockLabel,
      sheetRowNumber: sheetRowNumber,
      setNumber: setNumber,
      rawText: rawText,
    );
  }

  ActiveSheetWritePlan planSetClear({
    required String historyBlockLabel,
    required int sheetRowNumber,
    required int setNumber,
  }) {
    return _sets.planSetClear(
      historyBlockLabel: historyBlockLabel,
      sheetRowNumber: sheetRowNumber,
      setNumber: setNumber,
    );
  }
}

class _WorkoutExerciseGroup {
  _WorkoutExerciseGroup(this.primary);

  final WorkoutSlot primary;

  Iterable<int> get sheetRowNumbers sync* {
    yield primary.sheetRowNumber;
    for (final backup in primary.backups) {
      yield backup.sheetRowNumber;
    }
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is _WorkoutExerciseGroup && primary == other.primary;
  }

  @override
  int get hashCode => primary.hashCode;
}

List<T> _reordered<T>(List<T> items, ReorderIntent intent) {
  if (intent.fromIndex < 0 ||
      intent.fromIndex >= items.length ||
      intent.toIndex < 0 ||
      intent.toIndex >= items.length ||
      intent.fromIndex == intent.toIndex) {
    return List<T>.unmodifiable(items);
  }
  final reordered = [...items];
  final item = reordered.removeAt(intent.fromIndex);
  reordered.insert(intent.toIndex, item);
  return List<T>.unmodifiable(reordered);
}

bool _nestedListEquals<T>(List<List<T>> first, List<List<T>> second) {
  if (first.length != second.length) {
    return false;
  }
  for (var index = 0; index < first.length; index += 1) {
    if (!_listEquals(first[index], second[index])) {
      return false;
    }
  }
  return true;
}

_DirectExercisesReference? _directExercisesReference(String formula) {
  final normalized = formula.trim();
  final match = RegExp(
    r"^=('?Exercises'?)!([A-Z]+)(\d+)$",
  ).firstMatch(normalized);
  if (match == null) {
    return null;
  }
  return _DirectExercisesReference(
    columnNumber: _columnNumber(match.group(2)!),
    rowNumber: int.parse(match.group(3)!),
  );
}

class _DirectExercisesReference {
  const _DirectExercisesReference({
    required this.columnNumber,
    required this.rowNumber,
  });

  final int columnNumber;
  final int rowNumber;
}

int _columnNumber(String letters) {
  var columnNumber = 0;
  for (final codeUnit in letters.codeUnits) {
    columnNumber = columnNumber * 26 + (codeUnit - 64);
  }
  return columnNumber;
}
