import 'package:flutter_test/flutter_test.dart';
import 'package:workout_tracker/migration.dart';
import 'package:workout_tracker/sheets.dart';

void main() {
  test('dry run is allowlisted and reports unmappable legacy values', () async {
    final client = _Client(
      activeRows: _activeRows(format: '{Seconds}[@]{RPE}'),
      exerciseRows: _exerciseRows(format: '{Seconds}[@]{RPE}'),
    );
    final migrator = LegacyFieldMigrator(
      client: client,
      allowedSpreadsheetIds: const ['approved'],
    );

    expect(() => migrator.dryRun('other'), throwsStateError);
    final report = await migrator.dryRun('approved');
    expect(report.canApply, isFalse);
    expect(report.changes, hasLength(2));
    expect(report.blockers.join(' '), contains('cannot map'));
    expect(client.applied, isFalse);
  });

  test('migrates approved rows and leaves history text untouched', () async {
    final client = _Client(
      activeRows: _activeRows(),
      exerciseRows: _exerciseRows(),
      activeFormulas: const [
        SheetsCellFormula(
          sheetRowNumber: 3,
          sheetColumnNumber: 1,
          formula: '=Exercises!A2',
        ),
        SheetsCellFormula(
          sheetRowNumber: 3,
          sheetColumnNumber: 8,
          formula: '=Exercises!I2',
        ),
      ],
    );
    final migrator = LegacyFieldMigrator(
      client: client,
      allowedSpreadsheetIds: const ['approved'],
    );

    final report = await migrator.migrate('approved', confirmed: true);

    expect(report.wasApplied, isTrue);
    expect(report.refreshedSheet?.schemaViolations, isEmpty);
    expect(client.activeRows.first.take(10), [
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
    ]);
    expect(client.activeRows[2][4], 'x5@8');
    expect(client.activeRows[2][9], 'x');
    expect(client.activeRows[2][10], 'raw notes from paper');
    expect(
      client.activeFormulas.map(
        (formula) => '${formula.sheetColumnNumber}:${formula.formula}',
      ),
      ['1:=Exercises!A2', '7:=Exercises!G2'],
    );
    expect(client.exerciseRows.first, [
      'Exercise',
      'Description',
      'Default Sets',
      'Default Rest',
      'Default Tempo',
      'Notes',
      'Log Format',
      'Default Values',
    ]);
    expect(client.exerciseRows[1][7], 'x5@8');
    expect(client.schemaVersion, workbookSchemaVersion);
  });

  test('does not guess a legacy path for a versioned workbook', () async {
    final client = _Client(
      activeRows: _activeRows(),
      exerciseRows: _exerciseRows(),
      schemaVersion: workbookSchemaVersion,
    );
    final report = await LegacyFieldMigrator(
      client: client,
      allowedSpreadsheetIds: const ['approved'],
    ).dryRun('approved');

    expect(report.recognized, isFalse);
    expect(report.blockers.join(' '), contains(workbookSchemaVersion));
  });

  test('rejects a stale workbook before applying operations', () async {
    final client = _Client(
      activeRows: _activeRows(),
      exerciseRows: _exerciseRows(),
      mutateBeforeRead: 2,
    );
    final migrator = LegacyFieldMigrator(
      client: client,
      allowedSpreadsheetIds: const ['approved'],
    );

    await expectLater(
      migrator.migrate('approved', confirmed: true),
      throwsA(isA<StateError>()),
    );
    expect(client.applied, isFalse);
  });
}

List<List<String>> _activeRows({String format = '{Weight}[x]{Reps}[@]{RPE}'}) =>
    [
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
      [...List.filled(10, ''), 'S1'],
      [
        'Squat',
        '3',
        '5',
        '8',
        '2 min',
        '2-1-1',
        'Stay braced.',
        format,
        'Legs',
        '',
        'raw notes from paper',
      ],
    ];

List<List<String>> _exerciseRows({
  String format = '{Weight}[x]{Reps}[@]{RPE}',
}) => [
  const [
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
  ['Squat', 'Back squat', '3', '5', '8', '2 min', '2-1-1', '', format],
];

class _Client implements SheetsWorkbookClient {
  _Client({
    required List<List<String>> activeRows,
    required List<List<String>> exerciseRows,
    Iterable<SheetsCellFormula> activeFormulas = const [],
    this.schemaVersion,
    this.mutateBeforeRead,
  }) : activeRows = activeRows.map((row) => [...row]).toList(),
       exerciseRows = exerciseRows.map((row) => [...row]).toList(),
       activeFormulas = [...activeFormulas];

  final active = const SheetsSheetIdentity(sheetId: 1, title: 'Active');
  final exercises = const SheetsSheetIdentity(sheetId: 2, title: 'Exercises');
  final List<List<String>> activeRows;
  final List<List<String>> exerciseRows;
  final List<SheetsCellFormula> activeFormulas;
  final int? mutateBeforeRead;
  String? schemaVersion;
  bool applied = false;
  var _readCount = 0;

  @override
  Future<SheetsWorkbookMetadata> fetchMetadata(String spreadsheetId) async {
    return SheetsWorkbookMetadata(
      sheets: [active, exercises],
      developerMetadata: [
        if (schemaVersion case final version?)
          SheetsDeveloperMetadata(
            id: 9,
            key: workbookSchemaKey,
            value: version,
          ),
      ],
    );
  }

  @override
  Future<SheetsWorkbookSnapshot> readGrids({
    required String spreadsheetId,
    required Iterable<SheetsGridRead> reads,
  }) async {
    _readCount += 1;
    if (_readCount == mutateBeforeRead) {
      activeRows[2][6] = 'Changed concurrently.';
    }
    return SheetsWorkbookSnapshot(
      sheets: [
        for (final read in reads)
          SheetsGridSnapshot(
            sheet: read.sheet,
            rows: read.sheet.sheetId == active.sheetId
                ? activeRows
                : exerciseRows,
            cellFormulas: read.sheet.sheetId == active.sheetId
                ? activeFormulas
                : const [],
          ),
      ],
    );
  }

  @override
  Future<void> applyOperations({
    required String spreadsheetId,
    required Iterable<SheetsWorkbookOperation> operations,
  }) async {
    applied = true;
    for (final operation in operations) {
      final rows = operation.sheet.sheetId == active.sheetId
          ? activeRows
          : exerciseRows;
      switch (operation) {
        case SheetsCellWrite():
          while (rows.length < operation.sheetRowNumber) {
            rows.add([]);
          }
          final row = rows[operation.sheetRowNumber - 1];
          while (row.length < operation.sheetColumnNumber) {
            row.add('');
          }
          final column = operation.sheetColumnNumber;
          activeFormulas.removeWhere(
            (formula) =>
                operation.sheet.sheetId == active.sheetId &&
                formula.sheetRowNumber == operation.sheetRowNumber &&
                formula.sheetColumnNumber == column,
          );
          if (operation.mode == SheetsValueInputMode.userEntered) {
            activeFormulas.add(
              SheetsCellFormula(
                sheetRowNumber: operation.sheetRowNumber,
                sheetColumnNumber: column,
                formula: operation.value,
              ),
            );
            row[column - 1] = _evaluate(operation.value);
          } else {
            row[column - 1] = operation.value;
          }
        case SheetsColumnDeletion():
          for (final row in rows) {
            final index = operation.sheetColumnNumber - 1;
            if (index < row.length) {
              final proposedEnd = index + operation.columnCount;
              row.removeRange(
                index,
                proposedEnd < row.length ? proposedEnd : row.length,
              );
            }
          }
        case SheetsMetadataWrite():
          schemaVersion = operation.value;
        default:
          throw UnsupportedError('$operation');
      }
    }
    activeFormulas.sort(
      (left, right) =>
          left.sheetColumnNumber.compareTo(right.sheetColumnNumber),
    );
  }

  String _evaluate(String formula) {
    if (formula.endsWith('!A2')) {
      return exerciseRows[1][0];
    }
    if (formula.endsWith('!I2') || formula.endsWith('!G2')) {
      return exerciseRows[1][8];
    }
    throw UnsupportedError('Unsupported test formula: $formula');
  }
}
