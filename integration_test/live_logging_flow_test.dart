import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:googleapis/sheets/v4.dart' as sheets;
import 'package:http/http.dart' as http;
import 'package:integration_test/integration_test.dart';
import 'package:workout_tracker/google_sheets.dart';
import 'package:workout_tracker/sheet_contract.dart';
import 'package:workout_tracker/workout_tracker_app.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  final runLiveGoogleTests =
      Platform.environment['WORKOUT_TRACKER_RUN_LIVE_GOOGLE_TESTS'] == '1';

  http.Client? client;
  late DevelopmentSheetResetHarness resetHarness;
  late GoogleSheetsReadAdapter readAdapter;
  late SpreadsheetValidationService validationService;

  setUpAll(() async {
    if (!runLiveGoogleTests) {
      return;
    }

    final authorizationGateway = NativeGoogleSignInAuthorizationGateway();
    final headers = await authorizationGateway.authorizationHeaders(
      GoogleApisSheetsWriteClient.writeScopes,
    );
    final authenticatedClient = GoogleAuthorizationHeadersClient(
      headers: headers,
    );
    client = authenticatedClient;
    final api = sheets.SheetsApi(authenticatedClient);
    resetHarness = DevelopmentSheetResetHarness(
      client: GoogleApisDevelopmentSheetResetClient(api),
    );
    readAdapter = GoogleSheetsReadAdapter(
      client: GoogleApisSheetsSpreadsheetClient(api),
    );
    validationService = GoogleSignInSpreadsheetValidationService(
      authorizationGateway: authorizationGateway,
    );
  });

  tearDownAll(() {
    client?.close();
  });

  testWidgets(
    'runs the live logging flow against the development sheet',
    (tester) async {
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

      await _tapVisible(
        tester,
        find.byKey(const ValueKey('validate-spreadsheet')),
      );
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

      var activeSheet = await _waitForLoggedSetValue(
        readAdapter: readAdapter,
        primarySheetRowNumber: 3,
        selectedSheetRowNumber: 3,
        expectedValue: '80x8@8',
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

      activeSheet = await _waitForLoggedSetValue(
        readAdapter: readAdapter,
        primarySheetRowNumber: 3,
        selectedSheetRowNumber: 3,
        expectedValue: '82.5x8@8',
      );
      primaryContext = activeSheet.buildExerciseLoggingContext(
        primarySheetRowNumber: 3,
        selectedSheetRowNumber: 3,
        historyBlockLabel: 'Week 2',
      );
      expect(primaryContext.selectedHistory.entries.first.rawValue, '82.5x8@8');

      await _tapVisible(tester, find.byKey(const ValueKey('clear-S1')));
      await _waitForFinder(tester, find.text('Next set S1'));

      activeSheet = await _waitForLoggedSetValue(
        readAdapter: readAdapter,
        primarySheetRowNumber: 3,
        selectedSheetRowNumber: 3,
        expectedValue: '',
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

      activeSheet = await _waitForLoggedSetValue(
        readAdapter: readAdapter,
        primarySheetRowNumber: 3,
        selectedSheetRowNumber: 4,
        expectedValue: '25x10@8',
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

      await tester.enterText(
        find.byKey(const ValueKey('new-history-block-label')),
        'Week 3',
      );
      await _tapVisible(tester, find.text('Create history block'));

      activeSheet = await _waitForHistoryBlock(
        readAdapter: readAdapter,
        label: 'Week 3',
      );
      expect(
        activeSheet.historyBlocks.map((block) => block.label),
        contains('Week 3'),
      );
    },
    skip: !runLiveGoogleTests,
  );
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

Future<ParsedActiveSheet> _waitForLoggedSetValue({
  required GoogleSheetsReadAdapter readAdapter,
  required int primarySheetRowNumber,
  required int selectedSheetRowNumber,
  required String expectedValue,
  Duration timeout = const Duration(seconds: 60),
}) async {
  final end = DateTime.now().add(timeout);
  ParsedActiveSheet? lastRead;
  while (DateTime.now().isBefore(end)) {
    lastRead = await readAdapter.readParsedActiveSheet(
      workoutTrackerDevelopmentSpreadsheetId,
    );
    final context = lastRead.buildExerciseLoggingContext(
      primarySheetRowNumber: primarySheetRowNumber,
      selectedSheetRowNumber: selectedSheetRowNumber,
      historyBlockLabel: 'Week 2',
    );
    if (context.selectedHistory.entries.first.rawValue == expectedValue) {
      return lastRead;
    }
    await Future<void>.delayed(const Duration(milliseconds: 250));
  }
  final lastValue = lastRead
      ?.buildExerciseLoggingContext(
        primarySheetRowNumber: primarySheetRowNumber,
        selectedSheetRowNumber: selectedSheetRowNumber,
        historyBlockLabel: 'Week 2',
      )
      .selectedHistory
      .entries
      .first
      .rawValue;
  fail(
    'Timed out waiting for logged set value $expectedValue; got $lastValue.',
  );
}

Future<ParsedActiveSheet> _waitForHistoryBlock({
  required GoogleSheetsReadAdapter readAdapter,
  required String label,
  Duration timeout = const Duration(seconds: 60),
}) async {
  final end = DateTime.now().add(timeout);
  ParsedActiveSheet? lastRead;
  while (DateTime.now().isBefore(end)) {
    lastRead = await readAdapter.readParsedActiveSheet(
      workoutTrackerDevelopmentSpreadsheetId,
    );
    if (lastRead.historyBlocks.any((block) => block.label == label)) {
      return lastRead;
    }
    await Future<void>.delayed(const Duration(milliseconds: 250));
  }
  fail(
    'Timed out waiting for history block $label; got '
    '${lastRead?.historyBlocks.map((block) => block.label).toList()}.',
  );
}
