import 'package:googleapis/sheets/v4.dart' as sheets;
import 'package:workout_tracker/google_sheets.dart';
import 'package:workout_tracker/sheet_contract.dart';

import 'google_authorization_client.dart';
import 'spreadsheet_validation_service.dart';
import 'spreadsheet_validation_core.dart';

typedef WorkbookClientFactory =
    SheetsWorkbookClient Function(sheets.SheetsApi api);

class SpreadsheetAccess implements WorkbookService {
  SpreadsheetAccess(
    this._googleAccess, {
    WorkbookClientFactory? workbookClientFactory,
  }) : _workbookClientFactory =
           workbookClientFactory ?? ((api) => GoogleApisWorkbookClient(api));

  final ApiAccess _googleAccess;
  final WorkbookClientFactory _workbookClientFactory;

  @override
  Future<ValidationReport> validateSpreadsheet(String spreadsheetId) {
    return _runWritableWorkbook(
      (service) => service.validateSpreadsheet(spreadsheetId),
    );
  }

  @override
  Future<ValidationReport> applyActiveSheetWritePlan({
    required String spreadsheetId,
    required ParsedActiveSheet activeSheet,
    required ActiveSheetWritePlan plan,
  }) {
    return _runWritableWorkbook(
      (service) => service.applyActiveSheetWritePlan(
        spreadsheetId: spreadsheetId,
        activeSheet: activeSheet,
        plan: plan,
      ),
    );
  }

  @override
  Future<ValidationReport> createCanonicalExercise({
    required String spreadsheetId,
    required ParsedActiveSheet activeSheet,
    required CanonicalExerciseDefinition exercise,
  }) {
    return _runWritableWorkbook(
      (service) => service.createCanonicalExercise(
        spreadsheetId: spreadsheetId,
        activeSheet: activeSheet,
        exercise: exercise,
      ),
    );
  }

  @override
  Future<ValidationReport> updateCanonicalExercise({
    required String spreadsheetId,
    required ParsedActiveSheet activeSheet,
    required CanonicalExercise selectedExercise,
    required CanonicalExerciseDefinition exercise,
  }) {
    return _runWritableWorkbook(
      (service) => service.updateCanonicalExercise(
        spreadsheetId: spreadsheetId,
        activeSheet: activeSheet,
        selectedExercise: selectedExercise,
        exercise: exercise,
      ),
    );
  }

  @override
  Future<ValidationReport> addExerciseToWorkout({
    required String spreadsheetId,
    required ParsedActiveSheet activeSheet,
    required CanonicalExercise exercise,
    required WorkoutPlacementMetadata metadata,
    required ExercisePlacementTarget placement,
  }) {
    return _runWritableWorkbook(
      (service) => service.addExerciseToWorkout(
        spreadsheetId: spreadsheetId,
        activeSheet: activeSheet,
        exercise: exercise,
        metadata: metadata,
        placement: placement,
      ),
    );
  }

  @override
  Future<ValidationReport> reorderCanonicalExercises({
    required String spreadsheetId,
    required ParsedActiveSheet activeSheet,
    required ReorderIntent intent,
  }) {
    return _runWritableWorkbook(
      (service) => service.reorderCanonicalExercises(
        spreadsheetId: spreadsheetId,
        activeSheet: activeSheet,
        intent: intent,
      ),
    );
  }

  @override
  Future<ValidationReport> reorderWorkoutExercises({
    required String spreadsheetId,
    required ParsedActiveSheet activeSheet,
    required String workout,
    required ReorderIntent intent,
  }) {
    return _runWritableWorkbook(
      (service) => service.reorderWorkoutExercises(
        spreadsheetId: spreadsheetId,
        activeSheet: activeSheet,
        workout: workout,
        intent: intent,
      ),
    );
  }

  @override
  Future<ValidationReport> deleteWorkoutExercise({
    required String spreadsheetId,
    required ParsedActiveSheet activeSheet,
    required int primarySheetRowNumber,
  }) {
    return _runWritableWorkbook(
      (service) => service.deleteWorkoutExercise(
        spreadsheetId: spreadsheetId,
        activeSheet: activeSheet,
        primarySheetRowNumber: primarySheetRowNumber,
      ),
    );
  }

  Future<ValidationReport> _runWritableWorkbook(
    Future<ValidationReport> Function(ValidationService service) action,
  ) {
    return _googleAccess.run(
      scopes: GoogleApisWorkbookClient.writeScopes,
      action: (resources) {
        final workbookClient = _workbookClientFactory(resources.sheetsApi);
        final service = ValidationService(
          readAdapter: SheetsReadAdapter(client: workbookClient),
          writeAdapter: SheetsWriteAdapter(client: workbookClient),
        );
        return action(service);
      },
    );
  }
}
