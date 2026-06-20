import 'package:flutter_test/flutter_test.dart';
import 'package:workout_tracker/workout_tracker_app.dart';

void main() {
  test('selected spreadsheet encodes display metadata separately from ID', () {
    const selected = SelectedSpreadsheet(
      spreadsheetId: 'spreadsheet-id',
      name: '2026 Workouts',
      drivePath: 'My Drive / Workouts / 2026 Workouts',
      webViewLink: 'https://docs.google.com/spreadsheets/d/spreadsheet-id',
      accountEmail: 'user@example.com',
    );

    final decoded = decodeSelectedSpreadsheet(
      encodeSelectedSpreadsheet(selected),
    );

    expect(decoded?.spreadsheetId, 'spreadsheet-id');
    expect(decoded?.displayLabel, 'My Drive / Workouts / 2026 Workouts');
    expect(decoded?.accountEmail, 'user@example.com');
  });

  test(
    'disabled spreadsheet picker reports both actions unavailable',
    () async {
      const picker = DisabledSpreadsheetPicker(reason: 'Selection disabled.');

      expect(picker.availability.canChoose, isFalse);
      expect(picker.availability.canCreate, isFalse);
      expect(picker.availability.summary, 'Selection disabled.');
      await expectLater(picker.chooseSpreadsheet(), throwsA(isA<StateError>()));
      await expectLater(picker.createSpreadsheet(), throwsA(isA<StateError>()));
    },
  );
}
