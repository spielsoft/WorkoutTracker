import 'package:flutter_test/flutter_test.dart';
import 'package:workout_tracker/google_sheets.dart';
import 'package:workout_tracker/log_format.dart';

void main() {
  test(
    'requests grid data only for the active sheet and Exercises tab',
    () async {
      final client = _FakeGoogleSheetsSpreadsheetClient(
        GoogleSpreadsheetSnapshot(
          sheets: [
            GoogleSheetSnapshot(title: 'Active Workout', rows: const []),
            GoogleSheetSnapshot(title: 'Exercises', rows: const []),
          ],
        ),
      );
      final adapter = GoogleSheetsReadAdapter(client: client);

      await adapter.readActiveSheetInput('spreadsheet-id');

      expect(client.metadataSpreadsheetIds, ['spreadsheet-id']);
      expect(client.gridRequests, [
        const _GridRequest(
          spreadsheetId: 'spreadsheet-id',
          ranges: ["'Active Workout'", "'Exercises'"],
        ),
      ]);
    },
  );

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
  final List<String> metadataSpreadsheetIds = [];
  final List<_GridRequest> gridRequests = [];

  @override
  Future<GoogleSpreadsheetMetadata> fetchSpreadsheetMetadata(
    String spreadsheetId,
  ) async {
    metadataSpreadsheetIds.add(spreadsheetId);
    return GoogleSpreadsheetMetadata(
      sheets: snapshot.sheets.map(
        (sheet) => GoogleSheetMetadata(title: sheet.title),
      ),
    );
  }

  @override
  Future<GoogleSpreadsheetSnapshot> fetchSpreadsheetGridData(
    String spreadsheetId, {
    required Iterable<String> ranges,
  }) {
    expect(spreadsheetId, 'spreadsheet-id');
    gridRequests.add(
      _GridRequest(spreadsheetId: spreadsheetId, ranges: ranges.toList()),
    );
    return Future.value(snapshot);
  }
}

class _GridRequest {
  const _GridRequest({required this.spreadsheetId, required this.ranges});

  final String spreadsheetId;
  final List<String> ranges;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is _GridRequest &&
            spreadsheetId == other.spreadsheetId &&
            _listEquals(ranges, other.ranges);
  }

  @override
  int get hashCode => Object.hash(spreadsheetId, Object.hashAll(ranges));

  @override
  String toString() {
    return '_GridRequest(spreadsheetId: $spreadsheetId, ranges: $ranges)';
  }
}

bool _listEquals<T>(List<T> left, List<T> right) {
  if (left.length != right.length) {
    return false;
  }
  for (var index = 0; index < left.length; index += 1) {
    if (left[index] != right[index]) {
      return false;
    }
  }
  return true;
}
