import 'dart:convert';
import 'dart:io';

abstract interface class AppStateStore {
  Future<String?> readSpreadsheetText();

  Future<void> writeSpreadsheetText(String value);
}

class FileAppStateStore implements AppStateStore {
  const FileAppStateStore();

  static const _spreadsheetTextKey = 'spreadsheetText';

  @override
  Future<String?> readSpreadsheetText() async {
    final file = await _stateFile();
    if (!await file.exists()) {
      return null;
    }
    final decoded = jsonDecode(await file.readAsString());
    if (decoded case <String, Object?>{
      _spreadsheetTextKey: final String value,
    }) {
      return value;
    }
    return null;
  }

  @override
  Future<void> writeSpreadsheetText(String value) async {
    final file = await _stateFile();
    await file.parent.create(recursive: true);
    await file.writeAsString(jsonEncode({_spreadsheetTextKey: value}));
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
