import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'google_account_session.dart';
import 'spreadsheet_selection.dart';

class GoogleWorkspaceAccessState {
  const GoogleWorkspaceAccessState({
    this.spreadsheetText,
    this.selectedSpreadsheet,
    this.googleAuthorization,
    this.workoutSelection,
  });

  final String? spreadsheetText;
  final SelectedSpreadsheet? selectedSpreadsheet;
  final GooglePickerAuthorizationSnapshot? googleAuthorization;
  final WorkoutSelectionState? workoutSelection;

  GoogleWorkspaceAccessState copyWith({
    String? spreadsheetText,
    SelectedSpreadsheet? selectedSpreadsheet,
    GooglePickerAuthorizationSnapshot? googleAuthorization,
    WorkoutSelectionState? workoutSelection,
  }) {
    return GoogleWorkspaceAccessState(
      spreadsheetText: spreadsheetText ?? this.spreadsheetText,
      selectedSpreadsheet: selectedSpreadsheet ?? this.selectedSpreadsheet,
      googleAuthorization: googleAuthorization ?? this.googleAuthorization,
      workoutSelection: workoutSelection ?? this.workoutSelection,
    );
  }

  GoogleWorkspaceAccessState migrateLegacy({
    String? spreadsheetText,
    SelectedSpreadsheet? selectedSpreadsheet,
    GooglePickerAuthorizationSnapshot? googleAuthorization,
    WorkoutSelectionState? workoutSelection,
  }) {
    return GoogleWorkspaceAccessState(
      spreadsheetText: this.spreadsheetText ?? spreadsheetText,
      selectedSpreadsheet: this.selectedSpreadsheet ?? selectedSpreadsheet,
      googleAuthorization: this.googleAuthorization ?? googleAuthorization,
      workoutSelection: this.workoutSelection ?? workoutSelection,
    );
  }

  Map<String, Object?> toJson() {
    return {
      if (spreadsheetText != null) 'spreadsheetText': spreadsheetText,
      if (selectedSpreadsheet != null)
        'selectedSpreadsheet': selectedSpreadsheet!.toJson(),
      if (googleAuthorization != null)
        'googleAuthorization': googleAuthorization!.toJson(),
      if (workoutSelection != null)
        'workoutSelection': workoutSelection!.toJson(),
    };
  }

  static GoogleWorkspaceAccessState fromJson(Object? value) {
    if (value case <String, Object?>{
      'spreadsheetText': final String spreadsheetText,
    }) {
      return GoogleWorkspaceAccessState(
        spreadsheetText: spreadsheetText,
        selectedSpreadsheet: SelectedSpreadsheet.fromJson(
          value['selectedSpreadsheet'],
        ),
        googleAuthorization: GooglePickerAuthorizationSnapshot.fromJson(
          value['googleAuthorization'],
        ),
        workoutSelection: WorkoutSelectionState.fromJson(
          value['workoutSelection'],
        ),
      );
    }
    if (value is Map<String, Object?>) {
      return GoogleWorkspaceAccessState(
        selectedSpreadsheet: SelectedSpreadsheet.fromJson(
          value['selectedSpreadsheet'],
        ),
        googleAuthorization: GooglePickerAuthorizationSnapshot.fromJson(
          value['googleAuthorization'],
        ),
        workoutSelection: WorkoutSelectionState.fromJson(
          value['workoutSelection'],
        ),
      );
    }
    return const GoogleWorkspaceAccessState();
  }
}

abstract interface class AppStateStore {
  Future<GoogleWorkspaceAccessState> readGoogleWorkspaceAccessState();

  Future<void> writeGoogleWorkspaceAccessState(
    GoogleWorkspaceAccessState value,
  );

  Future<void> clearGoogleWorkspaceAccessState();
}

abstract interface class GoogleWorkspaceAccessStateOwner {
  GoogleWorkspaceAccessState get value;

  Future<GoogleWorkspaceAccessState> restore();

  Future<GoogleWorkspaceAccessState> update(
    GoogleWorkspaceAccessState Function(GoogleWorkspaceAccessState current)
    updateState,
  );

  Future<void> clear();
}

class GoogleWorkspaceAccessStateController
    implements GoogleWorkspaceAccessStateOwner {
  GoogleWorkspaceAccessStateController(this._store);

  final AppStateStore _store;
  GoogleWorkspaceAccessState _state = const GoogleWorkspaceAccessState();
  Future<void> _pending = Future<void>.value();
  Future<GoogleWorkspaceAccessState>? _restoreFuture;
  bool _hasRestored = false;

  @override
  GoogleWorkspaceAccessState get value => _state;

  @override
  Future<GoogleWorkspaceAccessState> restore() {
    return _enqueue(() async {
      await _ensureRestored();
      return _state;
    });
  }

  @override
  Future<GoogleWorkspaceAccessState> update(
    GoogleWorkspaceAccessState Function(GoogleWorkspaceAccessState current)
    updateState,
  ) {
    return _enqueue(() async {
      await _ensureRestored();
      final updated = updateState(_state);
      _state = updated;
      await _store.writeGoogleWorkspaceAccessState(updated);
      return updated;
    });
  }

  @override
  Future<void> clear() {
    return _enqueue(() async {
      _state = const GoogleWorkspaceAccessState();
      _hasRestored = true;
      _restoreFuture = Future<GoogleWorkspaceAccessState>.value(_state);
      await _store.clearGoogleWorkspaceAccessState();
    });
  }

  Future<void> _ensureRestored() async {
    if (_hasRestored) {
      return;
    }
    _restoreFuture ??= _store.readGoogleWorkspaceAccessState();
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
  const FileAppStateStore({
    Directory? stateDirectory,
    List<Directory> legacyStateDirectories = const [],
  }) : _stateDirectoryOverride = stateDirectory,
       _legacyStateDirectoryOverrides = legacyStateDirectories;

  final Directory? _stateDirectoryOverride;
  final List<Directory> _legacyStateDirectoryOverrides;

  static const _googleWorkspaceAccessKey = 'googleWorkspaceAccess';
  static const _spreadsheetTextKey = 'spreadsheetText';
  static const _selectedSpreadsheetKey = 'selectedSpreadsheet';
  static const _googleAuthorizationKey = 'googleAuthorization';
  static const _workoutSelectionKey = 'workoutSelection';

  @override
  Future<GoogleWorkspaceAccessState> readGoogleWorkspaceAccessState() async {
    final decoded = await _readState();
    return GoogleWorkspaceAccessState.fromJson(
      decoded[_googleWorkspaceAccessKey],
    ).migrateLegacy(
      spreadsheetText: decoded[_spreadsheetTextKey] as String?,
      selectedSpreadsheet: SelectedSpreadsheet.fromJson(
        decoded[_selectedSpreadsheetKey],
      ),
      googleAuthorization: GooglePickerAuthorizationSnapshot.fromJson(
        decoded[_googleAuthorizationKey],
      ),
      workoutSelection: WorkoutSelectionState.fromJson(
        decoded[_workoutSelectionKey],
      ),
    );
  }

  @override
  Future<void> writeGoogleWorkspaceAccessState(
    GoogleWorkspaceAccessState value,
  ) async {
    final state = await _readState();
    state[_googleWorkspaceAccessKey] = value.toJson();
    state.remove(_spreadsheetTextKey);
    state.remove(_selectedSpreadsheetKey);
    state.remove(_googleAuthorizationKey);
    state.remove(_workoutSelectionKey);
    await _writeState(state);
  }

  @override
  Future<void> clearGoogleWorkspaceAccessState() async {
    final state = await _readState();
    state.remove(_googleWorkspaceAccessKey);
    state.remove(_spreadsheetTextKey);
    state.remove(_selectedSpreadsheetKey);
    state.remove(_googleAuthorizationKey);
    state.remove(_workoutSelectionKey);
    await _writeState(state);
  }

  Future<Map<String, Object?>> _readState() async {
    for (final file in await _stateFiles()) {
      final decoded = await _readStateFile(file);
      if (decoded != null) {
        return decoded;
      }
    }
    return <String, Object?>{};
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

  Future<List<File>> _stateFiles() async {
    final primary = await _stateFile();
    final files = <File>[primary];
    for (final directory in _legacyStateDirectories()) {
      final legacy = File(
        '${directory.path}${Platform.pathSeparator}state.json',
      );
      if (legacy.path != primary.path) {
        files.add(legacy);
      }
    }
    return files;
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

  List<Directory> _legacyStateDirectories() {
    if (_legacyStateDirectoryOverrides.isNotEmpty) {
      return _legacyStateDirectoryOverrides;
    }
    if (_stateDirectoryOverride != null) {
      return const [];
    }
    return defaultLegacyStateDirectories(
      isMacOS: Platform.isMacOS,
      environment: Platform.environment,
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

  static List<Directory> defaultLegacyStateDirectories({
    required bool isMacOS,
    required Map<String, String> environment,
  }) {
    final home = environment['HOME'];
    if (home == null || home.trim().isEmpty) {
      return const [];
    }
    final dotDirectory = Directory(
      '$home${Platform.pathSeparator}.workout_tracker',
    );
    if (!isMacOS) {
      return [dotDirectory];
    }
    return [
      dotDirectory,
      Directory(
        '$home${Platform.pathSeparator}Library'
        '${Platform.pathSeparator}Containers'
        '${Platform.pathSeparator}com.spielman.workouttracker'
        '${Platform.pathSeparator}Data'
        '${Platform.pathSeparator}Library'
        '${Platform.pathSeparator}Application Support'
        '${Platform.pathSeparator}WorkoutTracker',
      ),
    ];
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
