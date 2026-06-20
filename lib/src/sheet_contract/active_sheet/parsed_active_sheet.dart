part of '../active_sheet.dart';

class ParsedActiveSheet {
  ParsedActiveSheet._({
    required Iterable<WorkoutSlot> slots,
    Iterable<HistoryBlock> historyBlocks = const [],
    Iterable<WorkoutSlot> primarySlots = const [],
    Iterable<SchemaViolation> schemaViolations = const [],
    Iterable<FormulaHealingIssue> formulaHealingIssues = const [],
    Map<String, int> formulaExerciseColumnNumbers = const {},
    Iterable<Iterable<String>> rows = const [],
    Iterable<Iterable<String>> exercisesRows = const [],
  }) : slots = List<WorkoutSlot>.unmodifiable(slots),
       historyBlocks = List<HistoryBlock>.unmodifiable(historyBlocks),
       primarySlots = List<WorkoutSlot>.unmodifiable(primarySlots),
       schemaViolations = List<SchemaViolation>.unmodifiable(schemaViolations),
       formulaHealingIssues = List<FormulaHealingIssue>.unmodifiable(
         formulaHealingIssues,
       ),
       _formulaExerciseColumnNumbers = Map<String, int>.unmodifiable(
         formulaExerciseColumnNumbers,
       ),
       _rows = List<List<String>>.unmodifiable(
         rows.map((row) => List<String>.unmodifiable(row)),
       ),
       _exercisesRows = List<List<String>>.unmodifiable(
         exercisesRows.map((row) => List<String>.unmodifiable(row)),
       );

  final List<WorkoutSlot> slots;
  final List<HistoryBlock> historyBlocks;
  final List<WorkoutSlot> primarySlots;
  final List<SchemaViolation> schemaViolations;
  final List<FormulaHealingIssue> formulaHealingIssues;
  final Map<String, int> _formulaExerciseColumnNumbers;
  final List<List<String>> _rows;
  final List<List<String>> _exercisesRows;

  List<String> get selectableWorkouts {
    return _WorkoutReadModelBuilder(this).selectableWorkouts;
  }

  List<CanonicalExercise> get canonicalExercises {
    return _WorkoutReadModelBuilder(this).canonicalExercises;
  }

  HistoryBlock? selectHistoryBlock(String label) {
    for (final block in historyBlocks) {
      if (block.label == label) {
        return block;
      }
    }
    return null;
  }

  /// Builds the overview for one workout in parsed active-sheet order.
  ///
  /// Callers should pass a [workout] selected from [selectableWorkouts] and a
  /// [historyBlockLabel] selected from [historyBlocks]. The returned slot row
  /// numbers are the only supported primary-row inputs for
  /// [buildExerciseLoggingContext].
  WorkoutOverview buildWorkoutOverview({
    required String workout,
    required String historyBlockLabel,
  }) {
    return _WorkoutReadModelBuilder(this).buildWorkoutOverview(
      workout: workout,
      historyBlockLabel: historyBlockLabel,
    );
  }

  /// Builds the row-local logging context for one primary row and choice.
  ///
  /// [primarySheetRowNumber] must identify a primary row returned by
  /// [buildWorkoutOverview]. [selectedSheetRowNumber] must be either that same
  /// primary row or one of the backup row numbers exposed in the returned
  /// logging choices for that primary row.
  ExerciseLoggingContext buildExerciseLoggingContext({
    required int primarySheetRowNumber,
    required int selectedSheetRowNumber,
    required String historyBlockLabel,
  }) {
    return _WorkoutReadModelBuilder(this).buildExerciseLoggingContext(
      primarySheetRowNumber: primarySheetRowNumber,
      selectedSheetRowNumber: selectedSheetRowNumber,
      historyBlockLabel: historyBlockLabel,
    );
  }

  /// Plans a new visible history block inserted nearest the fixed metadata.
  ActiveSheetWritePlan planNewHistoryBlock({required String label}) {
    return _ActiveSheetWritePlanner(this).planNewHistoryBlock(label: label);
  }

  /// Plans set-column growth for an existing visible history block.
  ActiveSheetWritePlan planHistoryBlockGrowth({
    required String label,
    required int throughSetNumber,
  }) {
    return _ActiveSheetWritePlanner(
      this,
    ).planHistoryBlockGrowth(label: label, throughSetNumber: throughSetNumber);
  }

  /// Plans a logged-set write for a parsed exercise row.
  ///
  /// [sheetRowNumber] should come from the read-model row numbers exposed by
  /// [buildWorkoutOverview] or [buildExerciseLoggingContext]. Invalid row
  /// numbers or missing history blocks return an empty plan instead of leaking
  /// row-validity checks into callers.
  ActiveSheetWritePlan planSetLoggingWrite({
    required String historyBlockLabel,
    required int sheetRowNumber,
    required Map<String, String> fieldValues,
  }) {
    return _ActiveSheetWritePlanner(this).planSetLoggingWrite(
      historyBlockLabel: historyBlockLabel,
      sheetRowNumber: sheetRowNumber,
      fieldValues: fieldValues,
    );
  }

  /// Plans an edit for an existing visible set cell on a parsed exercise row.
  ActiveSheetWritePlan planSetEdit({
    required String historyBlockLabel,
    required int sheetRowNumber,
    required int setNumber,
    required Map<String, String> fieldValues,
  }) {
    return _ActiveSheetWritePlanner(this).planSetEdit(
      historyBlockLabel: historyBlockLabel,
      sheetRowNumber: sheetRowNumber,
      setNumber: setNumber,
      fieldValues: fieldValues,
    );
  }

  /// Plans a raw-text edit for an existing visible set cell.
  ActiveSheetWritePlan planRawSetEdit({
    required String historyBlockLabel,
    required int sheetRowNumber,
    required int setNumber,
    required String rawText,
  }) {
    return _ActiveSheetWritePlanner(this).planRawSetEdit(
      historyBlockLabel: historyBlockLabel,
      sheetRowNumber: sheetRowNumber,
      setNumber: setNumber,
      rawText: rawText,
    );
  }

  /// Plans a clear for an existing visible set cell on a parsed exercise row.
  ActiveSheetWritePlan planSetClear({
    required String historyBlockLabel,
    required int sheetRowNumber,
    required int setNumber,
  }) {
    return _ActiveSheetWritePlanner(this).planSetClear(
      historyBlockLabel: historyBlockLabel,
      sheetRowNumber: sheetRowNumber,
      setNumber: setNumber,
    );
  }

  ExercisesWritePlan planCanonicalExerciseAppend(
    CanonicalExerciseDefinition exercise,
  ) {
    return _ActiveSheetWritePlanner(this).planCanonicalExerciseAppend(exercise);
  }

  ExercisesWritePlan planCanonicalExerciseUpdate({
    required CanonicalExercise selectedExercise,
    required CanonicalExerciseDefinition exercise,
  }) {
    return _ActiveSheetWritePlanner(this).planCanonicalExerciseUpdate(
      selectedExercise: selectedExercise,
      exercise: exercise,
    );
  }

  ActiveSheetWritePlan planPrimaryWorkoutPlacement({
    required CanonicalExercise exercise,
    required String workout,
    WorkoutPlacementMetadata metadata = const WorkoutPlacementMetadata(),
  }) {
    return _ActiveSheetWritePlanner(this).planPrimaryWorkoutPlacement(
      exercise: exercise,
      workout: workout,
      metadata: metadata,
    );
  }

  ActiveSheetWritePlan planBackupWorkoutPlacement({
    required int primarySheetRowNumber,
    required CanonicalExercise exercise,
    WorkoutPlacementMetadata metadata = const WorkoutPlacementMetadata(),
  }) {
    return _ActiveSheetWritePlanner(this).planBackupWorkoutPlacement(
      primarySheetRowNumber: primarySheetRowNumber,
      exercise: exercise,
      metadata: metadata,
    );
  }

  ActiveSheetWritePlan planFormulaHealing({
    required int activeSheetRowNumber,
    int? selectedExerciseSheetRowNumber,
  }) {
    return _FormulaHealingPlanner(this).planFormulaHealing(
      activeSheetRowNumber: activeSheetRowNumber,
      selectedExerciseSheetRowNumber: selectedExerciseSheetRowNumber,
    );
  }

  /// Plans formula repairs for every issue with exactly one Exercises match.
  ActiveSheetWritePlan planUnambiguousFormulaHealing() {
    return _FormulaHealingPlanner(this).planUnambiguousFormulaHealing();
  }

  List<String> _sheetRow(int sheetRowNumber) {
    final rowIndex = sheetRowNumber - 1;
    if (rowIndex < 0 || rowIndex >= _rows.length) {
      return const [];
    }
    return _rows[rowIndex];
  }
}
