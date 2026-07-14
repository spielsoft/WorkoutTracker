import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_tracker/contract.dart';
import 'package:workout_tracker/app.dart';

import '../fixtures/workbook.dart';

class FakeGoogleAccountSession extends ChangeNotifier
    implements GoogleAccountSession {
  FakeGoogleAccountSession(
    this._currentAccount, {
    this.restoredAccount,
    this.restoreWait,
  });

  GoogleAccountProfile? _currentAccount;
  final GoogleAccountProfile? restoredAccount;
  final Future<void>? restoreWait;
  int restoreCount = 0;
  int signInCount = 0;
  int signOutCount = 0;
  final requestedScopes = <List<String>>[];

  @override
  GoogleAccountProfile? get currentAccount => _currentAccount;

  @override
  Future<void> restoreAccount({List<String> scopes = const []}) async {
    restoreCount += 1;
    if (restoreWait case final wait?) {
      await wait;
    }
    if (restoredAccount != null) {
      _currentAccount = restoredAccount;
      notifyListeners();
    }
  }

  @override
  Future<bool> signIn({List<String> scopes = const []}) async {
    signInCount += 1;
    requestedScopes.add(scopes);
    _currentAccount = const GoogleAccountProfile(
      email: 'right@example.com',
      displayName: 'Right Account',
    );
    notifyListeners();
    return true;
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

class MemoryAppStStore implements AppStStore {
  MemoryAppStStore(this.sheetText, {this.selectedSheet});

  String? sheetText;
  SelectedSheet? selectedSheet;
  WorkoutSelectionSt? workoutSelection;
  final accessStWrites = <WorkspaceAccessSt>[];
  int clearCount = 0;

  @override
  Future<WorkspaceAccessSt> readWorkspaceSt() async {
    return WorkspaceAccessSt(
      sheetText: sheetText,
      selectedSheet: selectedSheet,
      workoutSelection: workoutSelection,
    );
  }

  @override
  Future<void> writeWorkspaceSt(WorkspaceAccessSt value) async {
    sheetText = value.sheetText;
    selectedSheet = value.selectedSheet;
    workoutSelection = value.workoutSelection;
    accessStWrites.add(value);
  }

  @override
  Future<void> clearWorkspaceSt() async {
    clearCount += 1;
    sheetText = null;
    selectedSheet = null;
    workoutSelection = null;
  }
}

class FakeSheetPicker implements SheetPicker {
  @override
  PickerAvail get availability {
    return const PickerAvail.available();
  }

  @override
  Future<SelectedSheet?> chooseSheet() async {
    return null;
  }

  @override
  Future<SelectedSheet?> createSheet({String? name}) async {
    return null;
  }
}

class SelectingSheetPicker implements SheetPicker {
  @override
  PickerAvail get availability {
    return const PickerAvail.available();
  }

  @override
  Future<SelectedSheet?> chooseSheet() async {
    return const SelectedSheet(
      spreadsheetId: 'selected-spreadsheet-id',
      name: 'Development Workouts',
      accountEmail: 'athlete@example.com',
    );
  }

  @override
  Future<SelectedSheet?> createSheet({String? name}) async {
    return null;
  }
}

class CompletingSheetPicker implements SheetPicker {
  final chooseCompleter = Completer<SelectedSheet?>();
  final createCompleter = Completer<SelectedSheet?>();
  int chooseCount = 0;
  int createCount = 0;
  final createNames = <String?>[];

  @override
  PickerAvail get availability {
    return const PickerAvail.available();
  }

  @override
  Future<SelectedSheet?> chooseSheet() {
    chooseCount += 1;
    return chooseCompleter.future;
  }

  @override
  Future<SelectedSheet?> createSheet({String? name}) {
    createCount += 1;
    createNames.add(name);
    return createCompleter.future;
  }
}

class CompositeWorkbookCommandService implements WbkAccess {
  const CompositeWorkbookCommandService({
    required this.validation,
    required this.authoring,
  });

  final WbkAccess validation;
  final AppendingExerciseAuthoringService authoring;

  @override
  WbkSess open(String sheetId) {
    return _CompositeSess(
      validation: validation.open(sheetId),
      authoring: authoring,
    );
  }
}

class _CompositeSess implements WbkSess {
  _CompositeSess({required this.validation, required this.authoring});

  final WbkSess validation;
  final AppendingExerciseAuthoringService authoring;
  ValReport? _report;

  @override
  String get sheetId => validation.sheetId;

  @override
  Future<ValReport> read() async {
    return _report = await validation.read();
  }

  @override
  Future<ValReport> execute(WbkCmd cmd) async {
    final active = (_report ?? await read()).activeSheet;
    final report = switch (cmd) {
      CreateExeCmd(:final exercise) => authoring.createExercise(
        spreadsheetId: sheetId,
        activeSheet: active,
        exercise: exercise,
      ),
      UpdateExeCmd(:final selected, :final exercise) =>
        authoring.updateExercise(
          spreadsheetId: sheetId,
          activeSheet: active,
          selectedExercise: selected,
          exercise: exercise,
        ),
      PlaceExeCmd(:final exercise, :final metadata, :final placement) =>
        authoring.addExerciseToWorkout(
          spreadsheetId: sheetId,
          activeSheet: active,
          exercise: exercise,
          metadata: metadata,
          placement: placement,
        ),
      ReorderExesCmd(:final intent) => authoring.reorderExercises(
        spreadsheetId: sheetId,
        activeSheet: active,
        intent: intent,
      ),
      ReorderWorkoutCmd(:final workout, :final intent) =>
        authoring.reorderWorkoutExercises(
          spreadsheetId: sheetId,
          activeSheet: active,
          workout: workout,
          intent: intent,
        ),
      DeleteWorkoutExeCmd(:final primaryRow) => authoring.deleteWorkoutExercise(
        spreadsheetId: sheetId,
        activeSheet: active,
        primaryRow: primaryRow,
      ),
      _ => validation.execute(cmd),
    };
    return _report = await report;
  }
}

class AppendingExerciseAuthoringService {
  AppendingExerciseAuthoringService(List<List<String>> exercises)
    : _exercises = exercises.map((row) => row.toList()).toList();

  final List<List<String>> _exercises;
  final createdExercises = <ExerciseDef>[];

  Future<ValReport> createExercise({
    required String spreadsheetId,
    required ParsedActiveSheet activeSheet,
    required ExerciseDef exercise,
  }) async {
    createdExercises.add(exercise);
    _exercises.insert(0, [
      exercise.exercise,
      exercise.description,
      exercise.defaultSets,
      exercise.defaultRest,
      exercise.defaultTempo,
      exercise.notes,
      exercise.resolvedLogFormat,
      exercise.renderedDefaultValues,
    ]);
    final activeExerciseIndex = _exercises.indexWhere(
      (row) => row.first == 'Squat',
    );
    final activeExerciseRowNumber = activeExerciseIndex == -1
        ? 2
        : activeExerciseIndex + 2;
    return ValReport(
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
            sheetColumnNumber: 7,
            formula: '=Exercises!G$activeExerciseRowNumber',
          ),
        ],
      ),
    );
  }

  Future<ValReport> updateExercise({
    required String spreadsheetId,
    required ParsedActiveSheet activeSheet,
    required CanonicalExercise selectedExercise,
    required ExerciseDef exercise,
  }) {
    throw UnimplementedError();
  }

  Future<ValReport> addExerciseToWorkout({
    required String spreadsheetId,
    required ParsedActiveSheet activeSheet,
    required CanonicalExercise exercise,
    required WorkoutPlacementMetadata metadata,
    required ExercisePlacementTarget placement,
  }) {
    throw UnimplementedError();
  }

  Future<ValReport> reorderExercises({
    required String spreadsheetId,
    required ParsedActiveSheet activeSheet,
    required ReorderIntent intent,
  }) {
    throw UnimplementedError();
  }

  Future<ValReport> reorderWorkoutExercises({
    required String spreadsheetId,
    required ParsedActiveSheet activeSheet,
    required String workout,
    required ReorderIntent intent,
  }) {
    throw UnimplementedError();
  }

  Future<ValReport> deleteWorkoutExercise({
    required String spreadsheetId,
    required ParsedActiveSheet activeSheet,
    required int primaryRow,
  }) {
    throw UnimplementedError();
  }
}

class EditingExerciseAuthoringService
    extends AppendingExerciseAuthoringService {
  EditingExerciseAuthoringService(super.exercises);

  final updatedExercises = <({int row, ExerciseDef exercise})>[];

  int get exerciseCount => _exercises.length;

  @override
  Future<ValReport> updateExercise({
    required String spreadsheetId,
    required ParsedActiveSheet activeSheet,
    required CanonicalExercise selectedExercise,
    required ExerciseDef exercise,
  }) async {
    updatedExercises.add((
      row: selectedExercise.sheetRowNumber,
      exercise: exercise,
    ));
    _exercises[selectedExercise.sheetRowNumber - 2] = [
      exercise.exercise,
      exercise.description,
      exercise.defaultSets,
      exercise.defaultRest,
      exercise.defaultTempo,
      exercise.notes,
      exercise.resolvedLogFormat,
      exercise.renderedDefaultValues,
    ];
    return ValReport(
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
  Future<ValReport> addExerciseToWorkout({
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
    return ValReport(spreadsheetId: spreadsheetId, activeSheet: _activeSheet);
  }
}

class ReorderingExerciseAuthoringService
    extends AppendingExerciseAuthoringService {
  ReorderingExerciseAuthoringService(super.exercises);

  final reorderIntents = <ReorderIntent>[];

  @override
  Future<ValReport> reorderExercises({
    required String spreadsheetId,
    required ParsedActiveSheet activeSheet,
    required ReorderIntent intent,
  }) async {
    reorderIntents.add(intent);
    final plan = activeSheet.planCanonicalReorder(intent);
    final previewRows = plan.previewRowsAfterApplying([
      exercisesSheetColumns,
      ..._exercises,
    ]);
    _exercises
      ..clear()
      ..addAll(previewRows.skip(1).map((row) => row.toList()));
    return ValReport(
      spreadsheetId: spreadsheetId,
      activeSheet: exerciseInventoryParsedSheet(
        _exercises,
        cellFormulas: plan.formulaUpdates
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
  Future<ValReport> reorderWorkoutExercises({
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
  Future<ValReport> reorderWorkoutExercises({
    required String spreadsheetId,
    required ParsedActiveSheet activeSheet,
    required String workout,
    required ReorderIntent intent,
  }) async {
    reorderIntents.add(intent);
    final plan = activeSheet.planExerciseReorder(
      workout: workout,
      intent: intent,
    );
    final previewRows = plan.previewRowsAfterApplying(_rows);
    _rows
      ..clear()
      ..addAll(previewRows.map((row) => row.toList()));
    return ValReport(
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
  Future<ValReport> deleteWorkoutExercise({
    required String spreadsheetId,
    required ParsedActiveSheet activeSheet,
    required int primaryRow,
  }) async {
    deletedRows.add(primaryRow);
    if (rejectDelete) {
      return ValReport(
        spreadsheetId: spreadsheetId,
        activeSheet: activeSheet,
        writeRejections: [
          WriteRejection('Row $primaryRow no longer matches Pull Up.'),
        ],
      );
    }

    final plan = activeSheet.planDeletePrimary(primaryRow: primaryRow);
    final previewRows = plan.previewRowsAfterApplying(_rows);
    _rows
      ..clear()
      ..addAll(previewRows.map((row) => row.toList()));
    return ValReport(
      spreadsheetId: spreadsheetId,
      activeSheet: parseActiveSheet(ActiveSheetInput(rows: _rows)),
    );
  }
}

class CountingSheetPicker implements SheetPicker {
  int chooseCount = 0;
  int createCount = 0;
  final createNames = <String?>[];

  @override
  PickerAvail get availability {
    return const PickerAvail.available();
  }

  @override
  Future<SelectedSheet?> chooseSheet() async {
    chooseCount += 1;
    return null;
  }

  @override
  Future<SelectedSheet?> createSheet({String? name}) async {
    createCount += 1;
    createNames.add(name);
    return null;
  }
}

class RecordingSheetOpener implements SheetOpener {
  final openedUrls = <String>[];

  @override
  Future<void> openSheet(String url) async {
    openedUrls.add(url);
  }
}

class _IoAccess implements WbkAccess {
  _IoAccess(
    Iterable<ParsedActiveSheet> sheets, {
    Future<void> Function(ActiveSheetWritePlan plan)? onActiveWrite,
  }) : _io = _TestWbkIo(sheets, onActiveWrite: onActiveWrite);

  final _TestWbkIo _io;

  List<ActiveSheetWritePlan> get appliedPlans => _io.appliedPlans;

  @override
  WbkSess open(String sheetId) => ValSess(sheetId: sheetId, io: _io);
}

class _TestWbkIo implements WbkIo {
  _TestWbkIo(Iterable<ParsedActiveSheet> sheets, {this.onActiveWrite})
    : _sheets = sheets.toList();

  final List<ParsedActiveSheet> _sheets;
  final Future<void> Function(ActiveSheetWritePlan plan)? onActiveWrite;
  final appliedPlans = <ActiveSheetWritePlan>[];
  var _readIndex = 0;

  @override
  Future<ParsedActiveSheet> read() async {
    final i = _readIndex++;
    return i < _sheets.length ? _sheets[i] : _sheets.last;
  }

  @override
  Future<void> writeActive(ActiveSheetWritePlan plan) async {
    appliedPlans.add(plan);
    await onActiveWrite?.call(plan);
  }

  @override
  Future<void> writeExercises(ExercisesWritePlan plan) async {
    throw UnimplementedError();
  }
}

class RevalidatingValService extends _IoAccess {
  RevalidatingValService({required List<ParsedActiveSheet> reports})
    : super(reports);
}

ParsedActiveSheet minimalValidParsedSheet() {
  return parseActiveSheet(
    ActiveSheetInput(
      rows: [
        [...activeSheetFixedColumns, 'Week 1'],
        [...List.filled(activeSheetFixedColumns.length, ''), 'S1'],
        [
          'Squat',
          '3',
          '3 min',
          '',
          'x5@8',
          '',
          defaultExerciseLogFormat,
          'Legs',
          '',
          '',
        ],
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
        ['Squat', '3', '3 min', '', 'x5@8', '', '', 'Legs', '', 'x', '150x5@8'],
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
          '3 min',
          '',
          'x5@8',
          '',
          '',
          'Legs',
          '',
          'x',
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
      sheetColumnNumber: 7,
      formula: '=Exercises!G2',
    ),
  ],
}) {
  return parseActiveSheet(
    ActiveSheetInput(
      rows: [
        [...activeSheetFixedColumns, 'Week 1'],
        [...List.filled(activeSheetFixedColumns.length, ''), 'S1'],
        ['Squat', '3', '3 min', '', 'x5@8', '', '', 'Legs', '', 'x', ''],
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
  String defaultRest = '2 min',
  String defaultTempo = '2-1-1',
  String notes = '',
  String logFormat = '{Weight}[x]{Reps}[@]{RPE}',
  Map<String, String> defaultValues = const {
    'Weight': '',
    'Reps': '10',
    'RPE': '8',
  },
}) {
  final parsed = parseLogFormat(logFormat);
  return [
    name,
    description,
    defaultSets,
    defaultRest,
    defaultTempo,
    notes,
    logFormat,
    if (parsed is ParsedLogFormat) parsed.renderValues(defaultValues) else '',
  ];
}

class CompletingWriteValidationService extends _IoAccess {
  CompletingWriteValidationService(ParsedActiveSheet validSheet)
    : super([
        validSheet,
        validSheet,
      ], onActiveWrite: (_) => Completer<void>().future);
}

class FailingWriteValidationService extends _IoAccess {
  FailingWriteValidationService(ParsedActiveSheet validSheet)
    : super([
        validSheet,
        validSheet,
      ], onActiveWrite: (_) => Future.error(StateError('network unavailable')));
}

class RecoverableConfirmationFailureService implements WbkAccess {
  RecoverableConfirmationFailureService()
    : initialSheet = twoSetLoggingSheet(s2Value: ''),
      conflictingSheet = twoSetLoggingSheet(s2Value: '95x10@7'),
      savedSheet = twoSetLoggingSheet(s2Value: '155x6@8');

  final ParsedActiveSheet initialSheet;
  final ParsedActiveSheet conflictingSheet;
  final ParsedActiveSheet savedSheet;
  late final _IoAccess _delegate = _IoAccess([
    initialSheet,
    initialSheet,
    ...List.filled(7, conflictingSheet),
    initialSheet,
    savedSheet,
  ]);

  List<ActiveSheetWritePlan> get appliedPlans => _delegate.appliedPlans;

  @override
  WbkSess open(String sheetId) {
    return _delegate.open(sheetId);
  }
}

class DamageAfterSaveValidationService extends _IoAccess {
  DamageAfterSaveValidationService({
    required ParsedActiveSheet validSheet,
    required ParsedActiveSheet damagedSheet,
  }) : super([validSheet, validSheet, damagedSheet]);
}

class FormulaRepairValidationService extends _IoAccess {
  FormulaRepairValidationService({
    required ParsedActiveSheet initialSheet,
    required ParsedActiveSheet repairedSheet,
  }) : super([initialSheet, initialSheet, repairedSheet]);
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
  rows[2][8] = 'TRUE';
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
          sheetColumnNumber: 7,
          formula: '=Exercises!G2',
        ),
      ],
    ),
  );
}
