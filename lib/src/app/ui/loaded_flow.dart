import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:workout_tracker/contract.dart';

import '../controller.dart';
import '../exercise_create_screen.dart';
import '../exercise_edit_screen.dart';
import '../exercise_library.dart';
import '../logging.dart';
import '../placement_screen.dart';
import '../workout_home.dart';
import '../state_store.dart';
import '../workspace.dart';
import '../validation_core.dart';
import 'view.dart';

sealed class _Page {
  const _Page();
}

final class _Home extends _Page {
  const _Home();
}

final class _Library extends _Page {
  const _Library();
}

final class _Create extends _Page {
  const _Create();
}

final class _Edit extends _Page {
  const _Edit(this.exercise);

  final CanonicalExercise exercise;
}

final class _Placement extends _Page {
  const _Placement(this.intent);

  final PlaceIntent intent;
}

final class _Log extends _Page {
  const _Log();
}

/// Owns typed page history and transient state after a workbook is loaded.
///
/// Screens see narrow action interfaces. Returning from a feature pops the
/// page that launched it, so no feature needs an origin flag.
final class LoadedFlow
    implements
        WorkoutHomeActions,
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

  final List<_Page> _pages = [const _Home()];
  int? _highlightedRow;
  ExerciseDef? _pendingEdit;

  List<AppPage> pages({
    required bool busy,
    required String sheetLabel,
    String? error,
  }) {
    return [
      for (final page in _pages)
        AppPage(
          id: page,
          view: _view(page, busy: busy, sheetLabel: sheetLabel, error: error),
        ),
    ];
  }

  AppView view({
    required bool busy,
    required String sheetLabel,
    String? error,
  }) => pages(busy: busy, sheetLabel: sheetLabel, error: error).last.view;

  AppView _view(
    _Page page, {
    required bool busy,
    required String sheetLabel,
    String? error,
  }) {
    final setup = _ctrl.workoutSetup!;
    return switch (page) {
      _Home() => WorkoutHomeView(
        isBusy: busy,
        error: _ctrl.error ?? error,
        setup: setup,
        sheetLabel: sheetLabel,
      ),
      _Library() => LibraryView(
        isBusy: busy,
        error: _ctrl.error ?? error,
        exercises: setup.activeSheet.canonicalExercises,
        sheetLabel: sheetLabel,
        highlightedRow: _highlightedRow,
      ),
      _Create() => CreateExerciseView(
        isBusy: busy,
        error: _ctrl.error ?? error,
        sheetLabel: sheetLabel,
      ),
      _Edit(:final exercise) => EditExerciseView(
        isBusy: busy,
        error: _ctrl.error ?? error,
        sheetLabel: sheetLabel,
        exercise: exercise,
        formatImpact: _ctrl.pendingFormatUpdate,
        pendingExercise: _pendingEdit,
      ),
      _Placement(:final intent) => PlacementView(
        isBusy: busy,
        error: _ctrl.error ?? error,
        exercises: setup.activeSheet.canonicalExercises,
        sheetLabel: sheetLabel,
        intent: intent,
      ),
      _Log() => LogView(
        isBusy: busy,
        error: _ctrl.error ?? error,
        activeSheet: setup.activeSheet,
        sheetLabel: sheetLabel,
        target: setup.loggingTarget!,
      ),
    };
  }

  void showHome() {
    dismissError();
    _ctrl.closeExercise();
    _pages
      ..clear()
      ..add(const _Home());
    _changed();
  }

  void reset() {
    dismissError();
    _ctrl.closeExercise();
    _pages
      ..clear()
      ..add(const _Home());
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

  bool owns(Object id) => _pages.contains(id);

  bool didPop(Object id) {
    if (!identical(_pages.last, id)) return false;
    if (_pages.length == 1) return false;
    _leave(_pages.removeLast());
    _changed();
    return true;
  }

  @override
  Future<void> home(WorkoutHomeAction action) async {
    switch (action) {
      case BackToSheets():
        _ctrl.closeExercise();
        _showSheet();
      case OpenExerciseLibrary():
        _ctrl.closeExercise();
        _highlightedRow = null;
        _push(const _Library());
      case ChooseWorkout(:final workout):
        _ctrl.selectWorkout(workout);
        _saveSelection();
      case ChooseHistory(:final block):
        _ctrl.selectHistoryBlock(block);
        _saveSelection();
      case CreateWorkout(:final name):
        if (_ctrl.createWorkout(name)) _saveSelection();
      case CreateHistory(:final label):
        if (await _ctrl.createHistoryBlock(label)) _saveSelection();
      case OpenWorkoutLog(:final primaryRow):
        _ctrl.openExercise(primaryRow);
        _push(const _Log());
      case AddWorkoutPrimary(:final workout):
        _openPrimary(workout);
      case AddWorkoutBackup(:final slot):
        _openBackup(slot);
      case DeleteWorkoutExercise(:final primaryRow):
        await _ctrl.deleteWorkoutExercise(primaryRow: primaryRow);
    }
    _changed();
  }

  @override
  void dismissError() {
    _ctrl.clearError();
    _workspace.clearError();
  }

  @override
  Future<bool> reorder(ReorderIntent intent) => _pages.last is _Library
      ? _ctrl.reorderExercises(intent)
      : _ctrl.reorderWorkoutExercises(intent);

  @override
  Future<void> close() async {
    if (_pages.length == 1) return;
    _leave(_pages.removeLast());
    _changed();
  }

  @override
  Future<void> create() async {
    _ctrl.closeExercise();
    _push(const _Create());
    _changed();
  }

  @override
  Future<void> edit(CanonicalExercise exercise) async {
    _ctrl.closeExercise();
    _highlightedRow = null;
    _pendingEdit = null;
    _push(_Edit(exercise));
    _changed();
  }

  @override
  Future<bool> save(ExerciseDef exercise) async {
    final page = _pages.last;
    if (page case _Edit(exercise: final selected)) {
      final ok = await _ctrl.updateExercise(
        selectedExercise: selected,
        exercise: exercise,
      );
      if (!ok) {
        if (_ctrl.pendingFormatUpdate != null) _pendingEdit = exercise;
        return false;
      }
      _pendingEdit = null;
      _highlightedRow = selected.sheetRowNumber;
      _pages.removeLast();
      _changed();
      return true;
    }

    final ok = await _ctrl.createExercise(exercise: exercise);
    if (!ok) return false;
    if (_previous is _Library) {
      _highlightedRow = _lastExerciseRow(exercise.exercise);
    }
    _pages.removeLast();
    _changed();
    return true;
  }

  @override
  Future<bool> confirmFormatUpdate(
    Map<int, Map<String, String>> valuesByRow,
  ) async {
    final ok = await _ctrl.confirmExerciseUpdate(valuesByRow);
    if (!ok) return false;
    final page = _pages.last;
    if (page case _Edit(exercise: final selected)) {
      _pendingEdit = null;
      _highlightedRow = selected.sheetRowNumber;
      _pages.removeLast();
      _changed();
    }
    return true;
  }

  @override
  void cancelFormatUpdate() {
    _pendingEdit = _ctrl.pendingFormatUpdate?.exercise;
    _ctrl.cancelExerciseUpdate();
    _changed();
  }

  @override
  Future<bool> place(
    CanonicalExercise exercise,
    WorkoutPlacementMetadata metadata, {
    bool keepAdding = false,
  }) async {
    final page = _pages.last;
    if (page is! _Placement) return false;
    final intent = page.intent;
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
    if (ok && !keepAdding) _pages.removeLast();
    _changed();
    return ok;
  }

  @override
  Future<bool> execute(WbkCmd cmd) => _ctrl.execute(cmd);

  @override
  Future<void> selectRow(int sheetRow) async {
    _ctrl.selectLoggingRow(sheetRow);
  }

  _Page? get _previous => _pages.length < 2 ? null : _pages[_pages.length - 2];

  void _push(_Page page) {
    dismissError();
    _pages.add(page);
  }

  void _leave(_Page page) {
    dismissError();
    if (page is _Log) _ctrl.closeExercise();
    if (page is _Edit && _ctrl.pendingFormatUpdate != null) {
      _ctrl.cancelExerciseUpdate();
    }
    if (page is _Edit) _pendingEdit = null;
  }

  void _openPrimary(String workout) {
    _ctrl.closeExercise();
    _highlightedRow = null;
    _push(_Placement(PlaceIntent.primary(workout: workout)));
  }

  void _openBackup(WorkoutOverviewSlot slot) {
    final workout = _ctrl.workoutSetup?.selectedWorkout;
    if (workout == null) return;
    _ctrl.closeExercise();
    _push(
      _Placement(
        PlaceIntent.backup(
          workout: workout,
          primaryRow: slot.sheetRowNumber,
          primaryExercise: slot.exercise,
        ),
      ),
    );
  }

  int? _lastExerciseRow(String name) {
    final exercises = _ctrl.report?.activeSheet.canonicalExercises;
    if (exercises == null) return null;
    for (final exercise in exercises.reversed) {
      if (exercise.exercise == name) return exercise.sheetRowNumber;
    }
    return null;
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
