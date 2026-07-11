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

class _BlockWritePlanner {
  _BlockWritePlanner(this.context);

  final _WritePlanningContext context;

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
      expectations: [context.insertExpct(sheetColumnNumber)],
    );
  }

  ActiveSheetWritePlan planHistoryBlockGrowth({
    required String label,
    required int throughSetNumber,
  }) {
    final block = context.sheet.selectHistoryBlock(label);
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
        SetColumnExpct(
          blockLabel: label,
          setNumber: block.setColumns.length,
          sheetColumnNumber: block.setColumns.last.sheetColumnNumber,
          setLabel: block.setColumns.last.label,
        ),
        context.insertExpct(block.setColumns.last.sheetColumnNumber + 1),
      ],
    );
  }
}

class _SetWritePlanner {
  _SetWritePlanner({required this.context, required this.historyBlocks});

  final _WritePlanningContext context;
  final _BlockWritePlanner historyBlocks;

  ActiveSheetWritePlan planSetLoggingWrite({
    required String blockLabel,
    required int sheetRowNumber,
    required Map<String, String> fieldValues,
  }) {
    final slot = context.slotForRow(sheetRowNumber);
    final renderedSet = context.renderSetForRow(
      sheetRowNumber: sheetRowNumber,
      fieldValues: fieldValues,
    );
    if (renderedSet == null) {
      return ActiveSheetWritePlan();
    }

    final block = context.sheet.selectHistoryBlock(blockLabel);
    if (block == null) {
      return ActiveSheetWritePlan();
    }

    final row = context.sheet._sheetRow(sheetRowNumber);
    for (var index = 0; index < block.setColumns.length; index += 1) {
      final column = block.setColumns[index];
      if (_cell(row, column.sheetColumnNumber - 1).trim().isEmpty) {
        final setNumber = index + 1;
        return ActiveSheetWritePlan(
          cellUpdates: [
            CellUpdate(
              sheetRowNumber: sheetRowNumber,
              sheetColumnNumber: column.sheetColumnNumber,
              value: renderedSet,
            ),
          ],
          expectations: context.setCellExpcts(
            blockLabel: blockLabel,
            setNumber: setNumber,
            sheetRowNumber: sheetRowNumber,
            column: column,
          ),
          nextSetPosition: context.nextSetPosition(
            block: block,
            sheetRowNumber: sheetRowNumber,
            currentSetNumber: setNumber,
          ),
        );
      }
    }

    final newSetNumber = block.setColumns.length + 1;
    final growthPlan = historyBlocks.planHistoryBlockGrowth(
      label: blockLabel,
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
      expectations: [
        ...context.exerciseRowExpcts(slot),
        ...growthPlan.expectations,
      ],
      nextSetPosition: SetPosition(
        sheetRowNumber: sheetRowNumber,
        setNumber: newSetNumber + 1,
        sheetColumnNumber: null,
      ),
    );
  }

  ActiveSheetWritePlan planSetEdit({
    required String blockLabel,
    required int sheetRowNumber,
    required int setNumber,
    required Map<String, String> fieldValues,
  }) {
    final renderedSet = context.renderSetForRow(
      sheetRowNumber: sheetRowNumber,
      fieldValues: fieldValues,
    );
    if (renderedSet == null) {
      return ActiveSheetWritePlan();
    }

    return _planSetWrite(
      blockLabel: blockLabel,
      sheetRowNumber: sheetRowNumber,
      setNumber: setNumber,
      value: renderedSet,
    );
  }

  ActiveSheetWritePlan planRawSetEdit({
    required String blockLabel,
    required int sheetRowNumber,
    required int setNumber,
    required String rawText,
  }) {
    if (!context.isParsedExerciseRow(sheetRowNumber)) {
      return ActiveSheetWritePlan();
    }

    return _planSetWrite(
      blockLabel: blockLabel,
      sheetRowNumber: sheetRowNumber,
      setNumber: setNumber,
      value: rawText,
    );
  }

  ActiveSheetWritePlan planSetClear({
    required String blockLabel,
    required int sheetRowNumber,
    required int setNumber,
  }) {
    if (!context.isParsedExerciseRow(sheetRowNumber)) {
      return ActiveSheetWritePlan();
    }

    return _planSetWrite(
      blockLabel: blockLabel,
      sheetRowNumber: sheetRowNumber,
      setNumber: setNumber,
      value: '',
    );
  }

  ActiveSheetWritePlan _planSetWrite({
    required String blockLabel,
    required int sheetRowNumber,
    required int setNumber,
    required String value,
  }) {
    final column = context.setColumn(
      blockLabel: blockLabel,
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
          value: value,
        ),
      ],
      expectations: context.setCellExpcts(
        blockLabel: blockLabel,
        setNumber: setNumber,
        sheetRowNumber: sheetRowNumber,
        column: column,
      ),
    );
  }
}

class _ExerciseWritePlanner {
  _ExerciseWritePlanner(this.context);

  final _WritePlanningContext context;

  ExercisesWritePlan planCanonicalAppend(ExerciseDef exercise) {
    final append = ExercisesRowAppend(
      sheetRowNumber: 2,
      values: _exerciseValues(exercise),
    );
    return ExercisesWritePlan(rowAppends: [append]);
  }

  ExercisesWritePlan planCanonicalUpdate({
    required CanonicalExercise selectedExercise,
    required ExerciseDef exercise,
  }) {
    final sheetRowNumber = selectedExercise.sheetRowNumber;
    if (sheetRowNumber < 2 ||
        sheetRowNumber > context.sheet._exercisesRows.length) {
      return ExercisesWritePlan();
    }
    return ExercisesWritePlan(
      rowUpdates: [
        ExercisesRowUpdate(
          sheetRowNumber: sheetRowNumber,
          values: _exerciseValues(exercise),
        ),
      ],
    );
  }

  ExercisesWritePlan planCanonicalReorder(ReorderIntent intent) {
    if (context.sheet._exercisesRows.length < 3) {
      return ExercisesWritePlan();
    }
    final header = context.sheet._exercisesRows.first;
    final exerciseRows = context.sheet._exercisesRows.skip(1).toList();
    final reorderedRows = _reordered(exerciseRows, intent);
    if (_nestedListEquals(exerciseRows, reorderedRows)) {
      return ExercisesWritePlan();
    }

    final oldToNewRows = <int, int>{};
    for (var oldIndex = 0; oldIndex < exerciseRows.length; oldIndex += 1) {
      final row = exerciseRows[oldIndex];
      final newIndex = reorderedRows.indexWhere(
        (candidate) => identical(candidate, row),
      );
      if (newIndex >= 0) {
        oldToNewRows[oldIndex + 2] = newIndex + 2;
      }
    }

    return ExercisesWritePlan(
      rowUpdates: [
        for (var index = 0; index < reorderedRows.length; index += 1)
          ExercisesRowUpdate(
            sheetRowNumber: index + 2,
            values: _normalizedExerciseRow(header, reorderedRows[index]),
          ),
      ],
      formulaUpdates: context.reorderFormulaUpdates(oldToNewRows),
      expectations: [
        for (var index = 0; index < exerciseRows.length; index += 1)
          ExercisesRowExpct(
            sheetRowNumber: index + 2,
            expectedValues: exerciseRows[index],
          ),
        ...context.reorderFormulaExpcts(oldToNewRows),
      ],
    );
  }

  List<String> _exerciseValues(ExerciseDef exercise) {
    final header = context.sheet._exercisesRows.first;
    final columns = context.sheet._exerciseColumns!;
    final logFormatColumn = columns.logFormat;
    final row = List.filled(_exerciseRowWidth(header, logFormatColumn), '');
    _setRowValue(row, columns.exercise, exercise.exercise);
    _setRowValue(row, columns.description, exercise.description);
    _setRowValue(row, columns.defaultSets, exercise.defaultSets);
    _setRowValue(row, columns.defaultReps, exercise.defaultReps);
    _setRowValue(row, columns.defaultRpe, exercise.defaultRpe);
    _setRowValue(row, columns.defaultRest, exercise.defaultRest);
    _setRowValue(row, columns.defaultTempo, exercise.defaultTempo);
    _setRowValue(row, columns.notes, exercise.notes);
    _setRowValue(row, logFormatColumn, exercise.resolvedLogFormat);
    return row;
  }

  List<String> _normalizedExerciseRow(List<String> header, List<String> row) {
    final width = header.length < exercisesSheetColumns.length
        ? exercisesSheetColumns.length
        : header.length;
    return [for (var index = 0; index < width; index += 1) _cell(row, index)];
  }

  int _exerciseRowWidth(List<String> header, int logFormatColumn) {
    var width = header.length;
    if (width < exercisesSheetColumns.length) {
      width = exercisesSheetColumns.length;
    }
    if (width <= logFormatColumn) {
      width = logFormatColumn + 1;
    }
    return width;
  }

  void _setRowValue(List<String> row, int index, String value) {
    while (row.length <= index) {
      row.add('');
    }
    row[index] = value;
  }
}

class _WorkoutRowWritePlanner {
  _WorkoutRowWritePlanner(this.context);

  final _WritePlanningContext context;

  ActiveSheetWritePlan planExerciseReorder({
    required String workout,
    required ReorderIntent intent,
  }) {
    final groups = [
      for (final primary in context.sheet.primarySlots)
        _WorkoutExerciseGroup(primary),
    ];
    final workoutGroups = [
      for (final group in groups)
        if (group.primary.workout == workout) group,
    ];
    final reorderedWorkoutGroups = _reordered(workoutGroups, intent);
    if (_listEquals(workoutGroups, reorderedWorkoutGroups)) {
      return ActiveSheetWritePlan();
    }

    var reorderedWorkoutIndex = 0;
    final reorderedGroups = [
      for (final group in groups)
        if (group.primary.workout == workout)
          reorderedWorkoutGroups[reorderedWorkoutIndex++]
        else
          group,
    ];
    final targetRowNumbers = [
      for (final group in groups) ...group.sheetRowNumbers,
    ];
    final sourceRowNumbers = [
      for (final group in reorderedGroups) ...group.sheetRowNumbers,
    ];

    return ActiveSheetWritePlan(
      cellUpdates: [
        for (var index = 0; index < targetRowNumbers.length; index += 1)
          if (targetRowNumbers[index] != sourceRowNumbers[index])
            ...context.rowReorderCellUpdates(
              targetSheetRowNumber: targetRowNumbers[index],
              fromRow: sourceRowNumbers[index],
            ),
      ],
      expectations: [
        for (final rowNumber in targetRowNumbers)
          RowValuesExpct(
            sheetRowNumber: rowNumber,
            expectedValues: context.sheet._sheetRow(rowNumber),
          ),
        for (final formula in context.sheet._cellFormulas)
          if (targetRowNumbers.contains(formula.sheetRowNumber))
            FormulaExpct(
              sheetRowNumber: formula.sheetRowNumber,
              sheetColumnNumber: formula.sheetColumnNumber,
              expectedFormula: formula.formula,
            ),
      ],
    );
  }

  ActiveSheetWritePlan planPrimaryPlacement({
    required CanonicalExercise exercise,
    required String workout,
    WorkoutPlacementMetadata metadata = const WorkoutPlacementMetadata(),
  }) {
    final exercisesSheetRowNumber = exercise.sheetRowNumber;
    if (exercisesSheetRowNumber < 2) {
      return ActiveSheetWritePlan();
    }
    return _workoutPlacementPlan(
      sheetRowNumber: context.sheet._rows.length + 1,
      exercisesSheetRowNumber: exercisesSheetRowNumber,
      workout: workout,
      isBackup: false,
      metadata: metadata,
    );
  }

  ActiveSheetWritePlan planBackupPlacement({
    required int primaryRow,
    required CanonicalExercise exercise,
    WorkoutPlacementMetadata metadata = const WorkoutPlacementMetadata(),
  }) {
    final exercisesSheetRowNumber = exercise.sheetRowNumber;
    if (exercisesSheetRowNumber < 2) {
      return ActiveSheetWritePlan();
    }
    final primary = context.primarySlotForRow(primaryRow);
    if (primary == null) {
      return ActiveSheetWritePlan();
    }

    return _workoutPlacementPlan(
      sheetRowNumber: context.backupInsertionRowNumber(primary),
      exercisesSheetRowNumber: exercisesSheetRowNumber,
      workout: primary.workout,
      isBackup: true,
      parentPrimary: primary,
      metadata: metadata,
    );
  }

  ActiveSheetWritePlan planDeletePrimary({required int primaryRow}) {
    final primary = context.primarySlotForRow(primaryRow);
    if (primary == null) {
      return ActiveSheetWritePlan();
    }
    return ActiveSheetWritePlan(
      rowDeletions: context.rowDeletionsForSheetRows([
        primary.sheetRowNumber,
        for (final backup in primary.backups) backup.sheetRowNumber,
      ]),
      expectations: [
        context.rowExpct(primary),
        for (final backup in primary.backups) context.rowExpct(backup),
        BackupGroupExpct(
          primaryRow: primary.sheetRowNumber,
          expectedBackups: [
            for (final backup in primary.backups) context.rowExpct(backup),
          ],
        ),
      ],
    );
  }

  ActiveSheetWritePlan _workoutPlacementPlan({
    required int sheetRowNumber,
    required int exercisesSheetRowNumber,
    required String workout,
    required bool isBackup,
    required WorkoutPlacementMetadata metadata,
    WorkoutSlot? parentPrimary,
  }) {
    return ActiveSheetWritePlan(
      rowInsertions: [
        RowInsertion(
          sheetRowNumber: sheetRowNumber,
          cellCount: context.activeSheetRowWidth,
        ),
      ],
      cellUpdates: _placementUpdates(
        sheetRowNumber: sheetRowNumber,
        exercisesSheetRowNumber: exercisesSheetRowNumber,
        workout: workout,
        isBackup: isBackup,
        metadata: metadata,
      ),
      expectations: [
        if (parentPrimary != null) context.rowExpct(parentPrimary),
        context.rowInsertExpct(sheetRowNumber),
      ],
    );
  }

  List<CellUpdate> _placementUpdates({
    required int sheetRowNumber,
    required int exercisesSheetRowNumber,
    required String workout,
    required bool isBackup,
    required WorkoutPlacementMetadata metadata,
  }) {
    final activeColumns = context.sheet._columns!;
    final formulaColumns = [
      _FormulaDrivenColumn(
        activeColumnName: 'Exercise',
        activeSheetColumnIndex: activeColumns.exercise,
        exerciseColumnIndex: context.exerciseColumn('Exercise') - 1,
      ),
      _FormulaDrivenColumn(
        activeColumnName: 'Log Format',
        activeSheetColumnIndex: activeColumns.logFormat,
        exerciseColumnIndex: context.exerciseColumn('Log Format') - 1,
      ),
    ];

    return [
      for (final column in formulaColumns)
        CellUpdate.formula(
          sheetRowNumber: sheetRowNumber,
          sheetColumnNumber: column.activeSheetColumnIndex + 1,
          value: _directExercisesFormula(
            exerciseColumn: column.exerciseColumnIndex + 1,
            exercisesSheetRowNumber: exercisesSheetRowNumber,
          ),
        ),
      CellUpdate(
        sheetRowNumber: sheetRowNumber,
        sheetColumnNumber: activeColumns.workout + 1,
        value: _workoutCellValue(workout),
      ),
      CellUpdate(
        sheetRowNumber: sheetRowNumber,
        sheetColumnNumber: activeColumns.sets + 1,
        value: metadata.sets,
      ),
      CellUpdate(
        sheetRowNumber: sheetRowNumber,
        sheetColumnNumber: activeColumns.reps + 1,
        value: metadata.reps,
      ),
      CellUpdate(
        sheetRowNumber: sheetRowNumber,
        sheetColumnNumber: activeColumns.rpe + 1,
        value: metadata.rpe,
      ),
      CellUpdate(
        sheetRowNumber: sheetRowNumber,
        sheetColumnNumber: activeColumns.rest + 1,
        value: metadata.rest,
      ),
      CellUpdate(
        sheetRowNumber: sheetRowNumber,
        sheetColumnNumber: activeColumns.tempo + 1,
        value: metadata.tempo,
      ),
      CellUpdate(
        sheetRowNumber: sheetRowNumber,
        sheetColumnNumber: activeColumns.notes + 1,
        value: metadata.notes,
      ),
      CellUpdate(
        sheetRowNumber: sheetRowNumber,
        sheetColumnNumber: activeColumns.isBackup + 1,
        value: isBackup ? 'TRUE' : '',
      ),
    ];
  }

  String _workoutCellValue(String workout) {
    final trimmed = workout.trim();
    return trimmed == defaultWorkoutName ? '' : trimmed;
  }
}
