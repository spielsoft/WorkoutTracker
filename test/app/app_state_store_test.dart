import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:workout_tracker/workout_tracker_app.dart';

void main() {
  test('Google workspace access state groups sheet-adjacent persistence', () {
    const state = WorkspaceAccessState(
      spreadsheetText: 'spreadsheet-id',
      selectedSpreadsheet: SelectedSpreadsheet(
        spreadsheetId: 'spreadsheet-id',
        name: 'Development Workouts',
        accountEmail: 'user@example.com',
      ),
      pickerAuth: PickerAuth(
        accessToken: 'picker-access-token',
        accountEmail: 'user@example.com',
        displayName: 'User Name',
        photoUrl: 'https://example.com/user.png',
      ),
      workoutSelection: WorkoutSelectionState(
        spreadsheetId: 'spreadsheet-id',
        workout: 'Legs',
        historyBlock: 'Week 1',
      ),
    );

    final decoded = WorkspaceAccessState.fromJson(state.toJson());

    expect(decoded.spreadsheetText, 'spreadsheet-id');
    expect(decoded.selectedSpreadsheet?.name, 'Development Workouts');
    expect(decoded.selectedSpreadsheet?.accountEmail, 'user@example.com');
    expect(decoded.pickerAuth?.accessToken, 'picker-access-token');
    expect(decoded.pickerAuth?.accountEmail, 'user@example.com');
    expect(decoded.pickerAuth?.displayName, 'User Name');
    expect(decoded.pickerAuth?.photoUrl, 'https://example.com/user.png');
    expect(decoded.workoutSelection?.workout, 'Legs');
    expect(decoded.workoutSelection?.historyBlock, 'Week 1');
  });

  test('file app state store uses Application Support on macOS', () {
    final directory = FileAppStateStore.defaultStateDirectory(
      isWindows: false,
      isMacOS: true,
      environment: {'HOME': '/Users/athlete'},
      systemTemp: Directory('/tmp'),
    );

    expect(
      directory.path,
      [
        '',
        'Users',
        'athlete',
        'Library',
        'Application Support',
        'WorkoutTracker',
      ].join(Platform.pathSeparator),
    );
  });

  test('file app state store persists grouped state to disk', () async {
    final directory = await Directory.systemTemp.createTemp(
      'workout-tracker-state-test-',
    );
    addTearDown(() async {
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    });
    final store = FileAppStateStore(stateDirectory: directory);
    const state = WorkspaceAccessState(
      spreadsheetText: 'spreadsheet-id',
      selectedSpreadsheet: SelectedSpreadsheet(
        spreadsheetId: 'spreadsheet-id',
        name: 'Development Workouts',
      ),
      pickerAuth: PickerAuth(
        accessToken: 'picker-access-token',
        accountEmail: 'athlete@example.com',
      ),
    );

    await store.writeWorkspaceState(state);
    final restored = await store.readWorkspaceState();

    expect(restored.spreadsheetText, 'spreadsheet-id');
    expect(restored.selectedSpreadsheet?.name, 'Development Workouts');
    expect(restored.pickerAuth?.accountEmail, 'athlete@example.com');
  });

  test('state controller preserves overlapping workspace updates', () async {
    final directory = await Directory.systemTemp.createTemp(
      'workout-tracker-controller-state-test-',
    );
    addTearDown(() async {
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    });
    final store = FileAppStateStore(stateDirectory: directory);
    final controller = WorkspaceStateController(store);

    await Future.wait([
      controller.update(
        (state) => state.copyWith(spreadsheetText: 'spreadsheet-id'),
      ),
      controller.update(
        (state) => state.copyWith(
          selectedSpreadsheet: SelectedSpreadsheet(
            spreadsheetId: 'spreadsheet-id',
            name: 'Development Workouts',
          ),
          pickerAuth: PickerAuth(
            accessToken: 'picker-access-token',
            accountEmail: 'athlete@example.com',
          ),
        ),
      ),
      controller.update(
        (state) => state.copyWith(
          workoutSelection: const WorkoutSelectionState(
            spreadsheetId: 'spreadsheet-id',
            workout: 'Legs',
            historyBlock: 'Week 1',
          ),
        ),
      ),
    ]);

    final file = File('${directory.path}${Platform.pathSeparator}state.json');
    final decoded = jsonDecode(await file.readAsString());

    expect(decoded, isA<Map<String, Object?>>());
    final restored = await store.readWorkspaceState();
    expect(restored.spreadsheetText, 'spreadsheet-id');
    expect(restored.selectedSpreadsheet?.name, 'Development Workouts');
    expect(restored.pickerAuth?.accountEmail, 'athlete@example.com');
    expect(restored.workoutSelection?.workout, 'Legs');
  });

  test('file app state store ignores malformed existing state', () async {
    final directory = await Directory.systemTemp.createTemp(
      'workout-tracker-malformed-state-test-',
    );
    addTearDown(() async {
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    });
    await File(
      '${directory.path}${Platform.pathSeparator}state.json',
    ).writeAsString('{"googleWorkspaceAccess":{}}{"extra":true}');
    final store = FileAppStateStore(stateDirectory: directory);

    final restored = await store.readWorkspaceState();

    expect(restored.spreadsheetText, isNull);
    expect(restored.selectedSpreadsheet, isNull);
    expect(restored.pickerAuth, isNull);
  });
}
