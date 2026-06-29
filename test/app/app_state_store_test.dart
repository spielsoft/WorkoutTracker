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
}
