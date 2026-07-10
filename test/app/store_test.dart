import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:workout_tracker/app.dart';

void main() {
  test('Google workspace access state groups sheet-adjacent persistence', () {
    const state = WorkspaceAccessSt(
      sheetText: 'spreadsheet-id',
      selectedSheet: SelectedSheet(
        spreadsheetId: 'spreadsheet-id',
        name: 'Development Workouts',
        accountEmail: 'user@example.com',
      ),
      workoutSelection: WorkoutSelectionSt(
        spreadsheetId: 'spreadsheet-id',
        workout: 'Legs',
        historyBlock: 'Week 1',
      ),
    );

    final decoded = WorkspaceAccessSt.fromJson(state.toJson());

    expect(decoded.sheetText, 'spreadsheet-id');
    expect(decoded.selectedSheet?.name, 'Development Workouts');
    expect(decoded.selectedSheet?.accountEmail, 'user@example.com');
    expect(decoded.workoutSelection?.workout, 'Legs');
    expect(decoded.workoutSelection?.historyBlock, 'Week 1');
  });

  test('file app state store uses Application Support on macOS', () {
    final directory = FileAppStStore.defaultStDir(
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
    final store = FileAppStStore(stateDirectory: directory);
    const state = WorkspaceAccessSt(
      sheetText: 'spreadsheet-id',
      selectedSheet: SelectedSheet(
        spreadsheetId: 'spreadsheet-id',
        name: 'Development Workouts',
      ),
    );

    await store.writeWorkspaceSt(state);
    final restored = await store.readWorkspaceSt();

    expect(restored.sheetText, 'spreadsheet-id');
    expect(restored.selectedSheet?.name, 'Development Workouts');
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
    final store = FileAppStStore(stateDirectory: directory);
    final controller = WorkspaceStCtrl(store);

    await Future.wait([
      controller.update((state) => state.copyWith(sheetText: 'spreadsheet-id')),
      controller.update(
        (state) => state.copyWith(
          selectedSheet: SelectedSheet(
            spreadsheetId: 'spreadsheet-id',
            name: 'Development Workouts',
          ),
        ),
      ),
      controller.update(
        (state) => state.copyWith(
          workoutSelection: const WorkoutSelectionSt(
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
    final restored = await store.readWorkspaceSt();
    expect(restored.sheetText, 'spreadsheet-id');
    expect(restored.selectedSheet?.name, 'Development Workouts');
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
    final store = FileAppStStore(stateDirectory: directory);

    final restored = await store.readWorkspaceSt();

    expect(restored.sheetText, isNull);
    expect(restored.selectedSheet, isNull);
  });

  test('ignores retired picker authorization in existing state', () {
    final restored = WorkspaceAccessSt.fromJson({
      'sheetText': 'spreadsheet-id',
      'pickerAuth': {
        'accessToken': 'retired-token',
        'accountEmail': 'old@example.com',
      },
      'googleAuthorization': {'accessToken': 'older-token'},
    });

    expect(restored.sheetText, 'spreadsheet-id');
    expect(restored.toJson(), {'sheetText': 'spreadsheet-id'});
  });
}
