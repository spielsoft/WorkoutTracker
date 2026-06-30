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

class FileAppStateStore implements AppStateStore {
  const FileAppStateStore();

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
