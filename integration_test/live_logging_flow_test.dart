import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:googleapis/sheets/v4.dart' as sheets;
import 'package:googleapis_auth/auth_io.dart' as auth;
import 'package:integration_test/integration_test.dart';
import 'package:workout_tracker/google_sheets.dart';
import 'package:workout_tracker/workout_tracker_app.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  auth.AutoRefreshingAuthClient? client;
  late DevelopmentSheetResetHarness resetHarness;
  late GoogleSheetsReadAdapter readAdapter;
  late SpreadsheetValidationService validationService;

  setUpAll(() async {
    final authenticatedClient =
        await clientViaWorkoutTrackerDevelopmentCredentials(
          scopes: GoogleApisSheetsWriteClient.writeScopes,
        );
    client = authenticatedClient;
    final api = sheets.SheetsApi(authenticatedClient);
    resetHarness = DevelopmentSheetResetHarness(
      client: GoogleApisDevelopmentSheetResetClient(api),
    );
    readAdapter = GoogleSheetsReadAdapter(
      client: GoogleApisSheetsSpreadsheetClient(api),
    );
    validationService = GoogleSpreadsheetValidationService(
      readAdapter: readAdapter,
      writeAdapter: GoogleSheetsWriteAdapter(
        client: GoogleApisSheetsWriteClient(api),
      ),
    );
  });

  tearDownAll(() {
    client?.close();
  });

  testWidgets('runs the live logging flow against the development sheet', (
    tester,
  ) async {
    addTearDown(() async {
      await resetHarness.reset();
    });

    await resetHarness.reset();

    await tester.pumpWidget(
      WorkoutTrackerApp(
        validationService: validationService,
        initialSpreadsheetText: workoutTrackerDevelopmentSpreadsheetUrl,
      ),
    );

    await _tapVisible(tester, find.text('Validate spreadsheet'));
    await _waitForFinder(tester, find.text('Sheet contract valid'));
    await _waitForFinder(tester, find.text('Bulgarian Split Squat'));

    expect(find.text('Formulas valid'), findsOneWidget);
    expect(find.text('Reverse Lunge'), findsOneWidget);

    await _tapVisible(tester, find.text('Bulgarian Split Squat'));
    await _waitForFinder(tester, find.text('Bulgarian Split Squat logging'));

    await tester.enterText(find.byKey(const ValueKey('set-weight')), '80');
    await tester.enterText(find.byKey(const ValueKey('set-reps')), '8');
    await tester.enterText(find.byKey(const ValueKey('set-rpe')), '8');
    await _tapVisible(tester, find.text('Save set'));
    await _waitForFinder(tester, find.text('80x8@8'));

    var activeSheet = await readAdapter.readParsedActiveSheet(
      workoutTrackerDevelopmentSpreadsheetId,
    );
    var primaryContext = activeSheet.buildExerciseLoggingContext(
      primarySheetRowNumber: 3,
      selectedSheetRowNumber: 3,
      historyBlockLabel: 'Week 2',
    );
    expect(primaryContext.selectedHistory.entries.first.rawValue, '80x8@8');

    await tester.enterText(find.byKey(const ValueKey('raw-S1')), '82.5x8@8');
    await _tapVisible(tester, find.byKey(const ValueKey('save-S1')));
    await _waitForFinder(tester, find.text('82.5x8@8'));

    activeSheet = await readAdapter.readParsedActiveSheet(
      workoutTrackerDevelopmentSpreadsheetId,
    );
    primaryContext = activeSheet.buildExerciseLoggingContext(
      primarySheetRowNumber: 3,
      selectedSheetRowNumber: 3,
      historyBlockLabel: 'Week 2',
    );
    expect(primaryContext.selectedHistory.entries.first.rawValue, '82.5x8@8');

    await _tapVisible(tester, find.byKey(const ValueKey('clear-S1')));
    await _waitForFinder(tester, find.text('Next set S1'));

    activeSheet = await readAdapter.readParsedActiveSheet(
      workoutTrackerDevelopmentSpreadsheetId,
    );
    primaryContext = activeSheet.buildExerciseLoggingContext(
      primarySheetRowNumber: 3,
      selectedSheetRowNumber: 3,
      historyBlockLabel: 'Week 2',
    );
    expect(primaryContext.selectedHistory.entries.first.rawValue, isEmpty);

    await _tapVisible(tester, find.text('Reverse Lunge'));
    await _waitForFinder(tester, find.text('Reverse Lunge logging'));

    await tester.enterText(find.byKey(const ValueKey('set-weight')), '25');
    await tester.enterText(find.byKey(const ValueKey('set-reps')), '10');
    await tester.enterText(find.byKey(const ValueKey('set-rpe')), '8');
    await _tapVisible(tester, find.text('Save set'));
    await _waitForFinder(tester, find.text('25x10@8'));

    activeSheet = await readAdapter.readParsedActiveSheet(
      workoutTrackerDevelopmentSpreadsheetId,
    );
    final backupContext = activeSheet.buildExerciseLoggingContext(
      primarySheetRowNumber: 3,
      selectedSheetRowNumber: 4,
      historyBlockLabel: 'Week 2',
    );
    expect(backupContext.selectedHistory.entries.first.rawValue, '25x10@8');

    await _tapVisible(tester, find.text('Back to exercises'));
    await _waitForFinder(tester, find.text('Legs exercises'));

    activeSheet = await readAdapter.readParsedActiveSheet(
      workoutTrackerDevelopmentSpreadsheetId,
    );
    final overview = activeSheet.buildWorkoutOverview(
      workout: 'Legs',
      historyBlockLabel: 'Week 2',
    );
    expect(overview.slots.first.setCount, 1);
  });
}

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pump();
}

Future<void> _waitForFinder(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 60),
}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 200));
    if (finder.evaluate().isNotEmpty) {
      return;
    }
  }
  fail('Timed out waiting for ${finder.describeMatch(Plurality.many)}.');
}
