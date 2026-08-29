import 'package:flutter_test/flutter_test.dart';
import 'package:workout_tracker/contract.dart';
import 'package:workout_tracker/migration.dart';
import 'package:workout_tracker/sheets.dart';

void main() {
  test('previews every 0.9 format change without writing', () async {
    final client = _Client();
    final migrator = VersionFormatMigrator(
      client: client,
      allowedSpreadsheetIds: const ['approved'],
    );

    final report = await migrator.dryRun('approved');

    expect(report.kind, WbkMigrationKind.format09);
    expect(report.recognized, isTrue);
    expect(report.canApply, isTrue);
    expect(report.changes, [
      'Exercises row 2 Log Format: '
          '"{Weight}[x]{Reps}[@]{RPE}" → "{Weight}x{Reps}@{RPE}".',
      'Active row 3 Log Format: '
          '"{Weight}[x]{Reps}[@]{RPE}" → "{Weight}x{Reps}@{RPE}".',
      'Set workbook schema version to 1.0.',
    ]);
    expect(report.historyCellCount, 2);
    expect(client.applyCount, 0);
  });

  test('converts formats atomically and preserves rendered cells', () async {
    final client = _Client();
    final migrator = VersionFormatMigrator(
      client: client,
      allowedSpreadsheetIds: const ['approved'],
    );

    final report = await migrator.migrate('approved', confirmed: true);

    expect(report.wasApplied, isTrue);
    expect(client.applyCount, 1);
    expect(client.schemaVersion, '1.0');
    expect(
      report.refreshedSheet?.schemaViolations.single.message,
      'Workbook schema version "1.0" is unsupported.',
    );
    expect(client.exerciseRows[1][6], '{Weight}x{Reps}@{RPE}');
    expect(client.exerciseRows[1][7], '100x5@8');
    expect(client.activeRows[2][4], '95x5@8');
    expect(client.activeRows[2][6], '{Weight}x{Reps}@{RPE}');
    expect(client.activeRows[2].sublist(10), ['90x5@8', 'paper note']);
    expect(client.activeFormulas, contains(_formatFormula));
  });

  test('rejects damaged or stale 0.9 workbooks', () async {
    final damaged = _Client(defaultValues: 'not equivalent');
    final damagedMigrator = VersionFormatMigrator(
      client: damaged,
      allowedSpreadsheetIds: const ['approved'],
    );

    final preview = await damagedMigrator.dryRun('approved');
    expect(preview.canApply, isFalse);
    expect(preview.blockers.join(' '), contains('Default Values'));
    expect(damaged.applyCount, 0);

    final changedAfterPreview = _Client();
    final previewedMigrator = VersionFormatMigrator(
      client: changedAfterPreview,
      allowedSpreadsheetIds: const ['approved'],
    );
    final approvedPreview = await previewedMigrator.dryRun('approved');
    changedAfterPreview.activeRows[2][5] = 'Changed after preview.';
    await expectLater(
      previewedMigrator.migrate(
        'approved',
        confirmed: true,
        expected: approvedPreview,
      ),
      throwsA(isA<StateError>()),
    );
    expect(changedAfterPreview.applyCount, 0);

    final stale = _Client(mutateBeforeRead: 2);
    final staleMigrator = VersionFormatMigrator(
      client: stale,
      allowedSpreadsheetIds: const ['approved'],
    );
    await expectLater(
      staleMigrator.migrate('approved', confirmed: true),
      throwsA(isA<StateError>()),
    );
    expect(stale.applyCount, 0);
  });

  test('is a no-op after reaching 1.0 and never infers 0.9', () async {
    final client = _Client();
    final migrator = VersionFormatMigrator(
      client: client,
      allowedSpreadsheetIds: const ['approved'],
    );

    await migrator.migrate('approved', confirmed: true);
    final second = await migrator.migrate('approved', confirmed: true);

    expect(second.alreadyCurrent, isTrue);
    expect(second.wasApplied, isFalse);
    expect(client.applyCount, 1);

    final unversioned = _Client(schemaVersion: null);
    final unversionedReport = await VersionFormatMigrator(
      client: unversioned,
      allowedSpreadsheetIds: const ['approved'],
    ).dryRun('approved');
    expect(unversionedReport.recognized, isFalse);
    expect(unversionedReport.sourceVersion, isNull);
    expect(unversioned.applyCount, 0);
  });

  test('offers no in-app upgrade for a 1.0 or 1.1 workbook', () async {
    for (final version in ['1.0', '1.1']) {
      final client = _Client(schemaVersion: version);
      final routed = RoutedFieldMigrator(
        client: client,
        allowedSpreadsheetIds: const ['approved'],
      );

      final preview = await routed.dryRun('approved');
      expect(preview.kind, WbkMigrationKind.format09, reason: version);
      expect(preview.recognized, isFalse, reason: version);
      expect(preview.canApply, isFalse, reason: version);
      expect(preview.changes, isEmpty, reason: version);

      final applied = await routed.migrate('approved', confirmed: true);
      expect(applied.wasApplied, isFalse, reason: version);
      expect(client.applyCount, 0, reason: version);
      expect(client.schemaVersion, version, reason: version);
    }
  });
}

const _formatFormula = SheetsCellFormula(
  sheetRowNumber: 3,
  sheetColumnNumber: 7,
  formula: '=Exercises!G2',
);

class _Client implements SheetsWorkbookClient {
  _Client({
    this.schemaVersion = priorWorkbookSchemaVersion,
    this.mutateBeforeRead,
    String defaultValues = '100x5@8',
  }) : activeRows = [
         [...activeSheetFixedColumns, 'Week 1', ''],
         [...List.filled(activeSheetFixedColumns.length, ''), 'S1', 'S2'],
         [
           'Squat',
           '3',
           '2 min',
           '2-1-1',
           '95x5@8',
           'Stay braced.',
           '{Weight}[x]{Reps}[@]{RPE}',
           'Legs',
           '',
           'x',
           '90x5@8',
           'paper note',
         ],
       ],
       exerciseRows = [
         priorExercisesSheetColumns,
         [
           'Squat',
           'Back squat',
           '3',
           '2 min',
           '2-1-1',
           '',
           '{Weight}[x]{Reps}[@]{RPE}',
           defaultValues,
         ],
       ];

  final active = const SheetsSheetIdentity(sheetId: 1, title: 'Active');
  final exercises = const SheetsSheetIdentity(sheetId: 2, title: 'Exercises');
  final List<List<String>> activeRows;
  final List<List<String>> exerciseRows;
  final int? mutateBeforeRead;
  final List<SheetsCellFormula> activeFormulas = const [
    SheetsCellFormula(
      sheetRowNumber: 3,
      sheetColumnNumber: 1,
      formula: '=Exercises!A2',
    ),
    _formatFormula,
  ];
  String? schemaVersion;
  var readCount = 0;
  var applyCount = 0;

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
    readCount += 1;
    if (readCount == mutateBeforeRead) {
      activeRows[2][5] = 'Changed concurrently.';
    }
    activeRows[2][0] = exerciseRows[1][0];
    activeRows[2][6] = exerciseRows[1][6];
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
    applyCount += 1;
    for (final operation in operations) {
      switch (operation) {
        case SheetsCellWrite():
          final rows = operation.sheet.sheetId == active.sheetId
              ? activeRows
              : exerciseRows;
          rows[operation.sheetRowNumber - 1][operation.sheetColumnNumber - 1] =
              operation.value;
        case SheetsMetadataWrite():
          schemaVersion = operation.value;
        default:
          throw UnsupportedError('$operation');
      }
    }
  }
}
