part of '../active_sheet.dart';

class ActiveSheetWritePlan {
  ActiveSheetWritePlan({
    Iterable<HistoryColumnInsertion> columnInsertions = const [],
    Iterable<CellUpdate> cellUpdates = const [],
    Iterable<ActiveSheetWriteExpectation> expectations = const [],
    this.nextSetPosition,
  }) : columnInsertions = List<HistoryColumnInsertion>.unmodifiable(
         columnInsertions,
       ),
       cellUpdates = List<CellUpdate>.unmodifiable(cellUpdates),
       expectations = List<ActiveSheetWriteExpectation>.unmodifiable(
         expectations,
       );

  final List<HistoryColumnInsertion> columnInsertions;
  final List<CellUpdate> cellUpdates;
  final List<ActiveSheetWriteExpectation> expectations;
  final SetPosition? nextSetPosition;

  List<ActiveSheetWriteRejection> writeRejections(ParsedActiveSheet sheet) {
    return [
      for (final expectation in expectations)
        ...expectation.writeRejections(sheet),
    ];
  }

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
            _listEquals(expectations, other.expectations) &&
            nextSetPosition == other.nextSetPosition;
  }

  @override
  int get hashCode => Object.hash(
    Object.hashAll(columnInsertions),
    Object.hashAll(cellUpdates),
    Object.hashAll(expectations),
    nextSetPosition,
  );

  @override
  String toString() {
    return 'ActiveSheetWritePlan('
        'columnInsertions: $columnInsertions, '
        'cellUpdates: $cellUpdates, '
        'expectations: $expectations, '
        'nextSetPosition: $nextSetPosition'
        ')';
  }
}

abstract class ActiveSheetWriteExpectation {
  const ActiveSheetWriteExpectation();

  List<ActiveSheetWriteRejection> writeRejections(ParsedActiveSheet sheet);
}

class ActiveSheetWriteRejection {
  const ActiveSheetWriteRejection(this.message);

  final String message;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is ActiveSheetWriteRejection && message == other.message;
  }

  @override
  int get hashCode => message.hashCode;

  @override
  String toString() {
    return 'ActiveSheetWriteRejection(message: $message)';
  }
}

class ActiveSheetRowExpectation extends ActiveSheetWriteExpectation {
  const ActiveSheetRowExpectation({
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
  List<ActiveSheetWriteRejection> writeRejections(ParsedActiveSheet sheet) {
    final slot = _slotForRow(sheet, sheetRowNumber);
    if (slot != null &&
        slot.exercise == exercise &&
        slot.workout == workout &&
        slot.isBackup == isBackup) {
      return const [];
    }
    return [
      ActiveSheetWriteRejection(
        'Row $sheetRowNumber no longer matches $exercise '
        'in workout $workout.',
      ),
    ];
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is ActiveSheetRowExpectation &&
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
    return 'ActiveSheetRowExpectation('
        'sheetRowNumber: $sheetRowNumber, '
        'exercise: $exercise, '
        'workout: $workout, '
        'isBackup: $isBackup'
        ')';
  }
}

class ActiveSheetCellExpectation extends ActiveSheetWriteExpectation {
  const ActiveSheetCellExpectation({
    required this.sheetRowNumber,
    required this.sheetColumnNumber,
    required this.expectedValue,
  });

  final int sheetRowNumber;
  final int sheetColumnNumber;
  final String expectedValue;

  @override
  List<ActiveSheetWriteRejection> writeRejections(ParsedActiveSheet sheet) {
    final actualValue = _cell(
      sheet._sheetRow(sheetRowNumber),
      sheetColumnNumber - 1,
    );
    if (actualValue == expectedValue) {
      return const [];
    }
    return [
      ActiveSheetWriteRejection(
        'Cell row $sheetRowNumber column $sheetColumnNumber no longer matches '
        'the visible value.',
      ),
    ];
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is ActiveSheetCellExpectation &&
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
    return 'ActiveSheetCellExpectation('
        'sheetRowNumber: $sheetRowNumber, '
        'sheetColumnNumber: $sheetColumnNumber, '
        'expectedValue: $expectedValue'
        ')';
  }
}

class ActiveSheetSetColumnExpectation extends ActiveSheetWriteExpectation {
  const ActiveSheetSetColumnExpectation({
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
  List<ActiveSheetWriteRejection> writeRejections(ParsedActiveSheet sheet) {
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
      ActiveSheetWriteRejection(
        'Set column $historyBlockLabel S$setNumber no longer exists at '
        'column $sheetColumnNumber.',
      ),
    ];
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is ActiveSheetSetColumnExpectation &&
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
    return 'ActiveSheetSetColumnExpectation('
        'historyBlockLabel: $historyBlockLabel, '
        'setNumber: $setNumber, '
        'sheetColumnNumber: $sheetColumnNumber, '
        'setLabel: $setLabel'
        ')';
  }
}

class ActiveSheetInsertionPointExpectation extends ActiveSheetWriteExpectation {
  const ActiveSheetInsertionPointExpectation({
    required this.sheetColumnNumber,
    required this.expectedHeaderValue,
    required this.expectedSetLabel,
  });

  final int sheetColumnNumber;
  final String expectedHeaderValue;
  final String expectedSetLabel;

  @override
  List<ActiveSheetWriteRejection> writeRejections(ParsedActiveSheet sheet) {
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

  ActiveSheetWriteRejection _rejection() {
    return ActiveSheetWriteRejection(
      'History insertion point at column $sheetColumnNumber no longer matches '
      'the visible sheet.',
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is ActiveSheetInsertionPointExpectation &&
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
    return 'ActiveSheetInsertionPointExpectation('
        'sheetColumnNumber: $sheetColumnNumber, '
        'expectedHeaderValue: $expectedHeaderValue, '
        'expectedSetLabel: $expectedSetLabel'
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

class _ActiveSheetWritePlanner {
  _ActiveSheetWritePlanner(this.sheet);

  final ParsedActiveSheet sheet;

  ActiveSheetWritePlan planNewHistoryBlock({required String label}) {
    final sheetColumnNumber = activeSheetFixedColumns.length + 1;
    return ActiveSheetWritePlan(
      columnInsertions: [
        HistoryColumnInsertion(
          sheetColumnNumber: sheetColumnNumber,
          headers: [label],
          setLabels: const ['S1'],
        ),
      ],
      expectations: [_insertionPointExpectation(sheetColumnNumber)],
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
      expectations: [
        ActiveSheetSetColumnExpectation(
          historyBlockLabel: label,
          setNumber: block.setColumns.length,
          sheetColumnNumber: block.setColumns.last.sheetColumnNumber,
          setLabel: block.setColumns.last.label,
        ),
        _insertionPointExpectation(block.setColumns.last.sheetColumnNumber + 1),
      ],
    );
  }

  ActiveSheetWritePlan planSetLoggingWrite({
    required String historyBlockLabel,
    required int sheetRowNumber,
    required Map<String, String> fieldValues,
  }) {
    final slot = _slotForRow(sheetRowNumber);
    final expectations = slot == null
        ? const <ActiveSheetWriteExpectation>[]
        : <ActiveSheetWriteExpectation>[_rowExpectation(slot)];
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
        final targetExpectations = [
          ...expectations,
          ActiveSheetSetColumnExpectation(
            historyBlockLabel: historyBlockLabel,
            setNumber: setNumber,
            sheetColumnNumber: column.sheetColumnNumber,
            setLabel: column.label,
          ),
          ActiveSheetCellExpectation(
            sheetRowNumber: sheetRowNumber,
            sheetColumnNumber: column.sheetColumnNumber,
            expectedValue: _cell(row, column.sheetColumnNumber - 1),
          ),
        ];
        return ActiveSheetWritePlan(
          cellUpdates: [
            CellUpdate(
              sheetRowNumber: sheetRowNumber,
              sheetColumnNumber: column.sheetColumnNumber,
              value: renderedSet,
            ),
          ],
          expectations: targetExpectations,
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
      expectations: [...expectations, ...growthPlan.expectations],
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
    final slot = _slotForRow(sheetRowNumber);
    return ActiveSheetWritePlan(
      cellUpdates: [
        CellUpdate(
          sheetRowNumber: sheetRowNumber,
          sheetColumnNumber: column.sheetColumnNumber,
          value: renderedSet,
        ),
      ],
      expectations: [
        if (slot != null) _rowExpectation(slot),
        ActiveSheetSetColumnExpectation(
          historyBlockLabel: historyBlockLabel,
          setNumber: setNumber,
          sheetColumnNumber: column.sheetColumnNumber,
          setLabel: column.label,
        ),
        ActiveSheetCellExpectation(
          sheetRowNumber: sheetRowNumber,
          sheetColumnNumber: column.sheetColumnNumber,
          expectedValue: _cell(
            sheet._sheetRow(sheetRowNumber),
            column.sheetColumnNumber - 1,
          ),
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
    final slot = _slotForRow(sheetRowNumber);
    return ActiveSheetWritePlan(
      cellUpdates: [
        CellUpdate(
          sheetRowNumber: sheetRowNumber,
          sheetColumnNumber: column.sheetColumnNumber,
          value: rawText,
        ),
      ],
      expectations: [
        if (slot != null) _rowExpectation(slot),
        ActiveSheetSetColumnExpectation(
          historyBlockLabel: historyBlockLabel,
          setNumber: setNumber,
          sheetColumnNumber: column.sheetColumnNumber,
          setLabel: column.label,
        ),
        ActiveSheetCellExpectation(
          sheetRowNumber: sheetRowNumber,
          sheetColumnNumber: column.sheetColumnNumber,
          expectedValue: _cell(
            sheet._sheetRow(sheetRowNumber),
            column.sheetColumnNumber - 1,
          ),
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
    final slot = _slotForRow(sheetRowNumber);
    return ActiveSheetWritePlan(
      cellUpdates: [
        CellUpdate(
          sheetRowNumber: sheetRowNumber,
          sheetColumnNumber: column.sheetColumnNumber,
          value: '',
        ),
      ],
      expectations: [
        if (slot != null) _rowExpectation(slot),
        ActiveSheetSetColumnExpectation(
          historyBlockLabel: historyBlockLabel,
          setNumber: setNumber,
          sheetColumnNumber: column.sheetColumnNumber,
          setLabel: column.label,
        ),
        ActiveSheetCellExpectation(
          sheetRowNumber: sheetRowNumber,
          sheetColumnNumber: column.sheetColumnNumber,
          expectedValue: _cell(
            sheet._sheetRow(sheetRowNumber),
            column.sheetColumnNumber - 1,
          ),
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

  ActiveSheetRowExpectation _rowExpectation(WorkoutSlot slot) {
    return ActiveSheetRowExpectation(
      sheetRowNumber: slot.sheetRowNumber,
      exercise: slot.exercise,
      workout: slot.workout,
      isBackup: slot.isBackup,
    );
  }

  ActiveSheetInsertionPointExpectation _insertionPointExpectation(
    int sheetColumnNumber,
  ) {
    return ActiveSheetInsertionPointExpectation(
      sheetColumnNumber: sheetColumnNumber,
      expectedHeaderValue: _cell(sheet._sheetRow(1), sheetColumnNumber - 1),
      expectedSetLabel: _cell(sheet._sheetRow(2), sheetColumnNumber - 1),
    );
  }
}
