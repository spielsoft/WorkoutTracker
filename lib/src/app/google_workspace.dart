import 'package:flutter/foundation.dart';

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
    required this.pickerAvailability,
  });

  final SelectedSpreadsheet? selectedSpreadsheet;
  final String? pastedSpreadsheetText;
  final GoogleAccountProfile? accountProfile;
  final GooglePickerAuthorizationSnapshot? pickerAuthorization;
  final WorkoutSelectionState? workoutSelection;
  final SpreadsheetPickerAvailability pickerAvailability;

  bool get pastedSheetFallbackAvailable {
    return selectedSpreadsheet == null && !pickerAvailability.canChoose;
  }
}

abstract interface class GoogleWorkspaceLifecycle implements Listenable {
  GoogleWorkspaceState get state;

  Future<GoogleWorkspaceState> restore();

  Future<GoogleWorkspaceState> persistPastedSpreadsheetText(String text);

  Future<GoogleWorkspaceState> adoptSelectedSpreadsheet(
    SelectedSpreadsheet selected,
  );

  Future<SelectedSpreadsheet> resolveSelectedSpreadsheet(
    SelectedSpreadsheet selected,
  );

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
         pickerAvailability: _availabilityFor(spreadsheetPicker),
       );

  final GoogleWorkspaceAccessStateOwner? _accessState;
  final GoogleAccountSession? _accountSession;
  final SpreadsheetPicker? _spreadsheetPicker;
  final String _initialSpreadsheetText;
  final SelectedSpreadsheet? _initialSelectedSpreadsheet;
  GoogleWorkspaceState _state;

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
      pickerAvailability: _availabilityFor(_spreadsheetPicker),
    );
    notifyListeners();
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

  GoogleWorkspaceState _stateWith({
    required SelectedSpreadsheet? selectedSpreadsheet,
    required String? pastedSpreadsheetText,
    GooglePickerAuthorizationSnapshot? pickerAuthorization,
    required WorkoutSelectionState? workoutSelection,
  }) {
    return GoogleWorkspaceState(
      selectedSpreadsheet: selectedSpreadsheet,
      pastedSpreadsheetText: pastedSpreadsheetText,
      accountProfile: _accountSession?.currentAccount,
      pickerAuthorization:
          pickerAuthorization ?? _currentPickerAuthorization(_accountSession),
      workoutSelection: workoutSelection,
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
