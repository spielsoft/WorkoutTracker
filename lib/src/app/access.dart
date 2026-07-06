import 'package:googleapis/sheets/v4.dart' as sheets;
import 'package:workout_tracker/sheets.dart';
import 'package:workout_tracker/contract.dart';

import 'auth_client.dart';
import 'validation_service.dart';
import 'validation_core.dart';

typedef WbkClientFact = SheetsWorkbookClient Function(sheets.SheetsApi api);

class SheetAccess implements WbkSvc {
  SheetAccess(this._googleAccess, {WbkClientFact? workbookClientFactory})
    : _workbookClientFactory =
          workbookClientFactory ?? ((api) => GoogleApisWbkClient(api));

  final ApiAccess _googleAccess;
  final WbkClientFact _workbookClientFactory;

  @override
  Future<ValReport> validateSheet(String spreadsheetId) {
    return _runWritableWorkbook(
      (service) => service.validateSheet(spreadsheetId),
    );
  }

  @override
  Future<ValReport> applyWritePlan({
    required String spreadsheetId,
    required ParsedActiveSheet activeSheet,
    required ActiveSheetWritePlan plan,
  }) {
    return _runWritableWorkbook(
      (service) => service.applyWritePlan(
        spreadsheetId: spreadsheetId,
        activeSheet: activeSheet,
        plan: plan,
      ),
    );
  }

  @override
  Future<ValReport> createExercise({
    required String spreadsheetId,
    required ParsedActiveSheet activeSheet,
    required ExerciseDef exercise,
  }) {
    return _runWritableWorkbook(
      (service) => service.createExercise(
        spreadsheetId: spreadsheetId,
        activeSheet: activeSheet,
        exercise: exercise,
      ),
    );
  }

  @override
  Future<ValReport> updateExercise({
    required String spreadsheetId,
    required ParsedActiveSheet activeSheet,
    required CanonicalExercise selectedExercise,
    required ExerciseDef exercise,
  }) {
    return _runWritableWorkbook(
      (service) => service.updateExercise(
        spreadsheetId: spreadsheetId,
        activeSheet: activeSheet,
        selectedExercise: selectedExercise,
        exercise: exercise,
      ),
    );
  }

  @override
  Future<ValReport> addExerciseToWorkout({
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
  Future<ValReport> reorderExercises({
    required String spreadsheetId,
    required ParsedActiveSheet activeSheet,
    required ReorderIntent intent,
  }) {
    return _runWritableWorkbook(
      (service) => service.reorderExercises(
        spreadsheetId: spreadsheetId,
        activeSheet: activeSheet,
        intent: intent,
      ),
    );
  }

  @override
  Future<ValReport> reorderWorkoutExercises({
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
  Future<ValReport> deleteWorkoutExercise({
    required String spreadsheetId,
    required ParsedActiveSheet activeSheet,
    required int primaryRow,
  }) {
    return _runWritableWorkbook(
      (service) => service.deleteWorkoutExercise(
        spreadsheetId: spreadsheetId,
        activeSheet: activeSheet,
        primaryRow: primaryRow,
      ),
    );
  }

  Future<ValReport> _runWritableWorkbook(
    Future<ValReport> Function(ValSvc service) action,
  ) {
    return _googleAccess.run(
      scopes: GoogleApisWbkClient.writeScopes,
      action: (resources) {
        final workbookClient = _workbookClientFactory(resources.sheetsApi);
        final service = ValSvc(
          readAdapter: SheetsReadAdapter(client: workbookClient),
          writeAdapter: SheetsWriteAdapter(client: workbookClient),
        );
        return action(service);
      },
    );
  }
}
