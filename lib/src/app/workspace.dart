import 'package:flutter/foundation.dart';
import 'state_store.dart';
import 'account_session.dart';
import 'auth_client.dart';
import 'selection.dart';

const _pickerConfigReason =
    'Google Drive sheet selection is not configured for this build.';
const _restoreError =
    'Saved workspace could not be restored. Your current session can '
    'continue, but previous choices may need to be selected again.';
const _persistError =
    'This choice could not be saved. It remains available for this session '
    'but may be lost when the app closes.';

class AcctMismatch {
  const AcctMismatch({
    required this.sheet,
    required this.savedEmail,
    required this.currentEmail,
  });

  final SelectedSheet sheet;
  final String? savedEmail;
  final String? currentEmail;
}

class WorkspaceUiSt {
  const WorkspaceUiSt({
    this.selectedSheet,
    this.pastedText,
    this.accountProfile,
    this.workoutSelection,
    this.isCommandInFlight = false,
    this.isInitializing = false,
    this.accountMismatch,
    this.error,
    required this.pickerAvailability,
  });

  final SelectedSheet? selectedSheet;
  final String? pastedText;
  final GoogleAccountProfile? accountProfile;
  final WorkoutSelectionSt? workoutSelection;
  final bool isCommandInFlight;
  final bool isInitializing;
  final AcctMismatch? accountMismatch;
  final String? error;
  final PickerAvail pickerAvailability;

  bool get fallbackAvailable {
    return selectedSheet == null && !pickerAvailability.canChoose;
  }
}

abstract interface class WorkspaceLifecycle implements Listenable {
  WorkspaceUiSt get state;

  Future<WorkspaceUiSt> restore();

  Future<WorkspaceUiSt> persistPastedText(String text);

  Future<WorkspaceUiSt> chooseSheet();

  Future<WorkspaceUiSt> signIn();

  Future<WorkspaceUiSt> createSheet({String? name});

  Future<WorkspaceUiSt> confirmAccount();

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
       _needsInit =
           accessStOwner != null ||
           accountSession != null ||
           (initialSelection != null && picker != null),
       _initialText = initialText,
       _initialSelection = initialSelection,
       _state = WorkspaceUiSt(
         selectedSheet: initialSelection,
         pastedText: _trimmedOrNull(initialText),
         accountProfile: accountSession?.currentAccount,
         workoutSelection: null,
         isCommandInFlight: false,
         isInitializing:
             accessStOwner != null ||
             accountSession != null ||
             (initialSelection != null && picker != null),
         pickerAvailability: _availabilityFor(picker),
       );

  final WorkspaceStOwner? _accessSt;
  final GoogleAccountSession? _accountSession;
  final SheetPicker? _picker;
  final bool _needsInit;
  final String _initialText;
  final SelectedSheet? _initialSelection;
  WorkspaceUiSt _state;
  bool _isCommandInFlight = false;

  @override
  WorkspaceUiSt get state => _state;

  void clearError() {
    if (_state.error == null) return;
    _setUiSt(
      _stateWith(
        selectedSheet: _state.selectedSheet,
        pastedText: _state.pastedText,
        workoutSelection: _state.workoutSelection,
        clearError: true,
      ),
    );
  }

  @override
  Future<WorkspaceUiSt> restore() {
    if (!_needsInit) return _restore();
    return _runStCmd(_restore, initializing: true);
  }

  Future<WorkspaceUiSt> _restore() async {
    await _restoreAccount();
    final restored = await _restoreAccessSt();
    final accessSt = restored.state ?? const WorkspaceAccessSt();
    _state = WorkspaceUiSt(
      selectedSheet: accessSt.selectedSheet ?? _initialSelection,
      pastedText:
          _trimmedOrNull(accessSt.sheetText) ?? _trimmedOrNull(_initialText),
      accountProfile: _accountSession?.currentAccount,
      workoutSelection: accessSt.workoutSelection,
      isCommandInFlight: _isCommandInFlight,
      isInitializing: _needsInit,
      accountMismatch: switch (accessSt.selectedSheet ?? _initialSelection) {
        final selected? => _mismatchFor(selected),
        null => null,
      },
      error: restored.failed ? _restoreError : null,
      pickerAvailability: _availabilityFor(_picker),
    );
    notifyListeners();
    return _state;
  }

  @override
  Future<WorkspaceUiSt> persistPastedText(String text) async {
    final persistedText = _trimmedOrNull(text);
    final saved = await _updateSt(
      (accessSt) => WorkspaceAccessSt(
        sheetText: persistedText,
        selectedSheet: accessSt.selectedSheet,
        workoutSelection: accessSt.workoutSelection,
      ),
    );
    _setUiSt(
      _stateWith(
        selectedSheet: _state.selectedSheet,
        pastedText: persistedText,
        workoutSelection: _state.workoutSelection,
        error: saved.failed ? _persistError : null,
        clearError: true,
      ),
    );
    return _state;
  }

  Future<WorkspaceUiSt> _adoptSelection(SelectedSheet selected) async {
    final saved = await _updateSt(
      (accessSt) => WorkspaceAccessSt(
        sheetText: selected.id,
        selectedSheet: selected,
        workoutSelection: accessSt.workoutSelection,
      ),
    );
    _setUiSt(
      _stateWith(
        selectedSheet: selected,
        pastedText: selected.id,
        workoutSelection:
            saved.state?.workoutSelection ?? _state.workoutSelection,
        error: saved.failed ? _persistError : null,
        clearIssue: true,
      ),
    );
    return _state;
  }

  @override
  Future<WorkspaceUiSt> signIn() {
    return _runStCmd(() async {
      final account = _accountSession;
      if (account == null) {
        return _state;
      }
      await account.signIn(scopes: sheetScopes);
      final selected = _state.selectedSheet;
      _setUiSt(
        _stateWith(
          selectedSheet: selected,
          pastedText: _state.pastedText,
          workoutSelection: _state.workoutSelection,
          accountMismatch: selected == null ? null : _mismatchFor(selected),
          clearMismatch: true,
        ),
      );
      return _state;
    });
  }

  @override
  Future<WorkspaceUiSt> chooseSheet() async {
    final picker = _picker;
    if (picker == null ||
        (_accountSession != null && _accountSession.currentAccount == null)) {
      return _state;
    }
    return _runStCmd(() async {
      final selected = await picker.chooseSheet();
      if (selected == null) {
        return _state;
      }
      return _adoptSelection(selected);
    });
  }

  @override
  Future<WorkspaceUiSt> createSheet({String? name}) async {
    final picker = _picker;
    if (picker == null ||
        (_accountSession != null && _accountSession.currentAccount == null)) {
      return _state;
    }
    return _runStCmd(() async {
      final selected = await picker.createSheet(name: name);
      if (selected == null) {
        return _state;
      }
      return _adoptSelection(selected);
    });
  }

  @override
  Future<WorkspaceUiSt> confirmAccount() {
    return _runStCmd(() async {
      final mismatch = _state.accountMismatch;
      final currentEmail = _accountSession?.currentAccount?.email;
      if (mismatch == null || currentEmail == null) {
        return _state;
      }
      final rebound = SelectedSheet(
        spreadsheetId: mismatch.sheet.id,
        name: mismatch.sheet.name,
        drivePath: mismatch.sheet.drivePath,
        webViewLink: mismatch.sheet.webViewLink,
        accountEmail: currentEmail,
      );
      await _adoptSelection(rebound);
      return _state;
    });
  }

  @override
  Future<WorkspaceUiSt> persistWorkoutSelection(
    WorkoutSelectionSt selection,
  ) async {
    final saved = await _updateSt(
      (accessSt) => WorkspaceAccessSt(
        sheetText: accessSt.sheetText,
        selectedSheet: accessSt.selectedSheet,
        workoutSelection: selection,
      ),
    );
    _setUiSt(
      _stateWith(
        selectedSheet: _state.selectedSheet,
        pastedText: _state.pastedText,
        workoutSelection: selection,
        error: saved.failed ? _persistError : null,
        clearError: true,
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
          workoutSelection: null,
          isCommandInFlight: _isCommandInFlight,
          isInitializing: false,
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
      await _accountSession?.restoreAccount(scopes: sheetScopes);
    } on Object {
      // Startup restore is best-effort; explicit account actions report errors.
    }
  }

  AcctMismatch? _mismatchFor(SelectedSheet selected) {
    if (_accountSession == null) return null;
    return _mismatchForSelection(selected, _accountSession.currentAccount);
  }

  Future<({WorkspaceAccessSt? state, bool failed})> _restoreAccessSt() async {
    final accessSt = _accessSt;
    if (accessSt == null) return (state: null, failed: false);
    try {
      return (state: await accessSt.restore(), failed: false);
    } on Object {
      return (state: null, failed: true);
    }
  }

  Future<({WorkspaceAccessSt? state, bool failed})> _updateSt(
    WorkspaceAccessSt Function(WorkspaceAccessSt current) updateFn,
  ) async {
    final accessSt = _accessSt;
    if (accessSt == null) return (state: null, failed: false);
    try {
      return (state: await accessSt.update(updateFn), failed: false);
    } on Object {
      return (state: null, failed: true);
    }
  }

  void _setUiSt(WorkspaceUiSt state) {
    _state = state;
    notifyListeners();
  }

  Future<WorkspaceUiSt> _runStCmd(
    Future<WorkspaceUiSt> Function() action, {
    bool initializing = false,
  }) async {
    if (_isCommandInFlight) {
      return _state;
    }
    _beginCommand(initializing: initializing);
    try {
      await action();
    } finally {
      _endCommand();
    }
    return _state;
  }

  void _beginCommand({bool initializing = false}) {
    _isCommandInFlight = true;
    _setUiSt(
      _stateWith(
        selectedSheet: _state.selectedSheet,
        pastedText: _state.pastedText,
        workoutSelection: _state.workoutSelection,
        isCommandInFlight: true,
        isInitializing: initializing,
      ),
    );
  }

  void _endCommand() {
    _isCommandInFlight = false;
    _setUiSt(
      _stateWith(
        selectedSheet: _state.selectedSheet,
        pastedText: _state.pastedText,
        workoutSelection: _state.workoutSelection,
        isCommandInFlight: false,
        isInitializing: false,
      ),
    );
  }

  WorkspaceUiSt _stateWith({
    required SelectedSheet? selectedSheet,
    required String? pastedText,
    required WorkoutSelectionSt? workoutSelection,
    bool? isCommandInFlight,
    bool? isInitializing,
    AcctMismatch? accountMismatch,
    String? error,
    bool clearIssue = false,
    bool clearMismatch = false,
    bool clearError = false,
  }) {
    return WorkspaceUiSt(
      selectedSheet: selectedSheet,
      pastedText: pastedText,
      accountProfile: _accountSession?.currentAccount,
      workoutSelection: workoutSelection,
      isCommandInFlight: isCommandInFlight ?? _state.isCommandInFlight,
      isInitializing: isInitializing ?? _state.isInitializing,
      accountMismatch: clearIssue || clearMismatch
          ? accountMismatch
          : accountMismatch ?? _state.accountMismatch,
      error: clearIssue || clearError ? error : error ?? _state.error,
      pickerAvailability: _availabilityFor(_picker),
    );
  }
}

AcctMismatch? _mismatchForSelection(
  SelectedSheet selected,
  GoogleAccountProfile? current,
) {
  final savedEmail = _normalizedEmail(selected.accountEmail);
  final currentEmail = _normalizedEmail(current?.email);
  if (savedEmail == currentEmail && savedEmail != null) {
    return null;
  }
  if (savedEmail == null && currentEmail == null) {
    return null;
  }
  return AcctMismatch(
    sheet: selected,
    savedEmail: selected.accountEmail,
    currentEmail: current?.email,
  );
}

String? _normalizedEmail(String? email) {
  final normalized = email?.trim().toLowerCase();
  return normalized == null || normalized.isEmpty ? null : normalized;
}

PickerAvail _availabilityFor(SheetPicker? picker) {
  return picker?.availability ??
      const PickerAvail.unavailable(
        chooseReason: _pickerConfigReason,
        createReason: _pickerConfigReason,
      );
}

String? _trimmedOrNull(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}
