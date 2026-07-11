part of '../active.dart';

abstract class WriteExpct {
  const WriteExpct();

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

class ExercisesRowExpct extends WriteExpct {
  ExercisesRowExpct({
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
        other is ExercisesRowExpct &&
            sheetRowNumber == other.sheetRowNumber &&
            _listEquals(expectedValues, other.expectedValues);
  }

  @override
  int get hashCode =>
      Object.hash(sheetRowNumber, Object.hashAll(expectedValues));

  @override
  String toString() {
    return 'ExercisesRowExpct('
        'sheetRowNumber: $sheetRowNumber, '
        'expectedValues: $expectedValues'
        ')';
  }
}

class RowExpct extends WriteExpct {
  const RowExpct({
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
        other is RowExpct &&
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
    return 'RowExpct('
        'sheetRowNumber: $sheetRowNumber, '
        'exercise: $exercise, '
        'workout: $workout, '
        'isBackup: $isBackup'
        ')';
  }
}

class RowValuesExpct extends WriteExpct {
  RowValuesExpct({
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
        other is RowValuesExpct &&
            sheetRowNumber == other.sheetRowNumber &&
            _listEquals(expectedValues, other.expectedValues);
  }

  @override
  int get hashCode {
    return Object.hash(sheetRowNumber, Object.hashAll(expectedValues));
  }

  @override
  String toString() {
    return 'RowValuesExpct('
        'sheetRowNumber: $sheetRowNumber, '
        'expectedValues: $expectedValues'
        ')';
  }
}

class BackupGroupExpct extends WriteExpct {
  BackupGroupExpct({
    required this.primaryRow,
    required Iterable<RowExpct> expectedBackups,
  }) : expectedBackups = List<RowExpct>.unmodifiable(expectedBackups);

  final int primaryRow;
  final List<RowExpct> expectedBackups;

  @override
  List<WriteRejection> writeRejections(ParsedActiveSheet sheet) {
    WorkoutSlot? primary;
    for (final slot in sheet.primarySlots) {
      if (slot.sheetRowNumber == primaryRow) {
        primary = slot;
        break;
      }
    }
    final actualBackups = [
      if (primary != null)
        for (final backup in primary.backups)
          RowExpct(
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
        'Backup group for row $primaryRow no longer matches '
        'the planned delete.',
      ),
    ];
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is BackupGroupExpct &&
            primaryRow == other.primaryRow &&
            _listEquals(expectedBackups, other.expectedBackups);
  }

  @override
  int get hashCode {
    return Object.hash(primaryRow, Object.hashAll(expectedBackups));
  }

  @override
  String toString() {
    return 'BackupGroupExpct('
        'primaryRow: $primaryRow, '
        'expectedBackups: $expectedBackups'
        ')';
  }
}

class RepairRowExpct extends WriteExpct {
  RepairRowExpct({
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
        other is RepairRowExpct &&
            sheetRowNumber == other.sheetRowNumber &&
            _listEquals(expectedValues, other.expectedValues);
  }

  @override
  int get hashCode {
    return Object.hash(sheetRowNumber, Object.hashAll(expectedValues));
  }

  @override
  String toString() {
    return 'RepairRowExpct('
        'sheetRowNumber: $sheetRowNumber, '
        'expectedValues: $expectedValues'
        ')';
  }
}

class CellExpct extends WriteExpct {
  const CellExpct({
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
        other is CellExpct &&
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
    return 'CellExpct('
        'sheetRowNumber: $sheetRowNumber, '
        'sheetColumnNumber: $sheetColumnNumber, '
        'expectedValue: $expectedValue'
        ')';
  }
}

class FormulaExpct extends WriteExpct {
  const FormulaExpct({
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
        other is FormulaExpct &&
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
    return 'FormulaExpct('
        'sheetRowNumber: $sheetRowNumber, '
        'sheetColumnNumber: $sheetColumnNumber, '
        'expectedFormula: $expectedFormula'
        ')';
  }
}

class SetColumnExpct extends WriteExpct {
  const SetColumnExpct({
    required this.blockLabel,
    required this.setNumber,
    required this.sheetColumnNumber,
    required this.setLabel,
  });

  final String blockLabel;
  final int setNumber;
  final int sheetColumnNumber;
  final String setLabel;

  @override
  List<WriteRejection> writeRejections(ParsedActiveSheet sheet) {
    final block = sheet.selectHistoryBlock(blockLabel);
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
        'Set column $blockLabel S$setNumber no longer exists at '
        'column $sheetColumnNumber.',
      ),
    ];
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is SetColumnExpct &&
            blockLabel == other.blockLabel &&
            setNumber == other.setNumber &&
            sheetColumnNumber == other.sheetColumnNumber &&
            setLabel == other.setLabel;
  }

  @override
  int get hashCode {
    return Object.hash(blockLabel, setNumber, sheetColumnNumber, setLabel);
  }

  @override
  String toString() {
    return 'SetColumnExpct('
        'blockLabel: $blockLabel, '
        'setNumber: $setNumber, '
        'sheetColumnNumber: $sheetColumnNumber, '
        'setLabel: $setLabel'
        ')';
  }
}

class InsertExpct extends WriteExpct {
  const InsertExpct({
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
        other is InsertExpct &&
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
    return 'InsertExpct('
        'sheetColumnNumber: $sheetColumnNumber, '
        'expectedHeaderValue: $expectedHeaderValue, '
        'expectedSetLabel: $expectedSetLabel'
        ')';
  }
}

class RowInsertExpct extends WriteExpct {
  RowInsertExpct({required this.sheetRowNumber, Iterable<String>? expectedRow})
    : expectedRow = expectedRow == null
          ? null
          : List<String>.unmodifiable(expectedRow);

  final int sheetRowNumber;
  final List<String>? expectedRow;

  @override
  List<WriteRejection> writeRejections(ParsedActiveSheet sheet) {
    final rowIndex = sheetRowNumber - 1;
    final row = expectedRow;
    if (row == null) {
      if (rowIndex == sheet._rows.length) {
        return const [];
      }
      return [_rejection()];
    }
    if (rowIndex >= 0 &&
        rowIndex < sheet._rows.length &&
        _listEquals(sheet._rows[rowIndex], row)) {
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
        other is RowInsertExpct &&
            sheetRowNumber == other.sheetRowNumber &&
            _nullableListEquals(expectedRow, other.expectedRow);
  }

  @override
  int get hashCode {
    return Object.hash(
      sheetRowNumber,
      expectedRow == null ? null : Object.hashAll(expectedRow!),
    );
  }

  @override
  String toString() {
    return 'RowInsertExpct('
        'sheetRowNumber: $sheetRowNumber, '
        'expectedRow: $expectedRow'
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
