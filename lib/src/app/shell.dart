import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:workout_tracker/contract.dart';

import 'state_store.dart';
import 'workspace.dart';
import 'validation.dart';
import 'selection.dart';
import 'controller.dart';
import 'logging.dart';
import 'repair.dart';
import 'ui/flow.dart';
import 'ui/sheet.dart';
import 'ui/shared/name_dialog.dart';

part 'workout.dart';
part 'exercise_form.dart';
part 'exercise_library.dart';
part 'states.dart';
part 'a11y.dart';

enum _AppScreen {
  sheetSelection,
  workoutSetup,
  exerciseManager,
  exercisePicker,
  addExercise,
  editExercise,
  exerciseLogging,
}

enum _PlaceKind { primary, backup }

class _PlaceIntent {
  const _PlaceIntent.primary({required this.workout})
    : kind = _PlaceKind.primary,
      primaryRow = null,
      primaryExercise = null;

  const _PlaceIntent.backup({
    required this.workout,
    required this.primaryRow,
    required this.primaryExercise,
  }) : kind = _PlaceKind.backup;

  final _PlaceKind kind;
  final String workout;
  final int? primaryRow;
  final String? primaryExercise;
}

class WorkoutTrackerApp extends StatelessWidget {
  const WorkoutTrackerApp({
    required this.svc,
    this.navigatorKey,
    this.accountSession,
    this.appStStore,
    this.initialText = '',
    this.initialSelection,
    this.picker,
    this.sheetOpener = const UrlSheetOpener(),
    super.key,
  });

  final WbkAccess svc;
  final GlobalKey<NavigatorState>? navigatorKey;
  final GoogleAccountSession? accountSession;
  final AppStStore? appStStore;
  final String initialText;
  final SelectedSheet? initialSelection;
  final SheetPicker? picker;
  final SheetOpener sheetOpener;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WorkoutTracker',
      navigatorKey: navigatorKey,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0E7C66)),
        splashFactory: InkRipple.splashFactory,
        useMaterial3: true,
      ),
      scrollBehavior: const AppScrollBehavior(),
      home: AppShell(
        svc: svc,
        accountSession: accountSession,
        appStStore: appStStore,
        initialText: initialText,
        initialSelection: initialSelection,
        picker: picker,
        sheetOpener: sheetOpener,
      ),
    );
  }
}

class AppScrollBehavior extends MaterialScrollBehavior {
  const AppScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices {
    return {
      PointerDeviceKind.touch,
      PointerDeviceKind.mouse,
      PointerDeviceKind.stylus,
      PointerDeviceKind.invertedStylus,
      PointerDeviceKind.trackpad,
    };
  }
}

class AppShell extends StatefulWidget {
  const AppShell({
    required this.svc,
    this.accountSession,
    this.appStStore,
    required this.initialText,
    this.initialSelection,
    this.picker,
    required this.sheetOpener,
    super.key,
  });

  final WbkAccess svc;
  final GoogleAccountSession? accountSession;
  final AppStStore? appStStore;
  final String initialText;
  final SelectedSheet? initialSelection;
  final SheetPicker? picker;
  final SheetOpener sheetOpener;

  @override
  State<AppShell> createState() {
    return _AppShellSt();
  }
}

class _AppShellSt extends State<AppShell> {
  late final TextEditingController _sheetCtrl;
  late final AppCtrl _controller;
  _AppScreen _screen = _AppScreen.sheetSelection;
  _AppScreen _addReturnScreen = _AppScreen.exercisePicker;
  _PlaceIntent? placementIntent;
  CanonicalExercise? _editingExercise;
  int? _highlightedExerciseRow;
  WorkspaceStOwner? _stateCtrl;
  late final WorkspaceCtrl _workspaceLifecycle;

  @override
  void initState() {
    super.initState();
    _controller = AppCtrl(svc: widget.svc);
    _sheetCtrl = TextEditingController(
      text: widget.initialSelection?.id ?? widget.initialText,
    );
    final appStStore = widget.appStStore;
    if (appStStore != null) {
      _stateCtrl = WorkspaceStCtrl(appStStore);
    }
    _workspaceLifecycle = WorkspaceCtrl(
      accessStOwner: _stateCtrl,
      accountSession: widget.accountSession,
      picker: widget.picker,
      initialText: widget.initialText,
      initialSelection: widget.initialSelection,
    );
    unawaited(_restoreStartupSt());
  }

  @override
  void dispose() {
    _controller.dispose();
    _workspaceLifecycle.dispose();
    _sheetCtrl.dispose();
    super.dispose();
  }

  Future<void> _restoreStartupSt() async {
    WorkspaceUiSt workspaceSt;
    try {
      workspaceSt = await _workspaceLifecycle.restoreResolved();
    } on Object {
      return;
    }
    await _restoreSelection(workspaceSt);
  }

  Future<void> _restoreSelection(WorkspaceUiSt workspaceSt) async {
    if (!mounted) {
      return;
    }
    var savedSelection = workspaceSt.selectedSheet;
    if (savedSelection != null) {
      setState(() {
        _sheetCtrl.text = savedSelection.id;
      });
      await _validateSelected();
      _restoreWorkout(
        _workspaceLifecycle.workoutSelectionFor(
          _controller.report?.sheetId ?? savedSelection.id,
        ),
      );
      return;
    }
    final savedText = workspaceSt.pastedText;
    if (savedText != null && savedText != _sheetCtrl.text) {
      _sheetCtrl.text = savedText;
    }
  }

  void _usePastedText() {
    unawaited(() async {
      try {
        await _workspaceLifecycle.usePastedSheetText(_sheetCtrl.text);
      } on Object {
        // Text fallback persistence is best-effort.
      }
    }());
  }

  Future<void> _validateSelected() async {
    final selectedSheet = _workspaceLifecycle.state.selectedSheet;
    final selected = selectedSheet == null
        ? await _controller.validateSelection(_sheetCtrl.text)
        : await _controller.validateSelected(selectedSheet);
    final report = _controller.report;
    if (!mounted) {
      return;
    }
    setState(() {
      _screen = selected && report != null && !report.hasBlockingIssues
          ? _AppScreen.workoutSetup
          : _AppScreen.sheetSelection;
    });
  }

  Future<void> _chooseSheet() async {
    try {
      final workspaceSt = await _workspaceLifecycle.chooseSheet();
      await _validateSelection(workspaceSt);
    } on Object catch (error) {
      _controller.reportSelectionFailure(error);
    }
  }

  Future<void> _createSheet(String name) async {
    try {
      final workspaceSt = await _workspaceLifecycle.createSheet(name: name);
      await _validateSelection(workspaceSt);
    } on Object catch (error) {
      _controller.reportSelectionFailure(error);
    }
  }

  Future<bool> _authorizeSheetCreation() async {
    try {
      return await _workspaceLifecycle.authorizeSheetCreation();
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to connect Google Sheets: $error')),
        );
      }
      return false;
    }
  }

  Future<void> _validateSelection(WorkspaceUiSt workspaceSt) async {
    final selectedSheet = workspaceSt.selectedSheet;
    if (!mounted || selectedSheet == null) {
      return;
    }
    setState(() {
      _sheetCtrl.text = selectedSheet.id;
    });
    await _validateSelected();
  }

  Future<void> _handleSignedOut() async {
    await _workspaceLifecycle.signOut();
    _controller.clearSelection();
    setState(() {
      _sheetCtrl.clear();
      _screen = _AppScreen.sheetSelection;
      _addReturnScreen = _AppScreen.exercisePicker;
      placementIntent = null;
      _editingExercise = null;
    });
  }

  Future<String?> _promptForName({
    required String title,
    required String label,
    String? initialValue,
    String submitLabel = 'Add',
    Key? textFieldKey,
  }) async {
    final value = await showDialog<String>(
      context: context,
      builder: (context) {
        return NameDialog(
          title: title,
          label: label,
          initialValue: initialValue,
          submitLabel: submitLabel,
          textFieldKey: textFieldKey,
        );
      },
    );
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  Future<void> _promptForNewWorkout() async {
    final name = await _promptForName(
      title: 'Add workout',
      label: 'Workout name',
    );
    if (!mounted || name == null) {
      return;
    }
    final created = _controller.createWorkout(name);
    if (created) {
      _saveWorkoutSelection();
    }
  }

  Future<void> _promptNewBlock() async {
    final name = await _promptForName(
      title: 'Add history block',
      label: 'History block label',
    );
    if (!mounted || name == null) {
      return;
    }
    final created = await _controller.createHistoryBlock(name);
    if (created && mounted) {
      _saveWorkoutSelection();
    }
  }

  Future<void> _repairFormulas() async {
    final repaired = await _controller.repairFormulas();
    final report = _controller.report;
    if (!mounted || !repaired) {
      return;
    }
    setState(() {
      _screen = report != null && !report.hasBlockingIssues
          ? _AppScreen.workoutSetup
          : _AppScreen.sheetSelection;
    });
  }

  Future<void> _repairFormulaIssue({
    required int activeSheetRowNumber,
    required int selectedRow,
  }) async {
    final repaired = await _controller.repairFormulaIssue(
      activeSheetRowNumber: activeSheetRowNumber,
      selectedRow: selectedRow,
    );
    final report = _controller.report;
    if (!mounted || !repaired) {
      return;
    }
    setState(() {
      _screen = report != null && !report.hasBlockingIssues
          ? _AppScreen.workoutSetup
          : _AppScreen.sheetSelection;
    });
  }

  Future<void> _openSheet() async {
    final report = _controller.report;
    if (report == null) {
      return;
    }
    try {
      await widget.sheetOpener.openSheet(report.sheetUrl);
    } on Object catch (error) {
      _controller.reportOpenFailure(error);
    }
  }

  void _returnToSheetSelection() {
    _controller.closeExercise();
    placementIntent = null;
    _editingExercise = null;
    setState(() {
      _screen = _AppScreen.sheetSelection;
    });
  }

  void _selectWorkoutSetup() {
    placementIntent = null;
    _editingExercise = null;
    setState(() {
      _screen = _AppScreen.exercisePicker;
    });
  }

  void _returnToLoadedWorkout() {
    final report = _controller.report;
    if (report == null || report.hasBlockingIssues) {
      return;
    }
    placementIntent = null;
    _editingExercise = null;
    _controller.closeExercise();
    setState(() {
      _screen = _AppScreen.workoutSetup;
    });
  }

  void _returnToWorkoutSetup() {
    _controller.closeExercise();
    placementIntent = null;
    _editingExercise = null;
    setState(() {
      _screen = _AppScreen.workoutSetup;
    });
  }

  void _openExerciseManager() {
    _controller.closeExercise();
    placementIntent = null;
    _editingExercise = null;
    _highlightedExerciseRow = null;
    setState(() {
      _screen = _AppScreen.exerciseManager;
    });
  }

  void _openExercise(int primaryRow) {
    _controller.openExercise(primaryRow);
    setState(() {
      _screen = _AppScreen.exerciseLogging;
    });
  }

  void _closeExercise() {
    _controller.closeExercise();
    setState(() {
      _screen = _AppScreen.exercisePicker;
    });
  }

  void _openPrimaryAdd(String workout) {
    _controller.closeExercise();
    _editingExercise = null;
    _highlightedExerciseRow = null;
    setState(() {
      _addReturnScreen = _AppScreen.workoutSetup;
      placementIntent = _PlaceIntent.primary(workout: workout);
      _screen = _AppScreen.addExercise;
    });
  }

  void _openBackupAdd(WorkoutOverviewSlot primarySlot) {
    final workout = _controller.workoutSetup?.selectedWorkout;
    if (workout == null) {
      return;
    }
    final returnScreen = _screen == _AppScreen.workoutSetup
        ? _AppScreen.workoutSetup
        : _AppScreen.exercisePicker;
    _controller.closeExercise();
    _editingExercise = null;
    setState(() {
      _addReturnScreen = returnScreen;
      placementIntent = _PlaceIntent.backup(
        workout: workout,
        primaryRow: primarySlot.sheetRowNumber,
        primaryExercise: primarySlot.exercise,
      );
      _screen = _AppScreen.addExercise;
    });
  }

  Future<void> _confirmDeleteExercise(WorkoutOverviewSlot primarySlot) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete ${primarySlot.exercise}?'),
        content: Text(
          'This removes ${primarySlot.exercise} from the workout, including '
          'associated backups and logged history for those rows.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).pop(true),
            icon: const Icon(Icons.delete_outline),
            label: const Text('Delete exercise'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    await _controller.deleteWorkoutExercise(
      primaryRow: primarySlot.sheetRowNumber,
    );
  }

  void _openExerciseCreate() {
    _controller.closeExercise();
    _editingExercise = null;
    setState(() {
      _addReturnScreen = _screen == _AppScreen.exerciseManager
          ? _AppScreen.exerciseManager
          : _AppScreen.workoutSetup;
      placementIntent = null;
      _screen = _AppScreen.addExercise;
    });
  }

  void _closeExerciseAdd() {
    setState(() {
      placementIntent = null;
      _editingExercise = null;
      _screen = _addReturnScreen;
    });
  }

  void _openExerciseEdit(CanonicalExercise exercise) {
    _controller.closeExercise();
    placementIntent = null;
    _highlightedExerciseRow = null;
    setState(() {
      _editingExercise = exercise;
      _screen = _AppScreen.editExercise;
    });
  }

  void _closeExerciseEdit() {
    setState(() {
      _editingExercise = null;
      _screen = _AppScreen.exerciseManager;
    });
  }

  Future<void> _saveExerciseDraft(CanonicalExerciseDraft draft) async {
    final created = await _controller.createExercise(exercise: draft.toDef());
    if (!mounted || !created) {
      return;
    }
    final createdExerciseName = draft.normalized().exerciseName;
    setState(() {
      _highlightedExerciseRow = _addReturnScreen == _AppScreen.exerciseManager
          ? _lastExerciseRowByName(createdExerciseName)
          : null;
      _screen = _addReturnScreen;
    });
  }

  Future<void> _saveExerciseEdit(CanonicalExerciseDraft draft) async {
    final selectedExercise = _editingExercise;
    if (selectedExercise == null) {
      return;
    }
    final updated = await _controller.updateExercise(
      selectedExercise: selectedExercise,
      exercise: draft.toDef(),
    );
    if (!mounted || !updated) {
      return;
    }
    setState(() {
      _editingExercise = null;
      _highlightedExerciseRow = selectedExercise.sheetRowNumber;
      _screen = _AppScreen.exerciseManager;
    });
  }

  int? _lastExerciseRowByName(String exerciseName) {
    final exercises = _controller.report?.activeSheet.canonicalExercises;
    if (exercises == null) {
      return null;
    }
    for (final exercise in exercises.reversed) {
      if (exercise.exercise == exerciseName) {
        return exercise.sheetRowNumber;
      }
    }
    return null;
  }

  Future<void> _placeExercise(_ExercisePlacementDraft draft) async {
    final added = await _addExercisePlacement(draft);
    if (!mounted || !added) {
      return;
    }
    placementIntent = null;
    setState(() {
      _screen = _addReturnScreen;
    });
  }

  Future<bool> _placeAndKeepAdding(_ExercisePlacementDraft draft) async {
    final added = await _addExercisePlacement(draft);
    if (!mounted || !added) {
      return false;
    }
    setState(() {});
    return true;
  }

  Future<bool> _addExercisePlacement(_ExercisePlacementDraft draft) async {
    final intent = placementIntent;
    if (intent == null) {
      return false;
    }
    return _controller.addExerciseToWorkout(
      exercise: draft.exercise,
      metadata: draft.metadata,
      placement: switch (intent.kind) {
        _PlaceKind.primary => ExercisePlacementTarget.primary(
          workout: intent.workout,
        ),
        _PlaceKind.backup => ExercisePlacementTarget.backup(
          primaryRow: intent.primaryRow!,
        ),
      },
    );
  }

  void _selectWorkout(String? workout) {
    _controller.selectWorkout(workout);
    _saveWorkoutSelection();
    setState(() {
      _screen = _AppScreen.workoutSetup;
    });
  }

  void _selectHistoryBlock(String? historyBlock) {
    _controller.selectHistoryBlock(historyBlock);
    _saveWorkoutSelection();
    setState(() {
      _screen = _AppScreen.workoutSetup;
    });
  }

  void _restoreWorkout(WorkoutSelectionSt? savedSelection) {
    final report = _controller.report;
    if (savedSelection == null ||
        report == null ||
        savedSelection.sheetId != report.sheetId) {
      return;
    }
    _controller.restoreWorkoutSelection(
      workout: savedSelection.workout,
      historyBlock: savedSelection.historyBlock,
    );
  }

  void _saveWorkoutSelection() {
    final report = _controller.report;
    final setup = _controller.workoutSetup;
    if (report == null || setup == null) {
      return;
    }
    final selection = WorkoutSelectionSt(
      spreadsheetId: report.sheetId,
      workout: setup.selectedWorkout,
      historyBlock: setup.selectedHistoryBlock,
    );
    unawaited(() async {
      try {
        await _workspaceLifecycle.persistWorkoutSelection(selection);
      } on Object {
        // Workout-selection persistence is best-effort.
      }
    }());
  }

  Future<CmdResult> _runSheet(SheetCmd cmd) async {
    return switch (cmd) {
      SetSheetText(:final text) => _setSheetText(text),
      ValidateSheet() => await _runSheetAction(_validateSelected),
      ChooseSheet() => await _runSheetAction(_chooseSheet),
      AuthorizeCreate() =>
        await _authorizeSheetCreation()
            ? const CmdResult.done()
            : const CmdResult.failed(),
      CreateSheet(:final name) => await _runSheetAction(
        () => _createSheet(name),
      ),
      SignOut() => await _runSheetAction(_handleSignedOut),
      ReturnToSheet() => _runSheetSync(_returnToSheetSelection),
      ReturnToWorkout() => _runSheetSync(_returnToLoadedWorkout),
      RepairAll() => await _runSheetAction(_repairFormulas),
      RepairOne(:final activeRow, :final exerciseRow) => await _runSheetAction(
        () => _repairFormulaIssue(
          activeSheetRowNumber: activeRow,
          selectedRow: exerciseRow,
        ),
      ),
      OpenSheet() => await _runSheetAction(_openSheet),
    };
  }

  CmdResult _setSheetText(String text) {
    if (_sheetCtrl.text != text) {
      _sheetCtrl.text = text;
    }
    _usePastedText();
    return const CmdResult.done();
  }

  CmdResult _runSheetSync(VoidCallback action) {
    action();
    return const CmdResult.done();
  }

  Future<CmdResult> _runSheetAction(Future<void> Function() action) async {
    await action();
    return const CmdResult.done();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _A11yScreen(
        label: 'WorkoutTracker',
        child: SafeArea(
          child: ListenableBuilder(
            listenable: Listenable.merge([_controller, _workspaceLifecycle]),
            builder: (context, _) {
              final report = _controller.report;
              final error = _controller.error;
              final workspaceSt = _workspaceLifecycle.state;
              final isBusy =
                  _controller.isBusy || workspaceSt.isCommandInFlight;
              final picker = widget.picker;
              final selectedSheet = workspaceSt.selectedSheet;
              final pickerAvailability = workspaceSt.pickerAvailability;
              final hasLoadedWorkout =
                  report != null && !report.hasBlockingIssues;
              final showPickerAvailability =
                  selectedSheet == null && picker != null;
              final showSheetSelection =
                  _screen == _AppScreen.sheetSelection ||
                  report == null ||
                  report.hasBlockingIssues;
              final showTextFallback =
                  picker == null || workspaceSt.fallbackAvailable;
              return ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 840),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (showSheetSelection)
                          SheetScreen(
                            view: SheetView(
                              isBusy: isBusy,
                              error: error,
                              sheetText: _sheetCtrl.text,
                              selectedSheet: selectedSheet,
                              availability: pickerAvailability,
                              showAvailability: showPickerAvailability,
                              showTextFallback: showTextFallback,
                              hasLoadedWorkout: hasLoadedWorkout,
                              report: report,
                              account: widget.accountSession?.currentAccount,
                              hasPicker: picker != null,
                              showAccount: widget.accountSession != null,
                            ),
                            run: _runSheet,
                          ),
                        if (!showSheetSelection && error != null) ...[
                          IssuePanel(
                            icon: Icons.error_outline,
                            title: 'Connection or validation failed',
                            lines: [error],
                            tone: IssueTone.error,
                          ),
                          const SizedBox(height: 16),
                        ],
                        if (!showSheetSelection)
                          _WorkoutPane(
                            setup: _controller.workoutSetup!,
                            sheetLabel:
                                selectedSheet?.displayLabel ?? report.sheetId,
                            screen: _screen,
                            onBackToSheets: _returnToSheetSelection,
                            onOpenSetup: _selectWorkoutSetup,
                            onBackToSetup: _returnToWorkoutSetup,
                            onOpenLibrary: _openExerciseManager,
                            editingExercise: _editingExercise,
                            onWorkoutChanged: _selectWorkout,
                            onHistoryBlockChanged: _selectHistoryBlock,
                            onAddWorkout: isBusy ? null : _promptForNewWorkout,
                            onAddHistoryBlock: isBusy ? null : _promptNewBlock,
                            onCreateExercise: isBusy
                                ? null
                                : _openExerciseCreate,
                            onEditExercise: isBusy ? null : _openExerciseEdit,
                            highlightedExerciseRow: _highlightedExerciseRow,
                            onReorderExercises: isBusy
                                ? null
                                : _controller.reorderExercises,
                            onReorderWorkout: isBusy
                                ? null
                                : _controller.reorderWorkoutExercises,
                            onOpenExercise: _openExercise,
                            onAddPrimary: _openPrimaryAdd,
                            onAddBackup: _openBackupAdd,
                            onDeleteExercise: isBusy
                                ? null
                                : _confirmDeleteExercise,
                            addReturnScreen: _addReturnScreen,
                            addIntent: placementIntent,
                            onCloseExerciseAdd: _closeExerciseAdd,
                            onSubmitExercise: _saveExerciseDraft,
                            onSubmitExerciseEdit: _saveExerciseEdit,
                            onCloseExerciseEdit: _closeExerciseEdit,
                            onSubmitPlacement: _placeExercise,
                            onSubmitAndAddAnother: _placeAndKeepAdding,
                            onCloseExercise: _closeExercise,
                            onLoggingRowChanged: _controller.selectLoggingRow,
                            onExecute: _controller.execute,
                          ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
