import 'package:flutter/foundation.dart';
import 'package:workout_tracker/sheets.dart';

import 'state_store.dart';
import 'account_session.dart';
import 'selection.dart';

const _pickerConfigReason =
    'Google Drive Picker is not configured for this build.';

class WorkspaceUiSt {
  const WorkspaceUiSt({
    this.selectedSheet,
    this.pastedText,
    this.accountProfile,
    this.pickerAuthorization,
    this.workoutSelection,
    this.isCommandInFlight = false,
    required this.pickerAvailability,
  });

  final SelectedSheet? selectedSheet;
  final String? pastedText;
  final GoogleAccountProfile? accountProfile;
  final PickerAuth? pickerAuthorization;
  final WorkoutSelectionSt? workoutSelection;
  final bool isCommandInFlight;
  final PickerAvail pickerAvailability;

  bool get fallbackAvailable {
    return selectedSheet == null && !pickerAvailability.canChoose;
  }
}

abstract interface class WorkspaceLifecycle implements Listenable {
  WorkspaceUiSt get state;

  Future<WorkspaceUiSt> restore();

  Future<WorkspaceUiSt> restoreResolved();

  Future<WorkspaceUiSt> persistPastedText(String text);

  Future<WorkspaceUiSt> usePastedSheetText(String text);

  Future<WorkspaceUiSt> adoptSelection(SelectedSheet selected);

  Future<WorkspaceUiSt> chooseSheet();

  Future<bool> authorizeSheetCreation();

  Future<WorkspaceUiSt> createSheet({String? name});

  Future<SelectedSheet> resolveSelection(SelectedSheet selected);

  Future<WorkspaceUiSt> signOut();

  Future<WorkspaceUiSt> persistWorkoutSelection(WorkoutSelectionSt selection);

  WorkoutSelectionSt? workoutSelectionFor(String sheetId);
}

class WorkspaceCtrl extends ChangeNotifier implements WorkspaceLifecycle {
  WorkspaceCtrl({
    WorkspaceStOwner? accessStOwner,
    GoogleAccountSession? accountSession,
    SheetPicker? picker,
    String initialText = '',
    SelectedSheet? initialSelection,
  }) : _accessSt = accessStOwner,
       _accountSession = accountSession,
       _picker = picker,
       _initialText = initialText,
       _initialSelection = initialSelection,
       _state = WorkspaceUiSt(
         selectedSheet: initialSelection,
         pastedText: _trimmedOrNull(initialText),
         accountProfile: accountSession?.currentAccount,
         pickerAuthorization: _currentAuth(accountSession),
         workoutSelection: null,
         isCommandInFlight: false,
         pickerAvailability: _availabilityFor(picker),
       );

  final WorkspaceStOwner? _accessSt;
  final GoogleAccountSession? _accountSession;
  final SheetPicker? _picker;
  final String _initialText;
  final SelectedSheet? _initialSelection;
  WorkspaceUiSt _state;
  bool _isCommandInFlight = false;

  @override
  WorkspaceUiSt get state => _state;

  @override
  Future<WorkspaceUiSt> restore() async {
    await _restoreAccount();
    final restoredAccessSt = await _restoreAccessSt();
    final accessSt = restoredAccessSt ?? const WorkspaceAccessSt();
    if (restoredAccessSt != null) {
      _restoreAuth(accessSt.pickerAuth);
    }
    _state = WorkspaceUiSt(
      selectedSheet: accessSt.selectedSheet ?? _initialSelection,
      pastedText:
          _trimmedOrNull(accessSt.sheetText) ?? _trimmedOrNull(_initialText),
      accountProfile: _accountSession?.currentAccount,
      pickerAuthorization: _currentAuth(_accountSession),
      workoutSelection: accessSt.workoutSelection,
      isCommandInFlight: _isCommandInFlight,
      pickerAvailability: _availabilityFor(_picker),
    );
    notifyListeners();
    return _state;
  }

  @override
  Future<WorkspaceUiSt> restoreResolved() async {
    final restored = await restore();
    final selected = restored.selectedSheet;
    if (selected == null) {
      return restored;
    }
    await resolveSelection(selected);
    return _state;
  }

  @override
  Future<WorkspaceUiSt> persistPastedText(String text) async {
    final persistedText = _trimmedOrNull(text);
    await _updateSt(
      (accessSt) => WorkspaceAccessSt(
        sheetText: persistedText,
        selectedSheet: accessSt.selectedSheet,
        pickerAuth: accessSt.pickerAuth,
        workoutSelection: accessSt.workoutSelection,
      ),
    );
    _setUiSt(
      _stateWith(
        selectedSheet: _state.selectedSheet,
        pastedText: persistedText,
        workoutSelection: _state.workoutSelection,
      ),
    );
    return _state;
  }

  @override
  Future<WorkspaceUiSt> usePastedSheetText(String text) async {
    final persistedText = _trimmedOrNull(text);
    final updatedAccessSt = await _updateSt(
      (accessSt) => WorkspaceAccessSt(
        sheetText: persistedText,
        selectedSheet: null,
        pickerAuth: accessSt.pickerAuth,
        workoutSelection: null,
      ),
    );
    _setUiSt(
      _stateWith(
        selectedSheet: null,
        pastedText: persistedText,
        pickerAuthorization:
            updatedAccessSt?.pickerAuth ?? _state.pickerAuthorization,
        workoutSelection: null,
      ),
    );
    return _state;
  }

  @override
  Future<WorkspaceUiSt> adoptSelection(SelectedSheet selected) async {
    final authorization = _currentAuth(_accountSession);
    final updatedAccessSt = await _updateSt(
      (accessSt) => WorkspaceAccessSt(
        sheetText: selected.id,
        selectedSheet: selected,
        pickerAuth: authorization ?? accessSt.pickerAuth,
        workoutSelection: accessSt.workoutSelection,
      ),
    );
    _setUiSt(
      _stateWith(
        selectedSheet: selected,
        pastedText: selected.id,
        pickerAuthorization: authorization ?? updatedAccessSt?.pickerAuth,
        workoutSelection:
            updatedAccessSt?.workoutSelection ?? _state.workoutSelection,
      ),
    );
    return _state;
  }

  @override
  Future<WorkspaceUiSt> chooseSheet() async {
    final picker = _picker;
    if (picker == null) {
      return _state;
    }
    return _runStCmd(() async {
      final selected = await picker.chooseSheet();
      if (selected == null) {
        return _state;
      }
      return adoptSelection(selected);
    });
  }

  @override
  Future<bool> authorizeSheetCreation() async {
    if (_isCommandInFlight) {
      return false;
    }
    _beginCommand();
    try {
      final picker = _picker;
      if (picker != null) {
        return await picker.authorizeSheetCreation();
      }

      final accountSession = _accountSession;
      if (accountSession == null || accountSession.currentAccount != null) {
        return true;
      }
      await accountSession.switchAccount(
        scopes: GoogleApisWbkClient.writeScopes,
      );
      return accountSession.currentAccount != null;
    } finally {
      _endCommand();
    }
  }

  @override
  Future<WorkspaceUiSt> createSheet({String? name}) async {
    final picker = _picker;
    if (picker == null) {
      return _state;
    }
    return _runStCmd(() async {
      final selected = await picker.createSheet(name: name);
      if (selected == null) {
        return _state;
      }
      return adoptSelection(selected);
    });
  }

  @override
  Future<SelectedSheet> resolveSelection(SelectedSheet selected) async {
    final picker = _picker;
    if (picker == null) {
      return selected;
    }
    try {
      final resolved = await picker.resolveSelection(selected);
      await adoptSelection(resolved);
      return resolved;
    } on Object {
      return selected;
    }
  }

  @override
  Future<WorkspaceUiSt> persistWorkoutSelection(
    WorkoutSelectionSt selection,
  ) async {
    final updatedAccessSt = await _updateSt(
      (accessSt) => WorkspaceAccessSt(
        sheetText: accessSt.sheetText,
        selectedSheet: accessSt.selectedSheet,
        pickerAuth: accessSt.pickerAuth,
        workoutSelection: selection,
      ),
    );
    _setUiSt(
      _stateWith(
        selectedSheet: _state.selectedSheet,
        pastedText: _state.pastedText,
        pickerAuthorization:
            updatedAccessSt?.pickerAuth ?? _state.pickerAuthorization,
        workoutSelection: selection,
      ),
    );
    return _state;
  }

  @override
  WorkoutSelectionSt? workoutSelectionFor(String sheetId) {
    final selection = _state.workoutSelection;
    if (selection == null || selection.sheetId != sheetId) {
      return null;
    }
    return selection;
  }

  @override
  Future<WorkspaceUiSt> signOut() async {
    if (_isCommandInFlight) {
      return _state;
    }
    _beginCommand();
    try {
      await _accountSession?.signOut();
      await _accessSt?.clear();
      _setUiSt(
        WorkspaceUiSt(
          selectedSheet: null,
          pastedText: null,
          accountProfile: _accountSession?.currentAccount,
          pickerAuthorization: _currentAuth(_accountSession),
          workoutSelection: null,
          isCommandInFlight: _isCommandInFlight,
          pickerAvailability: _availabilityFor(_picker),
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

  Future<WorkspaceAccessSt?> _restoreAccessSt() async {
    try {
      return await _accessSt?.restore();
    } on Object {
      return null;
    }
  }

  void _restoreAuth(PickerAuth? authorization) {
    final accountSession = _accountSession;
    if (accountSession case final PickerAuthStore store) {
      store.restorePickerAuth(authorization);
    }
  }

  Future<WorkspaceAccessSt?> _updateSt(
    WorkspaceAccessSt Function(WorkspaceAccessSt current) updateFn,
  ) async {
    try {
      return await _accessSt?.update(updateFn);
    } on Object {
      return null;
    }
  }

  void _setUiSt(WorkspaceUiSt state) {
    _state = state;
    notifyListeners();
  }

  Future<WorkspaceUiSt> _runStCmd(
    Future<WorkspaceUiSt> Function() action,
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
    _setUiSt(
      _stateWith(
        selectedSheet: _state.selectedSheet,
        pastedText: _state.pastedText,
        pickerAuthorization: _state.pickerAuthorization,
        workoutSelection: _state.workoutSelection,
        isCommandInFlight: true,
      ),
    );
  }

  void _endCommand() {
    _isCommandInFlight = false;
    _setUiSt(
      _stateWith(
        selectedSheet: _state.selectedSheet,
        pastedText: _state.pastedText,
        pickerAuthorization: _state.pickerAuthorization,
        workoutSelection: _state.workoutSelection,
        isCommandInFlight: false,
      ),
    );
  }

  WorkspaceUiSt _stateWith({
    required SelectedSheet? selectedSheet,
    required String? pastedText,
    PickerAuth? pickerAuthorization,
    required WorkoutSelectionSt? workoutSelection,
    bool? isCommandInFlight,
  }) {
    return WorkspaceUiSt(
      selectedSheet: selectedSheet,
      pastedText: pastedText,
      accountProfile: _accountSession?.currentAccount,
      pickerAuthorization: pickerAuthorization ?? _currentAuth(_accountSession),
      workoutSelection: workoutSelection,
      isCommandInFlight: isCommandInFlight ?? _state.isCommandInFlight,
      pickerAvailability: _availabilityFor(_picker),
    );
  }
}

PickerAvail _availabilityFor(SheetPicker? picker) {
  return picker?.availability ??
      const PickerAvail.unavailable(
        chooseReason: _pickerConfigReason,
        createReason: _pickerConfigReason,
      );
}

PickerAuth? _currentAuth(GoogleAccountSession? accountSession) {
  if (accountSession case final PickerAuthStore store) {
    return store.currentAuthorization;
  }
  return null;
}

String? _trimmedOrNull(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}
