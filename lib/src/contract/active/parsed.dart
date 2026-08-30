part of '../active.dart';

class ParsedActiveSheet {
  ParsedActiveSheet._({
    required Iterable<WorkoutSlot> slots,
    Iterable<HistoryBlock> historyBlocks = const [],
    Iterable<WorkoutSlot> primarySlots = const [],
    Iterable<SchemaViolation> schemaViolations = const [],
    Iterable<FormulaHealingIssue> healingIssues = const [],
    Map<String, int> exerciseFormulaColumns = const {},
    this._exerciseColumns,
    required this._columns,
    Iterable<Iterable<String>> rows = const [],
    Iterable<Iterable<String>> exercisesRows = const [],
    Iterable<CellFormula> cellFormulas = const [],
  }) : slots = List<WorkoutSlot>.unmodifiable(slots),
       historyBlocks = List<HistoryBlock>.unmodifiable(historyBlocks),
       primarySlots = List<WorkoutSlot>.unmodifiable(primarySlots),
       schemaViolations = List<SchemaViolation>.unmodifiable(schemaViolations),
       healingIssues = List<FormulaHealingIssue>.unmodifiable(healingIssues),
       _exerciseFormulaColumns = Map<String, int>.unmodifiable(
         exerciseFormulaColumns,
       ),
       _rows = List<List<String>>.unmodifiable(
         rows.map((row) => List<String>.unmodifiable(row)),
       ),
       _exercisesRows = List<List<String>>.unmodifiable(
         exercisesRows.map((row) => List<String>.unmodifiable(row)),
       ),
       _cellFormulas = List<CellFormula>.unmodifiable(cellFormulas);

  final List<WorkoutSlot> slots;
  final List<HistoryBlock> historyBlocks;
  final List<WorkoutSlot> primarySlots;
  final List<SchemaViolation> schemaViolations;
  final List<FormulaHealingIssue> healingIssues;
  final Map<String, int> _exerciseFormulaColumns;
  final _ExercisesColumnIndexes? _exerciseColumns;
  final _FixedColumnIndexes? _columns;
  final List<List<String>> _rows;
  final List<List<String>> _exercisesRows;
  final List<CellFormula> _cellFormulas;

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
  /// [blockLabel] selected from [historyBlocks]. The returned slot row
  /// numbers are the only supported primary-row inputs for
  /// [buildLoggingContext].
  WorkoutOverview buildWorkoutOverview({
    required String workout,
    required String blockLabel,
  }) {
    return _WorkoutReadModelBuilder(
      this,
    ).buildWorkoutOverview(workout: workout, blockLabel: blockLabel);
  }

  /// Builds the row-local logging context for one primary row and choice.
  ///
  /// [primaryRow] must identify a primary row returned by
  /// [buildWorkoutOverview]. [selectedRow] must be either that same
  /// primary row or one of the backup row numbers exposed in the returned
  /// logging choices for that primary row.
  ExerciseLoggingContext buildLoggingContext({
    required int primaryRow,
    required int selectedRow,
    required String blockLabel,
  }) {
    return _WorkoutReadModelBuilder(this).buildLoggingContext(
      primaryRow: primaryRow,
      selectedRow: selectedRow,
      blockLabel: blockLabel,
    );
  }

  /// Plans a new visible history block inserted nearest the fixed metadata.
  ActiveSheetWritePlan planNewHistoryBlock({required String label}) {
    return _WritePlanner(this).planNewHistoryBlock(label: label);
  }

  /// Plans set-column growth for an existing visible history block.
  ActiveSheetWritePlan planHistoryBlockGrowth({
    required String label,
    required int throughSetNumber,
  }) {
    return _WritePlanner(
      this,
    ).planHistoryBlockGrowth(label: label, throughSetNumber: throughSetNumber);
  }

  /// Plans a logged-set write for a parsed exercise row.
  ///
  /// [sheetRowNumber] should come from the read-model row numbers exposed by
  /// [buildWorkoutOverview] or [buildLoggingContext]. Invalid row
  /// numbers or missing history blocks return an empty plan instead of leaking
  /// row-validity checks into callers.
  ActiveSheetWritePlan planSetLoggingWrite({
    required String blockLabel,
    required int sheetRowNumber,
    required Map<String, String> fieldValues,
  }) {
    return _WritePlanner(this).planSetLoggingWrite(
      blockLabel: blockLabel,
      sheetRowNumber: sheetRowNumber,
      fieldValues: fieldValues,
    );
  }

  /// Plans an edit for an existing visible set cell on a parsed exercise row.
  ActiveSheetWritePlan planSetEdit({
    required String blockLabel,
    required int sheetRowNumber,
    required int setNumber,
    required Map<String, String> fieldValues,
  }) {
    return _WritePlanner(this).planSetEdit(
      blockLabel: blockLabel,
      sheetRowNumber: sheetRowNumber,
      setNumber: setNumber,
      fieldValues: fieldValues,
    );
  }

  /// Plans a raw-text edit for an existing visible set cell.
  ActiveSheetWritePlan planRawSetEdit({
    required String blockLabel,
    required int sheetRowNumber,
    required int setNumber,
    required String rawText,
  }) {
    return _WritePlanner(this).planRawSetEdit(
      blockLabel: blockLabel,
      sheetRowNumber: sheetRowNumber,
      setNumber: setNumber,
      rawText: rawText,
    );
  }

  /// Plans a clear for an existing visible set cell on a parsed exercise row.
  ActiveSheetWritePlan planSetClear({
    required String blockLabel,
    required int sheetRowNumber,
    required int setNumber,
  }) {
    return _WritePlanner(this).planSetClear(
      blockLabel: blockLabel,
      sheetRowNumber: sheetRowNumber,
      setNumber: setNumber,
    );
  }

  ExercisesWritePlan planCanonicalAppend(ExerciseDef exercise) {
    return _WritePlanner(this).planCanonicalAppend(exercise);
  }

  ExercisesWritePlan planCanonicalUpdate({
    required CanonicalExercise selectedExercise,
    required ExerciseDef exercise,
  }) {
    return _WritePlanner(this).planCanonicalUpdate(
      selectedExercise: selectedExercise,
      exercise: exercise,
    );
  }

  /// Describes a format change that needs placement-specific confirmation.
  ///
  /// Returns null for the ordinary canonical-only path, including updates
  /// whose format did not change or which have no placed rows.
  ExeFormatImpact? inspectFormatUpdate({
    required CanonicalExercise selectedExercise,
    required ExerciseDef exercise,
  }) {
    if (schemaViolations.isNotEmpty || _columns == null) return null;
    return _formatImpact(this, selected: selectedExercise, exercise: exercise);
  }

  ExercisesWritePlan planCanonicalReorder(ReorderIntent intent) {
    return _WritePlanner(this).planCanonicalReorder(intent);
  }

  ActiveSheetWritePlan planExerciseReorder({
    required String workout,
    required ReorderIntent intent,
  }) {
    return _WritePlanner(
      this,
    ).planExerciseReorder(workout: workout, intent: intent);
  }

  ActiveSheetWritePlan planPrimaryPlacement({
    required CanonicalExercise exercise,
    required String workout,
    WorkoutPlacementMetadata metadata = const WorkoutPlacementMetadata(),
  }) {
    return _WritePlanner(this).planPrimaryPlacement(
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
    return _WritePlanner(this).planBackupPlacement(
      primaryRow: primaryRow,
      exercise: exercise,
      metadata: metadata,
    );
  }

  ActiveSheetWritePlan planDeletePrimary({required int primaryRow}) {
    return _WritePlanner(this).planDeletePrimary(primaryRow: primaryRow);
  }

  ActiveSheetWritePlan planFormulaHealing({
    required int activeSheetRowNumber,
    int? selectedRow,
  }) {
    return _HealingPlanner(this).planFormulaHealing(
      activeSheetRowNumber: activeSheetRowNumber,
      selectedRow: selectedRow,
    );
  }

  /// Plans formula repairs for every issue with exactly one Exercises match.
  ActiveSheetWritePlan planFormulaRepair() {
    return _HealingPlanner(this).planFormulaRepair();
  }

  List<String> _sheetRow(int sheetRowNumber) {
    final rowIndex = sheetRowNumber - 1;
    if (rowIndex < 0 || rowIndex >= _rows.length) {
      return const [];
    }
    return _rows[rowIndex];
  }

  /// The `Exercises` column a formula-driven active column references.
  int _exerciseColumn(String activeColumnName) {
    return _exerciseFormulaColumns[activeColumnName] ??
        _defaultExerciseColumn(activeColumnName);
  }
}
