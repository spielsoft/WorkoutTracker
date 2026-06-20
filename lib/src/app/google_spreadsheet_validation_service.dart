import 'package:workout_tracker/google_sheets.dart';
import 'package:workout_tracker/sheet_contract.dart';

import 'spreadsheet_validation_core.dart';

class GoogleSpreadsheetValidationService
    implements SpreadsheetValidationService, ExerciseAuthoringService {
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
  Future<SpreadsheetValidationReport> addExistingExerciseToWorkout({
    required String spreadsheetId,
    required ParsedActiveSheet activeSheet,
    required int exercisesSheetRowNumber,
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
      originalSheet: activeSheet,
      currentSheet: currentActiveSheet,
      exercisesSheetRowNumber: exercisesSheetRowNumber,
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
            exercisesSheetRowNumber: exercisesSheetRowNumber,
            metadata: metadata,
          )
        : currentActiveSheet.planPrimaryWorkoutPlacement(
            exercisesSheetRowNumber: exercisesSheetRowNumber,
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
}

ActiveSheetWriteRejection? _canonicalExerciseRowRejection({
  required ParsedActiveSheet originalSheet,
  required ParsedActiveSheet currentSheet,
  required int exercisesSheetRowNumber,
}) {
  final original = _canonicalExerciseForRow(
    originalSheet,
    exercisesSheetRowNumber,
  );
  final current = _canonicalExerciseForRow(
    currentSheet,
    exercisesSheetRowNumber,
  );
  if (original != null &&
      current != null &&
      _sameCanonicalExercise(original, current)) {
    return null;
  }

  final label = original?.displayName ?? 'selected exercise';
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
