import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_tracker/app.dart';

void main() {
  test(
    'restores selected sheet, account, picker availability, and fallback',
    () async {
      final accessSt = _MemoryWorkspaceStOwner(
        const WorkspaceAccessSt(
          sheetText: 'pasted-spreadsheet-id',
          selectedSheet: SelectedSheet(
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
      final workspace = WorkspaceCtrl(
        accessStOwner: accessSt,
        accountSession: accountSession,
        picker: const DisabledPicker(reason: 'Picker is unavailable.'),
      );

      final restored = await workspace.restore();

      expect(restored.selectedSheet?.id, 'selected-spreadsheet-id');
      expect(
        restored.selectedSheet?.displayLabel,
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
      final workspace = WorkspaceCtrl(
        accessStOwner: _MemoryWorkspaceStOwner(
          const WorkspaceAccessSt(sheetText: 'pasted-spreadsheet-id'),
        ),
        picker: const DisabledPicker(reason: 'Picker is unavailable.'),
      );

      final restored = await workspace.restore();

      expect(restored.selectedSheet, isNull);
      expect(restored.pastedText, 'pasted-spreadsheet-id');
      expect(restored.pickerAvailability.canChoose, isFalse);
      expect(restored.fallbackAvailable, isTrue);
    },
  );

  test(
    'persists selected sheet, pasted sheet text, picker auth, and workout selection',
    () async {
      final accessSt = _MemoryWorkspaceStOwner(const WorkspaceAccessSt());
      final accountSession = PickerAuthGateway();
      final picker = _ResolvingSheetPicker(
        const SelectedSheet(
          spreadsheetId: 'resolved-spreadsheet-id',
          name: 'Resolved Workouts',
          drivePath: 'My Drive / Resolved Workouts',
          accountEmail: 'athlete@example.com',
        ),
      );
      final workspace = WorkspaceCtrl(
        accessStOwner: accessSt,
        accountSession: accountSession,
        picker: picker,
      );

      await workspace.persistPastedText(
        ' https://docs.google.com/spreadsheets/d/pasted-id/edit ',
      );

      expect(
        accessSt.value.sheetText,
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
        const SelectedSheet(
          spreadsheetId: 'selected-spreadsheet-id',
          name: 'Original Workouts',
        ),
      );

      expect(selected.id, 'resolved-spreadsheet-id');
      expect(accessSt.value.sheetText, 'resolved-spreadsheet-id');
      expect(
        accessSt.value.selectedSheet?.displayLabel,
        'My Drive / Resolved Workouts',
      );
      expect(accessSt.value.pickerAuth?.accessToken, 'picker-token');

      await workspace.persistWorkoutSelection(
        const WorkoutSelectionSt(
          spreadsheetId: 'resolved-spreadsheet-id',
          workout: 'Legs',
          historyBlock: 'Week 1',
        ),
      );

      expect(
        workspace.workoutSelectionFor('resolved-spreadsheet-id')?.workout,
        'Legs',
      );
      expect(accessSt.value.workoutSelection?.historyBlock, 'Week 1');
    },
  );

  test('switches to pasted sheet text through a workspace command', () async {
    final accessSt = _MemoryWorkspaceStOwner(
      const WorkspaceAccessSt(
        sheetText: 'selected-spreadsheet-id',
        selectedSheet: SelectedSheet(
          spreadsheetId: 'selected-spreadsheet-id',
          name: 'Selected Workouts',
        ),
        pickerAuth: PickerAuth(
          accessToken: 'picker-token',
          accountEmail: 'athlete@example.com',
        ),
        workoutSelection: WorkoutSelectionSt(
          spreadsheetId: 'selected-spreadsheet-id',
          workout: 'Legs',
          historyBlock: 'Week 1',
        ),
      ),
    );
    final workspace = WorkspaceCtrl(accessStOwner: accessSt);
    await workspace.restore();

    final state = await workspace.usePastedSheetText(' pasted-spreadsheet-id ');

    expect(state.selectedSheet, isNull);
    expect(state.pastedText, 'pasted-spreadsheet-id');
    expect(state.workoutSelection, isNull);
    expect(accessSt.value.selectedSheet, isNull);
    expect(accessSt.value.sheetText, 'pasted-spreadsheet-id');
    expect(accessSt.value.pickerAuth, isNull);
    expect(accessSt.value.workoutSelection, isNull);
  });

  test(
    'restore clears legacy picker auth when the runtime session is not picker-backed',
    () async {
      final accessSt = _MemoryWorkspaceStOwner(
        const WorkspaceAccessSt(
          sheetText: 'selected-spreadsheet-id',
          selectedSheet: SelectedSheet(
            spreadsheetId: 'selected-spreadsheet-id',
            name: 'Selected Workouts',
          ),
          pickerAuth: PickerAuth(
            accessToken: 'picker-token',
            accountEmail: 'athlete@example.com',
          ),
        ),
      );
      final workspace = WorkspaceCtrl(
        accessStOwner: accessSt,
        accountSession: _RecordingGoogleAccountSession(
          const GoogleAccountProfile(email: 'athlete@example.com'),
        ),
      );

      final state = await workspace.restore();

      expect(state.selectedSheet?.id, 'selected-spreadsheet-id');
      expect(state.accountProfile?.email, 'athlete@example.com');
      expect(state.pickerAuthorization, isNull);
      expect(accessSt.value.pickerAuth, isNull);
    },
  );

  test(
    'restores and resolves a saved selected sheet in one workspace command',
    () async {
      final accessSt = _MemoryWorkspaceStOwner(
        const WorkspaceAccessSt(
          selectedSheet: SelectedSheet(
            spreadsheetId: 'saved-spreadsheet-id',
            name: 'Saved Workouts',
          ),
        ),
      );
      final picker = _ResolvingSheetPicker(
        const SelectedSheet(
          spreadsheetId: 'resolved-spreadsheet-id',
          name: 'Resolved Workouts',
        ),
      );
      final workspace = WorkspaceCtrl(accessStOwner: accessSt, picker: picker);

      final state = await workspace.restoreResolved();

      expect(state.selectedSheet?.id, 'resolved-spreadsheet-id');
      expect(accessSt.value.sheetText, 'resolved-spreadsheet-id');
      expect(accessSt.value.selectedSheet?.displayLabel, 'Resolved Workouts');
    },
  );

  test(
    'chooses and adopts a spreadsheet through the workspace command',
    () async {
      final accessSt = _MemoryWorkspaceStOwner(
        const WorkspaceAccessSt(sheetText: 'previous-id'),
      );
      final accountSession = PickerAuthGateway();
      accountSession.updatePickerAuth(
        const PickerAuth(
          accessToken: 'picker-token',
          accountEmail: 'athlete@example.com',
        ),
      );
      final picker = _CommandSheetPicker(
        chooseResult: const SelectedSheet(
          spreadsheetId: 'chosen-spreadsheet-id',
          name: 'Chosen Workouts',
          accountEmail: 'athlete@example.com',
        ),
      );
      final workspace = WorkspaceCtrl(
        accessStOwner: accessSt,
        accountSession: accountSession,
        picker: picker,
      );

      final state = await workspace.chooseSheet();

      expect(picker.chooseCount, 1);
      expect(state.selectedSheet?.id, 'chosen-spreadsheet-id');
      expect(accessSt.value.sheetText, 'chosen-spreadsheet-id');
      expect(accessSt.value.selectedSheet?.displayLabel, 'Chosen Workouts');
      expect(accessSt.value.pickerAuth?.accessToken, 'picker-token');
      expect(workspace.state.isCommandInFlight, isFalse);
    },
  );

  test('authorizes creation and adopts a created spreadsheet', () async {
    final accessSt = _MemoryWorkspaceStOwner(const WorkspaceAccessSt());
    final picker = _CommandSheetPicker(
      creationAuthorizationResult: true,
      createResult: const SelectedSheet(
        spreadsheetId: 'created-spreadsheet-id',
        name: 'Custom Training Log',
        accountEmail: 'athlete@example.com',
      ),
    );
    final workspace = WorkspaceCtrl(accessStOwner: accessSt, picker: picker);

    final authorized = await workspace.authorizeSheetCreation();
    final state = await workspace.createSheet(name: 'Custom Training Log');

    expect(authorized, isTrue);
    expect(picker.creationAuthorizationCount, 1);
    expect(picker.createCount, 1);
    expect(picker.createNames, ['Custom Training Log']);
    expect(state.selectedSheet?.id, 'created-spreadsheet-id');
    expect(accessSt.value.sheetText, 'created-spreadsheet-id');
    expect(accessSt.value.selectedSheet?.displayLabel, 'Custom Training Log');
  });

  test('blocks duplicate picker commands while one is in flight', () async {
    final picker = _CommandSheetPicker(
      chooseResult: const SelectedSheet(
        spreadsheetId: 'chosen-spreadsheet-id',
        name: 'Chosen Workouts',
      ),
    );
    final chooseCompleter = Completer<SelectedSheet?>();
    picker.chooseFuture = chooseCompleter.future;
    final workspace = WorkspaceCtrl(picker: picker);

    final first = workspace.chooseSheet();
    final second = workspace.chooseSheet();

    expect(picker.chooseCount, 1);
    expect(workspace.state.isCommandInFlight, isTrue);

    chooseCompleter.complete(picker.chooseResult);
    await first;
    final duplicateSt = await second;

    expect(duplicateSt.selectedSheet, isNull);
    expect(workspace.state.selectedSheet?.id, 'chosen-spreadsheet-id');
    expect(workspace.state.isCommandInFlight, isFalse);
  });

  test('logs out through workspace cleanup', () async {
    final accessSt = _MemoryWorkspaceStOwner(
      const WorkspaceAccessSt(
        sheetText: 'selected-spreadsheet-id',
        selectedSheet: SelectedSheet(
          spreadsheetId: 'selected-spreadsheet-id',
          name: 'Selected Workouts',
        ),
        pickerAuth: PickerAuth(
          accessToken: 'picker-token',
          accountEmail: 'athlete@example.com',
        ),
        workoutSelection: WorkoutSelectionSt(
          spreadsheetId: 'selected-spreadsheet-id',
          workout: 'Legs',
          historyBlock: 'Week 1',
        ),
      ),
    );
    final accountSession = _RecordingGoogleAccountSession(
      const GoogleAccountProfile(email: 'athlete@example.com'),
    );
    final workspace = WorkspaceCtrl(
      accessStOwner: accessSt,
      accountSession: accountSession,
      picker: _CommandSheetPicker(),
    );
    await workspace.restore();

    final state = await workspace.signOut();

    expect(accountSession.signOutCount, 1);
    expect(accessSt.value.selectedSheet, isNull);
    expect(accessSt.value.sheetText, isNull);
    expect(accessSt.value.pickerAuth, isNull);
    expect(accessSt.value.workoutSelection, isNull);
    expect(state.selectedSheet, isNull);
    expect(state.pastedText, isNull);
    expect(state.accountProfile, isNull);
    expect(state.pickerAuthorization, isNull);
    expect(state.workoutSelection, isNull);
  });
}

class _MemoryWorkspaceStOwner implements WorkspaceStOwner {
  _MemoryWorkspaceStOwner(this.value);

  @override
  WorkspaceAccessSt value;

  @override
  Future<void> clear() async {
    value = const WorkspaceAccessSt();
  }

  @override
  Future<WorkspaceAccessSt> restore() async {
    return value;
  }

  @override
  Future<WorkspaceAccessSt> update(
    WorkspaceAccessSt Function(WorkspaceAccessSt current) updateFn,
  ) async {
    value = updateFn(value);
    return value;
  }
}

class _ResolvingSheetPicker implements SheetPicker {
  const _ResolvingSheetPicker(this.resolved);

  final SelectedSheet resolved;

  @override
  PickerAvail get availability {
    return const PickerAvail.available();
  }

  @override
  Future<bool> authorizeSheetCreation() async {
    return true;
  }

  @override
  Future<SelectedSheet?> chooseSheet() async {
    return null;
  }

  @override
  Future<SelectedSheet?> createSheet({String? name}) async {
    return null;
  }

  @override
  Future<SelectedSheet> resolveSelection(SelectedSheet selected) async {
    return resolved;
  }
}

class _CommandSheetPicker implements SheetPicker {
  _CommandSheetPicker({
    this.chooseResult,
    this.creationAuthorizationResult = true,
    this.createResult,
  });

  final SelectedSheet? chooseResult;
  final bool creationAuthorizationResult;
  final SelectedSheet? createResult;
  Future<SelectedSheet?>? chooseFuture;
  int chooseCount = 0;
  int creationAuthorizationCount = 0;
  int createCount = 0;
  final createNames = <String?>[];

  @override
  PickerAvail get availability {
    return const PickerAvail.available();
  }

  @override
  Future<SelectedSheet?> chooseSheet() {
    chooseCount += 1;
    return chooseFuture ?? Future.value(chooseResult);
  }

  @override
  Future<bool> authorizeSheetCreation() async {
    creationAuthorizationCount += 1;
    return creationAuthorizationResult;
  }

  @override
  Future<SelectedSheet?> createSheet({String? name}) async {
    createCount += 1;
    createNames.add(name);
    return createResult;
  }

  @override
  Future<SelectedSheet> resolveSelection(SelectedSheet selected) async {
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
