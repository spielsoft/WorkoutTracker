part of '../active.dart';

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
