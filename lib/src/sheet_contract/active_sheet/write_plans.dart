part of '../active_sheet.dart';

class ActiveSheetWritePlan {
  ActiveSheetWritePlan({
    Iterable<HistoryColumnInsertion> columnInsertions = const [],
    Iterable<CellUpdate> cellUpdates = const [],
    this.nextSetPosition,
  }) : columnInsertions = List<HistoryColumnInsertion>.unmodifiable(
         columnInsertions,
       ),
       cellUpdates = List<CellUpdate>.unmodifiable(cellUpdates);

  final List<HistoryColumnInsertion> columnInsertions;
  final List<CellUpdate> cellUpdates;
  final SetPosition? nextSetPosition;

  List<List<String>> previewRowsAfterApplying(Iterable<Iterable<String>> rows) {
    final preview = rows.map((row) => row.toList()).toList();
    final sortedInsertions = [...columnInsertions]
      ..sort(
        (first, second) =>
            second.sheetColumnNumber.compareTo(first.sheetColumnNumber),
      );

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

    return preview.map((row) => List<String>.unmodifiable(row)).toList();
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is ActiveSheetWritePlan &&
            _listEquals(columnInsertions, other.columnInsertions) &&
            _listEquals(cellUpdates, other.cellUpdates) &&
            nextSetPosition == other.nextSetPosition;
  }

  @override
  int get hashCode => Object.hash(
    Object.hashAll(columnInsertions),
    Object.hashAll(cellUpdates),
    nextSetPosition,
  );

  @override
  String toString() {
    return 'ActiveSheetWritePlan('
        'columnInsertions: $columnInsertions, '
        'cellUpdates: $cellUpdates, '
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

class CellUpdate {
  const CellUpdate({
    required this.sheetRowNumber,
    required this.sheetColumnNumber,
    required this.value,
  });

  final int sheetRowNumber;
  final int sheetColumnNumber;
  final String value;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is CellUpdate &&
            sheetRowNumber == other.sheetRowNumber &&
            sheetColumnNumber == other.sheetColumnNumber &&
            value == other.value;
  }

  @override
  int get hashCode => Object.hash(sheetRowNumber, sheetColumnNumber, value);

  @override
  String toString() {
    return 'CellUpdate('
        'sheetRowNumber: $sheetRowNumber, '
        'sheetColumnNumber: $sheetColumnNumber, '
        'value: $value'
        ')';
  }
}

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

class _ActiveSheetWritePlanner {
  _ActiveSheetWritePlanner(this.sheet);

  final ParsedActiveSheet sheet;

  ActiveSheetWritePlan planNewHistoryBlock({required String label}) {
    return ActiveSheetWritePlan(
      columnInsertions: [
        HistoryColumnInsertion(
          sheetColumnNumber: activeSheetFixedColumns.length + 1,
          headers: [label],
          setLabels: const ['S1'],
        ),
      ],
    );
  }

  ActiveSheetWritePlan planHistoryBlockGrowth({
    required String label,
    required int throughSetNumber,
  }) {
    final block = sheet.selectHistoryBlock(label);
    if (block == null || throughSetNumber <= block.setColumns.length) {
      return ActiveSheetWritePlan();
    }

    final nextSetNumber = block.setColumns.length + 1;
    return ActiveSheetWritePlan(
      columnInsertions: [
        HistoryColumnInsertion(
          sheetColumnNumber: block.setColumns.last.sheetColumnNumber + 1,
          headers: List.filled(throughSetNumber - block.setColumns.length, ''),
          setLabels: [
            for (
              var setNumber = nextSetNumber;
              setNumber <= throughSetNumber;
              setNumber += 1
            )
              'S$setNumber',
          ],
        ),
      ],
    );
  }

  ActiveSheetWritePlan planSetLoggingWrite({
    required String historyBlockLabel,
    required int sheetRowNumber,
    required Map<String, String> fieldValues,
  }) {
    final renderedSet = _renderSetForRow(
      sheetRowNumber: sheetRowNumber,
      fieldValues: fieldValues,
    );
    if (renderedSet == null) {
      return ActiveSheetWritePlan();
    }

    final block = sheet.selectHistoryBlock(historyBlockLabel);
    if (block == null) {
      return ActiveSheetWritePlan();
    }

    final row = sheet._sheetRow(sheetRowNumber);
    for (final column in block.setColumns) {
      if (_cell(row, column.sheetColumnNumber - 1).trim().isEmpty) {
        final setNumber = block.setColumns.indexOf(column) + 1;
        return ActiveSheetWritePlan(
          cellUpdates: [
            CellUpdate(
              sheetRowNumber: sheetRowNumber,
              sheetColumnNumber: column.sheetColumnNumber,
              value: renderedSet,
            ),
          ],
          nextSetPosition: _nextSetPosition(
            block: block,
            sheetRowNumber: sheetRowNumber,
            currentSetNumber: setNumber,
          ),
        );
      }
    }

    final newSetNumber = block.setColumns.length + 1;
    final growthPlan = planHistoryBlockGrowth(
      label: historyBlockLabel,
      throughSetNumber: newSetNumber,
    );
    final newSheetColumnNumber = block.setColumns.isEmpty
        ? activeSheetFixedColumns.length + 1
        : block.setColumns.last.sheetColumnNumber + 1;
    return ActiveSheetWritePlan(
      columnInsertions: growthPlan.columnInsertions,
      cellUpdates: [
        CellUpdate(
          sheetRowNumber: sheetRowNumber,
          sheetColumnNumber: newSheetColumnNumber,
          value: renderedSet,
        ),
      ],
      nextSetPosition: SetPosition(
        sheetRowNumber: sheetRowNumber,
        setNumber: newSetNumber + 1,
        sheetColumnNumber: null,
      ),
    );
  }

  ActiveSheetWritePlan planSetEdit({
    required String historyBlockLabel,
    required int sheetRowNumber,
    required int setNumber,
    required Map<String, String> fieldValues,
  }) {
    final renderedSet = _renderSetForRow(
      sheetRowNumber: sheetRowNumber,
      fieldValues: fieldValues,
    );
    if (renderedSet == null) {
      return ActiveSheetWritePlan();
    }

    final column = _setColumn(
      historyBlockLabel: historyBlockLabel,
      setNumber: setNumber,
    );
    if (column == null) {
      return ActiveSheetWritePlan();
    }
    return ActiveSheetWritePlan(
      cellUpdates: [
        CellUpdate(
          sheetRowNumber: sheetRowNumber,
          sheetColumnNumber: column.sheetColumnNumber,
          value: renderedSet,
        ),
      ],
    );
  }

  ActiveSheetWritePlan planRawSetEdit({
    required String historyBlockLabel,
    required int sheetRowNumber,
    required int setNumber,
    required String rawText,
  }) {
    if (!_isParsedExerciseRow(sheetRowNumber)) {
      return ActiveSheetWritePlan();
    }

    final column = _setColumn(
      historyBlockLabel: historyBlockLabel,
      setNumber: setNumber,
    );
    if (column == null) {
      return ActiveSheetWritePlan();
    }
    return ActiveSheetWritePlan(
      cellUpdates: [
        CellUpdate(
          sheetRowNumber: sheetRowNumber,
          sheetColumnNumber: column.sheetColumnNumber,
          value: rawText,
        ),
      ],
    );
  }

  ActiveSheetWritePlan planSetClear({
    required String historyBlockLabel,
    required int sheetRowNumber,
    required int setNumber,
  }) {
    if (!_isParsedExerciseRow(sheetRowNumber)) {
      return ActiveSheetWritePlan();
    }

    final column = _setColumn(
      historyBlockLabel: historyBlockLabel,
      setNumber: setNumber,
    );
    if (column == null) {
      return ActiveSheetWritePlan();
    }
    return ActiveSheetWritePlan(
      cellUpdates: [
        CellUpdate(
          sheetRowNumber: sheetRowNumber,
          sheetColumnNumber: column.sheetColumnNumber,
          value: '',
        ),
      ],
    );
  }

  SetPosition _nextSetPosition({
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

  HistorySetColumn? _setColumn({
    required String historyBlockLabel,
    required int setNumber,
  }) {
    final block = sheet.selectHistoryBlock(historyBlockLabel);
    if (block == null || setNumber < 1 || setNumber > block.setColumns.length) {
      return null;
    }
    return block.setColumns[setNumber - 1];
  }

  bool _isParsedExerciseRow(int sheetRowNumber) {
    return sheet.slots.any((slot) => slot.sheetRowNumber == sheetRowNumber);
  }

  String? _renderSetForRow({
    required int sheetRowNumber,
    required Map<String, String> fieldValues,
  }) {
    final slot = _slotForRow(sheetRowNumber);
    if (slot == null) {
      return null;
    }
    final format = slot.logFormat;
    return format is ParsedLogFormat
        ? renderLogFormat(format, fieldValues)
        : null;
  }

  WorkoutSlot? _slotForRow(int sheetRowNumber) {
    for (final slot in sheet.slots) {
      if (slot.sheetRowNumber == sheetRowNumber) {
        return slot;
      }
    }
    return null;
  }
}
