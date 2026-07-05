import 'package:flutter_test/flutter_test.dart';
import 'package:workout_tracker/sheets.dart';
import 'package:workout_tracker/format.dart';

void main() {
  test(
    'requests grid data only for the active sheet and Exercises tab',
    () async {
      final client = _FakeSheetsWorkbookClient(
        SheetsWorkbookSnapshot(
          sheets: [
            SheetsGridSnapshot(
              sheet: const SheetsSheetIdentity(
                sheetId: 42,
                title: 'Active Workout',
              ),
              rows: const [],
            ),
            SheetsGridSnapshot(
              sheet: const SheetsSheetIdentity(sheetId: 84, title: 'Exercises'),
              rows: const [],
            ),
          ],
        ),
      );
      final adapter = SheetsReadAdapter(client: client);

      await adapter.readActiveSheetInput('spreadsheet-id');

      expect(client.metadataSpreadsheetIds, ['spreadsheet-id']);
      expect(client.gridRequests, [
        const _GridRequest(
          spreadsheetId: 'spreadsheet-id',
          reads: [
            _GridRead(sheetTitle: 'Active Workout'),
            _GridRead(sheetTitle: 'Exercises'),
          ],
        ),
      ]);
    },
  );

  test(
    'reads the first tab and Exercises tab into the sheet-contract parser',
    () async {
      final adapter = SheetsReadAdapter(
        client: _FakeSheetsWorkbookClient(
          SheetsWorkbookSnapshot(
            sheets: [
              SheetsGridSnapshot(
                sheet: const SheetsSheetIdentity(
                  sheetId: 42,
                  title: 'Active Workout',
                ),
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
                  SheetsCellFormula(
                    sheetRowNumber: 3,
                    sheetColumnNumber: 1,
                    formula: '=Exercises!A2',
                  ),
                  SheetsCellFormula(
                    sheetRowNumber: 3,
                    sheetColumnNumber: 2,
                    formula: '=Exercises!C2',
                  ),
                  SheetsCellFormula(
                    sheetRowNumber: 3,
                    sheetColumnNumber: 3,
                    formula: '=Exercises!D2',
                  ),
                  SheetsCellFormula(
                    sheetRowNumber: 3,
                    sheetColumnNumber: 4,
                    formula: '=Exercises!E2',
                  ),
                  SheetsCellFormula(
                    sheetRowNumber: 3,
                    sheetColumnNumber: 5,
                    formula: '=Exercises!F2',
                  ),
                  SheetsCellFormula(
                    sheetRowNumber: 3,
                    sheetColumnNumber: 6,
                    formula: '=Exercises!G2',
                  ),
                  SheetsCellFormula(
                    sheetRowNumber: 3,
                    sheetColumnNumber: 7,
                    formula: '=Exercises!H2',
                  ),
                  SheetsCellFormula(
                    sheetRowNumber: 3,
                    sheetColumnNumber: 8,
                    formula: '=Exercises!I2',
                  ),
                ],
              ),
              SheetsGridSnapshot(
                sheet: const SheetsSheetIdentity(
                  sheetId: 84,
                  title: 'Exercises',
                ),
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
              SheetsGridSnapshot(
                sheet: const SheetsSheetIdentity(
                  sheetId: 126,
                  title: 'Archive',
                ),
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

class _FakeSheetsWorkbookClient implements SheetsWorkbookClient {
  _FakeSheetsWorkbookClient(this.snapshot);

  final SheetsWorkbookSnapshot snapshot;
  final List<String> metadataSpreadsheetIds = [];
  final List<_GridRequest> gridRequests = [];

  @override
  Future<SheetsWorkbookMetadata> fetchMetadata(String spreadsheetId) async {
    metadataSpreadsheetIds.add(spreadsheetId);
    return SheetsWorkbookMetadata(
      sheets: snapshot.sheets.map((sheet) => sheet.sheet),
    );
  }

  @override
  Future<SheetsWorkbookSnapshot> readGrids({
    required String spreadsheetId,
    required Iterable<SheetsGridRead> reads,
  }) {
    expect(spreadsheetId, 'spreadsheet-id');
    gridRequests.add(
      _GridRequest(
        spreadsheetId: spreadsheetId,
        reads: [
          for (final read in reads) _GridRead(sheetTitle: read.sheet.title),
        ],
      ),
    );
    return Future.value(snapshot);
  }

  @override
  Future<void> applyOperations({
    required String spreadsheetId,
    required Iterable<SheetsWorkbookOperation> operations,
  }) {
    throw UnimplementedError();
  }
}

class _GridRequest {
  const _GridRequest({required this.spreadsheetId, required this.reads});

  final String spreadsheetId;
  final List<_GridRead> reads;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is _GridRequest &&
            spreadsheetId == other.spreadsheetId &&
            _listEquals(reads, other.reads);
  }

  @override
  int get hashCode => Object.hash(spreadsheetId, Object.hashAll(reads));

  @override
  String toString() {
    return '_GridRequest(spreadsheetId: $spreadsheetId, reads: $reads)';
  }
}

class _GridRead {
  const _GridRead({required this.sheetTitle});

  final String sheetTitle;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is _GridRead && sheetTitle == other.sheetTitle;
  }

  @override
  int get hashCode => sheetTitle.hashCode;

  @override
  String toString() {
    return '_GridRead(sheetTitle: $sheetTitle)';
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
