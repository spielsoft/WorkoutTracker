import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:workout_tracker/contract.dart';

import '../controller.dart';
import '../exercise_create_screen.dart';
import '../exercise_edit_screen.dart';
import '../exercise_library.dart';
import '../logging.dart';
import '../placement_screen.dart';
import '../setup.dart';
import '../state_store.dart';
import '../workout_screen.dart';
import '../workspace.dart';
import '../validation_core.dart';
import 'view.dart';

enum _Route { setup, workout, library, create, edit, placement, log }

/// Owns every route and transient state after a workbook is loaded.
///
/// Screens see only their narrow action interfaces. The application flow sees
/// one loaded-workout module and does not interpret feature commands.
final class LoadedFlow
    implements
        SetupActions,
        WorkoutActions,
        LibraryActions,
        CreateExerciseActions,
        EditExerciseActions,
        PlacementActions,
        LogActions {
  LoadedFlow(this._ctrl, this._workspace, this._showSheet, this._changed);

  final AppCtrl _ctrl;
  final WorkspaceCtrl _workspace;
  final VoidCallback _showSheet;
  final VoidCallback _changed;

  _Route _route = _Route.setup;
  CreateOrigin _createOrigin = CreateOrigin.setup;
  PlaceOrigin _placeOrigin = PlaceOrigin.workout;
  PlaceIntent? _placeIntent;
  CanonicalExercise? _editing;
  int? _highlightedRow;

  AppView view({required bool busy, required String sheetLabel}) {
    final setup = _ctrl.workoutSetup!;
    return switch (_route) {
      _Route.setup => SetupView(
        isBusy: busy,
        error: _ctrl.error,
        setup: setup,
        sheetLabel: sheetLabel,
      ),
      _Route.workout => WorkoutView(
        isBusy: busy,
        error: _ctrl.error,
        setup: setup,
        sheetLabel: sheetLabel,
      ),
      _Route.library => LibraryView(
        isBusy: busy,
        error: _ctrl.error,
        exercises: setup.activeSheet.canonicalExercises,
        sheetLabel: sheetLabel,
        highlightedRow: _highlightedRow,
      ),
      _Route.create => CreateExerciseView(
        isBusy: busy,
        error: _ctrl.error,
        sheetLabel: sheetLabel,
        origin: _createOrigin,
      ),
      _Route.edit => EditExerciseView(
        isBusy: busy,
        error: _ctrl.error,
        sheetLabel: sheetLabel,
        exercise: _editing!,
      ),
      _Route.placement => PlacementView(
        isBusy: busy,
        error: _ctrl.error,
        exercises: setup.activeSheet.canonicalExercises,
        sheetLabel: sheetLabel,
        intent: _placeIntent!,
        origin: _placeOrigin,
      ),
      _Route.log => LogView(
        isBusy: busy,
        error: _ctrl.error,
        activeSheet: setup.activeSheet,
        sheetLabel: sheetLabel,
        target: setup.loggingTarget!,
      ),
    };
  }

  void showSetup() {
    _clearTransient();
    _route = _Route.setup;
    _changed();
  }

  void reset() {
    _ctrl.closeExercise();
    _clearTransient();
    _route = _Route.setup;
  }

  void restoreWorkout(WorkoutSelectionSt? saved) {
    final report = _ctrl.report;
    if (saved == null || report == null || saved.sheetId != report.sheetId) {
      return;
    }
    _ctrl.restoreWorkoutSelection(
      workout: saved.workout,
      historyBlock: saved.historyBlock,
    );
  }

  @override
  Future<void> setup(SetupAction action) async {
    switch (action) {
      case BackToSheets():
        _ctrl.closeExercise();
        _clearTransient();
        _showSheet();
      case OpenExerciseLibrary():
        _ctrl.closeExercise();
        _clearTransient();
        _highlightedRow = null;
        _route = _Route.library;
      case ChooseWorkout(:final workout):
        _ctrl.selectWorkout(workout);
        _saveSelection();
        _route = _Route.setup;
      case ChooseHistory(:final block):
        _ctrl.selectHistoryBlock(block);
        _saveSelection();
        _route = _Route.setup;
      case CreateWorkout(:final name):
        if (_ctrl.createWorkout(name)) _saveSelection();
      case CreateHistory(:final label):
        if (await _ctrl.createHistoryBlock(label)) _saveSelection();
      case OpenSelectedWorkout():
        _clearTransient();
        _route = _Route.workout;
      case OpenSetupLog(:final primaryRow):
        _openLog(primaryRow);
      case AddSetupPrimary(:final workout):
        _openPrimary(workout);
      case AddSetupBackup(:final slot):
        _openBackup(slot, PlaceOrigin.setup);
      case DeleteSetupExercise(:final primaryRow):
        await _ctrl.deleteWorkoutExercise(primaryRow: primaryRow);
    }
    _changed();
  }

  @override
  Future<void> workout(WorkoutAction action) async {
    switch (action) {
      case BackToWorkoutSetup():
        showSetup();
        return;
      case AddWorkoutPrimary(:final workout):
        _openPrimary(workout);
      case OpenWorkoutLog(:final primaryRow):
        _openLog(primaryRow);
      case AddWorkoutBackup(:final slot):
        _openBackup(slot, PlaceOrigin.workout);
      case DeleteWorkoutRow(:final primaryRow):
        await _ctrl.deleteWorkoutExercise(primaryRow: primaryRow);
    }
    _changed();
  }

  @override
  Future<bool> reorder(ReorderIntent intent) => _route == _Route.library
      ? _ctrl.reorderExercises(intent)
      : _ctrl.reorderWorkoutExercises(intent);

  @override
  Future<void> close() async {
    switch (_route) {
      case _Route.library:
        showSetup();
      case _Route.create:
        _route = _createOrigin == CreateOrigin.library
            ? _Route.library
            : _Route.setup;
        _changed();
      case _Route.edit:
        _editing = null;
        _route = _Route.library;
        _changed();
      case _Route.placement:
        _placeIntent = null;
        _route = _placeOrigin == PlaceOrigin.setup
            ? _Route.setup
            : _Route.workout;
        _changed();
      case _Route.log:
        _ctrl.closeExercise();
        _route = _Route.workout;
        _changed();
      case _Route.setup || _Route.workout:
        return;
    }
  }

  @override
  Future<void> create() async {
    _ctrl.closeExercise();
    _editing = null;
    _createOrigin = _route == _Route.library
        ? CreateOrigin.library
        : CreateOrigin.setup;
    _placeIntent = null;
    _route = _Route.create;
    _changed();
  }

  @override
  Future<void> edit(CanonicalExercise exercise) async {
    _ctrl.closeExercise();
    _placeIntent = null;
    _highlightedRow = null;
    _editing = exercise;
    _route = _Route.edit;
    _changed();
  }

  @override
  Future<bool> save(ExerciseDef exercise) async {
    if (_route == _Route.edit) return _saveEdit(exercise);
    final ok = await _ctrl.createExercise(exercise: exercise);
    if (!ok) return false;
    _highlightedRow = _createOrigin == CreateOrigin.library
        ? _lastExerciseRow(exercise.exercise)
        : null;
    _route = _createOrigin == CreateOrigin.library
        ? _Route.library
        : _Route.setup;
    _changed();
    return true;
  }

  Future<bool> _saveEdit(ExerciseDef exercise) async {
    final selected = _editing;
    if (selected == null) return false;
    final ok = await _ctrl.updateExercise(
      selectedExercise: selected,
      exercise: exercise,
    );
    if (!ok) return false;
    _editing = null;
    _highlightedRow = selected.sheetRowNumber;
    _route = _Route.library;
    _changed();
    return true;
  }

  @override
  Future<bool> place(
    CanonicalExercise exercise,
    WorkoutPlacementMetadata metadata, {
    bool keepAdding = false,
  }) async {
    final intent = _placeIntent;
    if (intent == null) return false;
    final ok = await _ctrl.addExerciseToWorkout(
      exercise: exercise,
      metadata: metadata,
      placement: switch (intent.kind) {
        PlaceKind.primary => ExercisePlacementTarget.primary(
          workout: intent.workout,
        ),
        PlaceKind.backup => ExercisePlacementTarget.backup(
          primaryRow: intent.primaryRow!,
        ),
      },
    );
    if (ok && !keepAdding) {
      _placeIntent = null;
      _route = _placeOrigin == PlaceOrigin.setup
          ? _Route.setup
          : _Route.workout;
    }
    _changed();
    return ok;
  }

  @override
  Future<bool> execute(WbkCmd cmd) => _ctrl.execute(cmd);

  @override
  Future<void> selectRow(int sheetRow) async {
    _ctrl.selectLoggingRow(sheetRow);
  }

  void _openLog(int primaryRow) {
    _ctrl.openExercise(primaryRow);
    _route = _Route.log;
  }

  void _openPrimary(String workout) {
    _ctrl.closeExercise();
    _editing = null;
    _highlightedRow = null;
    _placeOrigin = PlaceOrigin.setup;
    _placeIntent = PlaceIntent.primary(workout: workout);
    _route = _Route.placement;
  }

  void _openBackup(WorkoutOverviewSlot slot, PlaceOrigin origin) {
    final workout = _ctrl.workoutSetup?.selectedWorkout;
    if (workout == null) return;
    _placeOrigin = origin;
    _ctrl.closeExercise();
    _editing = null;
    _placeIntent = PlaceIntent.backup(
      workout: workout,
      primaryRow: slot.sheetRowNumber,
      primaryExercise: slot.exercise,
    );
    _route = _Route.placement;
  }

  int? _lastExerciseRow(String name) {
    final exercises = _ctrl.report?.activeSheet.canonicalExercises;
    if (exercises == null) return null;
    for (final exercise in exercises.reversed) {
      if (exercise.exercise == name) return exercise.sheetRowNumber;
    }
    return null;
  }

  void _clearTransient() {
    _placeIntent = null;
    _editing = null;
  }

  void _saveSelection() {
    final report = _ctrl.report;
    final setup = _ctrl.workoutSetup;
    if (report == null || setup == null) return;
    unawaited(
      _workspace.persistWorkoutSelection(
        WorkoutSelectionSt(
          spreadsheetId: report.sheetId,
          workout: setup.selectedWorkout,
          historyBlock: setup.selectedHistoryBlock,
        ),
      ),
    );
  }
}
