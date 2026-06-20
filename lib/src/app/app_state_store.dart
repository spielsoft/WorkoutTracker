import 'dart:convert';
import 'dart:io';

import 'spreadsheet_selection.dart';

abstract interface class AppStateStore {
  Future<String?> readSpreadsheetText();

  Future<void> writeSpreadsheetText(String value);

  Future<SelectedSpreadsheet?> readSelectedSpreadsheet();

  Future<void> writeSelectedSpreadsheet(SelectedSpreadsheet value);

  Future<WorkoutSelectionState?> readWorkoutSelection();

  Future<void> writeWorkoutSelection(WorkoutSelectionState value);
}

class FileAppStateStore implements AppStateStore {
  const FileAppStateStore();

  static const _spreadsheetTextKey = 'spreadsheetText';
  static const _selectedSpreadsheetKey = 'selectedSpreadsheet';
  static const _workoutSelectionKey = 'workoutSelection';

  @override
  Future<String?> readSpreadsheetText() async {
    final decoded = await _readState();
    if (decoded case {_spreadsheetTextKey: final String value}) {
      return value;
    }
    return null;
  }

  @override
  Future<void> writeSpreadsheetText(String value) async {
    final state = await _readState();
    state[_spreadsheetTextKey] = value;
    await _writeState(state);
  }

  @override
  Future<SelectedSpreadsheet?> readSelectedSpreadsheet() async {
    final decoded = await _readState();
    return SelectedSpreadsheet.fromJson(decoded[_selectedSpreadsheetKey]);
  }

  @override
  Future<void> writeSelectedSpreadsheet(SelectedSpreadsheet value) async {
    final state = await _readState();
    state[_selectedSpreadsheetKey] = value.toJson();
    state[_spreadsheetTextKey] = value.spreadsheetId;
    await _writeState(state);
  }

  @override
  Future<WorkoutSelectionState?> readWorkoutSelection() async {
    final decoded = await _readState();
    return WorkoutSelectionState.fromJson(decoded[_workoutSelectionKey]);
  }

  @override
  Future<void> writeWorkoutSelection(WorkoutSelectionState value) async {
    final state = await _readState();
    state[_workoutSelectionKey] = value.toJson();
    await _writeState(state);
  }

  Future<Map<String, Object?>> _readState() async {
    final file = await _stateFile();
    if (!await file.exists()) {
      return <String, Object?>{};
    }
    final decoded = jsonDecode(await file.readAsString());
    if (decoded is Map<String, Object?>) {
      return decoded;
    }
    return <String, Object?>{};
  }

  Future<void> _writeState(Map<String, Object?> state) async {
    final file = await _stateFile();
    await file.parent.create(recursive: true);
    await file.writeAsString(jsonEncode(state));
  }

  Future<File> _stateFile() async {
    final directory = _stateDirectory();
    return File('${directory.path}${Platform.pathSeparator}state.json');
  }

  Directory _stateDirectory() {
    if (Platform.isWindows) {
      final appData = Platform.environment['APPDATA'];
      if (appData != null && appData.trim().isNotEmpty) {
        return Directory('$appData${Platform.pathSeparator}WorkoutTracker');
      }
    }

    final home = Platform.environment['HOME'];
    if (home != null && home.trim().isNotEmpty) {
      return Directory('$home${Platform.pathSeparator}.workout_tracker');
    }

    return Directory(
      '${Directory.systemTemp.path}${Platform.pathSeparator}workout_tracker',
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
