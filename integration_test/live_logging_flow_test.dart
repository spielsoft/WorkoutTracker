import 'dart:io' show Platform;

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:workout_tracker/app.dart';
import 'package:workout_tracker/contract.dart';
import 'package:workout_tracker/migration.dart';
import 'package:workout_tracker/sheets.dart';

import '../test/support/reset.dart'
    show DevelopmentSheetResetHarness, workoutTrackerDevelopmentSpreadsheetId;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  final enabled =
      Platform.environment['WORKOUT_TRACKER_RUN_LIVE_GOOGLE_TESTS'] == '1';

  testWidgets('converts and logs DB Step-Up in the development fixture', (
    _,
  ) async {
    final auth = NativeSignInAuthGateway();
    final google = ScopedApiAccess(auth: auth);
    final workspace = WorkspaceCtrl(
      accountSession: auth,
      picker: DriveSheetPicker(
        googleAccess: google,
        showPicker: _resolveFixture,
      ),
    );
    final entry = LiveLoggingEntry(
      workspace: workspace,
      svc: SheetAccess(google),
    );
    addTearDown(() {
      workspace.dispose();
      auth.dispose();
    });

    var fixtureWasReset = false;
    addTearDown(() async {
      if (fixtureWasReset) {
        await _resetFixture(google);
      }
    });

    final report = await entry.run(
      const LiveSet(
        blockLabel: 'Week 1',
        primaryRow: 3,
        selectedRow: 3,
        fields: {
          'Height (in)': '12',
          'Weight (lbs)': '15',
          'Reps': '8',
          'RPE': '8',
          'Pain': '0',
        },
        expectedRaw: '(12, 15)x8@8,0',
      ),
      beforeValidation: () async {
        fixtureWasReset = true;
        await _reset09(google);
        await _convert09(google);
        await _upgradeStepUp(SheetAccess(google));
      },
    );

    final logged = report.activeSheet.buildLoggingContext(
      primaryRow: 3,
      selectedRow: 3,
      blockLabel: 'Week 1',
    );
    expect(logged.selectedHistory.entries.map((entry) => entry.rawValue), [
      '(10)x6@7,0',
      '(12, 15)x8@8,0',
    ]);
    expect(logged.selectedHistory.entries.first.logEntry, isA<RawLogEntry>());
    expect(
      logged.selectedHistory.entries.last.logEntry,
      isA<FormattedLogEntry>(),
    );
    await _inspect(google);
  }, skip: !enabled);
}

const _stepUpFormat = '({Height (in)}, {Weight (lbs)})x{Reps}@{RPE},{Pain}';
const _oldHistory = '(10)x6@7,0';
const _loggedSet = '(12, 15)x8@8,0';

Future<SheetEntry?> _resolveFixture(SheetViewReq req) async {
  final entries = await req.load('WorkoutTracker development');
  for (final entry in entries) {
    if (entry.id == workoutTrackerDevelopmentSpreadsheetId) {
      return entry;
    }
  }
  throw StateError(
    'The destructive WorkoutTracker development fixture is not accessible.',
  );
}

Future<void> _resetFixture(ApiAccess google) {
  return google.run(
    scopes: GoogleApisWbkInit.writeScopes,
    action: (resources) {
      return DevelopmentSheetResetHarness(
        initializer: GoogleApisWbkInit(resources.sheetsApi),
      ).reset();
    },
  );
}

Future<void> _reset09(ApiAccess google) {
  return google.run(
    scopes: GoogleApisWbkInit.writeScopes,
    action: (resources) async {
      final client = GoogleApisWbkClient(resources.sheetsApi);
      await GoogleApisWbkInit(
        resources.sheetsApi,
        workbookClient: client,
      ).initializeWorkbook(
        spreadsheetId: workoutTrackerDevelopmentSpreadsheetId,
        workbook: _format09Fixture(),
      );
      final metadata = await client.fetchMetadata(
        workoutTrackerDevelopmentSpreadsheetId,
      );
      await client.applyOperations(
        spreadsheetId: workoutTrackerDevelopmentSpreadsheetId,
        operations: [
          SheetsMetadataWrite(
            sheet: metadata.sheets.first,
            key: workbookSchemaKey,
            value: priorWorkbookSchemaVersion,
            metadataId: metadata.metadataByKey(workbookSchemaKey)?.id,
          ),
        ],
      );
    },
  );
}

Future<void> _convert09(ApiAccess google) {
  return google.run(
    scopes: GoogleApisWbkClient.writeScopes,
    action: (resources) async {
      final migrator = VersionFormatMigrator(
        client: GoogleApisWbkClient(resources.sheetsApi),
        allowedSpreadsheetIds: const [workoutTrackerDevelopmentSpreadsheetId],
      );
      final preview = await migrator.dryRun(
        workoutTrackerDevelopmentSpreadsheetId,
      );
      // Live-only HITL output: review precedes the confirmed write.
      // ignore: avoid_print
      print(_migrationSummary(preview));
      expect(preview.canApply, isTrue);
      expect(preview.sourceVersion, priorWorkbookSchemaVersion);
      expect(preview.historyCellCount, 1);
      expect(preview.changes, hasLength(3));
      expect(
        preview.changes.where((change) => change.contains('Log Format')),
        hasLength(2),
      );

      final applied = await migrator.migrate(
        workoutTrackerDevelopmentSpreadsheetId,
        confirmed: true,
        expected: preview,
      );
      expect(applied.wasApplied, isTrue);
      expect(applied.refreshedSheet?.schemaViolations, isEmpty);
    },
  );
}

Future<void> _upgradeStepUp(WbkAccess access) async {
  final sess = access.open(workoutTrackerDevelopmentSpreadsheetId);
  final before = await sess.read();
  final selected = before.activeSheet.canonicalExercises.single;
  final exercise = ExerciseDef(
    exercise: selected.exercise,
    description: selected.description,
    defaultSets: selected.defaultSets,
    defaultRest: selected.defaultRest,
    defaultTempo: selected.defaultTempo,
    notes: selected.notes,
    logFormat: _stepUpFormat,
    defaultValues: const {
      'Height (in)': '12',
      'Weight (lbs)': '15',
      'Reps': '8',
      'RPE': '8',
      'Pain': '0',
    },
  );
  final review = await sess.execute(
    UpdateExeCmd(selected: selected, exercise: exercise),
  );
  final impact = review.exeFormatImpact;
  expect(impact, isNotNull);
  expect(impact!.rawHistoryCount, 1);

  final updated = await sess.execute(
    ConfirmExeUpdateCmd(
      impact: impact,
      valuesByRow: {
        3: {...impact.placements.single.proposedValues},
      },
    ),
  );
  expect(updated.hasBlockingIssues, isFalse);
}

Future<void> _inspect(ApiAccess google) {
  return google.run(
    scopes: GoogleApisWbkClient.writeScopes,
    action: (resources) async {
      final client = GoogleApisWbkClient(resources.sheetsApi);
      final metadata = await client.fetchMetadata(
        workoutTrackerDevelopmentSpreadsheetId,
      );
      expect(
        metadata.metadataByKey(workbookSchemaKey)?.value,
        workbookSchemaVersion,
      );
      final active = metadata.sheets.first;
      final exercises = metadata.sheetByTitle('Exercises')!;
      final snapshot = await client.readGrids(
        spreadsheetId: workoutTrackerDevelopmentSpreadsheetId,
        reads: [
          SheetsGridRead(sheet: active),
          SheetsGridRead(sheet: exercises),
        ],
      );
      final activeGrid = snapshot.sheets.firstWhere(
        (grid) => grid.sheet.sheetId == active.sheetId,
      );
      final exerciseGrid = snapshot.sheets.firstWhere(
        (grid) => grid.sheet.sheetId == exercises.sheetId,
      );

      expect(exerciseGrid.rows[1][6], _stepUpFormat);
      expect(exerciseGrid.rows[1][7], _loggedSet);
      expect(activeGrid.rows[2][4], _loggedSet);
      expect(activeGrid.rows[2].sublist(10, 12), [_oldHistory, _loggedSet]);
      expect([
        for (final formula in activeGrid.cellFormulas)
          if (formula.sheetRowNumber == 3)
            (formula.sheetColumnNumber, formula.formula),
      ], containsAll(const [(1, '=Exercises!A2'), (7, '=Exercises!G2')]));
    },
  );
}

Wbk _format09Fixture() {
  return Wbk(
    activeSheet: WbkTab(
      title: 'Active Workout',
      rows: [
        [...activeSheetFixedColumns, 'Week 1', ''],
        [...List.filled(activeSheetFixedColumns.length, ''), 'S1', 'S2'],
        const [
          '=Exercises!A2',
          '3',
          '90s',
          '3-1-1',
          '(12)x8@8,0',
          'Live conversion fixture.',
          '=Exercises!G2',
          'Legs',
          '',
          'x',
          _oldHistory,
          '',
        ],
      ],
    ),
    exercisesSheet: WbkTab(
      title: 'Exercises',
      rows: const [
        exercisesSheetColumns,
        [
          'DB Step-Up',
          'Dumbbell step-up',
          '3',
          '90s',
          '3-1-1',
          'Control the descent.',
          '[(]{Height (in)}[)x]{Reps}[@]{RPE}[,]{Pain}',
          '(12)x8@8,0',
        ],
      ],
    ),
  );
}

String _migrationSummary(FormatMigrationReport report) => [
  'Format migration dry run for ${report.spreadsheetId}:',
  ...report.changes.map((change) => '- $change'),
  '- ${report.historyCellCount} history cell preserved',
  if (report.blockers.isEmpty)
    '- no blockers'
  else
    ...report.blockers.map((blocker) => '- BLOCKER: $blocker'),
].join('\n');
