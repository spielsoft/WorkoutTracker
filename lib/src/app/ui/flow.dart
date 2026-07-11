import 'package:flutter/foundation.dart';

import '../controller.dart';
import '../selection.dart';
import '../state_store.dart';
import '../validation.dart';
import '../workspace.dart';
import 'loaded_flow.dart';
import 'sheet.dart';
import 'view.dart';

const _manualSheetLabel = 'Workout sheet';

/// Routes between sheet setup and the loaded-workout module.
///
/// Feature navigation and transient state belong to [LoadedFlow]. This facade
/// owns startup restoration, workbook validation, and account/sheet commands.
final class AppFlow extends ChangeNotifier {
  AppFlow({
    required WbkAccess svc,
    GoogleAccountSession? accountSession,
    AppStStore? appStStore,
    SheetPicker? picker,
    this._sheetOpener = const UrlSheetOpener(),
    String initialText = '',
    SelectedSheet? initialSelection,
  }) : _ctrl = AppCtrl(svc: svc),
       _workspace = WorkspaceCtrl(
         accessStOwner: appStStore == null ? null : WorkspaceStCtrl(appStStore),
         accountSession: accountSession,
         picker: picker,
         initialText: initialText,
         initialSelection: initialSelection,
       ),
       _showAccount = accountSession != null,
       _hasPicker = picker != null,
       _sheetText = initialSelection?.id ?? initialText {
    loaded = LoadedFlow(_ctrl, _workspace, _showSheet, notifyListeners);
    _ctrl.addListener(_forward);
    _workspace.addListener(_forward);
  }

  final AppCtrl _ctrl;
  final WorkspaceCtrl _workspace;
  final bool _showAccount;
  final bool _hasPicker;
  final SheetOpener _sheetOpener;
  late final LoadedFlow loaded;
  bool _showLoaded = false;
  String _sheetText;

  AppView get view {
    final report = _ctrl.report;
    final workspace = _workspace.state;
    final busy =
        _ctrl.isBusy || workspace.isCommandInFlight || workspace.isInitializing;
    if (!_showLoaded || report == null || report.hasBlockingIssues) {
      return SheetView(
        isBusy: busy,
        error: _ctrl.error ?? workspace.error,
        sheetText: _sheetText,
        selectedSheet: workspace.selectedSheet,
        availability: workspace.pickerAvailability,
        showAvailability: workspace.selectedSheet == null && _hasPicker,
        showTextFallback: !_hasPicker || workspace.fallbackAvailable,
        hasLoadedWorkout: report != null && !report.hasBlockingIssues,
        report: report,
        account: workspace.accountProfile,
        hasPicker: _hasPicker,
        showAccount: _showAccount,
        accountMismatch: workspace.accountMismatch,
      );
    }
    final label = workspace.selectedSheet?.displayLabel ?? _manualSheetLabel;
    return loaded.view(busy: busy, sheetLabel: label);
  }

  Future<void> restore() async {
    final workspace = await _workspace.restore();
    if (workspace.accountMismatch != null || workspace.error != null) {
      notifyListeners();
      return;
    }
    final selected = workspace.selectedSheet;
    if (selected != null) {
      _sheetText = selected.id;
      await _validate();
      loaded.restoreWorkout(
        _workspace.workoutSelectionFor(_ctrl.report?.sheetId ?? selected.id),
      );
    } else if (workspace.pastedText case final text?) {
      _sheetText = text;
    }
    notifyListeners();
  }

  Future<CmdResult> run(SheetCmd cmd) async {
    if (_workspace.state.isInitializing) {
      return const CmdResult.failed('WorkoutTracker is still starting.');
    }
    final result = switch (cmd) {
      SetSheetText(:final text) => await _setSheetText(text),
      ValidateSheet() => await _validate(),
      ChooseSheet() => await _chooseSheet(),
      SignIn() => await _signIn(),
      CreateSheet(:final name) => await _createSheet(name),
      SignOut() => await _signOut(),
      ConfirmAccount() => await _confirmAccount(),
      ReturnToSheet() => _showSheet(),
      ReturnToWorkout() => _returnToWorkout(),
      RepairAll() => await _repairAll(),
      RepairOne(:final activeRow, :final exerciseRow) => await _repairOne(
        activeRow,
        exerciseRow,
      ),
      OpenSheet() => await _openSheet(),
    };
    notifyListeners();
    return result;
  }

  Future<CmdResult> _setSheetText(String text) async {
    _sheetText = text;
    await _workspace.persistPastedText(text);
    return const CmdResult.done();
  }

  Future<CmdResult> _validate() async {
    final selected = _workspace.state.selectedSheet;
    final ok = selected == null
        ? await _ctrl.validateSelection(_sheetText)
        : await _ctrl.validateSelected(selected);
    final report = _ctrl.report;
    _showLoaded = ok && report != null && !report.hasBlockingIssues;
    if (_showLoaded) loaded.showSetup();
    return CmdResult.result(ok);
  }

  Future<CmdResult> _chooseSheet() async {
    try {
      final workspace = await _workspace.chooseSheet();
      final selected = workspace.selectedSheet;
      if (selected == null) return const CmdResult.failed();
      _sheetText = selected.id;
      return _validate();
    } on Object catch (error) {
      _ctrl.reportSelectionFailure(error);
      return CmdResult.failed(error.toString());
    }
  }

  Future<CmdResult> _signIn() async {
    try {
      final workspace = await _workspace.signIn();
      return workspace.accountProfile == null
          ? const CmdResult.failed('Google Sheets login was cancelled.')
          : const CmdResult.done();
    } on Object catch (error) {
      return CmdResult.failed('Unable to log in to Google Sheets: $error');
    }
  }

  Future<CmdResult> _createSheet(String name) async {
    try {
      final workspace = await _workspace.createSheet(name: name);
      final selected = workspace.selectedSheet;
      if (selected == null) return const CmdResult.failed();
      _sheetText = selected.id;
      return _validate();
    } on Object catch (error) {
      _ctrl.reportSelectionFailure(error);
      return CmdResult.failed(error.toString());
    }
  }

  Future<CmdResult> _signOut() async {
    await _workspace.signOut();
    _ctrl.clearSelection();
    _sheetText = '';
    _showLoaded = false;
    loaded.reset();
    return const CmdResult.done();
  }

  Future<CmdResult> _confirmAccount() async {
    final workspace = await _workspace.confirmAccount();
    if (workspace.accountMismatch != null || workspace.error != null) {
      return CmdResult.failed(workspace.error);
    }
    final selected = workspace.selectedSheet;
    if (selected == null) return const CmdResult.failed();
    _sheetText = selected.id;
    return _validate();
  }

  CmdResult _showSheet() {
    _ctrl.closeExercise();
    _showLoaded = false;
    return const CmdResult.done();
  }

  CmdResult _returnToWorkout() {
    final report = _ctrl.report;
    if (report == null || report.hasBlockingIssues) {
      return const CmdResult.failed();
    }
    loaded.showSetup();
    _showLoaded = true;
    return const CmdResult.done();
  }

  Future<CmdResult> _repairAll() async {
    final ok = await _ctrl.repairFormulas();
    if (ok) {
      _showLoaded = _ctrl.report?.hasBlockingIssues == false;
      if (_showLoaded) loaded.showSetup();
    }
    return CmdResult.result(ok);
  }

  Future<CmdResult> _repairOne(int activeRow, int exerciseRow) async {
    final ok = await _ctrl.repairFormulaIssue(
      activeSheetRowNumber: activeRow,
      selectedRow: exerciseRow,
    );
    if (ok) {
      _showLoaded = _ctrl.report?.hasBlockingIssues == false;
      if (_showLoaded) loaded.showSetup();
    }
    return CmdResult.result(ok);
  }

  Future<CmdResult> _openSheet() async {
    final report = _ctrl.report;
    if (report == null) return const CmdResult.failed();
    try {
      await _sheetOpener.openSheet(report.sheetUrl);
      return const CmdResult.done();
    } on Object catch (error) {
      _ctrl.reportOpenFailure(error);
      return CmdResult.failed(error.toString());
    }
  }

  void _forward() => notifyListeners();

  @override
  void dispose() {
    _ctrl.removeListener(_forward);
    _workspace.removeListener(_forward);
    _ctrl.dispose();
    _workspace.dispose();
    super.dispose();
  }
}
