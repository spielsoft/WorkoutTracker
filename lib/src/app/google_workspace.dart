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
    required this.pickerAvailability,
  });

  final SelectedSpreadsheet? selectedSpreadsheet;
  final String? pastedSpreadsheetText;
  final GoogleAccountProfile? accountProfile;
  final GooglePickerAuthorizationSnapshot? pickerAuthorization;
  final SpreadsheetPickerAvailability pickerAvailability;

  bool get pastedSheetFallbackAvailable {
    return selectedSpreadsheet == null && !pickerAvailability.canChoose;
  }
}

abstract interface class GoogleWorkspaceLifecycle implements Listenable {
  GoogleWorkspaceState get state;

  Future<GoogleWorkspaceState> restore();
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
      pickerAvailability: _availabilityFor(_spreadsheetPicker),
    );
    notifyListeners();
    return _state;
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
