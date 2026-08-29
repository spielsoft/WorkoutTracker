import 'package:flutter_test/flutter_test.dart';
import 'package:workout_tracker/contract.dart';
import 'package:workout_tracker/sheets.dart';

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
                    'Rest',
                    'Tempo',
                    'Targets',
                    'Notes',
                    'Log Format',
                    'Workout',
                    'is_backup',
                    'is_exercise',
                    'Week 1',
                  ],
                  ['', '', '', '', '', '', '', '', '', '', 'S1'],
                  [
                    'Squat',
                    '3',
                    '3 min',
                    '',
                    'x5@8',
                    'Stay braced.',
                    '{Weight}x{Reps}@{RPE}',
                    'Legs',
                    '',
                    'x',
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
                    sheetColumnNumber: 7,
                    formula: '=Exercises!G2',
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
                    'Default Rest',
                    'Default Tempo',
                    'Notes',
                    'Log Format',
                    'Default Values',
                  ],
                  [
                    'Squat',
                    'Back squat',
                    '3',
                    '3 min',
                    '2-1-1',
                    'Stay braced.',
                    '{Weight}x{Reps}@{RPE}',
                    'x5@8',
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
            .buildWorkoutOverview(workout: 'Legs', blockLabel: 'Week 1')
            .slots
            .single
            .setCount,
        1,
      );
      expect(activeSheet.healingIssues, isEmpty);
    },
  );

  test('reports a missing Exercises tab to the contract parser', () async {
    final adapter = SheetsReadAdapter(
      client: _FakeSheetsWorkbookClient(
        SheetsWorkbookSnapshot(
          sheets: [
            SheetsGridSnapshot(
              sheet: const SheetsSheetIdentity(
                sheetId: 42,
                title: 'Active Workout',
              ),
              rows: [activeSheetFixedColumns],
            ),
          ],
        ),
      ),
    );

    final parsed = await adapter.readParsedActiveSheet('spreadsheet-id');

    expect(
      parsed.schemaViolations.map((issue) => issue.message),
      contains('The Exercises tab is missing.'),
    );
  });

  test('routes declared 0.9 formats without treating them as 1.0', () async {
    final parsedOld = await SheetsReadAdapter(
      client: _FakeSheetsWorkbookClient(
        _versionedSnapshot(
          '{Reps}[@]{RPE}',
          '8@7',
          exerciseColumns: priorExercisesSheetColumns,
        ),
        schemaVersion: '0.9',
      ),
    ).readParsedActiveSheet('spreadsheet-id');

    expect(parsedOld.schemaViolations, isEmpty);
    expect(parsedOld.canonicalExercises.single.defaultValues, {
      'Reps': '8',
      'RPE': '7',
    });
    expect(parsedOld.slots.single.targetValues, const {
      'Reps': '8',
      'RPE': '7',
    });

    final current = await SheetsReadAdapter(
      client: _FakeSheetsWorkbookClient(
        _versionedSnapshot('{Reps}[@]{RPE}', '8@7'),
      ),
    ).readParsedActiveSheet('spreadsheet-id');
    expect(
      current.schemaViolations.map((issue) => issue.message),
      contains('Targets do not match Log Format.'),
    );
  });

  test('does not infer a schema version from workbook structure', () async {
    final parsed = await SheetsReadAdapter(
      client: _FakeSheetsWorkbookClient(
        _versionedSnapshot('{Reps}@{RPE}', '8@7'),
        schemaVersion: null,
      ),
    ).readParsedActiveSheet('spreadsheet-id');

    expect(
      parsed.schemaViolations.map((issue) => issue.message),
      contains('Workbook schema version metadata is missing.'),
    );
  });
}

SheetsWorkbookSnapshot _versionedSnapshot(
  String format,
  String values, {
  List<String> exerciseColumns = exercisesSheetColumns,
}) {
  return SheetsWorkbookSnapshot(
    sheets: [
      SheetsGridSnapshot(
        sheet: const SheetsSheetIdentity(sheetId: 42, title: 'Active Workout'),
        rows: [
          activeSheetFixedColumns,
          List.filled(activeSheetFixedColumns.length, ''),
          ['Lift', '1', '', '', values, '', format, '', '', 'x'],
        ],
      ),
      SheetsGridSnapshot(
        sheet: const SheetsSheetIdentity(sheetId: 84, title: 'Exercises'),
        rows: [
          exerciseColumns,
          ['Lift', '', '1', '', '', '', format, values],
        ],
      ),
    ],
  );
}

class _FakeSheetsWorkbookClient implements SheetsWorkbookClient {
  _FakeSheetsWorkbookClient(
    this.snapshot, {
    this.schemaVersion = workbookSchemaVersion,
  });

  final SheetsWorkbookSnapshot snapshot;
  final String? schemaVersion;
  final List<String> metadataSpreadsheetIds = [];
  final List<_GridRequest> gridRequests = [];

  @override
  Future<SheetsWorkbookMetadata> fetchMetadata(String spreadsheetId) async {
    metadataSpreadsheetIds.add(spreadsheetId);
    return SheetsWorkbookMetadata(
      sheets: snapshot.sheets.map((sheet) => sheet.sheet),
      developerMetadata: [
        if (schemaVersion case final value?)
          SheetsDeveloperMetadata(id: 1, key: workbookSchemaKey, value: value),
      ],
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
