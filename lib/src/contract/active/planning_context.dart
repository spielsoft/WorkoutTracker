part of '../active.dart';

class _WritePlanningContext {
  _WritePlanningContext(this.sheet);

  final ParsedActiveSheet sheet;

  int get activeSheetRowWidth {
    final headerWidth = sheet._sheetRow(1).length;
    return headerWidth < activeSheetFixedColumns.length
        ? activeSheetFixedColumns.length
        : headerWidth;
  }

  WorkoutSlot? slotForRow(int sheetRowNumber) {
    for (final slot in sheet.slots) {
      if (slot.sheetRowNumber == sheetRowNumber) {
        return slot;
      }
    }
    return null;
  }

  WorkoutSlot? primarySlotForRow(int sheetRowNumber) {
    for (final slot in sheet.primarySlots) {
      if (slot.sheetRowNumber == sheetRowNumber && !slot.isBackup) {
        return slot;
      }
    }
    return null;
  }

  bool isParsedExerciseRow(int sheetRowNumber) {
    return sheet.slots.any((slot) => slot.sheetRowNumber == sheetRowNumber);
  }

  String? renderSetForRow({
    required int sheetRowNumber,
    required Map<String, String> fieldValues,
  }) {
    final slot = slotForRow(sheetRowNumber);
    if (slot == null) {
      return null;
    }
    final format = slot.logFormat;
    return format is ParsedLogFormat ? format.render(fieldValues) : null;
  }

  HistorySetColumn? setColumn({
    required String blockLabel,
    required int setNumber,
  }) {
    final block = sheet.selectHistoryBlock(blockLabel);
    if (block == null || setNumber < 1 || setNumber > block.setColumns.length) {
      return null;
    }
    return block.setColumns[setNumber - 1];
  }

  SetPosition nextSetPosition({
    required HistoryBlock block,
    required int sheetRowNumber,
    required int currentSetNumber,
  }) {
    final nextSetNumber = currentSetNumber + 1;
    final existingNextColumn = nextSetNumber <= block.setColumns.length
        ? block.setColumns[nextSetNumber - 1].sheetColumnNumber
        : null;
    return SetPosition(
      sheetRowNumber: sheetRowNumber,
      setNumber: nextSetNumber,
      sheetColumnNumber: existingNextColumn,
    );
  }

  List<WriteExpct> exerciseRowExpcts(WorkoutSlot? slot) {
    if (slot == null) {
      return const [];
    }
    return [rowExpct(slot), logFormatExpct(slot)];
  }

  List<WriteExpct> setCellExpcts({
    required String blockLabel,
    required int setNumber,
    required int sheetRowNumber,
    required HistorySetColumn column,
  }) {
    return [
      ...exerciseRowExpcts(slotForRow(sheetRowNumber)),
      SetColumnExpct(
        blockLabel: blockLabel,
        setNumber: setNumber,
        sheetColumnNumber: column.sheetColumnNumber,
        setLabel: column.label,
      ),
      CellExpct(
        sheetRowNumber: sheetRowNumber,
        sheetColumnNumber: column.sheetColumnNumber,
        expectedValue: _cell(
          sheet._sheetRow(sheetRowNumber),
          column.sheetColumnNumber - 1,
        ),
      ),
    ];
  }

  RowExpct rowExpct(WorkoutSlot slot) {
    return RowExpct(
      sheetRowNumber: slot.sheetRowNumber,
      exercise: slot.exercise,
      workout: slot.workout,
      isBackup: slot.isBackup,
    );
  }

  CellExpct logFormatExpct(WorkoutSlot slot) {
    final sheetColumnNumber = activeSheetFixedColumns.indexOf('Log Format') + 1;
    return CellExpct(
      sheetRowNumber: slot.sheetRowNumber,
      sheetColumnNumber: sheetColumnNumber,
      expectedValue: _cell(
        sheet._sheetRow(slot.sheetRowNumber),
        sheetColumnNumber - 1,
      ),
    );
  }

  InsertExpct insertExpct(int sheetColumnNumber) {
    return InsertExpct(
      sheetColumnNumber: sheetColumnNumber,
      expectedHeaderValue: _cell(sheet._sheetRow(1), sheetColumnNumber - 1),
      expectedSetLabel: _cell(sheet._sheetRow(2), sheetColumnNumber - 1),
    );
  }

  RowInsertExpct rowInsertExpct(int sheetRowNumber) {
    final rowIndex = sheetRowNumber - 1;
    return RowInsertExpct(
      sheetRowNumber: sheetRowNumber,
      expectedRow: rowIndex >= 0 && rowIndex < sheet._rows.length
          ? sheet._rows[rowIndex]
          : null,
    );
  }

  List<RowDeletion> rowDeletionsForSheetRows(Iterable<int> sheetRowNumbers) {
    final sortedRows = sheetRowNumbers.toSet().toList()..sort();
    if (sortedRows.isEmpty) {
      return const [];
    }

    final deletions = <RowDeletion>[];
    var startRow = sortedRows.first;
    var previousRow = startRow;

    for (final row in sortedRows.skip(1)) {
      if (row == previousRow + 1) {
        previousRow = row;
        continue;
      }
      deletions.add(
        RowDeletion(
          sheetRowNumber: startRow,
          rowCount: previousRow - startRow + 1,
        ),
      );
      startRow = row;
      previousRow = row;
    }

    deletions.add(
      RowDeletion(
        sheetRowNumber: startRow,
        rowCount: previousRow - startRow + 1,
      ),
    );
    return deletions;
  }

  int backupInsertionRowNumber(WorkoutSlot primary) {
    var sheetRowNumber = primary.sheetRowNumber + 1;
    for (final backup in primary.backups) {
      sheetRowNumber = backup.sheetRowNumber + 1;
    }
    return sheetRowNumber;
  }

  int exerciseColumn(String activeColumnName) {
    return sheet._exerciseFormulaColumns[activeColumnName] ??
        _defaultExerciseColumn(activeColumnName);
  }

  List<CellUpdate> rowReorderCellUpdates({
    required int targetSheetRowNumber,
    required int fromRow,
  }) {
    final sourceRow = sheet._sheetRow(fromRow);
    final targetRow = sheet._sheetRow(targetSheetRowNumber);
    var width = activeSheetRowWidth;
    if (width < sourceRow.length) {
      width = sourceRow.length;
    }
    if (width < targetRow.length) {
      width = targetRow.length;
    }

    return [
      for (
        var sheetColumnNumber = 1;
        sheetColumnNumber <= width;
        sheetColumnNumber += 1
      )
        if (formulaForCell(fromRow, sheetColumnNumber) case final formula?)
          CellUpdate.formula(
            sheetRowNumber: targetSheetRowNumber,
            sheetColumnNumber: sheetColumnNumber,
            value: formula,
          )
        else
          CellUpdate(
            sheetRowNumber: targetSheetRowNumber,
            sheetColumnNumber: sheetColumnNumber,
            value: _cell(sourceRow, sheetColumnNumber - 1),
          ),
    ];
  }

  String? formulaForCell(int sheetRowNumber, int sheetColumnNumber) {
    for (final formula in sheet._cellFormulas) {
      if (formula.sheetRowNumber == sheetRowNumber &&
          formula.sheetColumnNumber == sheetColumnNumber) {
        return formula.formula;
      }
    }
    return null;
  }

  List<CellUpdate> reorderFormulaUpdates(Map<int, int> oldToNewRows) {
    return [
      for (final formula in sheet._cellFormulas)
        if (_exerciseRef(formula.formula) case final reference?)
          if (oldToNewRows[reference.rowNumber] case final newRowNumber?)
            if (newRowNumber != reference.rowNumber)
              CellUpdate.formula(
                sheetRowNumber: formula.sheetRowNumber,
                sheetColumnNumber: formula.sheetColumnNumber,
                value: _directExercisesFormula(
                  exerciseColumn: reference.columnNumber,
                  exercisesSheetRowNumber: newRowNumber,
                ),
              ),
    ];
  }

  List<FormulaExpct> reorderFormulaExpcts(Map<int, int> oldToNewRows) {
    return [
      for (final formula in sheet._cellFormulas)
        if (_exerciseRef(formula.formula) case final reference?)
          if (oldToNewRows[reference.rowNumber] case final newRowNumber?)
            if (newRowNumber != reference.rowNumber)
              FormulaExpct(
                sheetRowNumber: formula.sheetRowNumber,
                sheetColumnNumber: formula.sheetColumnNumber,
                expectedFormula: formula.formula,
              ),
    ];
  }
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

_ExerciseRef? _exerciseRef(String formula) {
  final normalized = formula.trim();
  final match = RegExp(
    r"^=('?Exercises'?)!([A-Z]+)(\d+)$",
  ).firstMatch(normalized);
  if (match == null) {
    return null;
  }
  return _ExerciseRef(
    columnNumber: _columnNumber(match.group(2)!),
    rowNumber: int.parse(match.group(3)!),
  );
}

class _ExerciseRef {
  const _ExerciseRef({required this.columnNumber, required this.rowNumber});

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
