import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:workout_tracker/workout_tracker_app.dart';

void main() {
  test('Google workspace access state groups sheet-adjacent persistence', () {
    const state = GoogleWorkspaceAccessState(
      spreadsheetText: 'spreadsheet-id',
      selectedSpreadsheet: SelectedSpreadsheet(
        spreadsheetId: 'spreadsheet-id',
        name: 'Development Workouts',
        accountEmail: 'user@example.com',
      ),
      googleAuthorization: GooglePickerAuthorizationSnapshot(
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

    final decoded = GoogleWorkspaceAccessState.fromJson(state.toJson());

    expect(decoded.spreadsheetText, 'spreadsheet-id');
    expect(decoded.selectedSpreadsheet?.name, 'Development Workouts');
    expect(decoded.selectedSpreadsheet?.accountEmail, 'user@example.com');
    expect(decoded.googleAuthorization?.accessToken, 'picker-access-token');
    expect(decoded.googleAuthorization?.accountEmail, 'user@example.com');
    expect(decoded.googleAuthorization?.displayName, 'User Name');
    expect(
      decoded.googleAuthorization?.photoUrl,
      'https://example.com/user.png',
    );
    expect(decoded.workoutSelection?.workout, 'Legs');
    expect(decoded.workoutSelection?.historyBlock, 'Week 1');
  });

  test('Google workspace access state can migrate legacy separated keys', () {
    final migrated = const GoogleWorkspaceAccessState().migrateLegacy(
      spreadsheetText: 'legacy-spreadsheet-id',
      selectedSpreadsheet: const SelectedSpreadsheet(
        spreadsheetId: 'selected-spreadsheet-id',
        name: 'Saved Workouts',
      ),
      workoutSelection: const WorkoutSelectionState(
        spreadsheetId: 'selected-spreadsheet-id',
        workout: 'Upper',
        historyBlock: 'Week 2',
      ),
    );

    expect(migrated.spreadsheetText, 'legacy-spreadsheet-id');
    expect(
      migrated.selectedSpreadsheet?.spreadsheetId,
      'selected-spreadsheet-id',
    );
    expect(migrated.workoutSelection?.workout, 'Upper');
  });

  test('file app state store uses macOS app container support directory', () {
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
        'Containers',
        'com.spielman.workouttracker',
        'Data',
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
    const state = GoogleWorkspaceAccessState(
      spreadsheetText: 'spreadsheet-id',
      selectedSpreadsheet: SelectedSpreadsheet(
        spreadsheetId: 'spreadsheet-id',
        name: 'Development Workouts',
      ),
      googleAuthorization: GooglePickerAuthorizationSnapshot(
        accessToken: 'picker-access-token',
        accountEmail: 'athlete@example.com',
      ),
    );

    await store.writeGoogleWorkspaceAccessState(state);
    final restored = await store.readGoogleWorkspaceAccessState();

    expect(restored.spreadsheetText, 'spreadsheet-id');
    expect(restored.selectedSpreadsheet?.name, 'Development Workouts');
    expect(restored.googleAuthorization?.accountEmail, 'athlete@example.com');
  });
}
