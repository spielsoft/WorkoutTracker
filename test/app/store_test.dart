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

  test('file app state store restores grouped state after restart', () async {
    final directory = await Directory.systemTemp.createTemp(
      'workout-tracker-state-test-',
    );
    addTearDown(() async {
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    });
    final store = FileAppStStore(() async => directory);
    const state = WorkspaceAccessSt(
      sheetText: 'spreadsheet-id',
      selectedSheet: SelectedSheet(
        spreadsheetId: 'spreadsheet-id',
        name: 'Development Workouts',
      ),
    );

    await store.writeWorkspaceSt(state);
    final restored = await FileAppStStore(
      () async => directory,
    ).readWorkspaceSt();

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
    final store = FileAppStStore(() async => directory);
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

  test('file app state store reports malformed existing state', () async {
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
    final store = FileAppStStore(() async => directory);

    await expectLater(store.readWorkspaceSt(), throwsA(isA<FormatException>()));
  });

  test('file app state store reports an I/O failure', () async {
    final directory = await Directory.systemTemp.createTemp(
      'workout-tracker-failed-state-test-',
    );
    addTearDown(() async {
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    });
    final blocker = File(
      '${directory.path}${Platform.pathSeparator}not-a-directory',
    );
    await blocker.writeAsString('blocked');
    final store = FileAppStStore(() async => Directory(blocker.path));

    await expectLater(
      store.writeWorkspaceSt(
        const WorkspaceAccessSt(sheetText: 'spreadsheet-id'),
      ),
      throwsA(isA<FileSystemException>()),
    );
  });

  test('workspace reports application-support lookup failure', () async {
    final store = FileAppStStore(() async {
      throw const FileSystemException('Application Support unavailable');
    });
    final workspace = WorkspaceCtrl(
      accessStOwner: WorkspaceStCtrl(store),
      initialText: 'session-sheet-id',
    );

    final restored = await workspace.restore();

    expect(restored.pastedText, 'session-sheet-id');
    expect(restored.error, contains('could not be restored'));
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
