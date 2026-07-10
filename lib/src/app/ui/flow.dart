import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:workout_tracker/contract.dart';

import '../controller.dart';
import '../selection.dart';
import '../state_store.dart';
import '../validation.dart';
import '../workspace.dart';

abstract interface class UiFlow implements Listenable {
  AppView get view;

  Future<void> restore();

  Future<CmdResult> run(UiCmd cmd);
}

enum AppRoute {
  sheet,
  setup,
  workout,
  library,
  createExercise,
  editExercise,
  placement,
  log,
}

sealed class AppView {
  const AppView({required this.isBusy, this.error});

  final bool isBusy;
  final String? error;
}

final class SheetView extends AppView {
  const SheetView({
    required super.isBusy,
    required this.sheetText,
    required this.selectedSheet,
    required this.availability,
    required this.showAvailability,
    required this.showTextFallback,
    required this.hasLoadedWorkout,
    required this.report,
    required this.account,
    required this.hasPicker,
    required this.showAccount,
    super.error,
  });

  final String sheetText;
  final SelectedSheet? selectedSheet;
  final PickerAvail availability;
  final bool showAvailability;
  final bool showTextFallback;
  final bool hasLoadedWorkout;
  final ValReport? report;
  final GoogleAccountProfile? account;
  final bool hasPicker;
  final bool showAccount;
}

sealed class LoadedView extends AppView {
  const LoadedView({
    required super.isBusy,
    required this.setup,
    required this.sheetLabel,
    super.error,
  });

  final WorkoutSetupReadModel setup;
  final String sheetLabel;
}

final class SetupView extends LoadedView {
  const SetupView({
    required super.isBusy,
    required super.setup,
    required super.sheetLabel,
    super.error,
  });
}

final class WorkoutView extends LoadedView {
  const WorkoutView({
    required super.isBusy,
    required super.setup,
    required super.sheetLabel,
    super.error,
  });
}

final class LibraryView extends LoadedView {
  const LibraryView({
    required super.isBusy,
    required super.setup,
    required super.sheetLabel,
    required this.highlightedRow,
    super.error,
  });

  final int? highlightedRow;
}

final class CreateExerciseView extends LoadedView {
  const CreateExerciseView({
    required super.isBusy,
    required super.setup,
    required super.sheetLabel,
    required this.returnRoute,
    super.error,
  });

  final AppRoute returnRoute;
}

final class EditExerciseView extends LoadedView {
  const EditExerciseView({
    required super.isBusy,
    required super.setup,
    required super.sheetLabel,
    required this.exercise,
    super.error,
  });

  final CanonicalExercise exercise;
}

enum PlaceKind { primary, backup }

class PlaceIntent {
  const PlaceIntent.primary({required this.workout})
    : kind = PlaceKind.primary,
      primaryRow = null,
      primaryExercise = null;

  const PlaceIntent.backup({
    required this.workout,
    required this.primaryRow,
    required this.primaryExercise,
  }) : kind = PlaceKind.backup;

  final PlaceKind kind;
  final String workout;
  final int? primaryRow;
  final String? primaryExercise;
}

final class PlacementView extends LoadedView {
  const PlacementView({
    required super.isBusy,
    required super.setup,
    required super.sheetLabel,
    required this.intent,
    required this.returnRoute,
    super.error,
  });

  final PlaceIntent intent;
  final AppRoute returnRoute;
}

final class LogView extends LoadedView {
  const LogView({
    required super.isBusy,
    required super.setup,
    required super.sheetLabel,
    required this.target,
    super.error,
  });

  final WorkoutLoggingTarget target;
}

class CmdResult {
  const CmdResult._(this.ok, this.message);

  const CmdResult.done() : this._(true, null);

  const CmdResult.failed([String? message]) : this._(false, message);

  final bool ok;
  final String? message;
}

sealed class UiCmd {
  const UiCmd();
}

sealed class SheetCmd extends UiCmd {
  const SheetCmd();
}

final class SetSheetText extends SheetCmd {
  const SetSheetText(this.text);

  final String text;
}

final class ValidateSheet extends SheetCmd {
  const ValidateSheet();
}

final class ChooseSheet extends SheetCmd {
  const ChooseSheet();
}

final class AuthorizeCreate extends SheetCmd {
  const AuthorizeCreate();
}

final class CreateSheet extends SheetCmd {
  const CreateSheet(this.name);

  final String name;
}

final class SignOut extends SheetCmd {
  const SignOut();
}

final class ReturnToSheet extends SheetCmd {
  const ReturnToSheet();
}

final class ReturnToWorkout extends SheetCmd {
  const ReturnToWorkout();
}

final class RepairAll extends SheetCmd {
  const RepairAll();
}

final class RepairOne extends SheetCmd {
  const RepairOne({required this.activeRow, required this.exerciseRow});

  final int activeRow;
  final int exerciseRow;
}

final class OpenSheet extends SheetCmd {
  const OpenSheet();
}

sealed class WorkoutCmd extends UiCmd {
  const WorkoutCmd();
}

final class OpenWorkout extends WorkoutCmd {
  const OpenWorkout();
}

final class BackToSetup extends WorkoutCmd {
  const BackToSetup();
}

final class OpenLibrary extends WorkoutCmd {
  const OpenLibrary();
}

final class SelectWorkout extends WorkoutCmd {
  const SelectWorkout(this.workout);

  final String? workout;
}

final class SelectHistory extends WorkoutCmd {
  const SelectHistory(this.block);

  final String? block;
}

final class AddWorkout extends WorkoutCmd {
  const AddWorkout(this.name);

  final String name;
}

final class AddHistory extends WorkoutCmd {
  const AddHistory(this.label);

  final String label;
}

final class OpenLog extends WorkoutCmd {
  const OpenLog(this.primaryRow);

  final int primaryRow;
}

sealed class LogCmd extends UiCmd {
  const LogCmd();
}

final class CloseLog extends LogCmd {
  const CloseLog();
}

final class AddPrimary extends WorkoutCmd {
  const AddPrimary(this.workout);

  final String workout;
}

final class AddBackup extends WorkoutCmd {
  const AddBackup(this.slot);

  final WorkoutOverviewSlot slot;
}

final class DeleteWorkoutExercise extends WorkoutCmd {
  const DeleteWorkoutExercise(this.primaryRow);

  final int primaryRow;
}

final class ReorderWorkout extends WorkoutCmd {
  const ReorderWorkout(this.intent);

  final ReorderIntent intent;
}

final class SelectLogRow extends LogCmd {
  const SelectLogRow(this.sheetRow);

  final int sheetRow;
}

final class ExecuteWbk extends LogCmd {
  const ExecuteWbk(this.cmd);

  final WbkCmd cmd;
}

sealed class ExerciseCmd extends UiCmd {
  const ExerciseCmd();
}

final class OpenExerciseCreate extends ExerciseCmd {
  const OpenExerciseCreate();
}

final class CloseExerciseCreate extends ExerciseCmd {
  const CloseExerciseCreate();
}

final class OpenExerciseEdit extends ExerciseCmd {
  const OpenExerciseEdit(this.exercise);

  final CanonicalExercise exercise;
}

final class CloseExerciseEdit extends ExerciseCmd {
  const CloseExerciseEdit();
}

final class SaveExercise extends ExerciseCmd {
  const SaveExercise({required this.exercise, required this.name});

  final ExerciseDef exercise;
  final String name;
}

final class SaveExerciseEdit extends ExerciseCmd {
  const SaveExerciseEdit(this.exercise);

  final ExerciseDef exercise;
}

final class SavePlacement extends ExerciseCmd {
  const SavePlacement({
    required this.exercise,
    required this.metadata,
    this.keepAdding = false,
  });

  final CanonicalExercise exercise;
  final WorkoutPlacementMetadata metadata;
  final bool keepAdding;
}

final class ReorderExercises extends ExerciseCmd {
  const ReorderExercises(this.intent);

  final ReorderIntent intent;
}

class AppFlow extends ChangeNotifier implements UiFlow {
  AppFlow({
    required WbkAccess svc,
    GoogleAccountSession? accountSession,
    AppStStore? appStStore,
    SheetPicker? picker,
    this._sheetOpener = const UrlSheetOpener(),
    String initialText = '',
    SelectedSheet? initialSelection,
  }) : _ctrl = AppCtrl(svc: svc),
       _workspace = WorkspaceCtrl(
         accessStOwner: appStStore == null ? null : WorkspaceStCtrl(appStStore),
         accountSession: accountSession,
         picker: picker,
         initialText: initialText,
         initialSelection: initialSelection,
       ),
       _accountSession = accountSession,
       _picker = picker,
       _sheetText = initialSelection?.id ?? initialText {
    _ctrl.addListener(_forward);
    _workspace.addListener(_forward);
  }

  final AppCtrl _ctrl;
  final WorkspaceCtrl _workspace;
  final GoogleAccountSession? _accountSession;
  final SheetPicker? _picker;
  final SheetOpener _sheetOpener;
  AppRoute _route = AppRoute.sheet;
  AppRoute _returnRoute = AppRoute.workout;
  PlaceIntent? _placeIntent;
  CanonicalExercise? _editingExercise;
  int? _highlightedRow;
  String _sheetText;

  GoogleAccountSession? get accountSession => _accountSession;

  @override
  AppView get view {
    final report = _ctrl.report;
    final busy = _ctrl.isBusy || _workspace.state.isCommandInFlight;
    if (_route == AppRoute.sheet ||
        report == null ||
        report.hasBlockingIssues) {
      final workspace = _workspace.state;
      return SheetView(
        isBusy: busy,
        error: _ctrl.error,
        sheetText: _sheetText,
        selectedSheet: workspace.selectedSheet,
        availability: workspace.pickerAvailability,
        showAvailability: workspace.selectedSheet == null && _picker != null,
        showTextFallback: _picker == null || workspace.fallbackAvailable,
        hasLoadedWorkout: report != null && !report.hasBlockingIssues,
        report: report,
        account: _accountSession?.currentAccount,
        hasPicker: _picker != null,
        showAccount: _accountSession != null,
      );
    }
    final setup = _ctrl.workoutSetup!;
    final label =
        _workspace.state.selectedSheet?.displayLabel ?? report.sheetId;
    return switch (_route) {
      AppRoute.setup => SetupView(
        isBusy: busy,
        error: _ctrl.error,
        setup: setup,
        sheetLabel: label,
      ),
      AppRoute.workout => WorkoutView(
        isBusy: busy,
        error: _ctrl.error,
        setup: setup,
        sheetLabel: label,
      ),
      AppRoute.library => LibraryView(
        isBusy: busy,
        error: _ctrl.error,
        setup: setup,
        sheetLabel: label,
        highlightedRow: _highlightedRow,
      ),
      AppRoute.createExercise => CreateExerciseView(
        isBusy: busy,
        error: _ctrl.error,
        setup: setup,
        sheetLabel: label,
        returnRoute: _returnRoute,
      ),
      AppRoute.editExercise => EditExerciseView(
        isBusy: busy,
        error: _ctrl.error,
        setup: setup,
        sheetLabel: label,
        exercise: _editingExercise!,
      ),
      AppRoute.placement => PlacementView(
        isBusy: busy,
        error: _ctrl.error,
        setup: setup,
        sheetLabel: label,
        intent: _placeIntent!,
        returnRoute: _returnRoute,
      ),
      AppRoute.log => LogView(
        isBusy: busy,
        error: _ctrl.error,
        setup: setup,
        sheetLabel: label,
        target: setup.loggingTarget!,
      ),
      AppRoute.sheet => throw StateError('Sheet route handled above.'),
    };
  }

  @override
  Future<void> restore() async {
    final workspace = await _workspace.restoreResolved();
    final selected = workspace.selectedSheet;
    if (selected != null) {
      _sheetText = selected.id;
      await _validate();
      _restoreWorkout(
        _workspace.workoutSelectionFor(_ctrl.report?.sheetId ?? selected.id),
      );
    } else if (workspace.pastedText case final text?) {
      _sheetText = text;
    }
    notifyListeners();
  }

  @override
  Future<CmdResult> run(UiCmd cmd) async {
    final result = switch (cmd) {
      SetSheetText(:final text) => await _setSheetText(text),
      ValidateSheet() => await _validate(),
      ChooseSheet() => await _chooseSheet(),
      AuthorizeCreate() => await _authorizeCreate(),
      CreateSheet(:final name) => await _createSheet(name),
      SignOut() => await _signOut(),
      ReturnToSheet() => _goSheet(),
      ReturnToWorkout() => _returnToWorkout(),
      RepairAll() => await _repairAll(),
      RepairOne(:final activeRow, :final exerciseRow) => await _repairOne(
        activeRow,
        exerciseRow,
      ),
      OpenSheet() => await _openSheet(),
      OpenWorkout() => _openWorkout(),
      BackToSetup() => _backToSetup(),
      OpenLibrary() => _openLibrary(),
      SelectWorkout(:final workout) => _selectWorkout(workout),
      SelectHistory(:final block) => _selectHistory(block),
      AddWorkout(:final name) => _addWorkout(name),
      AddHistory(:final label) => await _addHistory(label),
      OpenLog(:final primaryRow) => _openLog(primaryRow),
      CloseLog() => _closeLog(),
      AddPrimary(:final workout) => _addPrimary(workout),
      AddBackup(:final slot) => _addBackup(slot),
      DeleteWorkoutExercise(:final primaryRow) => await _deleteWorkout(
        primaryRow,
      ),
      ReorderWorkout(:final intent) => CmdResult._(
        await _ctrl.reorderWorkoutExercises(intent),
        null,
      ),
      SelectLogRow(:final sheetRow) => _selectLogRow(sheetRow),
      ExecuteWbk(:final cmd) => CmdResult._(await _ctrl.execute(cmd), null),
      OpenExerciseCreate() => _openExerciseCreate(),
      CloseExerciseCreate() => _closeExerciseCreate(),
      OpenExerciseEdit(:final exercise) => _openExerciseEdit(exercise),
      CloseExerciseEdit() => _closeExerciseEdit(),
      SaveExercise(:final exercise, :final name) => await _saveExercise(
        exercise,
        name,
      ),
      SaveExerciseEdit(:final exercise) => await _saveExerciseEdit(exercise),
      SavePlacement(:final exercise, :final metadata, :final keepAdding) =>
        await _savePlacement(exercise, metadata, keepAdding),
      ReorderExercises(:final intent) => CmdResult._(
        await _ctrl.reorderExercises(intent),
        null,
      ),
    };
    notifyListeners();
    return result;
  }

  Future<CmdResult> _setSheetText(String text) async {
    _sheetText = text;
    await _workspace.persistPastedText(text);
    return const CmdResult.done();
  }

  Future<CmdResult> _validate() async {
    final selected = _workspace.state.selectedSheet;
    final ok = selected == null
        ? await _ctrl.validateSelection(_sheetText)
        : await _ctrl.validateSelected(selected);
    final report = _ctrl.report;
    _route = ok && report != null && !report.hasBlockingIssues
        ? AppRoute.setup
        : AppRoute.sheet;
    return CmdResult._(ok, null);
  }

  Future<CmdResult> _chooseSheet() async {
    try {
      final workspace = await _workspace.chooseSheet();
      final selected = workspace.selectedSheet;
      if (selected == null) {
        return const CmdResult.failed();
      }
      _sheetText = selected.id;
      return _validate();
    } on Object catch (error) {
      _ctrl.reportSelectionFailure(error);
      return CmdResult.failed(error.toString());
    }
  }

  Future<CmdResult> _authorizeCreate() async {
    try {
      final ok = await _workspace.authorizeSheetCreation();
      return CmdResult._(ok, null);
    } on Object catch (error) {
      return CmdResult.failed('Unable to connect Google Sheets: $error');
    }
  }

  Future<CmdResult> _createSheet(String name) async {
    try {
      final workspace = await _workspace.createSheet(name: name);
      final selected = workspace.selectedSheet;
      if (selected == null) {
        return const CmdResult.failed();
      }
      _sheetText = selected.id;
      return _validate();
    } on Object catch (error) {
      _ctrl.reportSelectionFailure(error);
      return CmdResult.failed(error.toString());
    }
  }

  Future<CmdResult> _signOut() async {
    await _workspace.signOut();
    _ctrl.clearSelection();
    _sheetText = '';
    _route = AppRoute.sheet;
    _returnRoute = AppRoute.workout;
    _placeIntent = null;
    _editingExercise = null;
    return const CmdResult.done();
  }

  CmdResult _goSheet() {
    _ctrl.closeExercise();
    _placeIntent = null;
    _editingExercise = null;
    _route = AppRoute.sheet;
    return const CmdResult.done();
  }

  CmdResult _returnToWorkout() {
    final report = _ctrl.report;
    if (report == null || report.hasBlockingIssues) {
      return const CmdResult.failed();
    }
    _placeIntent = null;
    _editingExercise = null;
    _ctrl.closeExercise();
    _route = AppRoute.setup;
    return const CmdResult.done();
  }

  Future<CmdResult> _repairAll() async {
    final ok = await _ctrl.repairFormulas();
    if (ok) {
      _route = _ctrl.report?.hasBlockingIssues == false
          ? AppRoute.setup
          : AppRoute.sheet;
    }
    return CmdResult._(ok, null);
  }

  Future<CmdResult> _repairOne(int activeRow, int exerciseRow) async {
    final ok = await _ctrl.repairFormulaIssue(
      activeSheetRowNumber: activeRow,
      selectedRow: exerciseRow,
    );
    if (ok) {
      _route = _ctrl.report?.hasBlockingIssues == false
          ? AppRoute.setup
          : AppRoute.sheet;
    }
    return CmdResult._(ok, null);
  }

  Future<CmdResult> _openSheet() async {
    final report = _ctrl.report;
    if (report == null) {
      return const CmdResult.failed();
    }
    try {
      await _sheetOpener.openSheet(report.sheetUrl);
      return const CmdResult.done();
    } on Object catch (error) {
      _ctrl.reportOpenFailure(error);
      return CmdResult.failed(error.toString());
    }
  }

  CmdResult _openWorkout() {
    _placeIntent = null;
    _editingExercise = null;
    _route = AppRoute.workout;
    return const CmdResult.done();
  }

  CmdResult _backToSetup() {
    _ctrl.closeExercise();
    _placeIntent = null;
    _editingExercise = null;
    _route = AppRoute.setup;
    return const CmdResult.done();
  }

  CmdResult _openLibrary() {
    _ctrl.closeExercise();
    _placeIntent = null;
    _editingExercise = null;
    _highlightedRow = null;
    _route = AppRoute.library;
    return const CmdResult.done();
  }

  CmdResult _selectWorkout(String? workout) {
    _ctrl.selectWorkout(workout);
    _saveWorkoutSelection();
    _route = AppRoute.setup;
    return const CmdResult.done();
  }

  CmdResult _selectHistory(String? block) {
    _ctrl.selectHistoryBlock(block);
    _saveWorkoutSelection();
    _route = AppRoute.setup;
    return const CmdResult.done();
  }

  CmdResult _addWorkout(String name) {
    final ok = _ctrl.createWorkout(name);
    if (ok) {
      _saveWorkoutSelection();
    }
    return CmdResult._(ok, null);
  }

  Future<CmdResult> _addHistory(String label) async {
    final ok = await _ctrl.createHistoryBlock(label);
    if (ok) {
      _saveWorkoutSelection();
    }
    return CmdResult._(ok, null);
  }

  CmdResult _openLog(int primaryRow) {
    _ctrl.openExercise(primaryRow);
    _route = AppRoute.log;
    return const CmdResult.done();
  }

  CmdResult _closeLog() {
    _ctrl.closeExercise();
    _route = AppRoute.workout;
    return const CmdResult.done();
  }

  CmdResult _addPrimary(String workout) {
    _ctrl.closeExercise();
    _editingExercise = null;
    _highlightedRow = null;
    _returnRoute = AppRoute.setup;
    _placeIntent = PlaceIntent.primary(workout: workout);
    _route = AppRoute.placement;
    return const CmdResult.done();
  }

  CmdResult _addBackup(WorkoutOverviewSlot slot) {
    final workout = _ctrl.workoutSetup?.selectedWorkout;
    if (workout == null) {
      return const CmdResult.failed();
    }
    _returnRoute = _route == AppRoute.setup ? AppRoute.setup : AppRoute.workout;
    _ctrl.closeExercise();
    _editingExercise = null;
    _placeIntent = PlaceIntent.backup(
      workout: workout,
      primaryRow: slot.sheetRowNumber,
      primaryExercise: slot.exercise,
    );
    _route = AppRoute.placement;
    return const CmdResult.done();
  }

  Future<CmdResult> _deleteWorkout(int primaryRow) async {
    return CmdResult._(
      await _ctrl.deleteWorkoutExercise(primaryRow: primaryRow),
      null,
    );
  }

  CmdResult _selectLogRow(int sheetRow) {
    _ctrl.selectLoggingRow(sheetRow);
    return const CmdResult.done();
  }

  CmdResult _openExerciseCreate() {
    _ctrl.closeExercise();
    _editingExercise = null;
    _returnRoute = _route == AppRoute.library
        ? AppRoute.library
        : AppRoute.setup;
    _placeIntent = null;
    _route = AppRoute.createExercise;
    return const CmdResult.done();
  }

  CmdResult _closeExerciseCreate() {
    _placeIntent = null;
    _editingExercise = null;
    _route = _returnRoute;
    return const CmdResult.done();
  }

  CmdResult _openExerciseEdit(CanonicalExercise exercise) {
    _ctrl.closeExercise();
    _placeIntent = null;
    _highlightedRow = null;
    _editingExercise = exercise;
    _route = AppRoute.editExercise;
    return const CmdResult.done();
  }

  CmdResult _closeExerciseEdit() {
    _editingExercise = null;
    _route = AppRoute.library;
    return const CmdResult.done();
  }

  Future<CmdResult> _saveExercise(ExerciseDef exercise, String name) async {
    final ok = await _ctrl.createExercise(exercise: exercise);
    if (!ok) {
      return const CmdResult.failed();
    }
    _highlightedRow = _returnRoute == AppRoute.library
        ? _lastExerciseRow(name)
        : null;
    _route = _returnRoute;
    return const CmdResult.done();
  }

  Future<CmdResult> _saveExerciseEdit(ExerciseDef exercise) async {
    final selected = _editingExercise;
    if (selected == null) {
      return const CmdResult.failed();
    }
    final ok = await _ctrl.updateExercise(
      selectedExercise: selected,
      exercise: exercise,
    );
    if (!ok) {
      return const CmdResult.failed();
    }
    _editingExercise = null;
    _highlightedRow = selected.sheetRowNumber;
    _route = AppRoute.library;
    return const CmdResult.done();
  }

  int? _lastExerciseRow(String name) {
    final exercises = _ctrl.report?.activeSheet.canonicalExercises;
    if (exercises == null) {
      return null;
    }
    for (final exercise in exercises.reversed) {
      if (exercise.exercise == name) {
        return exercise.sheetRowNumber;
      }
    }
    return null;
  }

  Future<CmdResult> _savePlacement(
    CanonicalExercise exercise,
    WorkoutPlacementMetadata metadata,
    bool keepAdding,
  ) async {
    final intent = _placeIntent;
    if (intent == null) {
      return const CmdResult.failed();
    }
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
      _route = _returnRoute;
    }
    return CmdResult._(ok, null);
  }

  void _restoreWorkout(WorkoutSelectionSt? saved) {
    final report = _ctrl.report;
    if (saved == null || report == null || saved.sheetId != report.sheetId) {
      return;
    }
    _ctrl.restoreWorkoutSelection(
      workout: saved.workout,
      historyBlock: saved.historyBlock,
    );
  }

  void _saveWorkoutSelection() {
    final report = _ctrl.report;
    final setup = _ctrl.workoutSetup;
    if (report == null || setup == null) {
      return;
    }
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

  void _forward() => notifyListeners();

  @override
  void dispose() {
    _ctrl.removeListener(_forward);
    _workspace.removeListener(_forward);
    _ctrl.dispose();
    _workspace.dispose();
    super.dispose();
  }
}
