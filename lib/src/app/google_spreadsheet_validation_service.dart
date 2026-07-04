import 'package:workout_tracker/google_sheets.dart';
import 'package:workout_tracker/sheet_contract.dart';

import 'spreadsheet_validation_core.dart';

class GoogleSpreadsheetValidationService implements WorkbookCommandService {
  const GoogleSpreadsheetValidationService({
    required this.readAdapter,
    this.writeAdapter,
  });

  final GoogleSheetsReadAdapter readAdapter;
  final GoogleSheetsWriteAdapter? writeAdapter;

  @override
  Future<SpreadsheetValidationReport> validateSpreadsheet(
    String spreadsheetId,
  ) async {
    return SpreadsheetValidationReport(
      spreadsheetId: spreadsheetId,
      activeSheet: await readAdapter.readParsedActiveSheet(spreadsheetId),
    );
  }

  @override
  Future<SpreadsheetValidationReport> applyActiveSheetWritePlan({
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
      return SpreadsheetValidationReport(
        spreadsheetId: spreadsheetId,
        activeSheet: currentActiveSheet,
        writeRejections: writeRejections,
      );
    }
    await writeAdapter.applyActiveSheetWritePlan(
      spreadsheetId: spreadsheetId,
      plan: plan,
    );
    return validateSpreadsheet(spreadsheetId);
  }

  @override
  Future<SpreadsheetValidationReport> createCanonicalExercise({
    required String spreadsheetId,
    required ParsedActiveSheet activeSheet,
    required CanonicalExerciseDefinition exercise,
  }) async {
    final writeAdapter = this.writeAdapter;
    if (writeAdapter == null) {
      throw StateError('Exercise authoring requires a write adapter.');
    }

    final currentActiveSheet = await readAdapter.readParsedActiveSheet(
      spreadsheetId,
    );
    final exercisesPlan = currentActiveSheet.planCanonicalExerciseAppend(
      exercise,
    );
    final exercisesRow = exercisesPlan.rowAppends.singleOrNull;
    if (exercisesRow == null) {
      throw StateError('No exercise row was planned.');
    }

    await writeAdapter.applyExercisesWritePlan(
      spreadsheetId: spreadsheetId,
      plan: exercisesPlan,
    );
    return validateSpreadsheet(spreadsheetId);
  }

  @override
  Future<SpreadsheetValidationReport> updateCanonicalExercise({
    required String spreadsheetId,
    required ParsedActiveSheet activeSheet,
    required CanonicalExercise selectedExercise,
    required CanonicalExerciseDefinition exercise,
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
      return SpreadsheetValidationReport(
        spreadsheetId: spreadsheetId,
        activeSheet: currentActiveSheet,
        writeRejections: [canonicalExerciseRejection],
      );
    }
    final exercisesPlan = currentActiveSheet.planCanonicalExerciseUpdate(
      selectedExercise: selectedExercise,
      exercise: exercise,
    );
    final exercisesRow = exercisesPlan.rowUpdates.singleOrNull;
    if (exercisesRow == null) {
      throw StateError('No exercise row update was planned.');
    }

    await writeAdapter.applyExercisesWritePlan(
      spreadsheetId: spreadsheetId,
      plan: exercisesPlan,
    );
    return validateSpreadsheet(spreadsheetId);
  }

  @override
  Future<SpreadsheetValidationReport> addExistingExerciseToWorkout({
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
      return SpreadsheetValidationReport(
        spreadsheetId: spreadsheetId,
        activeSheet: currentActiveSheet,
        writeRejections: [canonicalExerciseRejection],
      );
    }
    final activePlan = placement.isBackup
        ? currentActiveSheet.planBackupWorkoutPlacement(
            primarySheetRowNumber: placement.primarySheetRowNumber!,
            exercise: exercise,
            metadata: metadata,
          )
        : currentActiveSheet.planPrimaryWorkoutPlacement(
            exercise: exercise,
            workout: placement.workout ?? defaultWorkoutName,
            metadata: metadata,
          );
    final writeRejections = activePlan.writeRejections(currentActiveSheet);
    if (writeRejections.isNotEmpty) {
      return SpreadsheetValidationReport(
        spreadsheetId: spreadsheetId,
        activeSheet: currentActiveSheet,
        writeRejections: writeRejections,
      );
    }

    await writeAdapter.applyActiveSheetWritePlan(
      spreadsheetId: spreadsheetId,
      plan: activePlan,
    );
    return validateSpreadsheet(spreadsheetId);
  }

  @override
  Future<SpreadsheetValidationReport> reorderCanonicalExercises({
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
    final exercisesPlan = activeSheet.planCanonicalExerciseReorder(intent);
    final writeRejections = exercisesPlan.writeRejections(currentActiveSheet);
    if (writeRejections.isNotEmpty) {
      return SpreadsheetValidationReport(
        spreadsheetId: spreadsheetId,
        activeSheet: currentActiveSheet,
        writeRejections: writeRejections,
      );
    }
    if (exercisesPlan.rowUpdates.isEmpty &&
        exercisesPlan.activeSheetFormulaUpdates.isEmpty) {
      return SpreadsheetValidationReport(
        spreadsheetId: spreadsheetId,
        activeSheet: currentActiveSheet,
      );
    }

    await writeAdapter.applyExercisesWritePlan(
      spreadsheetId: spreadsheetId,
      plan: exercisesPlan,
    );
    return validateSpreadsheet(spreadsheetId);
  }

  @override
  Future<SpreadsheetValidationReport> reorderWorkoutExercises({
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
    final activePlan = activeSheet.planWorkoutExerciseReorder(
      workout: workout,
      intent: intent,
    );
    final writeRejections = activePlan.writeRejections(currentActiveSheet);
    if (writeRejections.isNotEmpty) {
      return SpreadsheetValidationReport(
        spreadsheetId: spreadsheetId,
        activeSheet: currentActiveSheet,
        writeRejections: writeRejections,
      );
    }
    if (activePlan.cellUpdates.isEmpty &&
        activePlan.columnInsertions.isEmpty &&
        activePlan.rowInsertions.isEmpty) {
      return SpreadsheetValidationReport(
        spreadsheetId: spreadsheetId,
        activeSheet: currentActiveSheet,
      );
    }

    await writeAdapter.applyActiveSheetWritePlan(
      spreadsheetId: spreadsheetId,
      plan: activePlan,
    );
    return validateSpreadsheet(spreadsheetId);
  }

  @override
  Future<SpreadsheetValidationReport> deleteWorkoutExercise({
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
    final activePlan = activeSheet.planPrimaryWorkoutExerciseDeletion(
      primarySheetRowNumber: primarySheetRowNumber,
    );
    final writeRejections = activePlan.writeRejections(currentActiveSheet);
    if (writeRejections.isNotEmpty) {
      return SpreadsheetValidationReport(
        spreadsheetId: spreadsheetId,
        activeSheet: currentActiveSheet,
        writeRejections: writeRejections,
      );
    }
    if (activePlan.rowDeletions.isEmpty) {
      return SpreadsheetValidationReport(
        spreadsheetId: spreadsheetId,
        activeSheet: currentActiveSheet,
        writeRejections: [
          ActiveSheetWriteRejection(
            'Row $primarySheetRowNumber is no longer a primary workout '
            'exercise.',
          ),
        ],
      );
    }

    await writeAdapter.applyActiveSheetWritePlan(
      spreadsheetId: spreadsheetId,
      plan: activePlan,
    );
    return validateSpreadsheet(spreadsheetId);
  }
}

ActiveSheetWriteRejection? _canonicalExerciseRowRejection({
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
  return ActiveSheetWriteRejection(
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
