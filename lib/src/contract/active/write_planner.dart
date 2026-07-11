part of '../active.dart';

class _WritePlanner {
  _WritePlanner(ParsedActiveSheet sheet)
    : _context = _WritePlanningContext(sheet);

  final _WritePlanningContext _context;

  bool get _blocked => _context.sheet.schemaViolations.isNotEmpty;

  late final _BlockWritePlanner _historyBlocks = _BlockWritePlanner(_context);
  late final _ExerciseWritePlanner _canonicalExercises = _ExerciseWritePlanner(
    _context,
  );
  late final _WorkoutRowWritePlanner _workoutRows = _WorkoutRowWritePlanner(
    _context,
  );
  late final _SetWritePlanner _sets = _SetWritePlanner(
    context: _context,
    historyBlocks: _historyBlocks,
  );

  ActiveSheetWritePlan planNewHistoryBlock({required String label}) {
    if (_blocked) return ActiveSheetWritePlan();
    return _historyBlocks.planNewHistoryBlock(label: label);
  }

  ActiveSheetWritePlan planHistoryBlockGrowth({
    required String label,
    required int throughSetNumber,
  }) {
    if (_blocked) return ActiveSheetWritePlan();
    return _historyBlocks.planHistoryBlockGrowth(
      label: label,
      throughSetNumber: throughSetNumber,
    );
  }

  ExercisesWritePlan planCanonicalAppend(ExerciseDef exercise) {
    if (_blocked || _context.sheet._exerciseColumns == null) {
      return ExercisesWritePlan();
    }
    return _canonicalExercises.planCanonicalAppend(exercise);
  }

  ExercisesWritePlan planCanonicalUpdate({
    required CanonicalExercise selectedExercise,
    required ExerciseDef exercise,
  }) {
    if (_blocked || _context.sheet._exerciseColumns == null) {
      return ExercisesWritePlan();
    }
    return _canonicalExercises.planCanonicalUpdate(
      selectedExercise: selectedExercise,
      exercise: exercise,
    );
  }

  ExercisesWritePlan planCanonicalReorder(ReorderIntent intent) {
    if (_blocked || _context.sheet._exerciseColumns == null) {
      return ExercisesWritePlan();
    }
    return _canonicalExercises.planCanonicalReorder(intent);
  }

  ActiveSheetWritePlan planExerciseReorder({
    required String workout,
    required ReorderIntent intent,
  }) {
    if (_blocked) return ActiveSheetWritePlan();
    return _workoutRows.planExerciseReorder(workout: workout, intent: intent);
  }

  ActiveSheetWritePlan planPrimaryPlacement({
    required CanonicalExercise exercise,
    required String workout,
    WorkoutPlacementMetadata metadata = const WorkoutPlacementMetadata(),
  }) {
    if (_blocked || _context.sheet._exerciseColumns == null) {
      return ActiveSheetWritePlan();
    }
    return _workoutRows.planPrimaryPlacement(
      exercise: exercise,
      workout: workout,
      metadata: metadata,
    );
  }

  ActiveSheetWritePlan planBackupPlacement({
    required int primaryRow,
    required CanonicalExercise exercise,
    WorkoutPlacementMetadata metadata = const WorkoutPlacementMetadata(),
  }) {
    if (_blocked || _context.sheet._exerciseColumns == null) {
      return ActiveSheetWritePlan();
    }
    return _workoutRows.planBackupPlacement(
      primaryRow: primaryRow,
      exercise: exercise,
      metadata: metadata,
    );
  }

  ActiveSheetWritePlan planDeletePrimary({required int primaryRow}) {
    if (_blocked) return ActiveSheetWritePlan();
    return _workoutRows.planDeletePrimary(primaryRow: primaryRow);
  }

  ActiveSheetWritePlan planSetLoggingWrite({
    required String blockLabel,
    required int sheetRowNumber,
    required Map<String, String> fieldValues,
  }) {
    if (_blocked) return ActiveSheetWritePlan();
    return _sets.planSetLoggingWrite(
      blockLabel: blockLabel,
      sheetRowNumber: sheetRowNumber,
      fieldValues: fieldValues,
    );
  }

  ActiveSheetWritePlan planSetEdit({
    required String blockLabel,
    required int sheetRowNumber,
    required int setNumber,
    required Map<String, String> fieldValues,
  }) {
    if (_blocked) return ActiveSheetWritePlan();
    return _sets.planSetEdit(
      blockLabel: blockLabel,
      sheetRowNumber: sheetRowNumber,
      setNumber: setNumber,
      fieldValues: fieldValues,
    );
  }

  ActiveSheetWritePlan planRawSetEdit({
    required String blockLabel,
    required int sheetRowNumber,
    required int setNumber,
    required String rawText,
  }) {
    if (_blocked) return ActiveSheetWritePlan();
    return _sets.planRawSetEdit(
      blockLabel: blockLabel,
      sheetRowNumber: sheetRowNumber,
      setNumber: setNumber,
      rawText: rawText,
    );
  }

  ActiveSheetWritePlan planSetClear({
    required String blockLabel,
    required int sheetRowNumber,
    required int setNumber,
  }) {
    if (_blocked) return ActiveSheetWritePlan();
    return _sets.planSetClear(
      blockLabel: blockLabel,
      sheetRowNumber: sheetRowNumber,
      setNumber: setNumber,
    );
  }
}
