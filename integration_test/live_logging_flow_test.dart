import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:googleapis/sheets/v4.dart' as sheets;
import 'package:http/http.dart' as http;
import 'package:integration_test/integration_test.dart';
import 'package:workout_tracker/app.dart';
import 'package:workout_tracker/contract.dart';
import 'package:workout_tracker/sheets.dart';

import '../test/support/reset.dart'
    show DevelopmentSheetResetHarness, workoutTrackerDevelopmentSpreadsheetId;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const workoutTrackerDevelopmentSpreadsheetUrl =
      'https://docs.google.com/spreadsheets/d/'
      '$workoutTrackerDevelopmentSpreadsheetId/edit?gid=0#gid=0';

  final runLiveGoogleTests =
      Platform.environment['WORKOUT_TRACKER_RUN_LIVE_GOOGLE_TESTS'] == '1';

  http.Client? client;
  late DevelopmentSheetResetHarness resetHarness;
  late SheetsReadAdapter readAdapter;
  late WbkSvc svc;

  setUpAll(() async {
    if (!runLiveGoogleTests) {
      return;
    }

    final auth = NativeSignInAuthGateway();
    final headers = await auth.authorizationHeaders(
      GoogleApisWbkClient.writeScopes,
    );
    final authenticatedClient = AuthHeadersClient(headers: headers);
    client = authenticatedClient;
    final api = sheets.SheetsApi(authenticatedClient);
    resetHarness = DevelopmentSheetResetHarness(
      initializer: GoogleApisWbkInit(api),
    );
    readAdapter = SheetsReadAdapter(client: GoogleApisWbkClient(api));
    svc = SheetAccess(ScopedApiAccess(auth: auth));
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
          svc: svc,
          initialText: workoutTrackerDevelopmentSpreadsheetUrl,
        ),
      );

      await _tapVisible(
        tester,
        find.byKey(const ValueKey('validate-spreadsheet')),
      );
      await _waitForFinder(tester, find.text('Bulgarian Split Squat'));

      expect(find.text('Reverse Lunge'), findsOneWidget);

      await _tapVisible(tester, find.text('Bulgarian Split Squat'));
      await _waitForFinder(tester, find.text('Next set S1'));

      await tester.enterText(
        find.byKey(const ValueKey('set-field-Weight')),
        '80',
      );
      await tester.enterText(find.byKey(const ValueKey('set-field-Reps')), '8');
      await tester.enterText(find.byKey(const ValueKey('set-field-RPE')), '8');
      await _tapVisible(tester, find.text('Save set'));
      await _waitForTextFieldValue(
        tester,
        find.byKey(const ValueKey('logged-S1-field-Weight')),
        '80',
      );

      var activeSheet = await _waitForLoggedSetValue(
        readAdapter: readAdapter,
        primarySheetRowNumber: 3,
        selectedSheetRowNumber: 3,
        expectedValue: '80x8@8',
      );
      var primaryContext = activeSheet.buildLoggingContext(
        primaryRow: 3,
        selectedRow: 3,
        blockLabel: 'Week 2',
      );
      expect(primaryContext.selectedHistory.entries.first.rawValue, '80x8@8');

      await tester.enterText(
        find.byKey(const ValueKey('logged-S1-field-Weight')),
        '82.5',
      );
      await _tapVisible(tester, find.byKey(const ValueKey('save-S1')));
      await _waitForTextFieldValue(
        tester,
        find.byKey(const ValueKey('logged-S1-field-Weight')),
        '82.5',
      );

      activeSheet = await _waitForLoggedSetValue(
        readAdapter: readAdapter,
        primarySheetRowNumber: 3,
        selectedSheetRowNumber: 3,
        expectedValue: '82.5x8@8',
      );
      primaryContext = activeSheet.buildLoggingContext(
        primaryRow: 3,
        selectedRow: 3,
        blockLabel: 'Week 2',
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
      primaryContext = activeSheet.buildLoggingContext(
        primaryRow: 3,
        selectedRow: 3,
        blockLabel: 'Week 2',
      );
      expect(primaryContext.selectedHistory.entries.first.rawValue, isEmpty);

      await _tapVisible(tester, find.text('Reverse Lunge'));
      await _waitForFinder(tester, find.text('Next set S1'));

      await tester.enterText(
        find.byKey(const ValueKey('set-field-Weight')),
        '25',
      );
      await tester.enterText(
        find.byKey(const ValueKey('set-field-Reps')),
        '10',
      );
      await tester.enterText(find.byKey(const ValueKey('set-field-RPE')), '8');
      await _tapVisible(tester, find.text('Save set'));
      await _waitForTextFieldValue(
        tester,
        find.byKey(const ValueKey('logged-S1-field-Weight')),
        '25',
      );

      activeSheet = await _waitForLoggedSetValue(
        readAdapter: readAdapter,
        primarySheetRowNumber: 3,
        selectedSheetRowNumber: 4,
        expectedValue: '25x10@8,',
      );
      final backupContext = activeSheet.buildLoggingContext(
        primaryRow: 3,
        selectedRow: 4,
        blockLabel: 'Week 2',
      );
      expect(backupContext.selectedHistory.entries.first.rawValue, '25x10@8,');

      await _tapVisible(tester, find.byTooltip('Back to exercises'));
      await _waitForFinder(tester, find.text('Legs - Week 2'));

      activeSheet = await readAdapter.readParsedActiveSheet(
        workoutTrackerDevelopmentSpreadsheetId,
      );
      final overview = activeSheet.buildWorkoutOverview(
        workout: 'Legs',
        blockLabel: 'Week 2',
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

Future<void> _waitForTextFieldValue(
  WidgetTester tester,
  Finder finder,
  String expectedValue, {
  Duration timeout = const Duration(seconds: 60),
}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 200));
    final widgets = finder.evaluate().toList();
    if (widgets.isNotEmpty) {
      final textField = tester.widget<TextField>(finder);
      if (textField.controller?.text == expectedValue) {
        return;
      }
    }
  }
  final value = finder.evaluate().isEmpty
      ? '<missing>'
      : tester.widget<TextField>(finder).controller?.text;
  fail('Timed out waiting for text field value $expectedValue; got $value.');
}

Future<ParsedActiveSheet> _waitForLoggedSetValue({
  required SheetsReadAdapter readAdapter,
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
    final context = lastRead.buildLoggingContext(
      primaryRow: primarySheetRowNumber,
      selectedRow: selectedSheetRowNumber,
      blockLabel: 'Week 2',
    );
    if (context.selectedHistory.entries.first.rawValue == expectedValue) {
      return lastRead;
    }
    await Future<void>.delayed(const Duration(milliseconds: 250));
  }
  final lastValue = lastRead
      ?.buildLoggingContext(
        primaryRow: primarySheetRowNumber,
        selectedRow: selectedSheetRowNumber,
        blockLabel: 'Week 2',
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
  required SheetsReadAdapter readAdapter,
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
