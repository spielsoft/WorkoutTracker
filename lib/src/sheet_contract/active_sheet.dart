import '../set_notation/set_notation.dart';

const defaultWorkoutName = 'Default';

const activeSheetFixedColumns = [
  'Exercise',
  'Sets',
  'Reps',
  'RPE',
  'Rest',
  'Tempo',
  'Notes',
  'Workout',
  'is_backup',
];

class ActiveSheetInput {
  ActiveSheetInput({
    required Iterable<Iterable<String>> rows,
    Set<int> mergedFirstColumnRows = const {},
  }) : rows = List<List<String>>.unmodifiable(
         rows.map((row) => List<String>.unmodifiable(row)),
       ),
       mergedFirstColumnRows = Set.unmodifiable(mergedFirstColumnRows);

  final List<List<String>> rows;

  /// 1-based sheet row numbers whose first display cell is merged for humans.
  final Set<int> mergedFirstColumnRows;
}

class ParsedActiveSheet {
  ParsedActiveSheet({
    required Iterable<WorkoutSlot> slots,
    Iterable<HistoryBlock> historyBlocks = const [],
    Iterable<WorkoutSlot> primarySlots = const [],
    Iterable<SchemaViolation> schemaViolations = const [],
    Iterable<Iterable<String>> rows = const [],
  }) : slots = List<WorkoutSlot>.unmodifiable(slots),
       historyBlocks = List<HistoryBlock>.unmodifiable(historyBlocks),
       primarySlots = List<WorkoutSlot>.unmodifiable(primarySlots),
       schemaViolations = List<SchemaViolation>.unmodifiable(schemaViolations),
       _rows = List<List<String>>.unmodifiable(
         rows.map((row) => List<String>.unmodifiable(row)),
       );

  final List<WorkoutSlot> slots;
  final List<HistoryBlock> historyBlocks;
  final List<WorkoutSlot> primarySlots;
  final List<SchemaViolation> schemaViolations;
  final List<List<String>> _rows;

  List<String> get selectableWorkouts {
    final workouts = <String>[];
    for (final slot in primarySlots) {
      if (!workouts.contains(slot.workout)) {
        workouts.add(slot.workout);
      }
    }
    return List<String>.unmodifiable(workouts);
  }

  HistoryBlock? selectHistoryBlock(String label) {
    for (final block in historyBlocks) {
      if (block.label == label) {
        return block;
      }
    }
    return null;
  }

  WorkoutOverview buildWorkoutOverview({
    required String workout,
    required String historyBlockLabel,
  }) {
    final block = selectHistoryBlock(historyBlockLabel);
    return WorkoutOverview(
      workout: workout,
      slots: primarySlots
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
    final block = selectHistoryBlock(label);
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
    required SetNotation set,
  }) {
    final block = selectHistoryBlock(historyBlockLabel);
    if (block == null) {
      return ActiveSheetWritePlan();
    }

    final row = _sheetRow(sheetRowNumber);
    for (final column in block.setColumns) {
      if (_cell(row, column.sheetColumnNumber - 1).trim().isEmpty) {
        final setNumber = block.setColumns.indexOf(column) + 1;
        return ActiveSheetWritePlan(
          cellUpdates: [
            CellUpdate(
              sheetRowNumber: sheetRowNumber,
              sheetColumnNumber: column.sheetColumnNumber,
              value: renderSetNotation(set),
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
          value: renderSetNotation(set),
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
    required SetNotation set,
  }) {
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
          value: renderSetNotation(set),
        ),
      ],
    );
  }

  ActiveSheetWritePlan planSetClear({
    required String historyBlockLabel,
    required int sheetRowNumber,
    required int setNumber,
  }) {
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

  List<String> _sheetRow(int sheetRowNumber) {
    final rowIndex = sheetRowNumber - 1;
    if (rowIndex < 0 || rowIndex >= _rows.length) {
      return const [];
    }
    return _rows[rowIndex];
  }

  HistorySetColumn? _setColumn({
    required String historyBlockLabel,
    required int setNumber,
  }) {
    final block = selectHistoryBlock(historyBlockLabel);
    if (block == null || setNumber < 1 || setNumber > block.setColumns.length) {
      return null;
    }
    return block.setColumns[setNumber - 1];
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

  ExerciseLoggingContext buildExerciseLoggingContext({
    required int primarySheetRowNumber,
    required int selectedSheetRowNumber,
    required String historyBlockLabel,
  }) {
    final primary = primarySlots.firstWhere(
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

  int _setCountForRow(int sheetRowNumber, HistoryBlock block) {
    final row = _sheetRow(sheetRowNumber);
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
    final block = selectHistoryBlock(label);
    if (block == null) {
      return RowHistoryBlock(label: label);
    }

    final row = _sheetRow(sheetRowNumber);
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
    final row = _sheetRow(sheetRowNumber);
    final blocks = <RowHistoryBlock>[];
    for (final block in historyBlocks) {
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
  });

  final int sheetRowNumber;
  final String exercise;
  final bool isBackup;
}

class ExerciseLoggingContext {
  ExerciseLoggingContext({
    required this.selectedChoice,
    Iterable<WorkoutChoice> choices = const [],
    required this.notes,
    required this.rest,
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

class HistoryBlock {
  HistoryBlock({
    required this.label,
    Iterable<HistorySetColumn> setColumns = const [],
  }) : setColumns = List<HistorySetColumn>.unmodifiable(setColumns);

  final String label;
  final List<HistorySetColumn> setColumns;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is HistoryBlock &&
            label == other.label &&
            _listEquals(setColumns, other.setColumns);
  }

  @override
  int get hashCode => Object.hash(label, Object.hashAll(setColumns));

  @override
  String toString() {
    return 'HistoryBlock(label: $label, setColumns: $setColumns)';
  }
}

class HistorySetColumn {
  const HistorySetColumn({
    required this.label,
    required this.sheetColumnNumber,
  });

  final String label;
  final int sheetColumnNumber;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is HistorySetColumn &&
            label == other.label &&
            sheetColumnNumber == other.sheetColumnNumber;
  }

  @override
  int get hashCode => Object.hash(label, sheetColumnNumber);

  @override
  String toString() {
    return 'HistorySetColumn('
        'label: $label, '
        'sheetColumnNumber: $sheetColumnNumber'
        ')';
  }
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

class WorkoutSlot {
  WorkoutSlot({
    required this.sheetRowNumber,
    required this.exercise,
    required this.sets,
    required this.reps,
    required this.rpe,
    required this.rest,
    required this.tempo,
    required this.notes,
    required this.workout,
    required this.isBackup,
    Iterable<WorkoutSlot> backups = const [],
  }) : backups = List<WorkoutSlot>.unmodifiable(backups);

  final int sheetRowNumber;
  final String exercise;
  final String sets;
  final String reps;
  final String rpe;
  final String rest;
  final String tempo;
  final String notes;
  final String workout;
  final bool isBackup;
  final List<WorkoutSlot> backups;

  WorkoutSlot _withBackups(Iterable<WorkoutSlot> backups) {
    return WorkoutSlot(
      sheetRowNumber: sheetRowNumber,
      exercise: exercise,
      sets: sets,
      reps: reps,
      rpe: rpe,
      rest: rest,
      tempo: tempo,
      notes: notes,
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
            reps == other.reps &&
            rpe == other.rpe &&
            rest == other.rest &&
            tempo == other.tempo &&
            notes == other.notes &&
            workout == other.workout &&
            isBackup == other.isBackup &&
            _listEquals(backups, other.backups);
  }

  @override
  int get hashCode => Object.hash(
    sheetRowNumber,
    exercise,
    sets,
    reps,
    rpe,
    rest,
    tempo,
    notes,
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
        'reps: $reps, '
        'rpe: $rpe, '
        'rest: $rest, '
        'tempo: $tempo, '
        'notes: $notes, '
        'workout: $workout, '
        'isBackup: $isBackup, '
        'backups: $backups'
        ')';
  }
}

ParsedActiveSheet parseActiveSheet(ActiveSheetInput sheet) {
  if (sheet.rows.isEmpty) {
    return ParsedActiveSheet(slots: const []);
  }

  final columns = _FixedColumnIndexes.fromHeader(sheet.rows.first);
  final historyBlocks = _discoverHistoryBlocks(
    header: sheet.rows.first,
    setHeader: sheet.rows.length > 1 ? sheet.rows[1] : const [],
    firstHistoryColumn: columns.isBackup + 1,
  );
  final slots = <WorkoutSlot>[];
  final primarySlotBuilders = <_PrimarySlotBuilder>[];
  final schemaViolations = <SchemaViolation>[];
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
    final slot = WorkoutSlot(
      sheetRowNumber: sheetRowNumber,
      exercise: exercise,
      sets: _cell(row, columns.sets),
      reps: _cell(row, columns.reps),
      rpe: _cell(row, columns.rpe),
      rest: _cell(row, columns.rest),
      tempo: _cell(row, columns.tempo),
      notes: _cell(row, columns.notes),
      workout: workout.isEmpty ? defaultWorkoutName : workout,
      isBackup: _isTrue(_cell(row, columns.isBackup)),
    );
    slots.add(slot);

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

  return ParsedActiveSheet(
    slots: slots,
    historyBlocks: historyBlocks,
    primarySlots: primarySlotBuilders.map((builder) => builder.toSlot()),
    schemaViolations: schemaViolations,
    rows: sheet.rows,
  );
}

List<HistoryBlock> _discoverHistoryBlocks({
  required List<String> header,
  required List<String> setHeader,
  required int firstHistoryColumn,
}) {
  final builders = <_HistoryBlockBuilder>[];
  for (
    var columnIndex = firstHistoryColumn;
    columnIndex < header.length;
    columnIndex += 1
  ) {
    final label = header[columnIndex].trim();
    if (label.isNotEmpty) {
      builders.add(_HistoryBlockBuilder(label));
    }

    if (builders.isEmpty) {
      continue;
    }

    final setLabel = _cell(setHeader, columnIndex).trim();
    if (setLabel.isNotEmpty) {
      builders.last.setColumns.add(
        HistorySetColumn(label: setLabel, sheetColumnNumber: columnIndex + 1),
      );
    }
  }
  return builders.map((builder) => builder.toBlock()).toList();
}

class _HistoryBlockBuilder {
  _HistoryBlockBuilder(this.label);

  final String label;
  final List<HistorySetColumn> setColumns = [];

  HistoryBlock toBlock() {
    return HistoryBlock(label: label, setColumns: setColumns);
  }
}

class _PrimarySlotBuilder {
  _PrimarySlotBuilder(this.primary);

  final WorkoutSlot primary;
  final List<WorkoutSlot> backups = [];

  WorkoutSlot toSlot() => primary._withBackups(backups);
}

String _cell(List<String> row, int index) {
  if (index < 0 || index >= row.length) {
    return '';
  }
  return row[index];
}

bool _isTrue(String value) {
  return value.trim().toLowerCase() == 'true';
}

WorkoutChoice _choiceForSlot(WorkoutSlot slot) {
  return WorkoutChoice(
    sheetRowNumber: slot.sheetRowNumber,
    exercise: slot.exercise,
    isBackup: slot.isBackup,
  );
}

bool _listEquals<T>(List<T> first, List<T> second) {
  if (first.length != second.length) {
    return false;
  }

  for (var index = 0; index < first.length; index += 1) {
    if (first[index] != second[index]) {
      return false;
    }
  }
  return true;
}

class _FixedColumnIndexes {
  const _FixedColumnIndexes({
    required this.exercise,
    required this.sets,
    required this.reps,
    required this.rpe,
    required this.rest,
    required this.tempo,
    required this.notes,
    required this.workout,
    required this.isBackup,
  });

  factory _FixedColumnIndexes.fromHeader(List<String> header) {
    final indexes = <String, int>{};
    for (var index = 0; index < header.length; index += 1) {
      indexes[header[index]] = index;
    }

    return _FixedColumnIndexes(
      exercise: indexes['Exercise'] ?? 0,
      sets: indexes['Sets'] ?? 1,
      reps: indexes['Reps'] ?? 2,
      rpe: indexes['RPE'] ?? 3,
      rest: indexes['Rest'] ?? 4,
      tempo: indexes['Tempo'] ?? 5,
      notes: indexes['Notes'] ?? 6,
      workout: indexes['Workout'] ?? 7,
      isBackup: indexes['is_backup'] ?? 8,
    );
  }

  final int exercise;
  final int sets;
  final int reps;
  final int rpe;
  final int rest;
  final int tempo;
  final int notes;
  final int workout;
  final int isBackup;
}
