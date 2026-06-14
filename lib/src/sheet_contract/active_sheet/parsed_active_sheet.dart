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
       );

  final List<WorkoutSlot> slots;
  final List<HistoryBlock> historyBlocks;
  final List<WorkoutSlot> primarySlots;
  final List<SchemaViolation> schemaViolations;
  final List<FormulaHealingIssue> formulaHealingIssues;
  final Map<String, int> _formulaExerciseColumnNumbers;
  final List<List<String>> _rows;

  List<String> get selectableWorkouts {
    return _WorkoutReadModelBuilder(this).selectableWorkouts;
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
    return _WorkoutReadModelBuilder(this).buildWorkoutOverview(
      workout: workout,
      historyBlockLabel: historyBlockLabel,
    );
  }

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

  ActiveSheetWritePlan planNewHistoryBlock({required String label}) {
    return _ActiveSheetWritePlanner(this).planNewHistoryBlock(label: label);
  }

  ActiveSheetWritePlan planHistoryBlockGrowth({
    required String label,
    required int throughSetNumber,
  }) {
    return _ActiveSheetWritePlanner(
      this,
    ).planHistoryBlockGrowth(label: label, throughSetNumber: throughSetNumber);
  }

  ActiveSheetWritePlan planSetLoggingWrite({
    required String historyBlockLabel,
    required int sheetRowNumber,
    required SetNotation set,
  }) {
    return _ActiveSheetWritePlanner(this).planSetLoggingWrite(
      historyBlockLabel: historyBlockLabel,
      sheetRowNumber: sheetRowNumber,
      set: set,
    );
  }

  ActiveSheetWritePlan planSetEdit({
    required String historyBlockLabel,
    required int sheetRowNumber,
    required int setNumber,
    required SetNotation set,
  }) {
    return _ActiveSheetWritePlanner(this).planSetEdit(
      historyBlockLabel: historyBlockLabel,
      sheetRowNumber: sheetRowNumber,
      setNumber: setNumber,
      set: set,
    );
  }

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

  ActiveSheetWritePlan planFormulaHealing({
    required int activeSheetRowNumber,
    int? selectedExerciseSheetRowNumber,
  }) {
    return _FormulaHealingPlanner(this).planFormulaHealing(
      activeSheetRowNumber: activeSheetRowNumber,
      selectedExerciseSheetRowNumber: selectedExerciseSheetRowNumber,
    );
  }

  List<String> _sheetRow(int sheetRowNumber) {
    final rowIndex = sheetRowNumber - 1;
    if (rowIndex < 0 || rowIndex >= _rows.length) {
      return const [];
    }
    return _rows[rowIndex];
  }
}
