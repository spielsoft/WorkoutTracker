import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_tracker/contract.dart';
import 'package:workout_tracker/app.dart';

import '../service_fake.dart';
import '../../fixtures/workbook.dart';

import '../../support/widget.dart';

void main() {
  testWidgets('blocks logging with task-first formula repair guidance', (
    tester,
  ) async {
    final service = TestValSvc(
      parseWorkbookFixture(loadFormulaDamageFixture()),
    );

    await tester.pumpWidget(
      WorkoutTrackerApp(svc: service, initialText: 'spreadsheet-id'),
    );

    await tester.tap(find.byKey(const ValueKey('validate-spreadsheet')));
    await tester.pump();
    await tester.pump();

    expect(find.text('Reconnect exercises to logging rows'), findsOneWidget);
    expect(
      find.text(
        'Repair formula cells so each workout row points to the correct '
        'Exercises entry.',
      ),
      findsOneWidget,
    );
    expect(
      find.text('Squat can be reconnected automatically.'),
      findsOneWidget,
    );
    expect(find.text('Spreadsheet details'), findsOneWidget);
    expect(
      find.text('Active sheet row 3; will use Exercises row 2.'),
      findsOneWidget,
    );
    expect(find.text('Exercise: missing formula'), findsOneWidget);
    expect(find.text('Log Format: broken formula'), findsOneWidget);
    expect(find.text('Workout setup'), findsNothing);
    expect(find.byKey(const ValueKey('workout-home')), findsNothing);
    expect(find.text('Save set'), findsNothing);
  });

  testWidgets('repairs unambiguous formula issues from one grouped action', (
    tester,
  ) async {
    final service = FormulaRepairValidationService(
      initialSheet: parseWorkbookFixture(loadFormulaDamageFixture()),
      repairedSheet: repairedFormulaDamageFixtureSheet(),
    );

    await tester.pumpWidget(
      WorkoutTrackerApp(svc: service, initialText: 'spreadsheet-id'),
    );

    await tester.tap(find.byKey(const ValueKey('validate-spreadsheet')));
    await tester.pump();
    await tester.pump();

    expect(find.text('Reconnect exercises to logging rows'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('repair-unambiguous-formulas')),
      findsOneWidget,
    );
    expect(find.text('Workout setup'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('repair-unambiguous-formulas')));
    await tester.pump();
    await tester.pump();

    expect(service.appliedPlans.single.cellUpdates, const [
      CellUpdate.formula(
        sheetRowNumber: 3,
        sheetColumnNumber: 1,
        value: '=Exercises!A2',
      ),
      CellUpdate.formula(
        sheetRowNumber: 3,
        sheetColumnNumber: 7,
        value: '=Exercises!G2',
      ),
    ]);
    expect(find.text('Reconnect exercises to logging rows'), findsNothing);
    expect(find.byKey(const ValueKey('workout-home')), findsOneWidget);
  });

  testWidgets('shows duplicate formula repairs as individual row choices', (
    tester,
  ) async {
    final service = FormulaRepairValidationService(
      initialSheet: parseWorkbookFixture(
        loadAmbiguousFormulaRepairDamageFixture(),
      ),
      repairedSheet: repairedFormulaDamageFixtureSheet(),
    );

    await tester.pumpWidget(
      WorkoutTrackerApp(svc: service, initialText: 'spreadsheet-id'),
    );

    await tester.tap(find.byKey(const ValueKey('validate-spreadsheet')));
    await tester.pump();
    await tester.pump();

    expect(
      find.byKey(const ValueKey('repair-unambiguous-formulas')),
      findsNothing,
    );
    expect(find.byKey(const ValueKey('formula-repair-item-3')), findsOneWidget);
    expect(find.text('Choose the exercise for Squat'), findsOneWidget);
    expect(
      find.text('Select the Exercises entry that this logging row should use.'),
      findsOneWidget,
    );
    expect(find.text('Spreadsheet details'), findsOneWidget);
    expect(find.text('Active sheet row 3.'), findsOneWidget);
    expect(find.text('Repair Squat'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('formula-repair-picker-3')));
    await tester.pumpAndSettle();

    expect(find.text('Row 2: Squat - Back squat'), findsOneWidget);
    expect(find.text('Row 3: Squat - Safety-bar squat'), findsOneWidget);

    await tester.tap(find.text('Row 3: Squat - Safety-bar squat').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('repair-formula-row-3')));
    await tester.pump();
    await tester.pump();

    expect(
      service.appliedPlans.single.cellUpdates,
      containsAll(const [
        CellUpdate.formula(
          sheetRowNumber: 3,
          sheetColumnNumber: 1,
          value: '=Exercises!A3',
        ),
        CellUpdate.formula(
          sheetRowNumber: 3,
          sheetColumnNumber: 7,
          value: '=Exercises!G3',
        ),
      ]),
    );
  });

  testWidgets('shows structural damage as task-first manual repair guidance', (
    tester,
  ) async {
    final cases = <({WorkoutWorkbookFixture fixture, String expectedText})>[
      (
        fixture: loadFixedColumnDamageFixture(),
        expectedText: 'Active sheet row 1: Fixed column 1 must be "Exercise".',
      ),
      (
        fixture: loadMalformedHistoryDamageFixture(),
        expectedText:
            'Active sheet row 2: History set column S1 has no history block label.',
      ),
      (
        fixture: loadInvalidLogFormatDamageFixture(),
        expectedText:
            'Active sheet row 3: Invalid Log Format: Field labels cannot contain braces.',
      ),
      (
        fixture: loadBackupGroupingDamageFixture(),
        expectedText:
            'Active sheet row 3: Backup row has no preceding primary row in the same workout.',
      ),
    ];

    for (final entry in cases) {
      final opener = RecordingSheetOpener();
      final service = RevalidatingValService(
        reports: [
          parseWorkbookFixture(entry.fixture),
          minimalValidParsedSheet(),
        ],
      );

      await tester.pumpWidget(
        WorkoutTrackerApp(
          key: ValueKey(entry.expectedText),
          svc: service,
          sheetOpener: opener,
          initialText: 'spreadsheet-id',
        ),
      );

      await tester.tap(find.byKey(const ValueKey('validate-spreadsheet')));
      await tester.pump();
      await tester.pump();

      expect(find.text('Fix the active sheet structure'), findsOneWidget);
      expect(
        find.text(
          'Open Google Sheets to repair rows or headers before logging.',
        ),
        findsOneWidget,
      );
      expect(find.text('Spreadsheet details'), findsOneWidget);
      expect(find.text(entry.expectedText), findsOneWidget);
      expect(
        find.byKey(const ValueKey('repair-unambiguous-formulas')),
        findsNothing,
      );
      expect(find.byKey(const ValueKey('repair-formula-row-3')), findsNothing);
      expect(
        find.byKey(const ValueKey('open-spreadsheet-manual-repair')),
        findsOneWidget,
      );
      expect(find.text('Workout setup'), findsNothing);

      await tester.tap(
        find.byKey(const ValueKey('open-spreadsheet-manual-repair')),
      );
      await tester.pump();

      expect(opener.openedUrls, [
        'https://docs.google.com/spreadsheets/d/spreadsheet-id/edit?gid=0#gid=0',
      ]);

      await tester.tap(find.byKey(const ValueKey('validate-spreadsheet')));
      await tester.pump();
      await tester.pump();

      expect(find.text('Fix the active sheet structure'), findsNothing);
      expect(find.byKey(const ValueKey('workout-home')), findsOneWidget);
    }
  });

  testWidgets('restores and persists the spreadsheet field', (tester) async {
    final store = MemoryAppStStore('saved-spreadsheet-id');
    final service = TestValSvc.fromRows([
      [...activeSheetFixedColumns, 'Week 1'],
      [...List.filled(activeSheetFixedColumns.length, ''), 'S1'],
      ['Squat', '3', '3 min', '', 'x5@8', '', '', 'Legs', '', 'x', ''],
    ]);

    await tester.pumpWidget(
      WorkoutTrackerApp(
        svc: service,
        appStStore: store,
        initialText: 'initial-spreadsheet-id',
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Select'));
    await tester.pump();
    await tester.pump();

    expect(service.spreadsheetIds, ['saved-spreadsheet-id']);

    await tester.tap(find.byTooltip('Back to sheet selection'));
    await tester.pumpAndSettle();

    final input = find.byKey(const ValueKey('spreadsheet-selection-input'));

    await tester.enterText(input, 'edited-spreadsheet-id');
    await tester.pump();

    expect(store.accessStWrites.last.sheetText, 'edited-spreadsheet-id');
    expect(store.accessStWrites.last.selectedSheet, isNull);
    expect(store.accessStWrites.last.workoutSelection, isNull);
  });

  testWidgets('restores a selected Google Drive sheet label', (tester) async {
    final store = MemoryAppStStore(
      'saved-spreadsheet-id',
      selectedSheet: const SelectedSheet(
        spreadsheetId: 'selected-spreadsheet-id',
        name: '2026 Workouts',
        drivePath: 'My Drive / Workouts / 2026 Workouts',
        accountEmail: 'saved@example.com',
      ),
    );
    final accountSession = FakeGoogleAccountSession(
      const GoogleAccountProfile(email: 'saved@example.com'),
    );
    final service = TestValSvc.fromRows([
      [...activeSheetFixedColumns, 'Week 1'],
      [...List.filled(activeSheetFixedColumns.length, ''), 'S1'],
      ['Squat', '3', '3 min', '', 'x5@8', '', '', 'Legs', '', 'x', ''],
    ]);

    await tester.pumpWidget(
      WorkoutTrackerApp(
        svc: service,
        accountSession: accountSession,
        appStStore: store,
        picker: const DisabledPicker(
          reason: 'Google Drive sheet selection is unavailable.',
        ),
      ),
    );
    await tester.pump();

    expect(find.text('My Drive / Workouts / 2026 Workouts'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('spreadsheet-selection-input')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('spreadsheet-url-fallback')),
      findsNothing,
    );
  });

  testWidgets(
    'first-run setup has one primary sheet choice and secondary alternatives',
    (tester) async {
      final picker = CountingSheetPicker();
      final service = TestValSvc.fromRows([
        [...activeSheetFixedColumns, 'Week 1'],
        [...List.filled(activeSheetFixedColumns.length, ''), 'S1'],
        ['Squat', '3', '3 min', '', 'x5@8', '', '', 'Legs', '', 'x', ''],
      ]);

      await tester.pumpWidget(WorkoutTrackerApp(svc: service, picker: picker));
      await tester.pump();

      expect(find.text('Choose workout sheet'), findsOneWidget);
      expect(find.text('Create sheet'), findsOneWidget);
      expect(find.text('Paste link'), findsNothing);
      expect(
        find.byKey(const ValueKey('spreadsheet-selection-input')),
        findsNothing,
      );

      await tester.tap(find.text('Choose workout sheet'));
      await tester.pump();
      expect(picker.chooseCount, 1);

      await tester.tap(find.text('Create sheet'));
      await tester.pump();
      expect(find.text('Create sheet'), findsWidgets);
      expect(picker.createCount, 0);
    },
  );

  testWidgets(
    'exposes pasted sheet validation when picker choosing is unavailable',
    (tester) async {
      const picker = DisabledPicker(
        reason: 'Google Drive sheet selection is unavailable.',
      );
      final service = TestValSvc.fromRows([
        [...activeSheetFixedColumns, 'Week 1'],
        [...List.filled(activeSheetFixedColumns.length, ''), 'S1'],
        ['Squat', '3', '3 min', '', 'x5@8', '', '', 'Legs', '', 'x', ''],
      ]);

      await tester.pumpWidget(WorkoutTrackerApp(svc: service, picker: picker));
      await tester.pump();

      expect(find.text('Choose workout sheet'), findsOneWidget);
      expect(find.text('Create sheet'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const ValueKey('choose-google-spreadsheet')),
            )
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<OutlinedButton>(
              find.byKey(const ValueKey('create-google-spreadsheet')),
            )
            .onPressed,
        isNull,
      );
      expect(
        find.byKey(const ValueKey('spreadsheet-url-fallback')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('spreadsheet-selection-input')),
        findsOneWidget,
      );
      expect(
        find.text('Google Drive sheet selection is unavailable.'),
        findsOneWidget,
      );

      await tester.enterText(
        find.byKey(const ValueKey('spreadsheet-selection-input')),
        'https://docs.google.com/spreadsheets/d/pasted-spreadsheet-id/edit',
      );
      await tester.tap(find.byKey(const ValueKey('validate-spreadsheet')));
      await tester.pump();
      await tester.pump();

      expect(service.spreadsheetIds, ['pasted-spreadsheet-id']);
      expect(find.byKey(const ValueKey('workout-home')), findsOneWidget);
    },
  );

  testWidgets('does not launch duplicate picker actions while choosing', (
    tester,
  ) async {
    final picker = CompletingSheetPicker();
    final service = TestValSvc.fromRows([
      [...activeSheetFixedColumns, 'Week 1'],
      [...List.filled(activeSheetFixedColumns.length, ''), 'S1'],
      ['Squat', '3', '3 min', '', 'x5@8', '', '', 'Legs', '', 'x', ''],
    ]);

    await tester.pumpWidget(WorkoutTrackerApp(svc: service, picker: picker));
    await tester.pump();

    await tester.tap(find.text('Choose workout sheet'));
    await tester.tap(find.text('Choose workout sheet'));

    expect(picker.chooseCount, 1);
  });

  testWidgets('restores the Google account session on startup', (tester) async {
    final accountSession = FakeGoogleAccountSession(
      null,
      restoredAccount: const GoogleAccountProfile(
        email: 'saved@example.com',
        displayName: 'Saved Account',
      ),
    );
    final service = TestValSvc.fromRows([
      [...activeSheetFixedColumns, 'Week 1'],
      [...List.filled(activeSheetFixedColumns.length, ''), 'S1'],
      ['Squat', '3', '3 min', '', 'x5@8', '', '', 'Legs', '', 'x', ''],
    ]);

    await tester.pumpWidget(
      WorkoutTrackerApp(
        svc: service,
        accountSession: accountSession,
        initialText: 'spreadsheet-id',
      ),
    );
    await tester.pump();

    expect(accountSession.restoreCount, 1);
    expect(
      find.byTooltip('Google Sheets account: saved@example.com'),
      findsOneWidget,
    );
  });

  testWidgets('does not show a logged-out state while restoring an account', (
    tester,
  ) async {
    final gate = Completer<void>();
    final accountSession = FakeGoogleAccountSession(
      null,
      restoredAccount: const GoogleAccountProfile(
        email: 'saved@example.com',
        displayName: 'Saved Account',
      ),
      restoreWait: gate.future,
    );
    final service = TestValSvc.fromRows([
      [...activeSheetFixedColumns, 'Week 1'],
      [...List.filled(activeSheetFixedColumns.length, ''), 'S1'],
      ['Squat', '3', '3 min', '', 'x5@8', '', '', 'Legs', '', 'x', ''],
    ]);

    await tester.pumpWidget(
      WorkoutTrackerApp(
        svc: service,
        accountSession: accountSession,
        picker: FakeSheetPicker(),
      ),
    );
    await tester.pump();

    expect(find.text('Connecting to Google Sheets…'), findsOneWidget);
    expect(find.text('Not logged in'), findsNothing);
    expect(find.byIcon(Icons.account_circle_outlined), findsOneWidget);
    expect(
      find.byKey(const ValueKey('choose-google-spreadsheet')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('create-google-spreadsheet')),
      findsNothing,
    );

    gate.complete();
    await tester.pumpAndSettle();

    expect(find.text('Connecting to Google Sheets…'), findsNothing);
    expect(find.text('No workout sheet selected'), findsOneWidget);
    expect(find.text('saved@example.com'), findsNothing);
    expect(
      find.byTooltip('Google Sheets account: saved@example.com'),
      findsOneWidget,
    );
  });

  testWidgets('login enables sheet choice with all required scopes', (
    tester,
  ) async {
    final accountSession = FakeGoogleAccountSession(null);
    final service = TestValSvc.fromRows([
      [...activeSheetFixedColumns, 'Week 1'],
      [...List.filled(activeSheetFixedColumns.length, ''), 'S1'],
      ['Squat', '3', '3 min', '', 'x5@8', '', '', 'Legs', '', 'x', ''],
    ]);

    await tester.pumpWidget(
      WorkoutTrackerApp(
        svc: service,
        accountSession: accountSession,
        picker: FakeSheetPicker(),
      ),
    );
    await tester.pump();

    expect(
      find.byKey(const ValueKey('choose-google-spreadsheet')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('create-google-spreadsheet')),
      findsNothing,
    );

    await tester.tap(find.byTooltip('Connect Google Sheets'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Log in'));
    await tester.pumpAndSettle();

    expect(accountSession.signInCount, 1);
    expect(accountSession.requestedScopes.single, [
      driveMetaScope,
      'https://www.googleapis.com/auth/spreadsheets',
    ]);
    expect(
      find.byTooltip('Google Sheets account: right@example.com'),
      findsOneWidget,
    );
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Choose workout sheet'),
          )
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('shows account summary and logout in the Google Sheets menu', (
    tester,
  ) async {
    final service = TestValSvc.fromRows([
      [...activeSheetFixedColumns, 'Week 1'],
      [...List.filled(activeSheetFixedColumns.length, ''), 'S1'],
      ['Squat', '3', '3 min', '', 'x5@8', '', '', 'Legs', '', 'x', ''],
    ]);
    final accountSession = FakeGoogleAccountSession(
      const GoogleAccountProfile(
        email: 'wrong@example.com',
        displayName: 'Wrong Account',
      ),
    );

    await tester.pumpWidget(
      WorkoutTrackerApp(
        svc: service,
        accountSession: accountSession,
        initialText: 'spreadsheet-id',
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byTooltip('Google Sheets account: wrong@example.com'),
    );
    await tester.pumpAndSettle();

    expect(find.text('Wrong Account'), findsOneWidget);
    expect(find.text('wrong@example.com'), findsOneWidget);
    expect(find.text('Switch Google Sheets account'), findsNothing);
    expect(find.text('Log out'), findsOneWidget);
    expect(accountSession.requestedScopes, isEmpty);
  });

  testWidgets('logging out disconnects the selected workout sheet', (
    tester,
  ) async {
    final store =
        MemoryAppStStore(
            null,
            selectedSheet: const SelectedSheet(
              spreadsheetId: 'selected-spreadsheet-id',
              name: 'development',
              accountEmail: 'saved@example.com',
            ),
          )
          ..workoutSelection = const WorkoutSelectionSt(
            spreadsheetId: 'selected-spreadsheet-id',
            workout: 'Legs',
            historyBlock: 'Week 1',
          );
    final service = TestValSvc.fromRows([
      [...activeSheetFixedColumns, 'Week 1'],
      [...List.filled(activeSheetFixedColumns.length, ''), 'S1'],
      ['Squat', '3', '3 min', '', 'x5@8', '', '', 'Legs', '', 'x', ''],
    ]);
    final accountSession = FakeGoogleAccountSession(
      const GoogleAccountProfile(
        email: 'saved@example.com',
        displayName: 'Saved Account',
      ),
    );

    await tester.pumpWidget(
      WorkoutTrackerApp(
        svc: service,
        accountSession: accountSession,
        appStStore: store,
        picker: FakeSheetPicker(),
      ),
    );
    await tester.pump();
    await tester.pump();

    await tester.tap(find.byTooltip('Back to sheet selection'));
    await tester.pumpAndSettle();
    expect(find.text('development'), findsOneWidget);
    expect(find.text('Return to workout'), findsOneWidget);

    await tester.tap(
      find.byTooltip('Google Sheets account: saved@example.com'),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Log out'));
    await tester.pumpAndSettle();

    expect(accountSession.signOutCount, 1);
    expect(store.clearCount, 1);
    expect(store.selectedSheet, isNull);
    expect(store.sheetText, isNull);
    expect(store.workoutSelection, isNull);
    expect(find.text('development'), findsNothing);
    expect(find.text('Return to workout'), findsNothing);
    expect(find.text('Not logged in'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('choose-google-spreadsheet')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('create-google-spreadsheet')),
      findsNothing,
    );
  });

  testWidgets('shows the Google Sheets account menu in picker mode', (
    tester,
  ) async {
    final service = TestValSvc.fromRows([
      [...activeSheetFixedColumns, 'Week 1'],
      [...List.filled(activeSheetFixedColumns.length, ''), 'S1'],
      ['Squat', '3', '3 min', '', 'x5@8', '', '', 'Legs', '', 'x', ''],
    ]);
    final accountSession = FakeGoogleAccountSession(
      const GoogleAccountProfile(
        email: 'saved@example.com',
        displayName: 'Saved Account',
      ),
    );

    await tester.pumpWidget(
      WorkoutTrackerApp(
        svc: service,
        accountSession: accountSession,
        picker: FakeSheetPicker(),
      ),
    );
    await tester.pump();

    expect(
      find.byTooltip('Google Sheets account: saved@example.com'),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('spreadsheet-selection-input')),
      findsNothing,
    );
  });
}
