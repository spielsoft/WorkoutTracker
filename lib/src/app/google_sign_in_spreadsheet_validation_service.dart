import 'package:workout_tracker/google_sheets.dart';
import 'package:workout_tracker/sheet_contract.dart';

import 'google_account_session.dart';
import 'google_authorization_client.dart';
import 'google_spreadsheet_validation_wiring.dart';
import 'spreadsheet_validation_core.dart';

class GoogleSignInSpreadsheetValidationService
    implements SpreadsheetValidationService, ExerciseAuthoringService {
  GoogleSignInSpreadsheetValidationService({
    GoogleSignInAuthorizationGateway? authorizationGateway,
    GoogleSpreadsheetValidationServiceFactory? serviceFactory,
    GoogleAuthorizationClientFactory? authorizationClientFactory,
    ScopedGoogleApiAccess? googleAccess,
  }) : _serviceFactory =
           serviceFactory ?? defaultGoogleSpreadsheetValidationServiceFactory,
       _googleAccess =
           googleAccess ??
           GoogleScopedApiAccess(
             authorizationGateway:
                 authorizationGateway ??
                 NativeGoogleSignInAuthorizationGateway(),
             authorizationClientFactory: authorizationClientFactory,
           );

  final GoogleSpreadsheetValidationServiceFactory _serviceFactory;
  final ScopedGoogleApiAccess _googleAccess;

  @override
  Future<SpreadsheetValidationReport> validateSpreadsheet(
    String spreadsheetId,
  ) async {
    return _withGoogleSheetsService(
      scopes: GoogleApisSheetsWorkbookClient.writeScopes,
      canWrite: true,
      action: (service) => service.validateSpreadsheet(spreadsheetId),
    );
  }

  @override
  Future<SpreadsheetValidationReport> applyActiveSheetWritePlan({
    required String spreadsheetId,
    required ParsedActiveSheet activeSheet,
    required ActiveSheetWritePlan plan,
  }) async {
    return _withGoogleSheetsService(
      scopes: GoogleApisSheetsWorkbookClient.writeScopes,
      canWrite: true,
      action: (service) => service.applyActiveSheetWritePlan(
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
  }) async {
    return _withGoogleSheetsService(
      scopes: GoogleApisSheetsWorkbookClient.writeScopes,
      canWrite: true,
      action: (service) {
        if (service case final ExerciseAuthoringService authoringService) {
          return authoringService.createCanonicalExercise(
            spreadsheetId: spreadsheetId,
            activeSheet: activeSheet,
            exercise: exercise,
          );
        }
        throw StateError('Exercise authoring service is not configured.');
      },
    );
  }

  @override
  Future<SpreadsheetValidationReport> updateCanonicalExercise({
    required String spreadsheetId,
    required ParsedActiveSheet activeSheet,
    required CanonicalExercise selectedExercise,
    required CanonicalExerciseDefinition exercise,
  }) async {
    return _withGoogleSheetsService(
      scopes: GoogleApisSheetsWorkbookClient.writeScopes,
      canWrite: true,
      action: (service) {
        if (service case final ExerciseAuthoringService authoringService) {
          return authoringService.updateCanonicalExercise(
            spreadsheetId: spreadsheetId,
            activeSheet: activeSheet,
            selectedExercise: selectedExercise,
            exercise: exercise,
          );
        }
        throw StateError('Exercise authoring service is not configured.');
      },
    );
  }

  @override
  Future<SpreadsheetValidationReport> addExistingExerciseToWorkout({
    required String spreadsheetId,
    required ParsedActiveSheet activeSheet,
    required CanonicalExercise exercise,
    required WorkoutPlacementMetadata metadata,
    required ExercisePlacementTarget placement,
  }) async {
    return _withGoogleSheetsService(
      scopes: GoogleApisSheetsWorkbookClient.writeScopes,
      canWrite: true,
      action: (service) {
        if (service case final ExerciseAuthoringService authoringService) {
          return authoringService.addExistingExerciseToWorkout(
            spreadsheetId: spreadsheetId,
            activeSheet: activeSheet,
            exercise: exercise,
            metadata: metadata,
            placement: placement,
          );
        }
        throw StateError('Exercise authoring service is not configured.');
      },
    );
  }

  @override
  Future<SpreadsheetValidationReport> reorderCanonicalExercises({
    required String spreadsheetId,
    required ParsedActiveSheet activeSheet,
    required ReorderIntent intent,
  }) async {
    return _withGoogleSheetsService(
      scopes: GoogleApisSheetsWorkbookClient.writeScopes,
      canWrite: true,
      action: (service) {
        if (service case final ExerciseAuthoringService authoringService) {
          return authoringService.reorderCanonicalExercises(
            spreadsheetId: spreadsheetId,
            activeSheet: activeSheet,
            intent: intent,
          );
        }
        throw StateError('Exercise authoring service is not configured.');
      },
    );
  }

  @override
  Future<SpreadsheetValidationReport> reorderWorkoutExercises({
    required String spreadsheetId,
    required ParsedActiveSheet activeSheet,
    required String workout,
    required ReorderIntent intent,
  }) async {
    return _withGoogleSheetsService(
      scopes: GoogleApisSheetsWorkbookClient.writeScopes,
      canWrite: true,
      action: (service) {
        if (service case final ExerciseAuthoringService authoringService) {
          return authoringService.reorderWorkoutExercises(
            spreadsheetId: spreadsheetId,
            activeSheet: activeSheet,
            workout: workout,
            intent: intent,
          );
        }
        throw StateError('Exercise authoring service is not configured.');
      },
    );
  }

  @override
  Future<SpreadsheetValidationReport> deleteWorkoutExercise({
    required String spreadsheetId,
    required ParsedActiveSheet activeSheet,
    required int primarySheetRowNumber,
  }) async {
    return _withGoogleSheetsService(
      scopes: GoogleApisSheetsWorkbookClient.writeScopes,
      canWrite: true,
      action: (service) {
        if (service case final ExerciseAuthoringService authoringService) {
          return authoringService.deleteWorkoutExercise(
            spreadsheetId: spreadsheetId,
            activeSheet: activeSheet,
            primarySheetRowNumber: primarySheetRowNumber,
          );
        }
        throw StateError('Exercise authoring service is not configured.');
      },
    );
  }

  Future<SpreadsheetValidationReport> _withGoogleSheetsService({
    required List<String> scopes,
    required bool canWrite,
    required Future<SpreadsheetValidationReport> Function(
      SpreadsheetValidationService service,
    )
    action,
  }) async {
    return _googleAccess.run(
      scopes: scopes,
      action: (resources) async {
        return action(_serviceFactory(resources.sheetsApi, canWrite: canWrite));
      },
    );
  }
}
