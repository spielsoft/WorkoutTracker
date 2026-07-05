import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'google_account_session.dart';
import 'spreadsheet_selection.dart';

class WorkspaceAccessState {
  const WorkspaceAccessState({
    this.spreadsheetText,
    this.selectedSpreadsheet,
    this.pickerAuth,
    this.workoutSelection,
  });

  final String? spreadsheetText;
  final SelectedSpreadsheet? selectedSpreadsheet;
  final PickerAuth? pickerAuth;
  final WorkoutSelectionState? workoutSelection;

  WorkspaceAccessState copyWith({
    String? spreadsheetText,
    SelectedSpreadsheet? selectedSpreadsheet,
    PickerAuth? pickerAuth,
    WorkoutSelectionState? workoutSelection,
  }) {
    return WorkspaceAccessState(
      spreadsheetText: spreadsheetText ?? this.spreadsheetText,
      selectedSpreadsheet: selectedSpreadsheet ?? this.selectedSpreadsheet,
      pickerAuth: pickerAuth ?? this.pickerAuth,
      workoutSelection: workoutSelection ?? this.workoutSelection,
    );
  }

  Map<String, Object?> toJson() {
    return {
      if (spreadsheetText != null) 'spreadsheetText': spreadsheetText,
      if (selectedSpreadsheet != null)
        'selectedSpreadsheet': selectedSpreadsheet!.toJson(),
      if (pickerAuth != null) 'pickerAuth': pickerAuth!.toJson(),
      if (workoutSelection != null)
        'workoutSelection': workoutSelection!.toJson(),
    };
  }

  static WorkspaceAccessState fromJson(Object? value) {
    if (value case <String, Object?>{
      'spreadsheetText': final String spreadsheetText,
    }) {
      return WorkspaceAccessState(
        spreadsheetText: spreadsheetText,
        selectedSpreadsheet: SelectedSpreadsheet.fromJson(
          value['selectedSpreadsheet'],
        ),
        pickerAuth: _pickerAuthFromJson(value),
        workoutSelection: WorkoutSelectionState.fromJson(
          value['workoutSelection'],
        ),
      );
    }
    if (value is Map<String, Object?>) {
      return WorkspaceAccessState(
        selectedSpreadsheet: SelectedSpreadsheet.fromJson(
          value['selectedSpreadsheet'],
        ),
        pickerAuth: _pickerAuthFromJson(value),
        workoutSelection: WorkoutSelectionState.fromJson(
          value['workoutSelection'],
        ),
      );
    }
    return const WorkspaceAccessState();
  }

  static PickerAuth? _pickerAuthFromJson(Map<String, Object?> json) {
    return PickerAuth.fromJson(
      json['pickerAuth'] ?? json['googleAuthorization'],
    );
  }
}

abstract interface class AppStateStore {
  Future<WorkspaceAccessState> readWorkspaceState();

  Future<void> writeWorkspaceState(WorkspaceAccessState value);

  Future<void> clearWorkspaceState();
}

abstract interface class WorkspaceStateOwner {
  WorkspaceAccessState get value;

  Future<WorkspaceAccessState> restore();

  Future<WorkspaceAccessState> update(
    WorkspaceAccessState Function(WorkspaceAccessState current) updateState,
  );

  Future<void> clear();
}

class WorkspaceStateController implements WorkspaceStateOwner {
  WorkspaceStateController(this._store);

  final AppStateStore _store;
  WorkspaceAccessState _state = const WorkspaceAccessState();
  Future<void> _pending = Future<void>.value();
  Future<WorkspaceAccessState>? _restoreFuture;
  bool _hasRestored = false;

  @override
  WorkspaceAccessState get value => _state;

  @override
  Future<WorkspaceAccessState> restore() {
    return _enqueue(() async {
      await _ensureRestored();
      return _state;
    });
  }

  @override
  Future<WorkspaceAccessState> update(
    WorkspaceAccessState Function(WorkspaceAccessState current) updateState,
  ) {
    return _enqueue(() async {
      await _ensureRestored();
      final updated = updateState(_state);
      _state = updated;
      await _store.writeWorkspaceState(updated);
      return updated;
    });
  }

  @override
  Future<void> clear() {
    return _enqueue(() async {
      _state = const WorkspaceAccessState();
      _hasRestored = true;
      _restoreFuture = Future<WorkspaceAccessState>.value(_state);
      await _store.clearWorkspaceState();
    });
  }

  Future<void> _ensureRestored() async {
    if (_hasRestored) {
      return;
    }
    _restoreFuture ??= _store.readWorkspaceState();
    try {
      _state = await _restoreFuture!;
      _hasRestored = true;
    } on Object {
      _restoreFuture = null;
      rethrow;
    }
  }

  Future<T> _enqueue<T>(Future<T> Function() action) {
    final run = _pending.catchError((_) {}).then((_) => action());
    _pending = run.then<void>((_) {}, onError: (_) {});
    return run;
  }
}

class FileAppStateStore implements AppStateStore {
  const FileAppStateStore({Directory? stateDirectory})
    : _stateDirectoryOverride = stateDirectory;

  final Directory? _stateDirectoryOverride;

  static const _workspaceAccessKey = 'googleWorkspaceAccess';

  @override
  Future<WorkspaceAccessState> readWorkspaceState() async {
    final decoded = await _readState();
    return WorkspaceAccessState.fromJson(decoded[_workspaceAccessKey]);
  }

  @override
  Future<void> writeWorkspaceState(WorkspaceAccessState value) async {
    final state = await _readState();
    state[_workspaceAccessKey] = value.toJson();
    await _writeState(state);
  }

  @override
  Future<void> clearWorkspaceState() async {
    final state = await _readState();
    state.remove(_workspaceAccessKey);
    await _writeState(state);
  }

  Future<Map<String, Object?>> _readState() async {
    return await _readStateFile(await _stateFile()) ?? <String, Object?>{};
  }

  Future<Map<String, Object?>?> _readStateFile(File file) async {
    if (!await file.exists()) {
      return null;
    }
    Object? decoded;
    try {
      decoded = jsonDecode(await file.readAsString());
    } on FormatException {
      return null;
    }
    if (decoded is Map<String, Object?>) {
      return decoded;
    }
    return null;
  }

  Future<void> _writeState(Map<String, Object?> state) async {
    final file = await _stateFile();
    await file.parent.create(recursive: true);
    final temporaryFile = File(
      '${file.path}.${DateTime.now().microsecondsSinceEpoch}.'
      '$pid.tmp',
    );
    await temporaryFile.writeAsString(jsonEncode(state), flush: true);
    await temporaryFile.rename(file.path);
  }

  Future<File> _stateFile() async {
    final directory = _stateDirectory();
    return File('${directory.path}${Platform.pathSeparator}state.json');
  }

  Directory _stateDirectory() {
    return _stateDirectoryOverride ??
        defaultStateDirectory(
          isWindows: Platform.isWindows,
          isMacOS: Platform.isMacOS,
          environment: Platform.environment,
          systemTemp: Directory.systemTemp,
        );
  }

  static Directory defaultStateDirectory({
    required bool isWindows,
    required bool isMacOS,
    required Map<String, String> environment,
    required Directory systemTemp,
  }) {
    if (isWindows) {
      final appData = environment['APPDATA'];
      if (appData != null && appData.trim().isNotEmpty) {
        return Directory('$appData${Platform.pathSeparator}WorkoutTracker');
      }
    }

    final home = environment['HOME'];
    if (home != null && home.trim().isNotEmpty) {
      if (isMacOS) {
        return Directory(
          '$home${Platform.pathSeparator}Library'
          '${Platform.pathSeparator}Application Support'
          '${Platform.pathSeparator}WorkoutTracker',
        );
      }
      return Directory('$home${Platform.pathSeparator}.workout_tracker');
    }

    return Directory(
      '${systemTemp.path}${Platform.pathSeparator}workout_tracker',
    );
  }
}

class WorkoutSelectionState {
  const WorkoutSelectionState({
    required this.spreadsheetId,
    this.workout,
    this.historyBlock,
  });

  final String spreadsheetId;
  final String? workout;
  final String? historyBlock;

  Map<String, Object?> toJson() {
    return {
      'spreadsheetId': spreadsheetId,
      if (workout != null) 'workout': workout,
      if (historyBlock != null) 'historyBlock': historyBlock,
    };
  }

  static WorkoutSelectionState? fromJson(Object? value) {
    if (value case <String, Object?>{'spreadsheetId': final String id}) {
      return WorkoutSelectionState(
        spreadsheetId: id,
        workout: value['workout'] as String?,
        historyBlock: value['historyBlock'] as String?,
      );
    }
    return null;
  }
}
