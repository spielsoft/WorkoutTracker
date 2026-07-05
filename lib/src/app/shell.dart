import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:workout_tracker/sheet_contract.dart';

import 'app_state_store.dart';
import 'exercise_logging_flow.dart';
import 'google_workspace.dart';
import 'spreadsheet_validation.dart';
import 'spreadsheet_selection.dart';
import 'workout_tracker_controller.dart';

part 'shell_account.dart';
part 'shell_workout.dart';
part 'shell_exercise_authoring.dart';
part 'shell_exercise_manager.dart';
part 'shell_visual_states.dart';
part 'shell_logging.dart';
part 'shell_validation.dart';
part 'shell_accessibility.dart';

const _compactSegmentedButtonRadius = 8.0;

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
      primarySheetRowNumber = null,
      primaryExercise = null;

  const _PlaceIntent.backup({
    required this.workout,
    required this.primarySheetRowNumber,
    required this.primaryExercise,
  }) : kind = _PlaceKind.backup;

  final _PlaceKind kind;
  final String workout;
  final int? primarySheetRowNumber;
  final String? primaryExercise;
}

class WorkoutTrackerApp extends StatelessWidget {
  const WorkoutTrackerApp({
    required this.svc,
    this.accountSession,
    this.appStateStore,
    this.initialText = '',
    this.initialSelection,
    this.picker,
    this.spreadsheetOpener = const UrlLauncherSpreadsheetOpener(),
    super.key,
  });

  final WorkbookCommandService svc;
  final GoogleAccountSession? accountSession;
  final AppStateStore? appStateStore;
  final String initialText;
  final SelectedSpreadsheet? initialSelection;
  final SpreadsheetPicker? picker;
  final SpreadsheetOpener spreadsheetOpener;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WorkoutTracker',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0E7C66)),
        useMaterial3: true,
      ),
      scrollBehavior: const AppScrollBehavior(),
      home: AppShell(
        svc: svc,
        accountSession: accountSession,
        appStateStore: appStateStore,
        initialText: initialText,
        initialSelection: initialSelection,
        picker: picker,
        spreadsheetOpener: spreadsheetOpener,
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

class _SheetPick extends StatelessWidget {
  const _SheetPick({
    required this.selectedSpreadsheet,
    required this.availability,
    required this.showAvailabilitySummary,
    required this.isBusy,
    this.accountSession,
    required this.onSignedOut,
    this.onReturnToWorkout,
    required this.onChooseSpreadsheet,
    required this.onCreateSpreadsheet,
  });

  final SelectedSpreadsheet? selectedSpreadsheet;
  final PickerAvailability availability;
  final bool showAvailabilitySummary;
  final bool isBusy;
  final GoogleAccountSession? accountSession;
  final Future<void> Function() onSignedOut;
  final VoidCallback? onReturnToWorkout;
  final Future<void> Function() onChooseSpreadsheet;
  final Future<void> Function() onCreateSpreadsheet;

  @override
  Widget build(BuildContext context) {
    final selected = selectedSpreadsheet;
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.table_chart_outlined, color: colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    selected?.displayLabel ?? 'No workout sheet selected',
                    key: const ValueKey('selected-spreadsheet-label'),
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                if (accountSession != null) ...[
                  const SizedBox(width: 8),
                  _GoogleAccountMenu(
                    accountSession: accountSession!,
                    onSignedOut: onSignedOut,
                  ),
                ],
              ],
            ),
            if (selected?.accountEmail != null) ...[
              const SizedBox(height: 4),
              Text(
                selected!.accountEmail!,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 12),
            if (selected != null && onReturnToWorkout != null)
              FilledButton.tonalIcon(
                key: const ValueKey('return-to-selected-workout'),
                onPressed: isBusy ? null : onReturnToWorkout,
                icon: const Icon(Icons.fitness_center_outlined),
                label: const Text('Return to workout'),
              )
            else
              FilledButton.icon(
                key: const ValueKey('choose-google-spreadsheet'),
                onPressed: isBusy || !availability.canChoose
                    ? null
                    : onChooseSpreadsheet,
                icon: const Icon(Icons.drive_folder_upload_outlined),
                label: Text(
                  selected == null ? 'Choose workout sheet' : 'Change sheet',
                ),
              ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (selected != null && onReturnToWorkout != null)
                  OutlinedButton.icon(
                    key: const ValueKey('choose-google-spreadsheet'),
                    onPressed: isBusy || !availability.canChoose
                        ? null
                        : onChooseSpreadsheet,
                    icon: const Icon(Icons.drive_folder_upload_outlined),
                    label: const Text('Change sheet'),
                  ),
                OutlinedButton.icon(
                  key: const ValueKey('create-google-spreadsheet'),
                  onPressed: isBusy || !availability.canCreate
                      ? null
                      : onCreateSpreadsheet,
                  icon: const Icon(Icons.add_to_drive_outlined),
                  label: const Text('Create sheet'),
                ),
              ],
            ),
            if (showAvailabilitySummary && availability.summary != null) ...[
              const SizedBox(height: 8),
              Text(
                availability.summary!,
                key: const ValueKey('spreadsheet-picker-availability'),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _NameDialog extends StatefulWidget {
  const _NameDialog({
    required this.title,
    required this.label,
    this.initialValue,
    this.submitLabel = 'Add',
    this.textFieldKey,
  });

  final String title;
  final String label;
  final String? initialValue;
  final String submitLabel;
  final Key? textFieldKey;

  @override
  State<_NameDialog> createState() => _NamePromptDialogState();
}

class _NamePromptDialogState extends State<_NameDialog> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
    _controller.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _controller.text.length,
    );
    _focusNode = FocusNode();
    _focusNode.addListener(_selectTextAfterFocus);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _focusNode.removeListener(_selectTextAfterFocus);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _selectTextAfterFocus() {
    if (!_focusNode.hasFocus) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_focusNode.hasFocus) {
        return;
      }
      _controller.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _controller.text.length,
      );
    });
  }

  void _submit() {
    Navigator.of(context).pop(_controller.text);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: _A11yTextField(
        label: widget.label,
        valueListenable: _controller,
        child: TextField(
          key: widget.textFieldKey,
          controller: _controller,
          focusNode: _focusNode,
          autofocus: true,
          decoration: InputDecoration(labelText: widget.label),
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _submit(),
          selectAllOnFocus: true,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: Text(widget.submitLabel)),
      ],
    );
  }
}

class _SheetTextFallback extends StatelessWidget {
  const _SheetTextFallback({
    required this.controller,
    required this.isBusy,
    required this.onChanged,
    required this.onSubmitted,
    required this.onValidate,
    required this.onSignedOut,
    this.accountSession,
  });

  final TextEditingController controller;
  final bool isBusy;
  final VoidCallback onChanged;
  final VoidCallback onSubmitted;
  final Future<void> Function() onValidate;
  final Future<void> Function() onSignedOut;
  final GoogleAccountSession? accountSession;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const ValueKey('spreadsheet-url-fallback'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _A11yTextField(
                label: 'Google Sheets URL or ID',
                valueListenable: controller,
                hint: 'Paste a Google Sheets URL or spreadsheet ID.',
                child: TextField(
                  key: const ValueKey('spreadsheet-selection-input'),
                  controller: controller,
                  decoration: const InputDecoration(
                    labelText: 'Paste Google Sheets URL or ID',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.table_chart_outlined),
                  ),
                  onChanged: (_) => onChanged(),
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => onSubmitted(),
                ),
              ),
            ),
            if (accountSession != null) ...[
              const SizedBox(width: 8),
              _GoogleAccountMenu(
                accountSession: accountSession!,
                onSignedOut: onSignedOut,
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          key: const ValueKey('validate-spreadsheet'),
          onPressed: isBusy ? null : onValidate,
          icon: isBusy
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.verified_outlined),
          label: const Text('Select'),
        ),
      ],
    );
  }
}

class AppShell extends StatefulWidget {
  const AppShell({
    required this.svc,
    this.accountSession,
    this.appStateStore,
    required this.initialText,
    this.initialSelection,
    this.picker,
    required this.spreadsheetOpener,
    super.key,
  });

  final WorkbookCommandService svc;
  final GoogleAccountSession? accountSession;
  final AppStateStore? appStateStore;
  final String initialText;
  final SelectedSpreadsheet? initialSelection;
  final SpreadsheetPicker? picker;
  final SpreadsheetOpener spreadsheetOpener;

  @override
  State<AppShell> createState() {
    return _AppShellState();
  }
}

class _AppShellState extends State<AppShell> {
  late final TextEditingController _spreadsheetController;
  late final AppController _controller;
  _AppScreen _screen = _AppScreen.sheetSelection;
  _AppScreen _exerciseAddReturnScreen = _AppScreen.exercisePicker;
  _PlaceIntent? placementIntent;
  CanonicalExercise? _editingExercise;
  int? _highlightedExerciseRow;
  WorkspaceStateOwner? _accessStateController;
  late final WorkspaceController _workspaceLifecycle;

  @override
  void initState() {
    super.initState();
    _controller = AppController(svc: widget.svc);
    _spreadsheetController = TextEditingController(
      text: widget.initialSelection?.spreadsheetId ?? widget.initialText,
    );
    final appStateStore = widget.appStateStore;
    if (appStateStore != null) {
      _accessStateController = WorkspaceStateController(appStateStore);
    }
    _workspaceLifecycle = WorkspaceController(
      accessStateOwner: _accessStateController,
      accountSession: widget.accountSession,
      picker: widget.picker,
      initialText: widget.initialText,
      initialSelection: widget.initialSelection,
    );
    unawaited(_restoreStartupState());
  }

  @override
  void dispose() {
    _controller.dispose();
    _workspaceLifecycle.dispose();
    _spreadsheetController.dispose();
    super.dispose();
  }

  Future<void> _restoreStartupState() async {
    WorkspaceUiState workspaceState;
    try {
      workspaceState = await _workspaceLifecycle.restoreResolved();
    } on Object {
      return;
    }
    await _restoreSelection(workspaceState);
  }

  Future<void> _restoreSelection(WorkspaceUiState workspaceState) async {
    if (!mounted) {
      return;
    }
    var savedSelection = workspaceState.selectedSpreadsheet;
    if (savedSelection != null) {
      setState(() {
        _spreadsheetController.text = savedSelection.spreadsheetId;
      });
      await _validateSelected();
      _restoreWorkoutSelection(
        _workspaceLifecycle.workoutSelectionFor(
          _controller.report?.spreadsheetId ?? savedSelection.spreadsheetId,
        ),
      );
      return;
    }
    final savedText = workspaceState.pastedText;
    if (savedText != null && savedText != _spreadsheetController.text) {
      _spreadsheetController.text = savedText;
    }
  }

  void _usePastedSpreadsheetText() {
    unawaited(() async {
      try {
        await _workspaceLifecycle.usePastedSpreadsheetText(
          _spreadsheetController.text,
        );
      } on Object {
        // Text fallback persistence is best-effort.
      }
    }());
  }

  Future<void> _validateSelected() async {
    final selectedSpreadsheet = _workspaceLifecycle.state.selectedSpreadsheet;
    final selected = selectedSpreadsheet == null
        ? await _controller.validateSelection(_spreadsheetController.text)
        : await _controller.validateSelected(selectedSpreadsheet);
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

  Future<void> _chooseSpreadsheet() async {
    try {
      final workspaceState = await _workspaceLifecycle.chooseSpreadsheet();
      await _validateWorkspaceSelection(workspaceState);
    } on Object catch (error) {
      _controller.reportSelectionFailure(error);
    }
  }

  Future<void> _createSpreadsheet() async {
    final hasGoogleAccount = await _authorizeSheetCreation();
    if (!mounted || !hasGoogleAccount) {
      return;
    }
    final defaultName = defaultWorkoutSpreadsheetTitle();
    final name = await _promptForSheetName(defaultName);
    if (!mounted || name == null) {
      return;
    }
    try {
      final workspaceState = await _workspaceLifecycle.createSpreadsheet(
        name: name,
      );
      await _validateWorkspaceSelection(workspaceState);
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

  Future<void> _validateWorkspaceSelection(
    WorkspaceUiState workspaceState,
  ) async {
    final selectedSpreadsheet = workspaceState.selectedSpreadsheet;
    if (!mounted || selectedSpreadsheet == null) {
      return;
    }
    setState(() {
      _spreadsheetController.text = selectedSpreadsheet.spreadsheetId;
    });
    await _validateSelected();
  }

  Future<void> _handleSignedOut() async {
    await _workspaceLifecycle.signOut();
    _controller.clearSelection();
    setState(() {
      _spreadsheetController.clear();
      _screen = _AppScreen.sheetSelection;
      _exerciseAddReturnScreen = _AppScreen.exercisePicker;
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
        return _NameDialog(
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

  Future<String?> _promptForSheetName(String defaultName) async {
    final value = await showDialog<String>(
      context: context,
      builder: (context) {
        return _NameDialog(
          title: 'Create sheet',
          label: 'Sheet name',
          initialValue: defaultName,
          submitLabel: 'Create',
          textFieldKey: const ValueKey('create-spreadsheet-name'),
        );
      },
    );
    if (value == null) {
      return null;
    }
    final trimmed = value.trim();
    return trimmed.isEmpty ? defaultName : trimmed;
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
      _persistWorkoutSelection();
    }
  }

  Future<void> _promptForNewHistoryBlock() async {
    final name = await _promptForName(
      title: 'Add history block',
      label: 'History block label',
    );
    if (!mounted || name == null) {
      return;
    }
    final created = await _controller.createHistoryBlock(name);
    if (created && mounted) {
      _persistWorkoutSelection();
    }
  }

  Future<void> _repairUnambiguousFormulas() async {
    final repaired = await _controller.repairUnambiguousFormulas();
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
      selectedExerciseSheetRowNumber: selectedRow,
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

  Future<void> _openSelectedSpreadsheet() async {
    final report = _controller.report;
    if (report == null) {
      return;
    }
    try {
      await widget.spreadsheetOpener.openSpreadsheet(report.spreadsheetUrl);
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

  void _openExercise(int primarySheetRowNumber) {
    _controller.openExercise(primarySheetRowNumber);
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

  void _openPrimaryExerciseAdd(String workout) {
    _controller.closeExercise();
    _editingExercise = null;
    _highlightedExerciseRow = null;
    setState(() {
      _exerciseAddReturnScreen = _AppScreen.workoutSetup;
      placementIntent = _PlaceIntent.primary(workout: workout);
      _screen = _AppScreen.addExercise;
    });
  }

  void _openBackupExerciseAdd(WorkoutOverviewSlot primarySlot) {
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
      _exerciseAddReturnScreen = returnScreen;
      placementIntent = _PlaceIntent.backup(
        workout: workout,
        primarySheetRowNumber: primarySlot.sheetRowNumber,
        primaryExercise: primarySlot.exercise,
      );
      _screen = _AppScreen.addExercise;
    });
  }

  Future<void> _confirmDeleteWorkoutExercise(
    WorkoutOverviewSlot primarySlot,
  ) async {
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
      primarySheetRowNumber: primarySlot.sheetRowNumber,
    );
  }

  void _openCanonicalExerciseCreation() {
    _controller.closeExercise();
    _editingExercise = null;
    setState(() {
      _exerciseAddReturnScreen = _screen == _AppScreen.exerciseManager
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
      _screen = _exerciseAddReturnScreen;
    });
  }

  void _openCanonicalExerciseEdit(CanonicalExercise exercise) {
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

  Future<void> _handleCanonicalExerciseDraft(
    CanonicalExerciseDraft draft,
  ) async {
    final created = await _controller.createCanonicalExercise(
      exercise: draft.toDefinition(),
    );
    if (!mounted || !created) {
      return;
    }
    final createdExerciseName = draft.normalized().exerciseName;
    setState(() {
      _highlightedExerciseRow =
          _exerciseAddReturnScreen == _AppScreen.exerciseManager
          ? _lastCanonicalExerciseSheetRowNumberByName(createdExerciseName)
          : null;
      _screen = _exerciseAddReturnScreen;
    });
  }

  Future<void> _handleCanonicalExerciseEditDraft(
    CanonicalExerciseDraft draft,
  ) async {
    final selectedExercise = _editingExercise;
    if (selectedExercise == null) {
      return;
    }
    final updated = await _controller.updateCanonicalExercise(
      selectedExercise: selectedExercise,
      exercise: draft.toDefinition(),
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

  int? _lastCanonicalExerciseSheetRowNumberByName(String exerciseName) {
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

  Future<void> _handleExercisePlacement(_ExercisePlacementDraft draft) async {
    final added = await _addExercisePlacement(draft);
    if (!mounted || !added) {
      return;
    }
    placementIntent = null;
    setState(() {
      _screen = _exerciseAddReturnScreen;
    });
  }

  Future<bool> _handleExercisePlacementAndAddAnother(
    _ExercisePlacementDraft draft,
  ) async {
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
          primarySheetRowNumber: intent.primarySheetRowNumber!,
        ),
      },
    );
  }

  void _selectWorkout(String? workout) {
    _controller.selectWorkout(workout);
    _persistWorkoutSelection();
    setState(() {
      _screen = _AppScreen.workoutSetup;
    });
  }

  void _selectHistoryBlock(String? historyBlock) {
    _controller.selectHistoryBlock(historyBlock);
    _persistWorkoutSelection();
    setState(() {
      _screen = _AppScreen.workoutSetup;
    });
  }

  void _restoreWorkoutSelection(WorkoutSelectionState? savedSelection) {
    final report = _controller.report;
    if (savedSelection == null ||
        report == null ||
        savedSelection.spreadsheetId != report.spreadsheetId) {
      return;
    }
    _controller.restoreWorkoutSelection(
      workout: savedSelection.workout,
      historyBlock: savedSelection.historyBlock,
    );
  }

  void _persistWorkoutSelection() {
    final report = _controller.report;
    final setup = _controller.workoutSetup;
    if (report == null || setup == null) {
      return;
    }
    final selection = WorkoutSelectionState(
      spreadsheetId: report.spreadsheetId,
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
              final workspaceState = _workspaceLifecycle.state;
              final isBusy =
                  _controller.isBusy || workspaceState.isCommandInFlight;
              final picker = widget.picker;
              final selectedSpreadsheet = workspaceState.selectedSpreadsheet;
              final pickerAvailability = workspaceState.pickerAvailability;
              final hasLoadedWorkout =
                  report != null && !report.hasBlockingIssues;
              final showPickerAvailability =
                  selectedSpreadsheet == null && picker != null;
              final showSheetSelection =
                  _screen == _AppScreen.sheetSelection ||
                  report == null ||
                  report.hasBlockingIssues;
              final showSpreadsheetTextFallback =
                  picker == null || workspaceState.fallbackAvailable;
              return ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 840),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (showSheetSelection) ...[
                          if (picker != null) ...[
                            _SheetPick(
                              selectedSpreadsheet: selectedSpreadsheet,
                              availability: pickerAvailability,
                              showAvailabilitySummary: showPickerAvailability,
                              isBusy: isBusy,
                              accountSession: widget.accountSession,
                              onSignedOut: _handleSignedOut,
                              onReturnToWorkout: hasLoadedWorkout
                                  ? _returnToLoadedWorkout
                                  : null,
                              onChooseSpreadsheet: _chooseSpreadsheet,
                              onCreateSpreadsheet: _createSpreadsheet,
                            ),
                            if (showSpreadsheetTextFallback)
                              const SizedBox(height: 12),
                          ],
                          if (showSpreadsheetTextFallback)
                            _SheetTextFallback(
                              controller: _spreadsheetController,
                              isBusy: isBusy,
                              accountSession: widget.accountSession,
                              onSignedOut: _handleSignedOut,
                              onChanged: _usePastedSpreadsheetText,
                              onSubmitted: _validateSelected,
                              onValidate: _validateSelected,
                            ),
                          const SizedBox(height: 24),
                        ],
                        if (error != null) ...[
                          _IssuePanel(
                            icon: Icons.error_outline,
                            title: 'Connection or validation failed',
                            lines: [error],
                            tone: _IssueTone.error,
                          ),
                          const SizedBox(height: 16),
                        ],
                        if (showSheetSelection && report != null)
                          _ValidationSummary(
                            report: report,
                            onRepairFormulas: isBusy
                                ? null
                                : _repairUnambiguousFormulas,
                            onRepairFormulaIssue: isBusy
                                ? null
                                : _repairFormulaIssue,
                            onOpenSpreadsheet: isBusy
                                ? null
                                : _openSelectedSpreadsheet,
                          ),
                        if (!showSheetSelection)
                          _WorkoutPane(
                            setup: _controller.workoutSetup!,
                            sheetLabel:
                                selectedSpreadsheet?.displayLabel ??
                                report.spreadsheetId,
                            screen: _screen,
                            onBackToSheetSelection: _returnToSheetSelection,
                            onSelectWorkoutSetup: _selectWorkoutSetup,
                            onBackToWorkoutSetup: _returnToWorkoutSetup,
                            onOpenExerciseManager: _openExerciseManager,
                            editingExercise: _editingExercise,
                            onWorkoutChanged: _selectWorkout,
                            onHistoryBlockChanged: _selectHistoryBlock,
                            onAddWorkout: isBusy ? null : _promptForNewWorkout,
                            onAddHistoryBlock: isBusy
                                ? null
                                : _promptForNewHistoryBlock,
                            onCreateCanonicalExercise: isBusy
                                ? null
                                : _openCanonicalExerciseCreation,
                            onEditCanonicalExercise: isBusy
                                ? null
                                : _openCanonicalExerciseEdit,
                            highlightedExerciseRow: _highlightedExerciseRow,
                            onReorderCanonicalExercises: isBusy
                                ? null
                                : _controller.reorderCanonicalExercises,
                            onReorderWorkoutExercises: isBusy
                                ? null
                                : _controller.reorderWorkoutExercises,
                            onOpenExercise: _openExercise,
                            onAddPrimaryExercise: _openPrimaryExerciseAdd,
                            onAddBackupExercise: _openBackupExerciseAdd,
                            onDeleteWorkoutExercise: isBusy
                                ? null
                                : _confirmDeleteWorkoutExercise,
                            exerciseAddReturnScreen: _exerciseAddReturnScreen,
                            addExercisePlacementIntent: placementIntent,
                            onCloseExerciseAdd: _closeExerciseAdd,
                            onSubmitCanonicalExercise:
                                _handleCanonicalExerciseDraft,
                            onSubmitCanonicalExerciseEdit:
                                _handleCanonicalExerciseEditDraft,
                            onCloseExerciseEdit: _closeExerciseEdit,
                            onSubmitExercisePlacement: _handleExercisePlacement,
                            onSubmitPlacementAndAddAnother:
                                _handleExercisePlacementAndAddAnother,
                            onCloseExercise: _closeExercise,
                            onLoggingRowChanged: _controller.selectLoggingRow,
                            onApplyWritePlan:
                                _controller.applyActiveSheetWritePlan,
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
