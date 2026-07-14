import 'package:workout_tracker/contract.dart';
import 'package:workout_tracker/sheets.dart';

import 'validation_core.dart';

abstract interface class WbkIo {
  Future<ParsedActiveSheet> read();

  Future<void> writeActive(ActiveSheetWritePlan plan);

  Future<void> writeExercises(ExercisesWritePlan plan);

  Future<void> writeExeUpdate(ExeUpdatePlan plan);
}

class AdapterWbkIo implements WbkIo {
  const AdapterWbkIo({
    required this.sheetId,
    required this.readAdapter,
    required this.writeAdapter,
  });

  final String sheetId;
  final SheetsReadAdapter readAdapter;
  final SheetsWriteAdapter writeAdapter;

  @override
  Future<ParsedActiveSheet> read() {
    return readAdapter.readParsedActiveSheet(sheetId);
  }

  @override
  Future<void> writeActive(ActiveSheetWritePlan plan) {
    return writeAdapter.applyWritePlan(spreadsheetId: sheetId, plan: plan);
  }

  @override
  Future<void> writeExercises(ExercisesWritePlan plan) {
    return writeAdapter.applyExercisesPlan(spreadsheetId: sheetId, plan: plan);
  }

  @override
  Future<void> writeExeUpdate(ExeUpdatePlan plan) {
    return writeAdapter.applyExeUpdate(spreadsheetId: sheetId, plan: plan);
  }
}

class ValSess implements WbkSess {
  ValSess({required this.sheetId, required this.io});

  static const _readRetries = 6;

  @override
  final String sheetId;
  final WbkIo io;
  ValReport? _report;

  @override
  Future<ValReport> read() => _read();

  @override
  Future<ValReport> execute(WbkCmd cmd) async {
    final baseline = await _baseline();
    if (baseline.schemaViolations.isNotEmpty) {
      return _rejectSchema(baseline);
    }
    return switch (cmd) {
      NewHistoryCmd(:final label) => _commitActive(
        baseline.activeSheet.planNewHistoryBlock(label: label),
        baseline,
      ),
      RepairAllCmd() => _commitActive(
        baseline.activeSheet.planFormulaRepair(),
        baseline,
      ),
      RepairOneCmd(:final activeRow, :final exerciseRow) => _commitActive(
        baseline.activeSheet.planFormulaHealing(
          activeSheetRowNumber: activeRow,
          selectedRow: exerciseRow,
        ),
        baseline,
      ),
      SaveSetCmd(:final blockLabel, :final sheetRow, :final fields) =>
        _commitActive(
          baseline.activeSheet.planSetLoggingWrite(
            blockLabel: blockLabel,
            sheetRowNumber: sheetRow,
            fieldValues: fields,
          ),
          baseline,
        ),
      EditSetCmd(
        :final blockLabel,
        :final sheetRow,
        :final setNumber,
        :final fields,
      ) =>
        _commitActive(
          baseline.activeSheet.planSetEdit(
            blockLabel: blockLabel,
            sheetRowNumber: sheetRow,
            setNumber: setNumber,
            fieldValues: fields,
          ),
          baseline,
        ),
      EditRawSetCmd(
        :final blockLabel,
        :final sheetRow,
        :final setNumber,
        :final rawText,
      ) =>
        _commitActive(
          baseline.activeSheet.planRawSetEdit(
            blockLabel: blockLabel,
            sheetRowNumber: sheetRow,
            setNumber: setNumber,
            rawText: rawText,
          ),
          baseline,
        ),
      ClearSetCmd(:final blockLabel, :final sheetRow, :final setNumber) =>
        _commitActive(
          baseline.activeSheet.planSetClear(
            blockLabel: blockLabel,
            sheetRowNumber: sheetRow,
            setNumber: setNumber,
          ),
          baseline,
        ),
      CreateExeCmd(:final exercise) => _createExe(exercise),
      UpdateExeCmd(:final selected, :final exercise) => _updateExe(
        baseline,
        selected: selected,
        exercise: exercise,
      ),
      ConfirmExeUpdateCmd(:final impact, :final valuesByRow) =>
        _commitExeUpdate(impact.plan(valuesByRow)),
      PlaceExeCmd(:final exercise, :final metadata, :final placement) =>
        _placeExe(
          baseline,
          exercise: exercise,
          metadata: metadata,
          placement: placement,
        ),
      ReorderExesCmd(:final intent) => _commitExercises(
        baseline.activeSheet.planCanonicalReorder(intent),
        baseline,
      ),
      ReorderWorkoutCmd(:final workout, :final intent) => _commitActive(
        baseline.activeSheet.planExerciseReorder(
          workout: workout,
          intent: intent,
        ),
        baseline,
      ),
      DeleteWorkoutExeCmd(:final primaryRow) => _deleteWorkoutExe(
        baseline,
        primaryRow,
      ),
    };
  }

  Future<ValReport> _createExe(ExerciseDef exercise) async {
    final current = await _read();
    if (current.schemaViolations.isNotEmpty) {
      return _rejectSchema(current);
    }
    final plan = current.activeSheet.planCanonicalAppend(exercise);
    if (plan.rowAppends.singleOrNull == null) {
      throw StateError('No exercise row was planned.');
    }
    await io.writeExercises(plan);
    return _read();
  }

  Future<ValReport> _placeExe(
    ValReport baseline, {
    required CanonicalExercise exercise,
    required WorkoutPlacementMetadata metadata,
    required ExercisePlacementTarget placement,
  }) {
    final plan = placement.isBackup
        ? baseline.activeSheet.planBackupPlacement(
            primaryRow: placement.primaryRow!,
            exercise: exercise,
            metadata: metadata,
          )
        : baseline.activeSheet.planPrimaryPlacement(
            exercise: exercise,
            workout: placement.workout ?? defaultWorkoutName,
            metadata: metadata,
          );
    return _commitActive(plan, baseline, selected: exercise);
  }

  Future<ValReport> _updateExe(
    ValReport baseline, {
    required CanonicalExercise selected,
    required ExerciseDef exercise,
  }) {
    if (selected.logFormat != exercise.resolvedLogFormat &&
        baseline.healingIssues.isNotEmpty) {
      return Future.value(
        _reject(
          baseline,
          const WriteRejection(
            'Repair active-sheet formulas before updating an exercise.',
          ),
        ),
      );
    }
    final impact = baseline.activeSheet.inspectFormatUpdate(
      selectedExercise: selected,
      exercise: exercise,
    );
    if (impact != null) {
      final report = ValReport(
        spreadsheetId: sheetId,
        activeSheet: baseline.activeSheet,
        exeFormatImpact: impact,
      );
      _report = report;
      return Future.value(report);
    }
    return _commitExercises(
      baseline.activeSheet.planCanonicalUpdate(
        selectedExercise: selected,
        exercise: exercise,
      ),
      baseline,
      selected: selected,
    );
  }

  Future<ValReport> _commitExeUpdate(ExeUpdatePlan plan) async {
    final current = await _read();
    if (current.schemaViolations.isNotEmpty) return _rejectSchema(current);
    final rejections = plan.writeRejections(current.activeSheet);
    if (rejections.isNotEmpty) return _rejectAll(current, rejections);
    await io.writeExeUpdate(plan);
    return _read();
  }

  Future<ValReport> _deleteWorkoutExe(
    ValReport baseline,
    int primaryRow,
  ) async {
    final plan = baseline.activeSheet.planDeletePrimary(primaryRow: primaryRow);
    if (plan.rowDeletions.isNotEmpty) {
      return _commitActive(plan, baseline);
    }
    final current = await _read();
    return _reject(
      current,
      WriteRejection(
        'Row $primaryRow is no longer a primary workout exercise.',
      ),
    );
  }

  Future<ValReport> _commitActive(
    ActiveSheetWritePlan plan,
    ValReport baseline, {
    CanonicalExercise? selected,
  }) async {
    final current = await _read();
    if (current.schemaViolations.isNotEmpty) {
      return _rejectSchema(current);
    }
    final exerciseRejection = selected == null
        ? null
        : _exerciseRowRejection(
            currentSheet: current.activeSheet,
            selectedExercise: selected,
          );
    if (exerciseRejection != null) {
      return _reject(current, exerciseRejection);
    }
    final rejections = plan.writeRejections(current.activeSheet);
    if (rejections.isNotEmpty) {
      return _rejectAll(current, rejections);
    }
    if (_activePlanIsEmpty(plan)) {
      return current;
    }

    await io.writeActive(plan);
    return _confirmActive(plan, baseline);
  }

  Future<ValReport> _commitExercises(
    ExercisesWritePlan plan,
    ValReport baseline, {
    CanonicalExercise? selected,
  }) async {
    final current = await _read();
    if (current.schemaViolations.isNotEmpty) {
      return _rejectSchema(current);
    }
    final exerciseRejection = selected == null
        ? null
        : _exerciseRowRejection(
            currentSheet: current.activeSheet,
            selectedExercise: selected,
          );
    if (exerciseRejection != null) {
      return _reject(current, exerciseRejection);
    }
    final rejections = plan.writeRejections(current.activeSheet);
    if (rejections.isNotEmpty) {
      return _rejectAll(current, rejections);
    }
    if (_exercisesPlanIsEmpty(plan)) {
      return current;
    }

    await io.writeExercises(plan);
    return _read();
  }

  Future<ValReport> _confirmActive(
    ActiveSheetWritePlan plan,
    ValReport baseline,
  ) async {
    var latest = await _read();
    if (plan.retainsLoggedSetWrite(latest.activeSheet)) {
      return latest;
    }
    for (var i = 0; i < _readRetries; i += 1) {
      latest = await _read();
      if (plan.retainsLoggedSetWrite(latest.activeSheet)) {
        return latest;
      }
    }
    _report = baseline;
    throw const _WriteFail('saved set was not visible after refresh.');
  }

  Future<ValReport> _baseline() async => _report ?? _read();

  Future<ValReport> _read() async {
    final report = ValReport(
      spreadsheetId: sheetId,
      activeSheet: await io.read(),
    );
    _report = report;
    return report;
  }

  ValReport _reject(ValReport current, WriteRejection rejection) {
    return _rejectAll(current, [rejection]);
  }

  ValReport _rejectSchema(ValReport current) {
    return _reject(
      current,
      const WriteRejection(
        'Workbook schema is invalid. No spreadsheet changes were applied.',
      ),
    );
  }

  ValReport _rejectAll(ValReport current, Iterable<WriteRejection> rejections) {
    final report = ValReport(
      spreadsheetId: sheetId,
      activeSheet: current.activeSheet,
      writeRejections: rejections,
    );
    _report = report;
    return report;
  }
}

class _WriteFail implements Exception {
  const _WriteFail(this.message);

  final String message;

  @override
  String toString() => message;
}

bool _activePlanIsEmpty(ActiveSheetWritePlan plan) {
  return plan.columnInsertions.isEmpty &&
      plan.rowInsertions.isEmpty &&
      plan.rowDeletions.isEmpty &&
      plan.cellUpdates.isEmpty;
}

bool _exercisesPlanIsEmpty(ExercisesWritePlan plan) {
  return plan.rowAppends.isEmpty &&
      plan.rowUpdates.isEmpty &&
      plan.formulaUpdates.isEmpty;
}

WriteRejection? _exerciseRowRejection({
  required ParsedActiveSheet currentSheet,
  required CanonicalExercise selectedExercise,
}) {
  final current = currentSheet.canonicalExercises
      .where(
        (exercise) =>
            exercise.sheetRowNumber == selectedExercise.sheetRowNumber,
      )
      .firstOrNull;
  if (current != null && _sameExercise(selectedExercise, current)) {
    return null;
  }
  return WriteRejection(
    'Exercises row ${selectedExercise.sheetRowNumber} no longer matches '
    '${selectedExercise.displayName}.',
  );
}

bool _sameExercise(CanonicalExercise a, CanonicalExercise b) {
  return a.sheetRowNumber == b.sheetRowNumber &&
      a.exercise == b.exercise &&
      a.description == b.description &&
      a.defaultSets == b.defaultSets &&
      a.defaultRest == b.defaultRest &&
      a.defaultTempo == b.defaultTempo &&
      a.notes == b.notes &&
      a.logFormat == b.logFormat &&
      _sameFields(a.defaultValues, b.defaultValues);
}

bool _sameFields(Map<String, String> a, Map<String, String> b) {
  if (a.length != b.length) return false;
  return a.entries.every((entry) => b[entry.key] == entry.value);
}
