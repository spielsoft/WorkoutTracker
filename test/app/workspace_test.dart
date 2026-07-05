import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_tracker/app.dart';

void main() {
  test(
    'restores selected sheet, account, picker availability, and fallback',
    () async {
      final accessState = _MemoryWorkspaceStateOwner(
        const WorkspaceAccessState(
          spreadsheetText: 'pasted-spreadsheet-id',
          selectedSpreadsheet: SelectedSpreadsheet(
            spreadsheetId: 'selected-spreadsheet-id',
            name: '2026 Workouts',
            drivePath: 'My Drive / Workouts / 2026 Workouts',
            accountEmail: 'athlete@example.com',
          ),
          pickerAuth: PickerAuth(
            accessToken: 'picker-access-token',
            accountEmail: 'athlete@example.com',
            displayName: 'Athlete Name',
          ),
        ),
      );
      final accountSession = PickerAuthGateway();
      final workspace = WorkspaceController(
        accessStateOwner: accessState,
        accountSession: accountSession,
        picker: const DisabledPicker(reason: 'Picker is unavailable.'),
      );

      final restored = await workspace.restore();

      expect(
        restored.selectedSpreadsheet?.spreadsheetId,
        'selected-spreadsheet-id',
      );
      expect(
        restored.selectedSpreadsheet?.displayLabel,
        'My Drive / Workouts / 2026 Workouts',
      );
      expect(restored.pastedText, 'pasted-spreadsheet-id');
      expect(restored.accountProfile?.email, 'athlete@example.com');
      expect(restored.accountProfile?.displayName, 'Athlete Name');
      expect(restored.pickerAuthorization?.accessToken, 'picker-access-token');
      expect(restored.workoutSelection?.workout, isNull);
      expect(restored.pickerAvailability.canChoose, isFalse);
      expect(restored.fallbackAvailable, isFalse);
      expect(workspace.state, same(restored));
    },
  );

  test(
    'restores pasted sheet fallback when picker choosing is unavailable',
    () async {
      final workspace = WorkspaceController(
        accessStateOwner: _MemoryWorkspaceStateOwner(
          const WorkspaceAccessState(spreadsheetText: 'pasted-spreadsheet-id'),
        ),
        picker: const DisabledPicker(reason: 'Picker is unavailable.'),
      );

      final restored = await workspace.restore();

      expect(restored.selectedSpreadsheet, isNull);
      expect(restored.pastedText, 'pasted-spreadsheet-id');
      expect(restored.pickerAvailability.canChoose, isFalse);
      expect(restored.fallbackAvailable, isTrue);
    },
  );

  test(
    'persists selected sheet, pasted sheet text, picker auth, and workout selection',
    () async {
      final accessState = _MemoryWorkspaceStateOwner(
        const WorkspaceAccessState(),
      );
      final accountSession = PickerAuthGateway();
      final picker = _ResolvingSpreadsheetPicker(
        const SelectedSpreadsheet(
          spreadsheetId: 'resolved-spreadsheet-id',
          name: 'Resolved Workouts',
          drivePath: 'My Drive / Resolved Workouts',
          accountEmail: 'athlete@example.com',
        ),
      );
      final workspace = WorkspaceController(
        accessStateOwner: accessState,
        accountSession: accountSession,
        picker: picker,
      );

      await workspace.persistPastedText(
        ' https://docs.google.com/spreadsheets/d/pasted-id/edit ',
      );

      expect(
        accessState.value.spreadsheetText,
        'https://docs.google.com/spreadsheets/d/pasted-id/edit',
      );

      accountSession.updatePickerAuth(
        const PickerAuth(
          accessToken: 'picker-token',
          accountEmail: 'athlete@example.com',
          displayName: 'Athlete Name',
        ),
      );
      final selected = await workspace.resolveSelection(
        const SelectedSpreadsheet(
          spreadsheetId: 'selected-spreadsheet-id',
          name: 'Original Workouts',
        ),
      );

      expect(selected.spreadsheetId, 'resolved-spreadsheet-id');
      expect(accessState.value.spreadsheetText, 'resolved-spreadsheet-id');
      expect(
        accessState.value.selectedSpreadsheet?.displayLabel,
        'My Drive / Resolved Workouts',
      );
      expect(accessState.value.pickerAuth?.accessToken, 'picker-token');

      await workspace.persistWorkoutSelection(
        const WorkoutSelectionState(
          spreadsheetId: 'resolved-spreadsheet-id',
          workout: 'Legs',
          historyBlock: 'Week 1',
        ),
      );

      expect(
        workspace.workoutSelectionFor('resolved-spreadsheet-id')?.workout,
        'Legs',
      );
      expect(accessState.value.workoutSelection?.historyBlock, 'Week 1');
    },
  );

  test('switches to pasted sheet text through a workspace command', () async {
    final accessState = _MemoryWorkspaceStateOwner(
      const WorkspaceAccessState(
        spreadsheetText: 'selected-spreadsheet-id',
        selectedSpreadsheet: SelectedSpreadsheet(
          spreadsheetId: 'selected-spreadsheet-id',
          name: 'Selected Workouts',
        ),
        pickerAuth: PickerAuth(
          accessToken: 'picker-token',
          accountEmail: 'athlete@example.com',
        ),
        workoutSelection: WorkoutSelectionState(
          spreadsheetId: 'selected-spreadsheet-id',
          workout: 'Legs',
          historyBlock: 'Week 1',
        ),
      ),
    );
    final workspace = WorkspaceController(accessStateOwner: accessState);
    await workspace.restore();

    final state = await workspace.usePastedSpreadsheetText(
      ' pasted-spreadsheet-id ',
    );

    expect(state.selectedSpreadsheet, isNull);
    expect(state.pastedText, 'pasted-spreadsheet-id');
    expect(state.workoutSelection, isNull);
    expect(accessState.value.selectedSpreadsheet, isNull);
    expect(accessState.value.spreadsheetText, 'pasted-spreadsheet-id');
    expect(accessState.value.pickerAuth?.accessToken, 'picker-token');
    expect(accessState.value.workoutSelection, isNull);
  });

  test(
    'restores and resolves a saved selected sheet in one workspace command',
    () async {
      final accessState = _MemoryWorkspaceStateOwner(
        const WorkspaceAccessState(
          selectedSpreadsheet: SelectedSpreadsheet(
            spreadsheetId: 'saved-spreadsheet-id',
            name: 'Saved Workouts',
          ),
        ),
      );
      final picker = _ResolvingSpreadsheetPicker(
        const SelectedSpreadsheet(
          spreadsheetId: 'resolved-spreadsheet-id',
          name: 'Resolved Workouts',
        ),
      );
      final workspace = WorkspaceController(
        accessStateOwner: accessState,
        picker: picker,
      );

      final state = await workspace.restoreResolved();

      expect(
        state.selectedSpreadsheet?.spreadsheetId,
        'resolved-spreadsheet-id',
      );
      expect(accessState.value.spreadsheetText, 'resolved-spreadsheet-id');
      expect(
        accessState.value.selectedSpreadsheet?.displayLabel,
        'Resolved Workouts',
      );
    },
  );

  test(
    'chooses and adopts a spreadsheet through the workspace command',
    () async {
      final accessState = _MemoryWorkspaceStateOwner(
        const WorkspaceAccessState(spreadsheetText: 'previous-id'),
      );
      final accountSession = PickerAuthGateway();
      accountSession.updatePickerAuth(
        const PickerAuth(
          accessToken: 'picker-token',
          accountEmail: 'athlete@example.com',
        ),
      );
      final picker = _CommandSpreadsheetPicker(
        chooseResult: const SelectedSpreadsheet(
          spreadsheetId: 'chosen-spreadsheet-id',
          name: 'Chosen Workouts',
          accountEmail: 'athlete@example.com',
        ),
      );
      final workspace = WorkspaceController(
        accessStateOwner: accessState,
        accountSession: accountSession,
        picker: picker,
      );

      final state = await workspace.chooseSpreadsheet();

      expect(picker.chooseCount, 1);
      expect(state.selectedSpreadsheet?.spreadsheetId, 'chosen-spreadsheet-id');
      expect(accessState.value.spreadsheetText, 'chosen-spreadsheet-id');
      expect(
        accessState.value.selectedSpreadsheet?.displayLabel,
        'Chosen Workouts',
      );
      expect(accessState.value.pickerAuth?.accessToken, 'picker-token');
      expect(workspace.state.isCommandInFlight, isFalse);
    },
  );

  test('authorizes creation and adopts a created spreadsheet', () async {
    final accessState = _MemoryWorkspaceStateOwner(
      const WorkspaceAccessState(),
    );
    final picker = _CommandSpreadsheetPicker(
      creationAuthorizationResult: true,
      createResult: const SelectedSpreadsheet(
        spreadsheetId: 'created-spreadsheet-id',
        name: 'Custom Training Log',
        accountEmail: 'athlete@example.com',
      ),
    );
    final workspace = WorkspaceController(
      accessStateOwner: accessState,
      picker: picker,
    );

    final authorized = await workspace.authorizeSheetCreation();
    final state = await workspace.createSpreadsheet(
      name: 'Custom Training Log',
    );

    expect(authorized, isTrue);
    expect(picker.creationAuthorizationCount, 1);
    expect(picker.createCount, 1);
    expect(picker.createNames, ['Custom Training Log']);
    expect(state.selectedSpreadsheet?.spreadsheetId, 'created-spreadsheet-id');
    expect(accessState.value.spreadsheetText, 'created-spreadsheet-id');
    expect(
      accessState.value.selectedSpreadsheet?.displayLabel,
      'Custom Training Log',
    );
  });

  test('blocks duplicate picker commands while one is in flight', () async {
    final picker = _CommandSpreadsheetPicker(
      chooseResult: const SelectedSpreadsheet(
        spreadsheetId: 'chosen-spreadsheet-id',
        name: 'Chosen Workouts',
      ),
    );
    final chooseCompleter = Completer<SelectedSpreadsheet?>();
    picker.chooseFuture = chooseCompleter.future;
    final workspace = WorkspaceController(picker: picker);

    final first = workspace.chooseSpreadsheet();
    final second = workspace.chooseSpreadsheet();

    expect(picker.chooseCount, 1);
    expect(workspace.state.isCommandInFlight, isTrue);

    chooseCompleter.complete(picker.chooseResult);
    await first;
    final duplicateState = await second;

    expect(duplicateState.selectedSpreadsheet, isNull);
    expect(
      workspace.state.selectedSpreadsheet?.spreadsheetId,
      'chosen-spreadsheet-id',
    );
    expect(workspace.state.isCommandInFlight, isFalse);
  });

  test('logs out through workspace cleanup', () async {
    final accessState = _MemoryWorkspaceStateOwner(
      const WorkspaceAccessState(
        spreadsheetText: 'selected-spreadsheet-id',
        selectedSpreadsheet: SelectedSpreadsheet(
          spreadsheetId: 'selected-spreadsheet-id',
          name: 'Selected Workouts',
        ),
        pickerAuth: PickerAuth(
          accessToken: 'picker-token',
          accountEmail: 'athlete@example.com',
        ),
        workoutSelection: WorkoutSelectionState(
          spreadsheetId: 'selected-spreadsheet-id',
          workout: 'Legs',
          historyBlock: 'Week 1',
        ),
      ),
    );
    final accountSession = _RecordingGoogleAccountSession(
      const GoogleAccountProfile(email: 'athlete@example.com'),
    );
    final workspace = WorkspaceController(
      accessStateOwner: accessState,
      accountSession: accountSession,
      picker: _CommandSpreadsheetPicker(),
    );
    await workspace.restore();

    final state = await workspace.signOut();

    expect(accountSession.signOutCount, 1);
    expect(accessState.value.selectedSpreadsheet, isNull);
    expect(accessState.value.spreadsheetText, isNull);
    expect(accessState.value.pickerAuth, isNull);
    expect(accessState.value.workoutSelection, isNull);
    expect(state.selectedSpreadsheet, isNull);
    expect(state.pastedText, isNull);
    expect(state.accountProfile, isNull);
    expect(state.pickerAuthorization, isNull);
    expect(state.workoutSelection, isNull);
  });
}

class _MemoryWorkspaceStateOwner implements WorkspaceStateOwner {
  _MemoryWorkspaceStateOwner(this.value);

  @override
  WorkspaceAccessState value;

  @override
  Future<void> clear() async {
    value = const WorkspaceAccessState();
  }

  @override
  Future<WorkspaceAccessState> restore() async {
    return value;
  }

  @override
  Future<WorkspaceAccessState> update(
    WorkspaceAccessState Function(WorkspaceAccessState current) updateState,
  ) async {
    value = updateState(value);
    return value;
  }
}

class _ResolvingSpreadsheetPicker implements SpreadsheetPicker {
  const _ResolvingSpreadsheetPicker(this.resolved);

  final SelectedSpreadsheet resolved;

  @override
  PickerAvailability get availability {
    return const PickerAvailability.available();
  }

  @override
  Future<bool> authorizeSheetCreation() async {
    return true;
  }

  @override
  Future<SelectedSpreadsheet?> chooseSpreadsheet() async {
    return null;
  }

  @override
  Future<SelectedSpreadsheet?> createSpreadsheet({String? name}) async {
    return null;
  }

  @override
  Future<SelectedSpreadsheet> resolveSelection(
    SelectedSpreadsheet selected,
  ) async {
    return resolved;
  }
}

class _CommandSpreadsheetPicker implements SpreadsheetPicker {
  _CommandSpreadsheetPicker({
    this.chooseResult,
    this.creationAuthorizationResult = true,
    this.createResult,
  });

  final SelectedSpreadsheet? chooseResult;
  final bool creationAuthorizationResult;
  final SelectedSpreadsheet? createResult;
  Future<SelectedSpreadsheet?>? chooseFuture;
  int chooseCount = 0;
  int creationAuthorizationCount = 0;
  int createCount = 0;
  final createNames = <String?>[];

  @override
  PickerAvailability get availability {
    return const PickerAvailability.available();
  }

  @override
  Future<SelectedSpreadsheet?> chooseSpreadsheet() {
    chooseCount += 1;
    return chooseFuture ?? Future.value(chooseResult);
  }

  @override
  Future<bool> authorizeSheetCreation() async {
    creationAuthorizationCount += 1;
    return creationAuthorizationResult;
  }

  @override
  Future<SelectedSpreadsheet?> createSpreadsheet({String? name}) async {
    createCount += 1;
    createNames.add(name);
    return createResult;
  }

  @override
  Future<SelectedSpreadsheet> resolveSelection(
    SelectedSpreadsheet selected,
  ) async {
    return selected;
  }
}

class _RecordingGoogleAccountSession extends ChangeNotifier
    implements GoogleAccountSession {
  _RecordingGoogleAccountSession(this._currentAccount);

  GoogleAccountProfile? _currentAccount;
  int signOutCount = 0;

  @override
  GoogleAccountProfile? get currentAccount => _currentAccount;

  @override
  Future<void> restoreAccount() async {}

  @override
  Future<void> switchAccount({List<String> scopes = const []}) async {}

  @override
  Future<void> signOut() async {
    signOutCount += 1;
    _currentAccount = null;
    notifyListeners();
  }
}
