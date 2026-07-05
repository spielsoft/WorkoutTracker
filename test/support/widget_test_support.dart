import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_tracker/sheet_contract.dart';
import 'package:workout_tracker/workout_tracker_app.dart';

import '../fixtures/workout_sheet_fixtures.dart';

class FakeGoogleAccountSession extends ChangeNotifier
    implements GoogleAccountSession {
  FakeGoogleAccountSession(this._currentAccount, {this.restoredAccount});

  GoogleAccountProfile? _currentAccount;
  final GoogleAccountProfile? restoredAccount;
  int restoreCount = 0;
  int switchCount = 0;
  int signOutCount = 0;
  final requestedScopes = <List<String>>[];

  @override
  GoogleAccountProfile? get currentAccount => _currentAccount;

  @override
  Future<void> restoreAccount() async {
    restoreCount += 1;
    if (restoredAccount != null) {
      _currentAccount = restoredAccount;
      notifyListeners();
    }
  }

  @override
  Future<void> switchAccount({List<String> scopes = const []}) async {
    switchCount += 1;
    requestedScopes.add(scopes);
    _currentAccount = const GoogleAccountProfile(
      email: 'right@example.com',
      displayName: 'Right Account',
    );
    notifyListeners();
  }

  @override
  Future<void> signOut() async {
    signOutCount += 1;
    _currentAccount = null;
    notifyListeners();
  }
}

Finder textFieldWithLabel(String labelText) {
  return find.byWidgetPredicate(
    (widget) =>
        widget is TextField && widget.decoration?.labelText == labelText,
    description: 'TextField with label "$labelText"',
  );
}

EditableText editableTextFor(Finder textField) {
  return find
          .descendant(of: textField, matching: find.byType(EditableText))
          .evaluate()
          .single
          .widget
      as EditableText;
}

Future<void> expectFlutterAccessibilityGuidelines(WidgetTester tester) async {
  final semantics = tester.ensureSemantics();
  try {
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));
  } finally {
    semantics.dispose();
  }
}

class MemoryAppStateStore implements AppStateStore {
  MemoryAppStateStore(
    this.spreadsheetText, {
    this.selectedSpreadsheet,
    this.googleAuthorization,
  });

  String? spreadsheetText;
  SelectedSpreadsheet? selectedSpreadsheet;
  GooglePickerAuthorizationSnapshot? googleAuthorization;
  WorkoutSelectionState? workoutSelection;
  final accessStateWrites = <GoogleWorkspaceAccessState>[];
  int clearCount = 0;

  @override
  Future<GoogleWorkspaceAccessState> readGoogleWorkspaceAccessState() async {
    return GoogleWorkspaceAccessState(
      spreadsheetText: spreadsheetText,
      selectedSpreadsheet: selectedSpreadsheet,
      googleAuthorization: googleAuthorization,
      workoutSelection: workoutSelection,
    );
  }

  @override
  Future<void> writeGoogleWorkspaceAccessState(
    GoogleWorkspaceAccessState value,
  ) async {
    spreadsheetText = value.spreadsheetText;
    selectedSpreadsheet = value.selectedSpreadsheet;
    googleAuthorization = value.googleAuthorization;
    workoutSelection = value.workoutSelection;
    accessStateWrites.add(value);
  }

  @override
  Future<void> clearGoogleWorkspaceAccessState() async {
    clearCount += 1;
    spreadsheetText = null;
    selectedSpreadsheet = null;
    googleAuthorization = null;
    workoutSelection = null;
  }
}

class FakeSpreadsheetPicker implements SpreadsheetPicker {
  @override
  SpreadsheetPickerAvailability get availability {
    return const SpreadsheetPickerAvailability.available();
  }

  @override
  Future<SelectedSpreadsheet?> chooseSpreadsheet() async {
    return null;
  }

  @override
  Future<bool> authorizeSpreadsheetCreation() async {
    return true;
  }

  @override
  Future<SelectedSpreadsheet?> createSpreadsheet({String? name}) async {
    return null;
  }

  @override
  Future<SelectedSpreadsheet> resolveSelectedSpreadsheet(
    SelectedSpreadsheet selected,
  ) async {
    return selected;
  }
}

class AuthorizingSpreadsheetPicker implements SpreadsheetPicker {
  AuthorizingSpreadsheetPicker(this.authorizationStore);

  final GooglePickerAuthorizationStore authorizationStore;

  @override
  SpreadsheetPickerAvailability get availability {
    return const SpreadsheetPickerAvailability.available();
  }

  @override
  Future<SelectedSpreadsheet?> chooseSpreadsheet() async {
    authorizationStore.updateGooglePickerAuthorization(
      const GooglePickerAuthorizationSnapshot(
        accessToken: 'picker-token',
        accountEmail: 'athlete@example.com',
        displayName: 'Athlete Name',
      ),
    );
    return const SelectedSpreadsheet(
      spreadsheetId: 'selected-spreadsheet-id',
      name: 'Development Workouts',
      accountEmail: 'athlete@example.com',
    );
  }

  @override
  Future<bool> authorizeSpreadsheetCreation() async {
    return true;
  }

  @override
  Future<SelectedSpreadsheet?> createSpreadsheet({String? name}) async {
    return null;
  }

  @override
  Future<SelectedSpreadsheet> resolveSelectedSpreadsheet(
    SelectedSpreadsheet selected,
  ) async {
    return selected;
  }
}

class CompletingSpreadsheetPicker implements SpreadsheetPicker {
  final chooseCompleter = Completer<SelectedSpreadsheet?>();
  final createCompleter = Completer<SelectedSpreadsheet?>();
  int chooseCount = 0;
  int createCount = 0;
  final createNames = <String?>[];

  @override
  SpreadsheetPickerAvailability get availability {
    return const SpreadsheetPickerAvailability.available();
  }

  @override
  Future<SelectedSpreadsheet?> chooseSpreadsheet() {
    chooseCount += 1;
    return chooseCompleter.future;
  }

  @override
  Future<bool> authorizeSpreadsheetCreation() async {
    return true;
  }

  @override
  Future<SelectedSpreadsheet?> createSpreadsheet({String? name}) {
    createCount += 1;
    createNames.add(name);
    return createCompleter.future;
  }

  @override
  Future<SelectedSpreadsheet> resolveSelectedSpreadsheet(
    SelectedSpreadsheet selected,
  ) async {
    return selected;
  }
}

class CompositeWorkbookCommandService implements WorkbookCommandService {
  const CompositeWorkbookCommandService({
    required this.validation,
    required this.authoring,
  });

  final WorkbookCommandService validation;
  final AppendingExerciseAuthoringService authoring;

  @override
  Future<SpreadsheetValidationReport> validateSpreadsheet(
    String spreadsheetId,
  ) {
    return validation.validateSpreadsheet(spreadsheetId);
  }

  @override
  Future<SpreadsheetValidationReport> applyActiveSheetWritePlan({
    required String spreadsheetId,
    required ParsedActiveSheet activeSheet,
    required ActiveSheetWritePlan plan,
  }) {
    return validation.applyActiveSheetWritePlan(
      spreadsheetId: spreadsheetId,
      activeSheet: activeSheet,
      plan: plan,
    );
  }

  @override
  Future<SpreadsheetValidationReport> createCanonicalExercise({
    required String spreadsheetId,
    required ParsedActiveSheet activeSheet,
    required CanonicalExerciseDefinition exercise,
  }) {
    return authoring.createCanonicalExercise(
      spreadsheetId: spreadsheetId,
      activeSheet: activeSheet,
      exercise: exercise,
    );
  }

  @override
  Future<SpreadsheetValidationReport> updateCanonicalExercise({
    required String spreadsheetId,
    required ParsedActiveSheet activeSheet,
    required CanonicalExercise selectedExercise,
    required CanonicalExerciseDefinition exercise,
  }) {
    return authoring.updateCanonicalExercise(
      spreadsheetId: spreadsheetId,
      activeSheet: activeSheet,
      selectedExercise: selectedExercise,
      exercise: exercise,
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
    return authoring.addExistingExerciseToWorkout(
      spreadsheetId: spreadsheetId,
      activeSheet: activeSheet,
      exercise: exercise,
      metadata: metadata,
      placement: placement,
    );
  }

  @override
  Future<SpreadsheetValidationReport> reorderCanonicalExercises({
    required String spreadsheetId,
    required ParsedActiveSheet activeSheet,
    required ReorderIntent intent,
  }) {
    return authoring.reorderCanonicalExercises(
      spreadsheetId: spreadsheetId,
      activeSheet: activeSheet,
      intent: intent,
    );
  }

  @override
  Future<SpreadsheetValidationReport> reorderWorkoutExercises({
    required String spreadsheetId,
    required ParsedActiveSheet activeSheet,
    required String workout,
    required ReorderIntent intent,
  }) {
    return authoring.reorderWorkoutExercises(
      spreadsheetId: spreadsheetId,
      activeSheet: activeSheet,
      workout: workout,
      intent: intent,
    );
  }

  @override
  Future<SpreadsheetValidationReport> deleteWorkoutExercise({
    required String spreadsheetId,
    required ParsedActiveSheet activeSheet,
    required int primarySheetRowNumber,
  }) {
    return authoring.deleteWorkoutExercise(
      spreadsheetId: spreadsheetId,
      activeSheet: activeSheet,
      primarySheetRowNumber: primarySheetRowNumber,
    );
  }
}

class AppendingExerciseAuthoringService {
  AppendingExerciseAuthoringService(List<List<String>> exercises)
    : _exercises = exercises.map((row) => row.toList()).toList();

  final List<List<String>> _exercises;
  final createdExercises = <CanonicalExerciseDefinition>[];

  Future<SpreadsheetValidationReport> createCanonicalExercise({
    required String spreadsheetId,
    required ParsedActiveSheet activeSheet,
    required CanonicalExerciseDefinition exercise,
  }) async {
    createdExercises.add(exercise);
    _exercises.insert(0, [
      exercise.exercise,
      exercise.description,
      exercise.defaultSets,
      exercise.defaultReps,
      exercise.defaultRpe,
      exercise.defaultRest,
      exercise.defaultTempo,
      exercise.notes,
      exercise.resolvedLogFormat,
    ]);
    final activeExerciseIndex = _exercises.indexWhere(
      (row) => row.first == 'Squat',
    );
    final activeExerciseRowNumber = activeExerciseIndex == -1
        ? 2
        : activeExerciseIndex + 2;
    return SpreadsheetValidationReport(
      spreadsheetId: spreadsheetId,
      activeSheet: exerciseInventoryParsedSheet(
        _exercises,
        cellFormulas: [
          CellFormula(
            sheetRowNumber: 3,
            sheetColumnNumber: 1,
            formula: '=Exercises!A$activeExerciseRowNumber',
          ),
          CellFormula(
            sheetRowNumber: 3,
            sheetColumnNumber: 8,
            formula: '=Exercises!I$activeExerciseRowNumber',
          ),
        ],
      ),
    );
  }

  Future<SpreadsheetValidationReport> updateCanonicalExercise({
    required String spreadsheetId,
    required ParsedActiveSheet activeSheet,
    required CanonicalExercise selectedExercise,
    required CanonicalExerciseDefinition exercise,
  }) {
    throw UnimplementedError();
  }

  Future<SpreadsheetValidationReport> addExistingExerciseToWorkout({
    required String spreadsheetId,
    required ParsedActiveSheet activeSheet,
    required CanonicalExercise exercise,
    required WorkoutPlacementMetadata metadata,
    required ExercisePlacementTarget placement,
  }) {
    throw UnimplementedError();
  }

  Future<SpreadsheetValidationReport> reorderCanonicalExercises({
    required String spreadsheetId,
    required ParsedActiveSheet activeSheet,
    required ReorderIntent intent,
  }) {
    throw UnimplementedError();
  }

  Future<SpreadsheetValidationReport> reorderWorkoutExercises({
    required String spreadsheetId,
    required ParsedActiveSheet activeSheet,
    required String workout,
    required ReorderIntent intent,
  }) {
    throw UnimplementedError();
  }

  Future<SpreadsheetValidationReport> deleteWorkoutExercise({
    required String spreadsheetId,
    required ParsedActiveSheet activeSheet,
    required int primarySheetRowNumber,
  }) {
    throw UnimplementedError();
  }
}

class EditingExerciseAuthoringService
    extends AppendingExerciseAuthoringService {
  EditingExerciseAuthoringService(super.exercises);

  final updatedExercises =
      <({int row, CanonicalExerciseDefinition exercise})>[];

  int get exerciseCount => _exercises.length;

  @override
  Future<SpreadsheetValidationReport> updateCanonicalExercise({
    required String spreadsheetId,
    required ParsedActiveSheet activeSheet,
    required CanonicalExercise selectedExercise,
    required CanonicalExerciseDefinition exercise,
  }) async {
    updatedExercises.add((
      row: selectedExercise.sheetRowNumber,
      exercise: exercise,
    ));
    _exercises[selectedExercise.sheetRowNumber - 2] = [
      exercise.exercise,
      exercise.description,
      exercise.defaultSets,
      exercise.defaultReps,
      exercise.defaultRpe,
      exercise.defaultRest,
      exercise.defaultTempo,
      exercise.notes,
      exercise.resolvedLogFormat,
    ];
    return SpreadsheetValidationReport(
      spreadsheetId: spreadsheetId,
      activeSheet: exerciseInventoryParsedSheet(_exercises),
    );
  }
}

class WorkoutPlacementRecordingService
    extends AppendingExerciseAuthoringService {
  WorkoutPlacementRecordingService(this._activeSheet) : super(const []);

  final ParsedActiveSheet _activeSheet;
  final placements = <({String exercise, String? workout, bool isBackup})>[];

  @override
  Future<SpreadsheetValidationReport> addExistingExerciseToWorkout({
    required String spreadsheetId,
    required ParsedActiveSheet activeSheet,
    required CanonicalExercise exercise,
    required WorkoutPlacementMetadata metadata,
    required ExercisePlacementTarget placement,
  }) async {
    placements.add((
      exercise: exercise.displayName,
      workout: placement.workout,
      isBackup: placement.isBackup,
    ));
    return SpreadsheetValidationReport(
      spreadsheetId: spreadsheetId,
      activeSheet: _activeSheet,
    );
  }
}

class ReorderingExerciseAuthoringService
    extends AppendingExerciseAuthoringService {
  ReorderingExerciseAuthoringService(super.exercises);

  final reorderIntents = <ReorderIntent>[];

  @override
  Future<SpreadsheetValidationReport> reorderCanonicalExercises({
    required String spreadsheetId,
    required ParsedActiveSheet activeSheet,
    required ReorderIntent intent,
  }) async {
    reorderIntents.add(intent);
    final plan = activeSheet.planCanonicalExerciseReorder(intent);
    final previewRows = plan.previewRowsAfterApplying([
      exercisesSheetColumns,
      ..._exercises,
    ]);
    _exercises
      ..clear()
      ..addAll(previewRows.skip(1).map((row) => row.toList()));
    return SpreadsheetValidationReport(
      spreadsheetId: spreadsheetId,
      activeSheet: exerciseInventoryParsedSheet(
        _exercises,
        cellFormulas: plan.activeSheetFormulaUpdates
            .map(
              (update) => CellFormula(
                sheetRowNumber: update.sheetRowNumber,
                sheetColumnNumber: update.sheetColumnNumber,
                formula: update.value,
              ),
            )
            .toList(),
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
    throw UnimplementedError();
  }
}

class ReorderingWorkoutExerciseAuthoringService
    extends AppendingExerciseAuthoringService {
  ReorderingWorkoutExerciseAuthoringService(List<List<String>> rows)
    : _rows = rows.map((row) => row.toList()).toList(),
      super(const []);

  final List<List<String>> _rows;
  final reorderIntents = <ReorderIntent>[];

  @override
  Future<SpreadsheetValidationReport> reorderWorkoutExercises({
    required String spreadsheetId,
    required ParsedActiveSheet activeSheet,
    required String workout,
    required ReorderIntent intent,
  }) async {
    reorderIntents.add(intent);
    final plan = activeSheet.planWorkoutExerciseReorder(
      workout: workout,
      intent: intent,
    );
    final previewRows = plan.previewRowsAfterApplying(_rows);
    _rows
      ..clear()
      ..addAll(previewRows.map((row) => row.toList()));
    return SpreadsheetValidationReport(
      spreadsheetId: spreadsheetId,
      activeSheet: parseActiveSheet(ActiveSheetInput(rows: _rows)),
    );
  }
}

class DeletingWorkoutExerciseAuthoringService
    extends AppendingExerciseAuthoringService {
  DeletingWorkoutExerciseAuthoringService(
    List<List<String>> rows, {
    this.rejectDelete = false,
  }) : _rows = rows.map((row) => row.toList()).toList(),
       super(const []);

  final List<List<String>> _rows;
  final bool rejectDelete;
  final deletedRows = <int>[];

  @override
  Future<SpreadsheetValidationReport> deleteWorkoutExercise({
    required String spreadsheetId,
    required ParsedActiveSheet activeSheet,
    required int primarySheetRowNumber,
  }) async {
    deletedRows.add(primarySheetRowNumber);
    if (rejectDelete) {
      return SpreadsheetValidationReport(
        spreadsheetId: spreadsheetId,
        activeSheet: activeSheet,
        writeRejections: [
          ActiveSheetWriteRejection(
            'Row $primarySheetRowNumber no longer matches Pull Up.',
          ),
        ],
      );
    }

    final plan = activeSheet.planPrimaryWorkoutExerciseDeletion(
      primarySheetRowNumber: primarySheetRowNumber,
    );
    final previewRows = plan.previewRowsAfterApplying(_rows);
    _rows
      ..clear()
      ..addAll(previewRows.map((row) => row.toList()));
    return SpreadsheetValidationReport(
      spreadsheetId: spreadsheetId,
      activeSheet: parseActiveSheet(ActiveSheetInput(rows: _rows)),
    );
  }
}

class CountingSpreadsheetPicker implements SpreadsheetPicker {
  int chooseCount = 0;
  int createCount = 0;
  int creationAuthorizationCount = 0;
  final createNames = <String?>[];
  Future<bool>? creationAuthorization;

  @override
  SpreadsheetPickerAvailability get availability {
    return const SpreadsheetPickerAvailability.available();
  }

  @override
  Future<SelectedSpreadsheet?> chooseSpreadsheet() async {
    chooseCount += 1;
    return null;
  }

  @override
  Future<SelectedSpreadsheet?> createSpreadsheet({String? name}) async {
    createCount += 1;
    createNames.add(name);
    return null;
  }

  @override
  Future<bool> authorizeSpreadsheetCreation() async {
    creationAuthorizationCount += 1;
    return creationAuthorization ?? true;
  }

  @override
  Future<SelectedSpreadsheet> resolveSelectedSpreadsheet(
    SelectedSpreadsheet selected,
  ) async {
    return selected;
  }
}

class RecordingSpreadsheetOpener implements SpreadsheetOpener {
  final openedUrls = <String>[];

  @override
  Future<void> openSpreadsheet(String url) async {
    openedUrls.add(url);
  }
}

class RevalidatingSpreadsheetValidationService extends WorkbookCommandService {
  RevalidatingSpreadsheetValidationService({required this.reports});

  final List<ParsedActiveSheet> reports;
  int _reportIndex = 0;

  @override
  Future<SpreadsheetValidationReport> validateSpreadsheet(
    String spreadsheetId,
  ) async {
    final index = _reportIndex.clamp(0, reports.length - 1);
    _reportIndex += 1;
    return SpreadsheetValidationReport(
      spreadsheetId: spreadsheetId,
      activeSheet: reports[index],
    );
  }

  @override
  Future<SpreadsheetValidationReport> applyActiveSheetWritePlan({
    required String spreadsheetId,
    required ParsedActiveSheet activeSheet,
    required ActiveSheetWritePlan plan,
  }) {
    throw UnimplementedError();
  }
}

ParsedActiveSheet minimalValidParsedSheet() {
  return parseActiveSheet(
    ActiveSheetInput(
      rows: [
        [...activeSheetFixedColumns, 'Week 1'],
        [...List.filled(activeSheetFixedColumns.length, ''), 'S1'],
        ['Squat', '3', '5', '8', '3 min', '', '', '', 'Legs', '', ''],
      ],
    ),
  );
}

ParsedActiveSheet loggedSetParsedSheet() {
  return parseActiveSheet(
    ActiveSheetInput(
      rows: [
        [...activeSheetFixedColumns, 'Week 1'],
        [...List.filled(activeSheetFixedColumns.length, ''), 'S1'],
        ['Squat', '3', '5', '8', '3 min', '', '', '', 'Legs', '', '150x5@8'],
      ],
    ),
  );
}

ParsedActiveSheet twoSetLoggingSheet({required String s2Value}) {
  return parseActiveSheet(
    ActiveSheetInput(
      rows: [
        [...activeSheetFixedColumns, 'Week 1', ''],
        [...List.filled(activeSheetFixedColumns.length, ''), 'S1', 'S2'],
        [
          'Squat',
          '3',
          '5',
          '8',
          '3 min',
          '',
          '',
          '',
          'Legs',
          '',
          '150x5@8',
          s2Value,
        ],
      ],
    ),
  );
}

ParsedActiveSheet exerciseInventoryParsedSheet(
  List<List<String>> exercises, {
  Iterable<CellFormula> cellFormulas = const [
    CellFormula(
      sheetRowNumber: 3,
      sheetColumnNumber: 1,
      formula: '=Exercises!A2',
    ),
    CellFormula(
      sheetRowNumber: 3,
      sheetColumnNumber: 8,
      formula: '=Exercises!I2',
    ),
  ],
}) {
  return parseActiveSheet(
    ActiveSheetInput(
      rows: [
        [...activeSheetFixedColumns, 'Week 1'],
        [...List.filled(activeSheetFixedColumns.length, ''), 'S1'],
        ['Squat', '3', '5', '8', '3 min', '', '', '', 'Legs', '', ''],
      ],
      cellFormulas: cellFormulas,
      exercisesRows: [exercisesSheetColumns, ...exercises],
    ),
  );
}

ParsedActiveSheet emptyExerciseInventoryParsedSheet() {
  return parseActiveSheet(
    ActiveSheetInput(
      rows: [
        [...activeSheetFixedColumns, 'Week 1'],
        [...List.filled(activeSheetFixedColumns.length, ''), 'S1'],
      ],
      exercisesRows: const [exercisesSheetColumns],
    ),
  );
}

List<String> exerciseRow(
  String name, {
  String description = '',
  String defaultSets = '3',
  String defaultReps = '10',
  String defaultRpe = '8',
  String defaultRest = '2 min',
  String defaultTempo = '',
  String notes = '',
  String logFormat = '{Weight}[x]{Reps}[@]{RPE}',
}) {
  return [
    name,
    description,
    defaultSets,
    defaultReps,
    defaultRpe,
    defaultRest,
    defaultTempo,
    notes,
    logFormat,
  ];
}

class CompletingWriteValidationService extends WorkbookCommandService {
  CompletingWriteValidationService(this.validSheet);

  final ParsedActiveSheet validSheet;
  final appliedPlans = <ActiveSheetWritePlan>[];
  final writeCompleter = Completer<SpreadsheetValidationReport>();

  @override
  Future<SpreadsheetValidationReport> validateSpreadsheet(
    String spreadsheetId,
  ) async {
    return SpreadsheetValidationReport(
      spreadsheetId: spreadsheetId,
      activeSheet: validSheet,
    );
  }

  @override
  Future<SpreadsheetValidationReport> applyActiveSheetWritePlan({
    required String spreadsheetId,
    required ParsedActiveSheet activeSheet,
    required ActiveSheetWritePlan plan,
  }) {
    appliedPlans.add(plan);
    return writeCompleter.future;
  }
}

class FailingWriteValidationService extends WorkbookCommandService {
  FailingWriteValidationService(this.validSheet);

  final ParsedActiveSheet validSheet;
  final appliedPlans = <ActiveSheetWritePlan>[];

  @override
  Future<SpreadsheetValidationReport> validateSpreadsheet(
    String spreadsheetId,
  ) async {
    return SpreadsheetValidationReport(
      spreadsheetId: spreadsheetId,
      activeSheet: validSheet,
    );
  }

  @override
  Future<SpreadsheetValidationReport> applyActiveSheetWritePlan({
    required String spreadsheetId,
    required ParsedActiveSheet activeSheet,
    required ActiveSheetWritePlan plan,
  }) async {
    appliedPlans.add(plan);
    throw StateError('network unavailable');
  }
}

class RecoverableConfirmationFailureService extends WorkbookCommandService {
  RecoverableConfirmationFailureService()
    : initialSheet = twoSetLoggingSheet(s2Value: ''),
      conflictingSheet = twoSetLoggingSheet(s2Value: '95x10@7'),
      savedSheet = twoSetLoggingSheet(s2Value: '155x6@8');

  final ParsedActiveSheet initialSheet;
  final ParsedActiveSheet conflictingSheet;
  final ParsedActiveSheet savedSheet;
  final appliedPlans = <ActiveSheetWritePlan>[];

  @override
  Future<SpreadsheetValidationReport> validateSpreadsheet(
    String spreadsheetId,
  ) async {
    final activeSheet = switch (appliedPlans.length) {
      0 => initialSheet,
      1 => conflictingSheet,
      _ => savedSheet,
    };
    return SpreadsheetValidationReport(
      spreadsheetId: spreadsheetId,
      activeSheet: activeSheet,
    );
  }

  @override
  Future<SpreadsheetValidationReport> applyActiveSheetWritePlan({
    required String spreadsheetId,
    required ParsedActiveSheet activeSheet,
    required ActiveSheetWritePlan plan,
  }) async {
    appliedPlans.add(plan);
    final activeSheet = appliedPlans.length == 1
        ? conflictingSheet
        : savedSheet;
    return SpreadsheetValidationReport(
      spreadsheetId: spreadsheetId,
      activeSheet: activeSheet,
    );
  }
}

class DamageAfterSaveValidationService extends WorkbookCommandService {
  DamageAfterSaveValidationService({
    required this.validSheet,
    required this.damagedSheet,
  });

  final ParsedActiveSheet validSheet;
  final ParsedActiveSheet damagedSheet;
  final appliedPlans = <ActiveSheetWritePlan>[];

  @override
  Future<SpreadsheetValidationReport> validateSpreadsheet(
    String spreadsheetId,
  ) async {
    return SpreadsheetValidationReport(
      spreadsheetId: spreadsheetId,
      activeSheet: validSheet,
    );
  }

  @override
  Future<SpreadsheetValidationReport> applyActiveSheetWritePlan({
    required String spreadsheetId,
    required ParsedActiveSheet activeSheet,
    required ActiveSheetWritePlan plan,
  }) async {
    appliedPlans.add(plan);
    return SpreadsheetValidationReport(
      spreadsheetId: spreadsheetId,
      activeSheet: damagedSheet,
    );
  }
}

class FormulaRepairValidationService extends WorkbookCommandService {
  FormulaRepairValidationService({
    required this.initialSheet,
    required this.repairedSheet,
  });

  final ParsedActiveSheet initialSheet;
  final ParsedActiveSheet repairedSheet;
  final List<ActiveSheetWritePlan> appliedPlans = [];

  @override
  Future<SpreadsheetValidationReport> validateSpreadsheet(
    String spreadsheetId,
  ) async {
    return SpreadsheetValidationReport(
      spreadsheetId: spreadsheetId,
      activeSheet: initialSheet,
    );
  }

  @override
  Future<SpreadsheetValidationReport> applyActiveSheetWritePlan({
    required String spreadsheetId,
    required ParsedActiveSheet activeSheet,
    required ActiveSheetWritePlan plan,
  }) async {
    appliedPlans.add(plan);
    return SpreadsheetValidationReport(
      spreadsheetId: spreadsheetId,
      activeSheet: repairedSheet,
    );
  }
}

ParsedActiveSheet parseWorkbookFixture(WorkoutWorkbookFixture fixture) {
  return parseActiveSheet(
    ActiveSheetInput(
      rows: fixture.activeSheet.rows,
      mergedFirstColumnRows: fixture.activeSheet.mergedFirstColumnRows,
      cellFormulas: fixture.activeSheet.cellFormulas.map(
        (formula) => CellFormula(
          sheetRowNumber: formula.sheetRowNumber,
          sheetColumnNumber: formula.sheetColumnNumber,
          formula: formula.formula,
        ),
      ),
      exercisesRows: fixture.exercisesSheet.rows,
    ),
  );
}

ParsedActiveSheet repairedFormulaDamageFixtureSheet() {
  final fixture = loadFormulaDamageFixture();
  return parseRepairedFormulaDamageFixtureRows(fixture.activeSheet.rows);
}

ParsedActiveSheet repairedFormulaDamageFixtureSheetWithBackupViolation() {
  final fixture = loadFormulaDamageFixture();
  final rows = fixture.activeSheet.rows.map((row) => row.toList()).toList();
  rows[2][9] = 'TRUE';
  return parseRepairedFormulaDamageFixtureRows(rows);
}

ParsedActiveSheet parseRepairedFormulaDamageFixtureRows(
  List<List<String>> rows,
) {
  final fixture = loadFormulaDamageFixture();
  return parseActiveSheet(
    ActiveSheetInput(
      rows: rows,
      exercisesRows: fixture.exercisesSheet.rows,
      cellFormulas: const [
        CellFormula(
          sheetRowNumber: 3,
          sheetColumnNumber: 1,
          formula: '=Exercises!A2',
        ),
        CellFormula(
          sheetRowNumber: 3,
          sheetColumnNumber: 2,
          formula: '=Exercises!C2',
        ),
        CellFormula(
          sheetRowNumber: 3,
          sheetColumnNumber: 3,
          formula: '=Exercises!D2',
        ),
        CellFormula(
          sheetRowNumber: 3,
          sheetColumnNumber: 4,
          formula: '=Exercises!E2',
        ),
        CellFormula(
          sheetRowNumber: 3,
          sheetColumnNumber: 5,
          formula: '=Exercises!F2',
        ),
        CellFormula(
          sheetRowNumber: 3,
          sheetColumnNumber: 6,
          formula: '=Exercises!G2',
        ),
        CellFormula(
          sheetRowNumber: 3,
          sheetColumnNumber: 7,
          formula: '=Exercises!H2',
        ),
        CellFormula(
          sheetRowNumber: 3,
          sheetColumnNumber: 8,
          formula: '=Exercises!I2',
        ),
      ],
    ),
  );
}
