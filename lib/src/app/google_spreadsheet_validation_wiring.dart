import 'package:googleapis/sheets/v4.dart' as sheets;
import 'package:workout_tracker/google_sheets.dart';
import 'package:workout_tracker/sheet_contract.dart';

import 'google_authorization_client.dart';
import 'google_spreadsheet_validation_service.dart';
import 'spreadsheet_validation_core.dart';

typedef GoogleSheetsWorkbookClientFactory =
    SheetsWorkbookClient Function(sheets.SheetsApi api);

class GoogleSpreadsheetWorkbookAccess
    implements SpreadsheetValidationService, ExerciseAuthoringService {
  GoogleSpreadsheetWorkbookAccess(
    this._googleAccess, {
    GoogleSheetsWorkbookClientFactory? workbookClientFactory,
  }) : _workbookClientFactory =
           workbookClientFactory ??
           ((api) => GoogleApisSheetsWorkbookClient(api));

  final ScopedGoogleApiAccess _googleAccess;
  final GoogleSheetsWorkbookClientFactory _workbookClientFactory;

  @override
  Future<SpreadsheetValidationReport> validateSpreadsheet(
    String spreadsheetId,
  ) {
    return _runWritableWorkbook(
      (service) => service.validateSpreadsheet(spreadsheetId),
    );
  }

  @override
  Future<SpreadsheetValidationReport> applyActiveSheetWritePlan({
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
  Future<SpreadsheetValidationReport> createCanonicalExercise({
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
  Future<SpreadsheetValidationReport> updateCanonicalExercise({
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
  Future<SpreadsheetValidationReport> addExistingExerciseToWorkout({
    required String spreadsheetId,
    required ParsedActiveSheet activeSheet,
    required CanonicalExercise exercise,
    required WorkoutPlacementMetadata metadata,
    required ExercisePlacementTarget placement,
  }) {
    return _runWritableWorkbook(
      (service) => service.addExistingExerciseToWorkout(
        spreadsheetId: spreadsheetId,
        activeSheet: activeSheet,
        exercise: exercise,
        metadata: metadata,
        placement: placement,
      ),
    );
  }

  @override
  Future<SpreadsheetValidationReport> reorderCanonicalExercises({
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
  Future<SpreadsheetValidationReport> reorderWorkoutExercises({
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
  Future<SpreadsheetValidationReport> deleteWorkoutExercise({
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

  Future<SpreadsheetValidationReport> _runWritableWorkbook(
    Future<SpreadsheetValidationReport> Function(
      GoogleSpreadsheetValidationService service,
    )
    action,
  ) {
    return _googleAccess.run(
      scopes: GoogleApisSheetsWorkbookClient.writeScopes,
      action: (resources) {
        final workbookClient = _workbookClientFactory(resources.sheetsApi);
        final service = GoogleSpreadsheetValidationService(
          readAdapter: GoogleSheetsReadAdapter(client: workbookClient),
          writeAdapter: GoogleSheetsWriteAdapter(client: workbookClient),
        );
        return action(service);
      },
    );
  }
}
