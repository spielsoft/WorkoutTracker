import 'package:flutter/foundation.dart';
import 'package:workout_tracker/google_sheets.dart';

import 'app_state_store.dart';
import 'google_account_session.dart';
import 'spreadsheet_selection.dart';

const _pickerNotConfiguredReason =
    'Google Drive Picker is not configured for this build.';

class GoogleWorkspaceState {
  const GoogleWorkspaceState({
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
  final GooglePickerAuthorizationSnapshot? pickerAuthorization;
  final WorkoutSelectionState? workoutSelection;
  final bool isCommandInFlight;
  final SpreadsheetPickerAvailability pickerAvailability;

  bool get pastedSheetFallbackAvailable {
    return selectedSpreadsheet == null && !pickerAvailability.canChoose;
  }
}

abstract interface class GoogleWorkspaceLifecycle implements Listenable {
  GoogleWorkspaceState get state;

  Future<GoogleWorkspaceState> restore();

  Future<GoogleWorkspaceState> restoreResolvedSelection();

  Future<GoogleWorkspaceState> persistPastedSpreadsheetText(String text);

  Future<GoogleWorkspaceState> usePastedSpreadsheetText(String text);

  Future<GoogleWorkspaceState> adoptSelectedSpreadsheet(
    SelectedSpreadsheet selected,
  );

  Future<GoogleWorkspaceState> chooseSpreadsheet();

  Future<bool> authorizeSpreadsheetCreation();

  Future<GoogleWorkspaceState> createSpreadsheet({String? name});

  Future<SelectedSpreadsheet> resolveSelectedSpreadsheet(
    SelectedSpreadsheet selected,
  );

  Future<GoogleWorkspaceState> signOut();

  Future<GoogleWorkspaceState> persistWorkoutSelection(
    WorkoutSelectionState selection,
  );

  WorkoutSelectionState? workoutSelectionFor(String spreadsheetId);
}

class GoogleWorkspaceLifecycleController extends ChangeNotifier
    implements GoogleWorkspaceLifecycle {
  GoogleWorkspaceLifecycleController({
    GoogleWorkspaceAccessStateOwner? accessStateOwner,
    GoogleAccountSession? accountSession,
    SpreadsheetPicker? spreadsheetPicker,
    String initialSpreadsheetText = '',
    SelectedSpreadsheet? initialSelectedSpreadsheet,
  }) : _accessState = accessStateOwner,
       _accountSession = accountSession,
       _spreadsheetPicker = spreadsheetPicker,
       _initialSpreadsheetText = initialSpreadsheetText,
       _initialSelectedSpreadsheet = initialSelectedSpreadsheet,
       _state = GoogleWorkspaceState(
         selectedSpreadsheet: initialSelectedSpreadsheet,
         pastedSpreadsheetText: _trimmedOrNull(initialSpreadsheetText),
         accountProfile: accountSession?.currentAccount,
         pickerAuthorization: _currentPickerAuthorization(accountSession),
         workoutSelection: null,
         isCommandInFlight: false,
         pickerAvailability: _availabilityFor(spreadsheetPicker),
       );

  final GoogleWorkspaceAccessStateOwner? _accessState;
  final GoogleAccountSession? _accountSession;
  final SpreadsheetPicker? _spreadsheetPicker;
  final String _initialSpreadsheetText;
  final SelectedSpreadsheet? _initialSelectedSpreadsheet;
  GoogleWorkspaceState _state;
  bool _isCommandInFlight = false;

  @override
  GoogleWorkspaceState get state => _state;

  @override
  Future<GoogleWorkspaceState> restore() async {
    await _restoreAccount();
    final restoredAccessState = await _restoreAccessState();
    final accessState =
        restoredAccessState ?? const GoogleWorkspaceAccessState();
    if (restoredAccessState != null) {
      _restorePickerAuthorization(accessState.googleAuthorization);
    }
    _state = GoogleWorkspaceState(
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
  Future<GoogleWorkspaceState> restoreResolvedSelection() async {
    final restored = await restore();
    final selected = restored.selectedSpreadsheet;
    if (selected == null) {
      return restored;
    }
    await resolveSelectedSpreadsheet(selected);
    return _state;
  }

  @override
  Future<GoogleWorkspaceState> persistPastedSpreadsheetText(String text) async {
    final persistedText = _trimmedOrNull(text);
    await _updateAccessStateBestEffort(
      (accessState) => GoogleWorkspaceAccessState(
        spreadsheetText: persistedText,
        selectedSpreadsheet: accessState.selectedSpreadsheet,
        googleAuthorization: accessState.googleAuthorization,
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
  Future<GoogleWorkspaceState> usePastedSpreadsheetText(String text) async {
    final persistedText = _trimmedOrNull(text);
    final updatedAccessState = await _updateAccessStateBestEffort(
      (accessState) => GoogleWorkspaceAccessState(
        spreadsheetText: persistedText,
        selectedSpreadsheet: null,
        googleAuthorization: accessState.googleAuthorization,
        workoutSelection: null,
      ),
    );
    _setState(
      _stateWith(
        selectedSpreadsheet: null,
        pastedSpreadsheetText: persistedText,
        pickerAuthorization:
            updatedAccessState?.googleAuthorization ??
            _state.pickerAuthorization,
        workoutSelection: null,
      ),
    );
    return _state;
  }

  @override
  Future<GoogleWorkspaceState> adoptSelectedSpreadsheet(
    SelectedSpreadsheet selected,
  ) async {
    final authorization = _currentPickerAuthorization(_accountSession);
    final updatedAccessState = await _updateAccessStateBestEffort(
      (accessState) => GoogleWorkspaceAccessState(
        spreadsheetText: selected.spreadsheetId,
        selectedSpreadsheet: selected,
        googleAuthorization: authorization ?? accessState.googleAuthorization,
        workoutSelection: accessState.workoutSelection,
      ),
    );
    _setState(
      _stateWith(
        selectedSpreadsheet: selected,
        pastedSpreadsheetText: selected.spreadsheetId,
        pickerAuthorization:
            authorization ?? updatedAccessState?.googleAuthorization,
        workoutSelection:
            updatedAccessState?.workoutSelection ?? _state.workoutSelection,
      ),
    );
    return _state;
  }

  @override
  Future<GoogleWorkspaceState> chooseSpreadsheet() async {
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
  Future<bool> authorizeSpreadsheetCreation() async {
    if (_isCommandInFlight) {
      return false;
    }
    _beginCommand();
    try {
      final picker = _spreadsheetPicker;
      if (picker != null) {
        return await picker.authorizeSpreadsheetCreation();
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
  Future<GoogleWorkspaceState> createSpreadsheet({String? name}) async {
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
  Future<SelectedSpreadsheet> resolveSelectedSpreadsheet(
    SelectedSpreadsheet selected,
  ) async {
    final picker = _spreadsheetPicker;
    if (picker == null) {
      return selected;
    }
    try {
      final resolved = await picker.resolveSelectedSpreadsheet(selected);
      await adoptSelectedSpreadsheet(resolved);
      return resolved;
    } on Object {
      return selected;
    }
  }

  @override
  Future<GoogleWorkspaceState> persistWorkoutSelection(
    WorkoutSelectionState selection,
  ) async {
    final updatedAccessState = await _updateAccessStateBestEffort(
      (accessState) => GoogleWorkspaceAccessState(
        spreadsheetText: accessState.spreadsheetText,
        selectedSpreadsheet: accessState.selectedSpreadsheet,
        googleAuthorization: accessState.googleAuthorization,
        workoutSelection: selection,
      ),
    );
    _setState(
      _stateWith(
        selectedSpreadsheet: _state.selectedSpreadsheet,
        pastedSpreadsheetText: _state.pastedSpreadsheetText,
        pickerAuthorization:
            updatedAccessState?.googleAuthorization ??
            _state.pickerAuthorization,
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
  Future<GoogleWorkspaceState> signOut() async {
    if (_isCommandInFlight) {
      return _state;
    }
    _beginCommand();
    try {
      await _accountSession?.signOut();
      await _accessState?.clear();
      _setState(
        GoogleWorkspaceState(
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

  Future<GoogleWorkspaceAccessState?> _restoreAccessState() async {
    try {
      return await _accessState?.restore();
    } on Object {
      return null;
    }
  }

  void _restorePickerAuthorization(
    GooglePickerAuthorizationSnapshot? authorization,
  ) {
    final accountSession = _accountSession;
    if (accountSession case final GooglePickerAuthorizationStore store) {
      store.restoreGooglePickerAuthorization(authorization);
    }
  }

  Future<GoogleWorkspaceAccessState?> _updateAccessStateBestEffort(
    GoogleWorkspaceAccessState Function(GoogleWorkspaceAccessState current)
    updateState,
  ) async {
    try {
      return await _accessState?.update(updateState);
    } on Object {
      return null;
    }
  }

  void _setState(GoogleWorkspaceState state) {
    _state = state;
    notifyListeners();
  }

  Future<GoogleWorkspaceState> _runStateCommand(
    Future<GoogleWorkspaceState> Function() action,
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

  GoogleWorkspaceState _stateWith({
    required SelectedSpreadsheet? selectedSpreadsheet,
    required String? pastedSpreadsheetText,
    GooglePickerAuthorizationSnapshot? pickerAuthorization,
    required WorkoutSelectionState? workoutSelection,
    bool? isCommandInFlight,
  }) {
    return GoogleWorkspaceState(
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

GooglePickerAuthorizationSnapshot? _currentPickerAuthorization(
  GoogleAccountSession? accountSession,
) {
  if (accountSession case final GooglePickerAuthorizationStore store) {
    return store.currentAuthorization;
  }
  return null;
}

String? _trimmedOrNull(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}
