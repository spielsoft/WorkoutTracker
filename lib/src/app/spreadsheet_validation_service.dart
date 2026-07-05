import 'package:workout_tracker/google_sheets.dart';
import 'package:workout_tracker/sheet_contract.dart';

import 'spreadsheet_validation_core.dart';

class ValidationService implements WorkbookService {
  const ValidationService({required this.readAdapter, this.writeAdapter});

  final SheetsReadAdapter readAdapter;
  final SheetsWriteAdapter? writeAdapter;

  @override
  Future<ValidationReport> validateSpreadsheet(String spreadsheetId) async {
    return ValidationReport(
      spreadsheetId: spreadsheetId,
      activeSheet: await readAdapter.readParsedActiveSheet(spreadsheetId),
    );
  }

  @override
  Future<ValidationReport> applyWritePlan({
    required String spreadsheetId,
    required ParsedActiveSheet activeSheet,
    required ActiveSheetWritePlan plan,
  }) async {
    final writeAdapter = this.writeAdapter;
    if (writeAdapter == null) {
      throw StateError('Sheet writes require a write adapter.');
    }
    final currentActiveSheet = await readAdapter.readParsedActiveSheet(
      spreadsheetId,
    );
    final writeRejections = plan.writeRejections(currentActiveSheet);
    if (writeRejections.isNotEmpty) {
      return ValidationReport(
        spreadsheetId: spreadsheetId,
        activeSheet: currentActiveSheet,
        writeRejections: writeRejections,
      );
    }
    await writeAdapter.applyWritePlan(spreadsheetId: spreadsheetId, plan: plan);
    return validateSpreadsheet(spreadsheetId);
  }

  @override
  Future<ValidationReport> createExercise({
    required String spreadsheetId,
    required ParsedActiveSheet activeSheet,
    required ExerciseDef exercise,
  }) async {
    final writeAdapter = this.writeAdapter;
    if (writeAdapter == null) {
      throw StateError('Exercise authoring requires a write adapter.');
    }

    final currentActiveSheet = await readAdapter.readParsedActiveSheet(
      spreadsheetId,
    );
    final exercisesPlan = currentActiveSheet.planCanonicalAppend(exercise);
    final exercisesRow = exercisesPlan.rowAppends.singleOrNull;
    if (exercisesRow == null) {
      throw StateError('No exercise row was planned.');
    }

    await writeAdapter.applyExercisesPlan(
      spreadsheetId: spreadsheetId,
      plan: exercisesPlan,
    );
    return validateSpreadsheet(spreadsheetId);
  }

  @override
  Future<ValidationReport> updateExercise({
    required String spreadsheetId,
    required ParsedActiveSheet activeSheet,
    required CanonicalExercise selectedExercise,
    required ExerciseDef exercise,
  }) async {
    final writeAdapter = this.writeAdapter;
    if (writeAdapter == null) {
      throw StateError('Exercise authoring requires a write adapter.');
    }

    final currentActiveSheet = await readAdapter.readParsedActiveSheet(
      spreadsheetId,
    );
    final canonicalExerciseRejection = _canonicalExerciseRowRejection(
      currentSheet: currentActiveSheet,
      selectedExercise: selectedExercise,
    );
    if (canonicalExerciseRejection != null) {
      return ValidationReport(
        spreadsheetId: spreadsheetId,
        activeSheet: currentActiveSheet,
        writeRejections: [canonicalExerciseRejection],
      );
    }
    final exercisesPlan = currentActiveSheet.planCanonicalUpdate(
      selectedExercise: selectedExercise,
      exercise: exercise,
    );
    final exercisesRow = exercisesPlan.rowUpdates.singleOrNull;
    if (exercisesRow == null) {
      throw StateError('No exercise row update was planned.');
    }

    await writeAdapter.applyExercisesPlan(
      spreadsheetId: spreadsheetId,
      plan: exercisesPlan,
    );
    return validateSpreadsheet(spreadsheetId);
  }

  @override
  Future<ValidationReport> addExerciseToWorkout({
    required String spreadsheetId,
    required ParsedActiveSheet activeSheet,
    required CanonicalExercise exercise,
    required WorkoutPlacementMetadata metadata,
    required ExercisePlacementTarget placement,
  }) async {
    final writeAdapter = this.writeAdapter;
    if (writeAdapter == null) {
      throw StateError('Exercise placement requires a write adapter.');
    }

    final currentActiveSheet = await readAdapter.readParsedActiveSheet(
      spreadsheetId,
    );
    final canonicalExerciseRejection = _canonicalExerciseRowRejection(
      currentSheet: currentActiveSheet,
      selectedExercise: exercise,
    );
    if (canonicalExerciseRejection != null) {
      return ValidationReport(
        spreadsheetId: spreadsheetId,
        activeSheet: currentActiveSheet,
        writeRejections: [canonicalExerciseRejection],
      );
    }
    final activePlan = placement.isBackup
        ? currentActiveSheet.planBackupPlacement(
            primarySheetRowNumber: placement.primarySheetRowNumber!,
            exercise: exercise,
            metadata: metadata,
          )
        : currentActiveSheet.planPrimaryPlacement(
            exercise: exercise,
            workout: placement.workout ?? defaultWorkoutName,
            metadata: metadata,
          );
    final writeRejections = activePlan.writeRejections(currentActiveSheet);
    if (writeRejections.isNotEmpty) {
      return ValidationReport(
        spreadsheetId: spreadsheetId,
        activeSheet: currentActiveSheet,
        writeRejections: writeRejections,
      );
    }

    await writeAdapter.applyWritePlan(
      spreadsheetId: spreadsheetId,
      plan: activePlan,
    );
    return validateSpreadsheet(spreadsheetId);
  }

  @override
  Future<ValidationReport> reorderExercises({
    required String spreadsheetId,
    required ParsedActiveSheet activeSheet,
    required ReorderIntent intent,
  }) async {
    final writeAdapter = this.writeAdapter;
    if (writeAdapter == null) {
      throw StateError('Exercise reorder requires a write adapter.');
    }

    final currentActiveSheet = await readAdapter.readParsedActiveSheet(
      spreadsheetId,
    );
    final exercisesPlan = activeSheet.planCanonicalReorder(intent);
    final writeRejections = exercisesPlan.writeRejections(currentActiveSheet);
    if (writeRejections.isNotEmpty) {
      return ValidationReport(
        spreadsheetId: spreadsheetId,
        activeSheet: currentActiveSheet,
        writeRejections: writeRejections,
      );
    }
    if (exercisesPlan.rowUpdates.isEmpty &&
        exercisesPlan.activeSheetFormulaUpdates.isEmpty) {
      return ValidationReport(
        spreadsheetId: spreadsheetId,
        activeSheet: currentActiveSheet,
      );
    }

    await writeAdapter.applyExercisesPlan(
      spreadsheetId: spreadsheetId,
      plan: exercisesPlan,
    );
    return validateSpreadsheet(spreadsheetId);
  }

  @override
  Future<ValidationReport> reorderWorkoutExercises({
    required String spreadsheetId,
    required ParsedActiveSheet activeSheet,
    required String workout,
    required ReorderIntent intent,
  }) async {
    final writeAdapter = this.writeAdapter;
    if (writeAdapter == null) {
      throw StateError('Workout reorder requires a write adapter.');
    }

    final currentActiveSheet = await readAdapter.readParsedActiveSheet(
      spreadsheetId,
    );
    final activePlan = activeSheet.planExerciseReorder(
      workout: workout,
      intent: intent,
    );
    final writeRejections = activePlan.writeRejections(currentActiveSheet);
    if (writeRejections.isNotEmpty) {
      return ValidationReport(
        spreadsheetId: spreadsheetId,
        activeSheet: currentActiveSheet,
        writeRejections: writeRejections,
      );
    }
    if (activePlan.cellUpdates.isEmpty &&
        activePlan.columnInsertions.isEmpty &&
        activePlan.rowInsertions.isEmpty) {
      return ValidationReport(
        spreadsheetId: spreadsheetId,
        activeSheet: currentActiveSheet,
      );
    }

    await writeAdapter.applyWritePlan(
      spreadsheetId: spreadsheetId,
      plan: activePlan,
    );
    return validateSpreadsheet(spreadsheetId);
  }

  @override
  Future<ValidationReport> deleteWorkoutExercise({
    required String spreadsheetId,
    required ParsedActiveSheet activeSheet,
    required int primarySheetRowNumber,
  }) async {
    final writeAdapter = this.writeAdapter;
    if (writeAdapter == null) {
      throw StateError('Workout exercise deletion requires a write adapter.');
    }

    final currentActiveSheet = await readAdapter.readParsedActiveSheet(
      spreadsheetId,
    );
    final activePlan = activeSheet.planPrimaryExerciseDeletion(
      primarySheetRowNumber: primarySheetRowNumber,
    );
    final writeRejections = activePlan.writeRejections(currentActiveSheet);
    if (writeRejections.isNotEmpty) {
      return ValidationReport(
        spreadsheetId: spreadsheetId,
        activeSheet: currentActiveSheet,
        writeRejections: writeRejections,
      );
    }
    if (activePlan.rowDeletions.isEmpty) {
      return ValidationReport(
        spreadsheetId: spreadsheetId,
        activeSheet: currentActiveSheet,
        writeRejections: [
          WriteRejection(
            'Row $primarySheetRowNumber is no longer a primary workout '
            'exercise.',
          ),
        ],
      );
    }

    await writeAdapter.applyWritePlan(
      spreadsheetId: spreadsheetId,
      plan: activePlan,
    );
    return validateSpreadsheet(spreadsheetId);
  }
}

WriteRejection? _canonicalExerciseRowRejection({
  required ParsedActiveSheet currentSheet,
  required CanonicalExercise selectedExercise,
}) {
  final current = _canonicalExerciseForRow(
    currentSheet,
    selectedExercise.sheetRowNumber,
  );
  if (current != null && _sameCanonicalExercise(selectedExercise, current)) {
    return null;
  }

  final exercisesSheetRowNumber = selectedExercise.sheetRowNumber;
  final label = selectedExercise.displayName;
  return WriteRejection(
    'Exercises row $exercisesSheetRowNumber no longer matches $label.',
  );
}

CanonicalExercise? _canonicalExerciseForRow(
  ParsedActiveSheet sheet,
  int sheetRowNumber,
) {
  for (final exercise in sheet.canonicalExercises) {
    if (exercise.sheetRowNumber == sheetRowNumber) {
      return exercise;
    }
  }
  return null;
}

bool _sameCanonicalExercise(CanonicalExercise first, CanonicalExercise second) {
  return first.sheetRowNumber == second.sheetRowNumber &&
      first.exercise == second.exercise &&
      first.description == second.description &&
      first.defaultSets == second.defaultSets &&
      first.defaultReps == second.defaultReps &&
      first.defaultRpe == second.defaultRpe &&
      first.defaultRest == second.defaultRest &&
      first.defaultTempo == second.defaultTempo &&
      first.notes == second.notes &&
      first.logFormat == second.logFormat;
}
