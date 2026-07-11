import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'selection.dart';

class WorkspaceAccessSt {
  const WorkspaceAccessSt({
    this.sheetText,
    this.selectedSheet,
    this.workoutSelection,
  });

  final String? sheetText;
  final SelectedSheet? selectedSheet;
  final WorkoutSelectionSt? workoutSelection;

  WorkspaceAccessSt copyWith({
    String? sheetText,
    SelectedSheet? selectedSheet,
    WorkoutSelectionSt? workoutSelection,
  }) {
    return WorkspaceAccessSt(
      sheetText: sheetText ?? this.sheetText,
      selectedSheet: selectedSheet ?? this.selectedSheet,
      workoutSelection: workoutSelection ?? this.workoutSelection,
    );
  }

  Map<String, Object?> toJson() {
    return {
      if (sheetText != null) 'sheetText': sheetText,
      if (selectedSheet != null) 'selectedSheet': selectedSheet!.toJson(),
      if (workoutSelection != null)
        'workoutSelection': workoutSelection!.toJson(),
    };
  }

  static WorkspaceAccessSt fromJson(Object? value) {
    if (value case <String, Object?>{'sheetText': final String sheetText}) {
      return WorkspaceAccessSt(
        sheetText: sheetText,
        selectedSheet: SelectedSheet.fromJson(value['selectedSheet']),
        workoutSelection: WorkoutSelectionSt.fromJson(
          value['workoutSelection'],
        ),
      );
    }
    if (value is Map<String, Object?>) {
      return WorkspaceAccessSt(
        selectedSheet: SelectedSheet.fromJson(value['selectedSheet']),
        workoutSelection: WorkoutSelectionSt.fromJson(
          value['workoutSelection'],
        ),
      );
    }
    return const WorkspaceAccessSt();
  }
}

abstract interface class AppStStore {
  Future<WorkspaceAccessSt> readWorkspaceSt();

  Future<void> writeWorkspaceSt(WorkspaceAccessSt value);

  Future<void> clearWorkspaceSt();
}

abstract interface class WorkspaceStOwner {
  WorkspaceAccessSt get value;

  Future<WorkspaceAccessSt> restore();

  Future<WorkspaceAccessSt> update(
    WorkspaceAccessSt Function(WorkspaceAccessSt current) updateFn,
  );

  Future<void> clear();
}

class WorkspaceStCtrl implements WorkspaceStOwner {
  WorkspaceStCtrl(this._store);

  final AppStStore _store;
  WorkspaceAccessSt _state = const WorkspaceAccessSt();
  Future<void> _pending = Future<void>.value();
  Future<WorkspaceAccessSt>? _restoreFuture;
  bool _hasRestored = false;

  @override
  WorkspaceAccessSt get value => _state;

  @override
  Future<WorkspaceAccessSt> restore() {
    return _enqueue(() async {
      await _ensureRestored();
      return _state;
    });
  }

  @override
  Future<WorkspaceAccessSt> update(
    WorkspaceAccessSt Function(WorkspaceAccessSt current) updateFn,
  ) {
    return _enqueue(() async {
      await _ensureRestored();
      final updated = updateFn(_state);
      _state = updated;
      await _store.writeWorkspaceSt(updated);
      return updated;
    });
  }

  @override
  Future<void> clear() {
    return _enqueue(() async {
      _state = const WorkspaceAccessSt();
      _hasRestored = true;
      _restoreFuture = Future<WorkspaceAccessSt>.value(_state);
      await _store.clearWorkspaceSt();
    });
  }

  Future<void> _ensureRestored() async {
    if (_hasRestored) {
      return;
    }
    _restoreFuture ??= _store.readWorkspaceSt();
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

class FileAppStStore implements AppStStore {
  const FileAppStStore(this._stDirProvider);

  final Future<Directory> Function() _stDirProvider;

  static const _workspaceAccessKey = 'googleWorkspaceAccess';

  @override
  Future<WorkspaceAccessSt> readWorkspaceSt() async {
    final decoded = await _readSt();
    return WorkspaceAccessSt.fromJson(decoded[_workspaceAccessKey]);
  }

  @override
  Future<void> writeWorkspaceSt(WorkspaceAccessSt value) async {
    final state = await _readSt();
    state[_workspaceAccessKey] = value.toJson();
    await _writeSt(state);
  }

  @override
  Future<void> clearWorkspaceSt() async {
    final state = await _readSt();
    state.remove(_workspaceAccessKey);
    await _writeSt(state);
  }

  Future<Map<String, Object?>> _readSt() async {
    return await _readStFile(await _stateFile()) ?? <String, Object?>{};
  }

  Future<Map<String, Object?>?> _readStFile(File file) async {
    if (!await file.exists()) {
      return null;
    }
    final decoded = jsonDecode(await file.readAsString());
    if (decoded is Map<String, Object?>) {
      return decoded;
    }
    return null;
  }

  Future<void> _writeSt(Map<String, Object?> state) async {
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
    final directory = await _stDirProvider();
    return File('${directory.path}${Platform.pathSeparator}state.json');
  }
}

class WorkoutSelectionSt {
  const WorkoutSelectionSt({
    required String spreadsheetId,
    this.workout,
    this.historyBlock,
  }) : sheetId = spreadsheetId;

  final String sheetId;
  final String? workout;
  final String? historyBlock;

  Map<String, Object?> toJson() {
    return {
      'spreadsheetId': sheetId,
      if (workout != null) 'workout': workout,
      if (historyBlock != null) 'historyBlock': historyBlock,
    };
  }

  static WorkoutSelectionSt? fromJson(Object? value) {
    if (value case <String, Object?>{'spreadsheetId': final String id}) {
      return WorkoutSelectionSt(
        spreadsheetId: id,
        workout: value['workout'] as String?,
        historyBlock: value['historyBlock'] as String?,
      );
    }
    return null;
  }
}
