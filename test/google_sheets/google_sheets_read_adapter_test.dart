import 'package:flutter_test/flutter_test.dart';
import 'package:workout_tracker/google_sheets.dart';
import 'package:workout_tracker/log_format.dart';

void main() {
  test(
    'reads the first tab and Exercises tab into the sheet-contract parser',
    () async {
      final adapter = GoogleSheetsReadAdapter(
        client: _FakeGoogleSheetsSpreadsheetClient(
          GoogleSpreadsheetSnapshot(
            sheets: [
              GoogleSheetSnapshot(
                title: 'Active Workout',
                rows: const [
                  [
                    'Exercise',
                    'Sets',
                    'Reps',
                    'RPE',
                    'Rest',
                    'Tempo',
                    'Notes',
                    'Log Format',
                    'Workout',
                    'is_backup',
                    'Week 1',
                  ],
                  ['', '', '', '', '', '', '', '', '', '', 'S1'],
                  [
                    'Squat',
                    '3',
                    '5',
                    '8',
                    '3 min',
                    '',
                    'Stay braced.',
                    '{Weight}[x]{Reps}[@]{RPE}',
                    'Legs',
                    '',
                    '225x5@8',
                  ],
                ],
                cellFormulas: const [
                  GoogleSheetCellFormula(
                    sheetRowNumber: 3,
                    sheetColumnNumber: 1,
                    formula: '=Exercises!A2',
                  ),
                  GoogleSheetCellFormula(
                    sheetRowNumber: 3,
                    sheetColumnNumber: 2,
                    formula: '=Exercises!C2',
                  ),
                  GoogleSheetCellFormula(
                    sheetRowNumber: 3,
                    sheetColumnNumber: 3,
                    formula: '=Exercises!D2',
                  ),
                  GoogleSheetCellFormula(
                    sheetRowNumber: 3,
                    sheetColumnNumber: 4,
                    formula: '=Exercises!E2',
                  ),
                  GoogleSheetCellFormula(
                    sheetRowNumber: 3,
                    sheetColumnNumber: 5,
                    formula: '=Exercises!F2',
                  ),
                  GoogleSheetCellFormula(
                    sheetRowNumber: 3,
                    sheetColumnNumber: 6,
                    formula: '=Exercises!G2',
                  ),
                  GoogleSheetCellFormula(
                    sheetRowNumber: 3,
                    sheetColumnNumber: 7,
                    formula: '=Exercises!H2',
                  ),
                  GoogleSheetCellFormula(
                    sheetRowNumber: 3,
                    sheetColumnNumber: 8,
                    formula: '=Exercises!I2',
                  ),
                ],
              ),
              GoogleSheetSnapshot(
                title: 'Exercises',
                rows: const [
                  [
                    'Exercise',
                    'Description',
                    'Default Sets',
                    'Default Reps',
                    'Default RPE',
                    'Default Rest',
                    'Default Tempo',
                    'Notes',
                    'Log Format',
                  ],
                  [
                    'Squat',
                    'Back squat',
                    '3',
                    '5',
                    '8',
                    '3 min',
                    '',
                    'Stay braced.',
                    '{Weight}[x]{Reps}[@]{RPE}',
                  ],
                ],
              ),
              GoogleSheetSnapshot(
                title: 'Archive',
                rows: const [
                  ['Exercise'],
                  ['This tab must not be treated as active.'],
                ],
              ),
            ],
          ),
        ),
      );

      final activeSheet = await adapter.readParsedActiveSheet('spreadsheet-id');

      expect(activeSheet.selectableWorkouts, ['Legs']);
      expect(activeSheet.historyBlocks.single.label, 'Week 1');
      expect(
        (activeSheet.slots.single.logFormat as ParsedLogFormat).fieldLabels,
        ['Weight', 'Reps', 'RPE'],
      );
      expect(
        activeSheet
            .buildWorkoutOverview(workout: 'Legs', historyBlockLabel: 'Week 1')
            .slots
            .single
            .setCount,
        1,
      );
      expect(activeSheet.formulaHealingIssues, isEmpty);
    },
  );
}

class _FakeGoogleSheetsSpreadsheetClient
    implements GoogleSheetsSpreadsheetClient {
  _FakeGoogleSheetsSpreadsheetClient(this.snapshot);

  final GoogleSpreadsheetSnapshot snapshot;

  @override
  Future<GoogleSpreadsheetSnapshot> fetchSpreadsheet(String spreadsheetId) {
    expect(spreadsheetId, 'spreadsheet-id');
    return Future.value(snapshot);
  }
}
