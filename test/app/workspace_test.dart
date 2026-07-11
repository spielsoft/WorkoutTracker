import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_tracker/app.dart';

void main() {
  test(
    'restores selected sheet, native account, picker availability, and fallback',
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
        ),
      );
      final accountSession = _RecordingGoogleAccountSession(
        const GoogleAccountProfile(
          email: 'athlete@example.com',
          displayName: 'Athlete Name',
        ),
      );
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
    'keeps selection commands blocked until restoration completes',
    () async {
      final restore = Completer<WorkspaceAccessSt>();
      final picker = _CommandSheetPicker(
        chooseResult: const SelectedSheet(
          spreadsheetId: 'chosen-id',
          name: 'Chosen',
        ),
      );
      final workspace = WorkspaceCtrl(
        accessStOwner: _DelayedWorkspaceStOwner(restore.future),
        picker: picker,
      );

      final restoring = workspace.restore();
      final choosing = workspace.chooseSheet();

      expect(workspace.state.isInitializing, isTrue);
      expect(workspace.state.isCommandInFlight, isTrue);
      expect(picker.chooseCount, 0);

      restore.complete(
        const WorkspaceAccessSt(
          selectedSheet: SelectedSheet(
            spreadsheetId: 'saved-id',
            name: 'Saved',
          ),
        ),
      );
      await restoring;
      await choosing;

      expect(workspace.state.isInitializing, isFalse);
      expect(workspace.state.selectedSheet?.id, 'saved-id');
      expect(picker.chooseCount, 0);
    },
  );

  test(
    'requires confirmation before rebinding a saved sheet account',
    () async {
      final accessSt = _MemoryWorkspaceStOwner(
        const WorkspaceAccessSt(
          selectedSheet: SelectedSheet(
            spreadsheetId: 'saved-id',
            name: 'Saved',
            accountEmail: 'saved@example.com',
          ),
        ),
      );
      final account = _RecordingGoogleAccountSession(
        const GoogleAccountProfile(email: 'current@example.com'),
      );
      final picker = _CommandSheetPicker();
      final workspace = WorkspaceCtrl(
        accessStOwner: accessSt,
        accountSession: account,
        picker: picker,
      );

      final restored = await workspace.restore();

      expect(restored.accountMismatch?.savedEmail, 'saved@example.com');
      expect(restored.accountMismatch?.currentEmail, 'current@example.com');
      expect(accessSt.value.selectedSheet?.accountEmail, 'saved@example.com');

      final confirmed = await workspace.confirmAccount();

      expect(confirmed.accountMismatch, isNull);
      expect(confirmed.error, isNull);
      expect(accessSt.value.selectedSheet?.accountEmail, 'current@example.com');
    },
  );

  test(
    'persists selected sheet, pasted sheet text, and workout selection',
    () async {
      final accessSt = _MemoryWorkspaceStOwner(const WorkspaceAccessSt());
      const selected = SelectedSheet(
        spreadsheetId: 'resolved-spreadsheet-id',
        name: 'Resolved Workouts',
        drivePath: 'My Drive / Resolved Workouts',
        accountEmail: 'athlete@example.com',
      );
      final workspace = WorkspaceCtrl(
        accessStOwner: accessSt,
        picker: _CommandSheetPicker(chooseResult: selected),
      );

      await workspace.persistPastedText(
        ' https://docs.google.com/spreadsheets/d/pasted-id/edit ',
      );

      expect(
        accessSt.value.sheetText,
        'https://docs.google.com/spreadsheets/d/pasted-id/edit',
      );

      await workspace.chooseSheet();

      expect(selected.id, 'resolved-spreadsheet-id');
      expect(accessSt.value.sheetText, 'resolved-spreadsheet-id');
      expect(
        accessSt.value.selectedSheet?.displayLabel,
        'My Drive / Resolved Workouts',
      );
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

  test(
    'chooses and adopts a spreadsheet through the workspace command',
    () async {
      final accessSt = _MemoryWorkspaceStOwner(
        const WorkspaceAccessSt(sheetText: 'previous-id'),
      );
      final picker = _CommandSheetPicker(
        chooseResult: const SelectedSheet(
          spreadsheetId: 'chosen-spreadsheet-id',
          name: 'Chosen Workouts',
          accountEmail: 'athlete@example.com',
        ),
      );
      final workspace = WorkspaceCtrl(accessStOwner: accessSt, picker: picker);

      final state = await workspace.chooseSheet();

      expect(picker.chooseCount, 1);
      expect(state.selectedSheet?.id, 'chosen-spreadsheet-id');
      expect(accessSt.value.sheetText, 'chosen-spreadsheet-id');
      expect(accessSt.value.selectedSheet?.displayLabel, 'Chosen Workouts');
      expect(workspace.state.isCommandInFlight, isFalse);
    },
  );

  test('creates and adopts a spreadsheet', () async {
    final accessSt = _MemoryWorkspaceStOwner(const WorkspaceAccessSt());
    final picker = _CommandSheetPicker(
      createResult: const SelectedSheet(
        spreadsheetId: 'created-spreadsheet-id',
        name: 'Custom Training Log',
        accountEmail: 'athlete@example.com',
      ),
    );
    final workspace = WorkspaceCtrl(accessStOwner: accessSt, picker: picker);

    final state = await workspace.createSheet(name: 'Custom Training Log');

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
    expect(accessSt.value.workoutSelection, isNull);
    expect(state.selectedSheet, isNull);
    expect(state.pastedText, isNull);
    expect(state.accountProfile, isNull);
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

class _DelayedWorkspaceStOwner implements WorkspaceStOwner {
  _DelayedWorkspaceStOwner(this.restored);

  final Future<WorkspaceAccessSt> restored;
  WorkspaceAccessSt _value = const WorkspaceAccessSt();

  @override
  WorkspaceAccessSt get value => _value;

  @override
  Future<void> clear() async => _value = const WorkspaceAccessSt();

  @override
  Future<WorkspaceAccessSt> restore() async => _value = await restored;

  @override
  Future<WorkspaceAccessSt> update(
    WorkspaceAccessSt Function(WorkspaceAccessSt current) updateFn,
  ) async => _value = updateFn(_value);
}

class _CommandSheetPicker implements SheetPicker {
  _CommandSheetPicker({this.chooseResult, this.createResult});

  final SelectedSheet? chooseResult;
  final SelectedSheet? createResult;
  Future<SelectedSheet?>? chooseFuture;
  int chooseCount = 0;
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
  Future<SelectedSheet?> createSheet({String? name}) async {
    createCount += 1;
    createNames.add(name);
    return createResult;
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
  Future<void> restoreAccount({List<String> scopes = const []}) async {}

  @override
  Future<bool> signIn({List<String> scopes = const []}) async {
    return _currentAccount != null;
  }

  @override
  Future<void> signOut() async {
    signOutCount += 1;
    _currentAccount = null;
    notifyListeners();
  }
}
