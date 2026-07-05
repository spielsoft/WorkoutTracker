import 'package:flutter/foundation.dart';
import 'package:workout_tracker/google_sheets.dart';

import 'app_state_store.dart';
import 'google_account_session.dart';
import 'spreadsheet_selection.dart';

const _pickerNotConfiguredReason =
    'Google Drive Picker is not configured for this build.';

class WorkspaceUiState {
  const WorkspaceUiState({
    this.selectedSpreadsheet,
    this.pastedSpreadsheetText,
    this.accountProfile,
    this.pickerAuthorization,
    this.workoutSelection,
    this.isCommandInFlight = false,
    required this.pickerAvailability,
  });

  final SelectedSpreadsheet? selectedSpreadsheet;
  final String? pastedSpreadsheetText;
  final GoogleAccountProfile? accountProfile;
  final PickerAuth? pickerAuthorization;
  final WorkoutSelectionState? workoutSelection;
  final bool isCommandInFlight;
  final SpreadsheetPickerAvailability pickerAvailability;

  bool get pastedSheetFallbackAvailable {
    return selectedSpreadsheet == null && !pickerAvailability.canChoose;
  }
}

abstract interface class WorkspaceLifecycle implements Listenable {
  WorkspaceUiState get state;

  Future<WorkspaceUiState> restore();

  Future<WorkspaceUiState> restoreResolvedSelection();

  Future<WorkspaceUiState> persistPastedSpreadsheetText(String text);

  Future<WorkspaceUiState> usePastedSpreadsheetText(String text);

  Future<WorkspaceUiState> adoptSelectedSpreadsheet(
    SelectedSpreadsheet selected,
  );

  Future<WorkspaceUiState> chooseSpreadsheet();

  Future<bool> authorizeSheetCreation();

  Future<WorkspaceUiState> createSpreadsheet({String? name});

  Future<SelectedSpreadsheet> resolveSelection(SelectedSpreadsheet selected);

  Future<WorkspaceUiState> signOut();

  Future<WorkspaceUiState> persistWorkoutSelection(
    WorkoutSelectionState selection,
  );

  WorkoutSelectionState? workoutSelectionFor(String spreadsheetId);
}

class WorkspaceController extends ChangeNotifier implements WorkspaceLifecycle {
  WorkspaceController({
    WorkspaceStateOwner? accessStateOwner,
    GoogleAccountSession? accountSession,
    SpreadsheetPicker? spreadsheetPicker,
    String initialSpreadsheetText = '',
    SelectedSpreadsheet? initialSelectedSpreadsheet,
  }) : _accessState = accessStateOwner,
       _accountSession = accountSession,
       _spreadsheetPicker = spreadsheetPicker,
       _initialSpreadsheetText = initialSpreadsheetText,
       _initialSelectedSpreadsheet = initialSelectedSpreadsheet,
       _state = WorkspaceUiState(
         selectedSpreadsheet: initialSelectedSpreadsheet,
         pastedSpreadsheetText: _trimmedOrNull(initialSpreadsheetText),
         accountProfile: accountSession?.currentAccount,
         pickerAuthorization: _currentPickerAuthorization(accountSession),
         workoutSelection: null,
         isCommandInFlight: false,
         pickerAvailability: _availabilityFor(spreadsheetPicker),
       );

  final WorkspaceStateOwner? _accessState;
  final GoogleAccountSession? _accountSession;
  final SpreadsheetPicker? _spreadsheetPicker;
  final String _initialSpreadsheetText;
  final SelectedSpreadsheet? _initialSelectedSpreadsheet;
  WorkspaceUiState _state;
  bool _isCommandInFlight = false;

  @override
  WorkspaceUiState get state => _state;

  @override
  Future<WorkspaceUiState> restore() async {
    await _restoreAccount();
    final restoredAccessState = await _restoreAccessState();
    final accessState = restoredAccessState ?? const WorkspaceAccessState();
    if (restoredAccessState != null) {
      _restorePickerAuthorization(accessState.pickerAuth);
    }
    _state = WorkspaceUiState(
      selectedSpreadsheet:
          accessState.selectedSpreadsheet ?? _initialSelectedSpreadsheet,
      pastedSpreadsheetText:
          _trimmedOrNull(accessState.spreadsheetText) ??
          _trimmedOrNull(_initialSpreadsheetText),
      accountProfile: _accountSession?.currentAccount,
      pickerAuthorization: _currentPickerAuthorization(_accountSession),
      workoutSelection: accessState.workoutSelection,
      isCommandInFlight: _isCommandInFlight,
      pickerAvailability: _availabilityFor(_spreadsheetPicker),
    );
    notifyListeners();
    return _state;
  }

  @override
  Future<WorkspaceUiState> restoreResolvedSelection() async {
    final restored = await restore();
    final selected = restored.selectedSpreadsheet;
    if (selected == null) {
      return restored;
    }
    await resolveSelection(selected);
    return _state;
  }

  @override
  Future<WorkspaceUiState> persistPastedSpreadsheetText(String text) async {
    final persistedText = _trimmedOrNull(text);
    await _updateAccessStateBestEffort(
      (accessState) => WorkspaceAccessState(
        spreadsheetText: persistedText,
        selectedSpreadsheet: accessState.selectedSpreadsheet,
        pickerAuth: accessState.pickerAuth,
        workoutSelection: accessState.workoutSelection,
      ),
    );
    _setState(
      _stateWith(
        selectedSpreadsheet: _state.selectedSpreadsheet,
        pastedSpreadsheetText: persistedText,
        workoutSelection: _state.workoutSelection,
      ),
    );
    return _state;
  }

  @override
  Future<WorkspaceUiState> usePastedSpreadsheetText(String text) async {
    final persistedText = _trimmedOrNull(text);
    final updatedAccessState = await _updateAccessStateBestEffort(
      (accessState) => WorkspaceAccessState(
        spreadsheetText: persistedText,
        selectedSpreadsheet: null,
        pickerAuth: accessState.pickerAuth,
        workoutSelection: null,
      ),
    );
    _setState(
      _stateWith(
        selectedSpreadsheet: null,
        pastedSpreadsheetText: persistedText,
        pickerAuthorization:
            updatedAccessState?.pickerAuth ?? _state.pickerAuthorization,
        workoutSelection: null,
      ),
    );
    return _state;
  }

  @override
  Future<WorkspaceUiState> adoptSelectedSpreadsheet(
    SelectedSpreadsheet selected,
  ) async {
    final authorization = _currentPickerAuthorization(_accountSession);
    final updatedAccessState = await _updateAccessStateBestEffort(
      (accessState) => WorkspaceAccessState(
        spreadsheetText: selected.spreadsheetId,
        selectedSpreadsheet: selected,
        pickerAuth: authorization ?? accessState.pickerAuth,
        workoutSelection: accessState.workoutSelection,
      ),
    );
    _setState(
      _stateWith(
        selectedSpreadsheet: selected,
        pastedSpreadsheetText: selected.spreadsheetId,
        pickerAuthorization: authorization ?? updatedAccessState?.pickerAuth,
        workoutSelection:
            updatedAccessState?.workoutSelection ?? _state.workoutSelection,
      ),
    );
    return _state;
  }

  @override
  Future<WorkspaceUiState> chooseSpreadsheet() async {
    final picker = _spreadsheetPicker;
    if (picker == null) {
      return _state;
    }
    return _runStateCommand(() async {
      final selected = await picker.chooseSpreadsheet();
      if (selected == null) {
        return _state;
      }
      return adoptSelectedSpreadsheet(selected);
    });
  }

  @override
  Future<bool> authorizeSheetCreation() async {
    if (_isCommandInFlight) {
      return false;
    }
    _beginCommand();
    try {
      final picker = _spreadsheetPicker;
      if (picker != null) {
        return await picker.authorizeSheetCreation();
      }

      final accountSession = _accountSession;
      if (accountSession == null || accountSession.currentAccount != null) {
        return true;
      }
      await accountSession.switchAccount(
        scopes: GoogleApisSheetsWorkbookClient.writeScopes,
      );
      return accountSession.currentAccount != null;
    } finally {
      _endCommand();
    }
  }

  @override
  Future<WorkspaceUiState> createSpreadsheet({String? name}) async {
    final picker = _spreadsheetPicker;
    if (picker == null) {
      return _state;
    }
    return _runStateCommand(() async {
      final selected = await picker.createSpreadsheet(name: name);
      if (selected == null) {
        return _state;
      }
      return adoptSelectedSpreadsheet(selected);
    });
  }

  @override
  Future<SelectedSpreadsheet> resolveSelection(
    SelectedSpreadsheet selected,
  ) async {
    final picker = _spreadsheetPicker;
    if (picker == null) {
      return selected;
    }
    try {
      final resolved = await picker.resolveSelection(selected);
      await adoptSelectedSpreadsheet(resolved);
      return resolved;
    } on Object {
      return selected;
    }
  }

  @override
  Future<WorkspaceUiState> persistWorkoutSelection(
    WorkoutSelectionState selection,
  ) async {
    final updatedAccessState = await _updateAccessStateBestEffort(
      (accessState) => WorkspaceAccessState(
        spreadsheetText: accessState.spreadsheetText,
        selectedSpreadsheet: accessState.selectedSpreadsheet,
        pickerAuth: accessState.pickerAuth,
        workoutSelection: selection,
      ),
    );
    _setState(
      _stateWith(
        selectedSpreadsheet: _state.selectedSpreadsheet,
        pastedSpreadsheetText: _state.pastedSpreadsheetText,
        pickerAuthorization:
            updatedAccessState?.pickerAuth ?? _state.pickerAuthorization,
        workoutSelection: selection,
      ),
    );
    return _state;
  }

  @override
  WorkoutSelectionState? workoutSelectionFor(String spreadsheetId) {
    final selection = _state.workoutSelection;
    if (selection == null || selection.spreadsheetId != spreadsheetId) {
      return null;
    }
    return selection;
  }

  @override
  Future<WorkspaceUiState> signOut() async {
    if (_isCommandInFlight) {
      return _state;
    }
    _beginCommand();
    try {
      await _accountSession?.signOut();
      await _accessState?.clear();
      _setState(
        WorkspaceUiState(
          selectedSpreadsheet: null,
          pastedSpreadsheetText: null,
          accountProfile: _accountSession?.currentAccount,
          pickerAuthorization: _currentPickerAuthorization(_accountSession),
          workoutSelection: null,
          isCommandInFlight: _isCommandInFlight,
          pickerAvailability: _availabilityFor(_spreadsheetPicker),
        ),
      );
      return _state;
    } finally {
      _endCommand();
    }
  }

  Future<void> _restoreAccount() async {
    try {
      await _accountSession?.restoreAccount();
    } on Object {
      // Startup restore is best-effort; explicit account actions report errors.
    }
  }

  Future<WorkspaceAccessState?> _restoreAccessState() async {
    try {
      return await _accessState?.restore();
    } on Object {
      return null;
    }
  }

  void _restorePickerAuthorization(PickerAuth? authorization) {
    final accountSession = _accountSession;
    if (accountSession case final PickerAuthStore store) {
      store.restorePickerAuth(authorization);
    }
  }

  Future<WorkspaceAccessState?> _updateAccessStateBestEffort(
    WorkspaceAccessState Function(WorkspaceAccessState current) updateState,
  ) async {
    try {
      return await _accessState?.update(updateState);
    } on Object {
      return null;
    }
  }

  void _setState(WorkspaceUiState state) {
    _state = state;
    notifyListeners();
  }

  Future<WorkspaceUiState> _runStateCommand(
    Future<WorkspaceUiState> Function() action,
  ) async {
    if (_isCommandInFlight) {
      return _state;
    }
    _beginCommand();
    try {
      return await action();
    } finally {
      _endCommand();
    }
  }

  void _beginCommand() {
    _isCommandInFlight = true;
    _setState(
      _stateWith(
        selectedSpreadsheet: _state.selectedSpreadsheet,
        pastedSpreadsheetText: _state.pastedSpreadsheetText,
        pickerAuthorization: _state.pickerAuthorization,
        workoutSelection: _state.workoutSelection,
        isCommandInFlight: true,
      ),
    );
  }

  void _endCommand() {
    _isCommandInFlight = false;
    _setState(
      _stateWith(
        selectedSpreadsheet: _state.selectedSpreadsheet,
        pastedSpreadsheetText: _state.pastedSpreadsheetText,
        pickerAuthorization: _state.pickerAuthorization,
        workoutSelection: _state.workoutSelection,
        isCommandInFlight: false,
      ),
    );
  }

  WorkspaceUiState _stateWith({
    required SelectedSpreadsheet? selectedSpreadsheet,
    required String? pastedSpreadsheetText,
    PickerAuth? pickerAuthorization,
    required WorkoutSelectionState? workoutSelection,
    bool? isCommandInFlight,
  }) {
    return WorkspaceUiState(
      selectedSpreadsheet: selectedSpreadsheet,
      pastedSpreadsheetText: pastedSpreadsheetText,
      accountProfile: _accountSession?.currentAccount,
      pickerAuthorization:
          pickerAuthorization ?? _currentPickerAuthorization(_accountSession),
      workoutSelection: workoutSelection,
      isCommandInFlight: isCommandInFlight ?? _state.isCommandInFlight,
      pickerAvailability: _availabilityFor(_spreadsheetPicker),
    );
  }
}

SpreadsheetPickerAvailability _availabilityFor(SpreadsheetPicker? picker) {
  return picker?.availability ??
      const SpreadsheetPickerAvailability.unavailable(
        chooseUnavailableReason: _pickerNotConfiguredReason,
        createUnavailableReason: _pickerNotConfiguredReason,
      );
}

PickerAuth? _currentPickerAuthorization(GoogleAccountSession? accountSession) {
  if (accountSession case final PickerAuthStore store) {
    return store.currentAuthorization;
  }
  return null;
}

String? _trimmedOrNull(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}
