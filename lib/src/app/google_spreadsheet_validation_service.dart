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
