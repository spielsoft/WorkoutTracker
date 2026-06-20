import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_tracker/sheet_contract.dart';
import 'package:workout_tracker/workout_tracker_app.dart';

import 'app/test_spreadsheet_validation_service.dart';
import 'fixtures/workout_sheet_fixtures.dart';

void main() {
  testWidgets('renders the main logging flow and sends a save to the service', (
    tester,
  ) async {
    final service = TestSpreadsheetValidationService.fromRows([
      [...activeSheetFixedColumns, 'Week 2', 'Week 1'],
      [...List.filled(activeSheetFixedColumns.length, ''), 'S1', 'S1'],
      [
        'Squat',
        '3',
        '5',
        '8',
        '3 min',
        'Controlled',
        'Stay braced.',
        '',
        'Legs',
        '',
        '',
        '',
      ],
      ['Bench Press', '4', '6', '8', '3 min', '', '', '', 'Upper', '', '', ''],
    ]);

    await tester.pumpWidget(
      WorkoutTrackerApp(
        validationService: service,
        initialSpreadsheetText: 'spreadsheet-id',
      ),
    );

    expect(find.text('WorkoutTracker'), findsNothing);
    expect(
      find.byKey(const ValueKey('spreadsheet-selection-input')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('validate-spreadsheet')));
    await tester.pump();
    await tester.pump();

    expect(service.spreadsheetIds, ['spreadsheet-id']);
    expect(find.byKey(const ValueKey('select-workout-setup')), findsOneWidget);
    expect(find.byTooltip('Back to sheet selection'), findsOneWidget);
    expect(find.text('Workout'), findsOneWidget);
    expect(find.text('History block'), findsOneWidget);
    expect(find.text('Legs (0/1 done)'), findsOneWidget);
    expect(find.text('Legs exercises'), findsOneWidget);
    expect(find.text('Squat'), findsOneWidget);

    await tester.tap(find.text('Week 2'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Week 1').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Legs (0/1 done)').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Upper (0/1 done)').last);
    await tester.pumpAndSettle();

    expect(find.text('Upper exercises'), findsOneWidget);
    expect(find.text('Bench Press'), findsOneWidget);
    expect(find.byKey(const ValueKey('select-workout-setup')), findsOneWidget);

    await tester.tap(find.text('Bench Press'));
    await tester.pumpAndSettle();

    expect(find.text('Bench Press'), findsWidgets);
    expect(find.text('Bench Press logging'), findsNothing);
    expect(find.byTooltip('Back to exercises'), findsOneWidget);
    expect(find.text('Workout setup'), findsNothing);
    expect(find.text('Upper exercises'), findsNothing);
    expect(find.byKey(const ValueKey('set-field-Weight')), findsOneWidget);
    expect(find.byKey(const ValueKey('set-field-Reps')), findsOneWidget);
    expect(find.byKey(const ValueKey('set-field-RPE')), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('set-field-Weight')),
      '155',
    );
    await tester.enterText(find.byKey(const ValueKey('set-field-Reps')), '6');
    await tester.enterText(find.byKey(const ValueKey('set-field-RPE')), '8');
    await tester.drag(find.byType(ListView), const Offset(0, -300));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save set'));
    await tester.pump();
    await tester.pump();

    expect(service.appliedPlans, hasLength(1));
    expect(service.appliedPlans.single.cellUpdates.single.value, '155x6@8');
    expect(
      tester
          .widget<TextField>(
            find.byKey(const ValueKey('logged-S1-field-Weight')),
          )
          .controller
          ?.text,
      '155',
    );
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('logged-S1-field-Reps')))
          .controller
          ?.text,
      '6',
    );
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('logged-S1-field-RPE')))
          .controller
          ?.text,
      '8',
    );
    expect(find.text('Next set S2'), findsOneWidget);
  });

  testWidgets('does not launch duplicate set saves while a write is pending', (
    tester,
  ) async {
    final service = _CompletingWriteValidationService(
      _minimalValidParsedSheet(),
    );

    await tester.pumpWidget(
      WorkoutTrackerApp(
        validationService: service,
        initialSpreadsheetText: 'spreadsheet-id',
      ),
    );

    await tester.tap(find.byKey(const ValueKey('validate-spreadsheet')));
    await tester.pump();
    await tester.pump();
    await tester.tap(find.text('Squat'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('set-field-Weight')),
      '155',
    );
    await tester.enterText(find.byKey(const ValueKey('set-field-Reps')), '6');
    await tester.enterText(find.byKey(const ValueKey('set-field-RPE')), '8');

    await tester.tap(find.text('Save set'));
    await tester.tap(find.text('Save set'));

    expect(service.appliedPlans, hasLength(1));
  });

  testWidgets('renders compact spreadsheet selection controls', (tester) async {
    final service = TestSpreadsheetValidationService.fromRows([
      [...activeSheetFixedColumns, 'Week 1'],
      [...List.filled(activeSheetFixedColumns.length, ''), 'S1'],
      ['Squat', '3', '5', '8', '3 min', '', '', '', 'Legs', '', ''],
    ]);

    await tester.pumpWidget(
      WorkoutTrackerApp(
        validationService: service,
        initialSpreadsheetText: 'spreadsheet-id',
      ),
    );

    expect(find.text('Spreadsheet validation'), findsNothing);
    expect(find.byKey(const ValueKey('validate-spreadsheet')), findsOneWidget);
    expect(find.byKey(const ValueKey('use-development-sheet')), findsNothing);
    expect(find.text('Select'), findsOneWidget);
    expect(find.text('Development'), findsNothing);
  });

  testWidgets('blocks logging with task-first formula repair guidance', (
    tester,
  ) async {
    final service = TestSpreadsheetValidationService(
      _parseWorkbookFixture(loadFormulaDamageFixture()),
    );

    await tester.pumpWidget(
      WorkoutTrackerApp(
        validationService: service,
        initialSpreadsheetText: 'spreadsheet-id',
      ),
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
    expect(find.byKey(const ValueKey('select-workout-setup')), findsNothing);
    expect(find.text('Save set'), findsNothing);
  });

  testWidgets('names warning and error states on validation panels', (
    tester,
  ) async {
    final cases = [
      (
        key: 'warning-state',
        fixture: loadFormulaDamageFixture(),
        stateLabel: 'Warning',
        panelTitle: 'Reconnect exercises to logging rows',
      ),
      (
        key: 'error-state',
        fixture: loadFixedColumnDamageFixture(),
        stateLabel: 'Error',
        panelTitle: 'Fix the active sheet structure',
      ),
    ];

    for (final entry in cases) {
      final service = TestSpreadsheetValidationService(
        _parseWorkbookFixture(entry.fixture),
      );

      await tester.pumpWidget(
        WorkoutTrackerApp(
          key: ValueKey(entry.key),
          validationService: service,
          initialSpreadsheetText: 'spreadsheet-id',
        ),
      );

      await tester.tap(find.byKey(const ValueKey('validate-spreadsheet')));
      await tester.pump();
      await tester.pump();

      expect(find.text(entry.panelTitle), findsOneWidget);
      expect(find.text(entry.stateLabel), findsOneWidget);
    }
  });

  testWidgets('repairs unambiguous formula issues from one grouped action', (
    tester,
  ) async {
    final service = _FormulaRepairValidationService(
      initialSheet: _parseWorkbookFixture(loadFormulaDamageFixture()),
      repairedSheet: _repairedFormulaDamageFixtureSheet(),
    );

    await tester.pumpWidget(
      WorkoutTrackerApp(
        validationService: service,
        initialSpreadsheetText: 'spreadsheet-id',
      ),
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
        sheetColumnNumber: 8,
        value: '=Exercises!I2',
      ),
    ]);
    expect(find.text('Reconnect exercises to logging rows'), findsNothing);
    expect(find.byKey(const ValueKey('select-workout-setup')), findsOneWidget);
  });

  testWidgets('shows duplicate formula repairs as individual row choices', (
    tester,
  ) async {
    final service = _FormulaRepairValidationService(
      initialSheet: _parseWorkbookFixture(
        loadAmbiguousFormulaRepairDamageFixture(),
      ),
      repairedSheet: _repairedFormulaDamageFixtureSheet(),
    );

    await tester.pumpWidget(
      WorkoutTrackerApp(
        validationService: service,
        initialSpreadsheetText: 'spreadsheet-id',
      ),
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

    expect(service.appliedPlans.single.cellUpdates, const [
      CellUpdate.formula(
        sheetRowNumber: 3,
        sheetColumnNumber: 1,
        value: '=Exercises!A3',
      ),
    ]);
  });

  testWidgets(
    'repairs a no-match formula row after choosing an Exercises row',
    (tester) async {
      final service = _FormulaRepairValidationService(
        initialSheet: _parseWorkbookFixture(
          loadNoExactMatchFormulaRepairDamageFixture(),
        ),
        repairedSheet: _repairedFormulaDamageFixtureSheet(),
      );

      await tester.pumpWidget(
        WorkoutTrackerApp(
          validationService: service,
          initialSpreadsheetText: 'spreadsheet-id',
        ),
      );

      await tester.tap(find.byKey(const ValueKey('validate-spreadsheet')));
      await tester.pump();
      await tester.pump();

      expect(
        find.byKey(const ValueKey('repair-unambiguous-formulas')),
        findsNothing,
      );
      expect(find.text('Choose the exercise for Front Squat'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('formula-repair-picker-3')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Row 2: Squat - Back squat').last);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('repair-formula-row-3')));
      await tester.pump();
      await tester.pump();

      expect(service.appliedPlans.single.cellUpdates, const [
        CellUpdate.formula(
          sheetRowNumber: 3,
          sheetColumnNumber: 1,
          value: '=Exercises!A2',
        ),
      ]);
      expect(find.text('Reconnect exercises to logging rows'), findsNothing);
      expect(
        find.byKey(const ValueKey('select-workout-setup')),
        findsOneWidget,
      );
    },
  );

  testWidgets('keeps logging blocked when formula repair leaves other issues', (
    tester,
  ) async {
    final service = _FormulaRepairValidationService(
      initialSheet: _parseWorkbookFixture(loadFormulaDamageFixture()),
      repairedSheet: _repairedFormulaDamageFixtureSheetWithBackupViolation(),
    );

    await tester.pumpWidget(
      WorkoutTrackerApp(
        validationService: service,
        initialSpreadsheetText: 'spreadsheet-id',
      ),
    );

    await tester.tap(find.byKey(const ValueKey('validate-spreadsheet')));
    await tester.pump();
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('repair-unambiguous-formulas')));
    await tester.pump();
    await tester.pump();

    expect(find.text('Reconnect exercises to logging rows'), findsNothing);
    expect(find.text('Fix the active sheet structure'), findsOneWidget);
    expect(find.text('Workout setup'), findsNothing);
    expect(find.byKey(const ValueKey('select-workout-setup')), findsNothing);
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
            'Active sheet row 3: Invalid Log Format: Field labels cannot contain brackets.',
      ),
      (
        fixture: loadBackupGroupingDamageFixture(),
        expectedText:
            'Active sheet row 3: Backup row has no preceding primary row in the same workout.',
      ),
    ];

    for (final entry in cases) {
      final opener = _RecordingSpreadsheetOpener();
      final service = _RevalidatingSpreadsheetValidationService(
        reports: [
          _parseWorkbookFixture(entry.fixture),
          _minimalValidParsedSheet(),
        ],
      );

      await tester.pumpWidget(
        WorkoutTrackerApp(
          key: ValueKey(entry.expectedText),
          validationService: service,
          spreadsheetOpener: opener,
          initialSpreadsheetText: 'spreadsheet-id',
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
      expect(
        find.byKey(const ValueKey('select-workout-setup')),
        findsOneWidget,
      );
    }
  });

  testWidgets('lists every current schema issue on the validation screen', (
    tester,
  ) async {
    final service = TestSpreadsheetValidationService(
      _parseWorkbookFixture(loadMalformedHistoryDamageFixture()),
    );

    await tester.pumpWidget(
      WorkoutTrackerApp(
        validationService: service,
        initialSpreadsheetText: 'spreadsheet-id',
      ),
    );

    await tester.tap(find.byKey(const ValueKey('validate-spreadsheet')));
    await tester.pump();
    await tester.pump();

    expect(find.text('Fix the active sheet structure'), findsOneWidget);
    expect(
      find.text(
        'Active sheet row 2: History set column S1 has no history block label.',
      ),
      findsOneWidget,
    );
    expect(
      find.text('Active sheet row 1: Duplicate history block label: Week 1.'),
      findsOneWidget,
    );
    expect(
      find.text(
        'Active sheet row 2: History block Week 1 skips set label S2 before S3.',
      ),
      findsOneWidget,
    );
    expect(
      find.text(
        'Active sheet row 1: History block Empty Block has no set columns.',
      ),
      findsOneWidget,
    );
    expect(find.text('Workout setup'), findsNothing);
    expect(find.byKey(const ValueKey('select-workout-setup')), findsNothing);
  });

  testWidgets(
    'returns to validation and drops typed logging input after damage',
    (tester) async {
      final validSheet = parseActiveSheet(
        ActiveSheetInput(
          rows: [
            [...activeSheetFixedColumns, 'Week 1'],
            [...List.filled(activeSheetFixedColumns.length, ''), 'S1'],
            ['Squat', '3', '5', '8', '3 min', '', '', '', 'Legs', '', ''],
          ],
        ),
      );
      final damagedSheet = _parseWorkbookFixture(
        loadBackupGroupingDamageFixture(),
      );
      final service = _DamageAfterSaveValidationService(
        validSheet: validSheet,
        damagedSheet: damagedSheet,
      );

      await tester.pumpWidget(
        WorkoutTrackerApp(
          validationService: service,
          initialSpreadsheetText: 'spreadsheet-id',
        ),
      );

      await tester.tap(find.byKey(const ValueKey('validate-spreadsheet')));
      await tester.pump();
      await tester.pump();
      await tester.tap(find.text('Squat'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('set-field-Weight')),
        '155',
      );
      await tester.enterText(find.byKey(const ValueKey('set-field-Reps')), '6');
      await tester.enterText(find.byKey(const ValueKey('set-field-RPE')), '8');

      await tester.tap(find.text('Save set'));
      await tester.pump();
      await tester.pump();

      expect(service.appliedPlans, hasLength(1));
      expect(find.text('Fix the active sheet structure'), findsOneWidget);
      expect(find.text('Workout setup'), findsNothing);
      expect(find.text('Save set'), findsNothing);
      expect(find.byKey(const ValueKey('set-field-Weight')), findsNothing);

      await tester.tap(find.byKey(const ValueKey('validate-spreadsheet')));
      await tester.pump();
      await tester.pump();
      await tester.tap(find.text('Squat'));
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('set-field-Weight')))
            .controller
            ?.text,
        isEmpty,
      );
    },
  );

  testWidgets('restores and persists the spreadsheet field', (tester) async {
    final store = _MemoryAppStateStore('saved-spreadsheet-id');
    final service = TestSpreadsheetValidationService.fromRows([
      [...activeSheetFixedColumns, 'Week 1'],
      [...List.filled(activeSheetFixedColumns.length, ''), 'S1'],
      ['Squat', '3', '5', '8', '3 min', '', '', '', 'Legs', '', ''],
    ]);

    await tester.pumpWidget(
      WorkoutTrackerApp(
        validationService: service,
        appStateStore: store,
        initialSpreadsheetText: 'initial-spreadsheet-id',
      ),
    );
    await tester.pump();

    final input = find.byKey(const ValueKey('spreadsheet-selection-input'));
    expect(
      tester.widget<TextField>(input).controller?.text,
      'saved-spreadsheet-id',
    );

    await tester.enterText(input, 'edited-spreadsheet-id');
    await tester.pump();

    expect(store.writes.last, 'edited-spreadsheet-id');
  });

  testWidgets('restores a selected Google Drive sheet label', (tester) async {
    final store = _MemoryAppStateStore(
      'legacy-spreadsheet-id',
      selectedSpreadsheet: const SelectedSpreadsheet(
        spreadsheetId: 'selected-spreadsheet-id',
        name: '2026 Workouts',
        drivePath: 'My Drive / Workouts / 2026 Workouts',
        accountEmail: 'saved@example.com',
      ),
    );
    final service = TestSpreadsheetValidationService.fromRows([
      [...activeSheetFixedColumns, 'Week 1'],
      [...List.filled(activeSheetFixedColumns.length, ''), 'S1'],
      ['Squat', '3', '5', '8', '3 min', '', '', '', 'Legs', '', ''],
    ]);

    await tester.pumpWidget(
      WorkoutTrackerApp(
        validationService: service,
        appStateStore: store,
        spreadsheetPicker: _FakeSpreadsheetPicker(),
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
      final picker = _CountingSpreadsheetPicker();
      final service = TestSpreadsheetValidationService.fromRows([
        [...activeSheetFixedColumns, 'Week 1'],
        [...List.filled(activeSheetFixedColumns.length, ''), 'S1'],
        ['Squat', '3', '5', '8', '3 min', '', '', '', 'Legs', '', ''],
      ]);

      await tester.pumpWidget(
        WorkoutTrackerApp(
          validationService: service,
          spreadsheetPicker: picker,
        ),
      );
      await tester.pump();

      expect(find.text('Choose workout sheet'), findsOneWidget);
      expect(find.text('Create sheet'), findsOneWidget);
      expect(find.text('Paste link'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(FilledButton),
          matching: find.text('Choose workout sheet'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(FilledButton),
          matching: find.text('Create sheet'),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: find.byType(FilledButton),
          matching: find.text('Paste link'),
        ),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('spreadsheet-selection-input')),
        findsNothing,
      );

      await tester.tap(find.text('Choose workout sheet'));
      await tester.pump();
      expect(picker.chooseCount, 1);

      await tester.tap(find.text('Create sheet'));
      await tester.pump();
      expect(picker.createCount, 1);

      await tester.tap(find.text('Paste link'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('spreadsheet-selection-input')),
        findsOneWidget,
      );
    },
  );

  testWidgets('returning sheet selection keeps loaded state compact', (
    tester,
  ) async {
    final store = _MemoryAppStateStore(
      null,
      selectedSpreadsheet: const SelectedSpreadsheet(
        spreadsheetId: 'selected-spreadsheet-id',
        name: '2026 Workouts',
        drivePath: 'My Drive / Workouts / 2026 Workouts',
        accountEmail: 'saved@example.com',
      ),
    );
    final service = TestSpreadsheetValidationService.fromRows([
      [...activeSheetFixedColumns, 'Week 1'],
      [...List.filled(activeSheetFixedColumns.length, ''), 'S1'],
      ['Squat', '3', '5', '8', '3 min', '', '', '', 'Legs', '', ''],
    ]);

    await tester.pumpWidget(
      WorkoutTrackerApp(
        validationService: service,
        appStateStore: store,
        spreadsheetPicker: _FakeSpreadsheetPicker(),
      ),
    );
    await tester.pump();
    await tester.pump();

    await tester.tap(find.byTooltip('Back to sheet selection'));
    await tester.pumpAndSettle();

    expect(find.text('My Drive / Workouts / 2026 Workouts'), findsOneWidget);
    expect(find.text('saved@example.com'), findsOneWidget);
    expect(find.text('Return to workout'), findsOneWidget);
    expect(find.text('Change sheet'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(FilledButton),
        matching: find.text('Return to workout'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(FilledButton),
        matching: find.text('Change sheet'),
      ),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('spreadsheet-selection-input')),
      findsNothing,
    );
  });

  testWidgets('shows text fallback when picker choosing is unavailable', (
    tester,
  ) async {
    const picker = DisabledSpreadsheetPicker(reason: 'Selection disabled.');
    final service = TestSpreadsheetValidationService.fromRows([
      [...activeSheetFixedColumns, 'Week 1'],
      [...List.filled(activeSheetFixedColumns.length, ''), 'S1'],
      ['Squat', '3', '5', '8', '3 min', '', '', '', 'Legs', '', ''],
    ]);

    await tester.pumpWidget(
      WorkoutTrackerApp(validationService: service, spreadsheetPicker: picker),
    );
    await tester.pump();

    expect(
      find.byKey(const ValueKey('spreadsheet-url-fallback')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('spreadsheet-selection-input')),
      findsOneWidget,
    );
    expect(find.text('Selection disabled.'), findsOneWidget);
  });

  testWidgets('does not launch duplicate picker actions while choosing', (
    tester,
  ) async {
    final picker = _CompletingSpreadsheetPicker();
    final service = TestSpreadsheetValidationService.fromRows([
      [...activeSheetFixedColumns, 'Week 1'],
      [...List.filled(activeSheetFixedColumns.length, ''), 'S1'],
      ['Squat', '3', '5', '8', '3 min', '', '', '', 'Legs', '', ''],
    ]);

    await tester.pumpWidget(
      WorkoutTrackerApp(validationService: service, spreadsheetPicker: picker),
    );
    await tester.pump();

    await tester.tap(find.text('Choose workout sheet'));
    await tester.tap(find.text('Choose workout sheet'));

    expect(picker.chooseCount, 1);
  });

  testWidgets('restores the Google account session on startup', (tester) async {
    final accountSession = _FakeGoogleAccountSession(
      null,
      restoredAccount: const GoogleAccountProfile(
        email: 'saved@example.com',
        displayName: 'Saved Account',
      ),
    );
    final service = TestSpreadsheetValidationService.fromRows([
      [...activeSheetFixedColumns, 'Week 1'],
      [...List.filled(activeSheetFixedColumns.length, ''), 'S1'],
      ['Squat', '3', '5', '8', '3 min', '', '', '', 'Legs', '', ''],
    ]);

    await tester.pumpWidget(
      WorkoutTrackerApp(
        validationService: service,
        accountSession: accountSession,
        initialSpreadsheetText: 'spreadsheet-id',
      ),
    );
    await tester.pump();

    expect(accountSession.restoreCount, 1);
    expect(find.byTooltip('Google account: saved@example.com'), findsOneWidget);
  });

  testWidgets(
    'labels workouts with selected-block progress and counts backups with parent',
    (tester) async {
      final service = TestSpreadsheetValidationService.fromRows([
        [...activeSheetFixedColumns, 'Week 1'],
        [...List.filled(activeSheetFixedColumns.length, ''), 'S1'],
        [
          'Pull Up',
          '3',
          '8',
          '8',
          '2 min',
          '',
          'Full hang.',
          '{Reps}',
          'Upper',
          '',
          '',
        ],
        [
          'Front Plank',
          '3',
          '45s',
          '8',
          '60s',
          '',
          'Brace hard.',
          '{Seconds}[s@]{RPE}',
          'Upper',
          'TRUE',
          '45s@8',
        ],
        ['Squat', '3', '5', '8', '3 min', '', '', '', 'Legs', '', ''],
      ]);

      await tester.pumpWidget(
        WorkoutTrackerApp(
          validationService: service,
          initialSpreadsheetText: 'spreadsheet-id',
        ),
      );

      await tester.tap(find.byKey(const ValueKey('validate-spreadsheet')));
      await tester.pump();
      await tester.pump();

      expect(find.text('Upper (1/1 done)'), findsOneWidget);
      await tester.tap(find.text('Upper (1/1 done)'));
      await tester.pumpAndSettle();
      expect(find.text('Legs (0/1 done)'), findsOneWidget);
    },
  );

  testWidgets('opens backup placement from a visible overview row action', (
    tester,
  ) async {
    final activeSheet = parseActiveSheet(
      ActiveSheetInput(
        rows: [
          [...activeSheetFixedColumns, 'Week 1'],
          [...List.filled(activeSheetFixedColumns.length, ''), 'S1'],
          [
            'Pull Up',
            '3',
            '8',
            '8',
            '2 min',
            '',
            'Full hang.',
            '{Reps}',
            'Upper',
            '',
            '',
          ],
        ],
        cellFormulas: const [
          CellFormula(
            sheetRowNumber: 3,
            sheetColumnNumber: 1,
            formula: '=Exercises!A2',
          ),
          CellFormula(
            sheetRowNumber: 3,
            sheetColumnNumber: 8,
            formula: '=Exercises!I2',
          ),
        ],
        exercisesRows: const [
          exercisesSheetColumns,
          [
            'Pull Up',
            'Bodyweight pull',
            '3',
            '8',
            '8',
            '2 min',
            '',
            'Full hang.',
            '{Reps}',
          ],
          [
            'Front Plank',
            'Core hold',
            '3',
            '45',
            '8',
            '60s',
            '',
            'Brace hard.',
            '{Seconds}[s@]{RPE}',
          ],
        ],
      ),
    );
    final service = TestSpreadsheetValidationService(activeSheet);

    await tester.pumpWidget(
      WorkoutTrackerApp(
        validationService: service,
        initialSpreadsheetText: 'spreadsheet-id',
      ),
    );

    await tester.tap(find.byKey(const ValueKey('validate-spreadsheet')));
    await tester.pump();
    await tester.pump();

    expect(find.text('Upper exercises'), findsOneWidget);
    expect(find.text('Pull Up'), findsOneWidget);

    await tester.tap(find.byTooltip('Backup actions for Pull Up'));
    await tester.pumpAndSettle();

    expect(find.text('Add backup exercise'), findsOneWidget);

    await tester.tap(find.text('Add backup exercise'));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Back to exercises'), findsOneWidget);
    expect(find.text('Add backup exercise'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('existing-exercise-selector')),
      findsOneWidget,
    );
  });

  testWidgets('summarizes backups without crowding primary overview rows', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    const longBackupName =
        'Very Long Machine Row Backup Name That Should Not Crowd The Row';
    final service = TestSpreadsheetValidationService.fromRows([
      [...activeSheetFixedColumns, 'Week 1'],
      [...List.filled(activeSheetFixedColumns.length, ''), 'S1'],
      [
        'Pull Up',
        '3',
        '8',
        '8',
        '2 min',
        '',
        'Full hang.',
        '{Reps}',
        'Upper',
        '',
        '',
      ],
      [
        longBackupName,
        '3',
        '10',
        '8',
        '2 min',
        '',
        '',
        '{Reps}',
        'Upper',
        'TRUE',
        '12',
      ],
      [
        'Another Long Cable Backup Option That Should Stay Secondary',
        '3',
        '10',
        '8',
        '2 min',
        '',
        '',
        '{Reps}',
        'Upper',
        'TRUE',
        '',
      ],
    ]);

    await tester.pumpWidget(
      WorkoutTrackerApp(
        validationService: service,
        initialSpreadsheetText: 'spreadsheet-id',
      ),
    );

    await tester.tap(find.byKey(const ValueKey('validate-spreadsheet')));
    await tester.pump();
    await tester.pump();

    final compactOverview = find.byKey(
      const ValueKey('compact-workout-overview'),
    );
    expect(compactOverview, findsOneWidget);
    expect(
      find.descendant(of: compactOverview, matching: find.text('Pull Up')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: compactOverview, matching: find.text('1 set')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: compactOverview, matching: find.text('2 backups')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: compactOverview, matching: find.text(longBackupName)),
      findsNothing,
    );
  });

  testWidgets(
    'selecting a workout setup opens the full exercise picker with compact context',
    (tester) async {
      final service = TestSpreadsheetValidationService.fromRows([
        [...activeSheetFixedColumns, 'Week 1'],
        [...List.filled(activeSheetFixedColumns.length, ''), 'S1'],
        [
          'Bulgarian Split Squat',
          '3',
          '8',
          '8',
          '90s',
          '',
          '',
          '',
          'Legs',
          '',
          '',
        ],
        ['Reverse Lunge', '3', '8', '8', '90s', '', '', '', 'Legs', 'TRUE', ''],
      ]);

      await tester.pumpWidget(
        WorkoutTrackerApp(
          validationService: service,
          initialSpreadsheetText: 'spreadsheet-id',
        ),
      );

      await tester.tap(find.byKey(const ValueKey('validate-spreadsheet')));
      await tester.pump();
      await tester.pump();

      expect(find.text('Legs - Week 1'), findsNothing);
      expect(
        find.byKey(const ValueKey('compact-workout-overview')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const ValueKey('select-workout-setup')));
      await tester.pumpAndSettle();

      expect(find.byTooltip('Back to workout setup'), findsOneWidget);
      expect(find.text('Legs - Week 1'), findsOneWidget);
      expect(find.text('Legs exercises'), findsNothing);
      expect(
        find.byKey(const ValueKey('full-workout-overview')),
        findsOneWidget,
      );
      expect(find.text('Bulgarian Split Squat'), findsOneWidget);
      expect(find.text('Reverse Lunge'), findsOneWidget);
    },
  );

  testWidgets('compresses logging context and history until expanded', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final service = TestSpreadsheetValidationService.fromRows([
      [...activeSheetFixedColumns, 'Week 2', 'Week 1', ''],
      [...List.filled(activeSheetFixedColumns.length, ''), 'S1', 'S1', 'S2'],
      [
        'Carry',
        '3',
        '40',
        '8',
        '90s',
        'Smooth',
        'Stay tall.',
        '{Distance}[@]{RPE}',
        'Conditioning',
        '',
        'worked up, grip failed',
        '30@7',
        '35@8',
      ],
    ]);

    await tester.pumpWidget(
      WorkoutTrackerApp(
        validationService: service,
        initialSpreadsheetText: 'spreadsheet-id',
      ),
    );

    await tester.tap(find.byKey(const ValueKey('validate-spreadsheet')));
    await tester.pump();
    await tester.pump();
    await tester.tap(find.text('Carry'));
    await tester.pumpAndSettle();

    expect(find.text('Carry'), findsWidgets);
    expect(find.text('Carry logging'), findsNothing);
    expect(find.text('Next set S2'), findsOneWidget);
    expect(find.text('Logged sets'), findsOneWidget);
    expect(find.byKey(const ValueKey('raw-S1')), findsOneWidget);
    expect(find.text('Training details'), findsOneWidget);
    expect(find.text('Plan 3 x 40 @ 8'), findsOneWidget);
    expect(find.text('Rest 90s | Tempo Smooth'), findsOneWidget);
    expect(find.text('Target: 3 sets x 40 @ 8'), findsNothing);
    expect(find.text('Rest: 90s'), findsNothing);
    expect(find.text('Tempo: Smooth'), findsNothing);
    expect(find.text('Notes: Stay tall.'), findsNothing);
    expect(find.text('Recent history'), findsOneWidget);
    expect(find.text('Week 1: 30@7, 35@8'), findsOneWidget);
    expect(find.text('Week 1'), findsNothing);
    expect(find.text('Week 1 S1: 30@7'), findsNothing);
    expect(find.text('S1: 30@7'), findsNothing);
    expect(find.text('S2: 35@8'), findsNothing);

    await tester.tap(find.text('Training details'));
    await tester.pumpAndSettle();

    expect(find.text('Target: 3 sets x 40 @ 8'), findsOneWidget);
    expect(find.text('Rest: 90s'), findsOneWidget);
    expect(find.text('Tempo: Smooth'), findsOneWidget);
    expect(find.text('Notes: Stay tall.'), findsOneWidget);
    expect(find.text('Latest history: 30@7'), findsOneWidget);

    await tester.tap(find.text('Recent history'));
    await tester.pumpAndSettle();

    expect(find.text('S1: 30@7'), findsOneWidget);
    expect(find.text('S2: 35@8'), findsOneWidget);
  });

  testWidgets(
    'prioritizes next set entry before context and history on a phone',
    (tester) async {
      tester.view.physicalSize = const Size(390, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final service = TestSpreadsheetValidationService.fromRows([
        [...activeSheetFixedColumns, 'Week 2', 'Week 1', ''],
        [...List.filled(activeSheetFixedColumns.length, ''), 'S1', 'S1', 'S2'],
        [
          'Carry',
          '3',
          '40',
          '8',
          '90s',
          'Smooth',
          'Stay tall.',
          '{Distance}[@]{RPE}',
          'Conditioning',
          '',
          'worked up, grip failed',
          '30@7',
          '35@8',
        ],
      ]);

      await tester.pumpWidget(
        WorkoutTrackerApp(
          validationService: service,
          initialSpreadsheetText: 'spreadsheet-id',
        ),
      );

      await tester.tap(find.byKey(const ValueKey('validate-spreadsheet')));
      await tester.pump();
      await tester.pump();
      await tester.tap(find.text('Carry'));
      await tester.pumpAndSettle();

      final nextSet = find.text('Next set S2');
      final nextSetField = find.byKey(const ValueKey('set-field-Distance'));
      final saveSet = find.text('Save set');
      final progress = find.text('Progress 1/2');
      final target = find.text('Plan 3 x 40 @ 8');
      final recentHistory = find.text('Recent history');

      expect(nextSet, findsOneWidget);
      expect(nextSetField, findsOneWidget);
      expect(saveSet, findsOneWidget);
      expect(progress, findsOneWidget);
      expect(target, findsOneWidget);
      expect(recentHistory, findsOneWidget);
      expect(
        tester.getTopLeft(nextSet).dy,
        lessThan(tester.getTopLeft(target).dy),
      );
      expect(
        tester.getTopLeft(nextSetField).dy,
        lessThan(tester.getTopLeft(target).dy),
      );
      expect(
        tester.getTopLeft(saveSet).dy,
        lessThan(tester.getTopLeft(target).dy),
      );
      expect(
        tester.getTopLeft(progress).dy,
        lessThan(tester.getTopLeft(recentHistory).dy),
      );
    },
  );

  testWidgets('keeps save reachable while editing a phone logging form', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.view.resetViewInsets();
    });

    final service = TestSpreadsheetValidationService.fromRows([
      [...activeSheetFixedColumns, 'Week 1'],
      [...List.filled(activeSheetFixedColumns.length, ''), 'S1'],
      [
        'Step Up',
        '3',
        '10',
        '8',
        '90s',
        '',
        '',
        '{Weight}[x]{Reps}[@]{RPE}[,]{Pain}',
        'Legs',
        '',
        '',
      ],
    ]);

    await tester.pumpWidget(
      WorkoutTrackerApp(
        validationService: service,
        initialSpreadsheetText: 'spreadsheet-id',
      ),
    );

    await tester.tap(find.byKey(const ValueKey('validate-spreadsheet')));
    await tester.pump();
    await tester.pump();
    await tester.tap(find.text('Step Up'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('set-field-Weight')));
    tester.view.viewInsets = const FakeViewPadding(bottom: 280);
    await tester.pump();

    final saveSet = find.text('Save set');
    expect(saveSet, findsOneWidget);
    expect(
      tester.getBottomLeft(saveSet).dy,
      lessThan(tester.view.physicalSize.height - tester.view.viewInsets.bottom),
    );
  });

  testWidgets('stacks logging fields into usable numeric phone inputs', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final service = TestSpreadsheetValidationService.fromRows([
      [...activeSheetFixedColumns, 'Week 1'],
      [...List.filled(activeSheetFixedColumns.length, ''), 'S1'],
      [
        'Step Up',
        '3',
        '10',
        '8',
        '90s',
        '',
        '',
        '{Weight}[x]{Reps}[@]{RPE}[,]{Pain}',
        'Legs',
        '',
        '',
      ],
    ]);

    await tester.pumpWidget(
      WorkoutTrackerApp(
        validationService: service,
        initialSpreadsheetText: 'spreadsheet-id',
      ),
    );

    await tester.tap(find.byKey(const ValueKey('validate-spreadsheet')));
    await tester.pump();
    await tester.pump();
    await tester.tap(find.text('Step Up'));
    await tester.pumpAndSettle();

    for (final key in const [
      ValueKey('set-field-Weight'),
      ValueKey('set-field-Reps'),
      ValueKey('set-field-RPE'),
      ValueKey('set-field-Pain'),
    ]) {
      final field = find.byKey(key);
      expect(field, findsOneWidget);
      expect(tester.getSize(field).width, greaterThanOrEqualTo(240));
      expect(
        tester.widget<TextField>(field).keyboardType,
        TextInputType.number,
      );
    }

    expect(tester.takeException(), isNull);
  });

  testWidgets('stacks logged structured set fields on a phone', (tester) async {
    tester.view.physicalSize = const Size(320, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final service = TestSpreadsheetValidationService.fromRows([
      [...activeSheetFixedColumns, 'Week 1'],
      [...List.filled(activeSheetFixedColumns.length, ''), 'S1'],
      [
        'Step Up',
        '3',
        '10',
        '8',
        '90s',
        '',
        '',
        '{Weight}[x]{Reps}[@]{RPE}',
        'Legs',
        '',
        '155x10@8',
      ],
    ]);

    await tester.pumpWidget(
      WorkoutTrackerApp(
        validationService: service,
        initialSpreadsheetText: 'spreadsheet-id',
      ),
    );

    await tester.tap(find.byKey(const ValueKey('validate-spreadsheet')));
    await tester.pump();
    await tester.pump();
    await tester.tap(find.text('Step Up'));
    await tester.pumpAndSettle();

    for (final key in const [
      ValueKey('logged-S1-field-Weight'),
      ValueKey('logged-S1-field-Reps'),
      ValueKey('logged-S1-field-RPE'),
    ]) {
      final field = find.byKey(key);
      expect(field, findsOneWidget);
      expect(tester.getSize(field).width, greaterThanOrEqualTo(240));
      expect(
        tester.widget<TextField>(field).keyboardType,
        TextInputType.number,
      );
    }
    expect(find.byTooltip('Save structured set'), findsOneWidget);
    expect(find.byTooltip('Clear set'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('stacks workout setup controls across phone width', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final service = TestSpreadsheetValidationService.fromRows([
      [...activeSheetFixedColumns, 'Week 2', 'Week 1'],
      [...List.filled(activeSheetFixedColumns.length, ''), 'S1', 'S1'],
      ['Squat', '3', '5', '8', '3 min', '', '', '', 'Legs', '', '', ''],
      ['Bench Press', '4', '6', '8', '3 min', '', '', '', 'Upper', '', '', ''],
    ]);

    await tester.pumpWidget(
      WorkoutTrackerApp(
        validationService: service,
        initialSpreadsheetText: 'spreadsheet-id',
      ),
    );

    await tester.tap(find.byKey(const ValueKey('validate-spreadsheet')));
    await tester.pump();
    await tester.pump();

    final selectors = find.byType(DropdownButtonFormField<String>);
    expect(selectors, findsNWidgets(2));
    for (final selector in selectors.evaluate()) {
      final width = tester.getSize(find.byWidget(selector.widget)).width;
      expect(width, greaterThanOrEqualTo(280));
      expect(width, lessThanOrEqualTo(360));
    }
    expect(find.byKey(const ValueKey('select-workout-setup')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'shows setup creation actions outside selectors and selects created values',
    (tester) async {
      final service = TestSpreadsheetValidationService.fromRows([
        [...activeSheetFixedColumns, 'Week 1'],
        [...List.filled(activeSheetFixedColumns.length, ''), 'S1'],
        ['Squat', '3', '5', '8', '3 min', '', '', '', 'Legs', '', ''],
      ]);

      await tester.pumpWidget(
        WorkoutTrackerApp(
          validationService: service,
          initialSpreadsheetText: 'spreadsheet-id',
        ),
      );

      await tester.tap(find.byKey(const ValueKey('validate-spreadsheet')));
      await tester.pump();
      await tester.pump();

      expect(find.byKey(const ValueKey('add-workout')), findsOneWidget);
      expect(find.byKey(const ValueKey('add-history-block')), findsOneWidget);

      await tester.tap(find.byType(DropdownButtonFormField<String>).first);
      await tester.pumpAndSettle();
      expect(find.text('Add new...'), findsNothing);
      await tester.tap(find.text('Legs (0/1 done)').last);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('add-workout')));
      await tester.pumpAndSettle();
      await tester.enterText(_textFieldWithLabel('Workout name'), 'Push');
      await tester.tap(find.widgetWithText(FilledButton, 'Add'));
      await tester.pumpAndSettle();

      expect(find.text('Push (0/0 done)'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('add-history-block')));
      await tester.pumpAndSettle();
      await tester.enterText(
        _textFieldWithLabel('History block label'),
        'Week 2',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Add'));
      await tester.pumpAndSettle();

      expect(service.appliedPlans, hasLength(1));
      expect(find.text('Week 2'), findsOneWidget);
    },
  );

  testWidgets('requires choosing an exercise before placing it in a workout', (
    tester,
  ) async {
    final activeSheet = parseActiveSheet(
      ActiveSheetInput(
        rows: [
          [...activeSheetFixedColumns, 'Week 1'],
          [...List.filled(activeSheetFixedColumns.length, ''), 'S1'],
          ['Pull Up', '3', '8', '8', '2 min', '', '', '{Reps}', 'Legs', '', ''],
        ],
        cellFormulas: const [
          CellFormula(
            sheetRowNumber: 3,
            sheetColumnNumber: 1,
            formula: '=Exercises!A2',
          ),
          CellFormula(
            sheetRowNumber: 3,
            sheetColumnNumber: 8,
            formula: '=Exercises!I2',
          ),
        ],
        exercisesRows: const [
          exercisesSheetColumns,
          [
            'Pull Up',
            'Bodyweight pull',
            '3',
            '8',
            '8',
            '2 min',
            '',
            'Full hang.',
            '{Reps}',
          ],
          [
            'Dip',
            'Parallel bar dip',
            '3',
            '10',
            '8',
            '2 min',
            '',
            'Locked out.',
            '{Reps}',
          ],
        ],
      ),
    );
    final service = TestSpreadsheetValidationService(activeSheet);

    await tester.pumpWidget(
      WorkoutTrackerApp(
        validationService: service,
        initialSpreadsheetText: 'spreadsheet-id',
      ),
    );

    await tester.tap(find.byKey(const ValueKey('validate-spreadsheet')));
    await tester.pump();
    await tester.pump();
    await tester.tap(
      find.byKey(const ValueKey('add-primary-exercise-from-setup')),
    );
    await tester.pumpAndSettle();

    final submitButton = tester.widget<FilledButton>(
      find.byKey(const ValueKey('place-existing-exercise')),
    );
    expect(submitButton.onPressed, isNull);
    expect(_textFieldWithLabel('Sets'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('existing-exercise-selector')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dip').last);
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const ValueKey('place-existing-exercise')),
          )
          .onPressed,
      isNotNull,
    );
    expect(
      tester.widget<TextField>(_textFieldWithLabel('Reps')).controller?.text,
      '10',
    );
  });

  testWidgets('stacks workout placement fields into phone-width inputs', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final activeSheet = parseActiveSheet(
      ActiveSheetInput(
        rows: [
          [...activeSheetFixedColumns, 'Week 1'],
          [...List.filled(activeSheetFixedColumns.length, ''), 'S1'],
          ['Pull Up', '3', '8', '8', '2 min', '', '', '{Reps}', 'Legs', '', ''],
        ],
        cellFormulas: const [
          CellFormula(
            sheetRowNumber: 3,
            sheetColumnNumber: 1,
            formula: '=Exercises!A2',
          ),
          CellFormula(
            sheetRowNumber: 3,
            sheetColumnNumber: 8,
            formula: '=Exercises!I2',
          ),
        ],
        exercisesRows: const [
          exercisesSheetColumns,
          [
            'Pull Up',
            'Bodyweight pull',
            '3',
            '8',
            '8',
            '2 min',
            '',
            'Full hang.',
            '{Reps}',
          ],
        ],
      ),
    );
    final service = TestSpreadsheetValidationService(activeSheet);

    await tester.pumpWidget(
      WorkoutTrackerApp(
        validationService: service,
        initialSpreadsheetText: 'spreadsheet-id',
      ),
    );

    await tester.tap(find.byKey(const ValueKey('validate-spreadsheet')));
    await tester.pump();
    await tester.pump();
    await tester.tap(
      find.byKey(const ValueKey('add-primary-exercise-from-setup')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('existing-exercise-selector')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pull Up').last);
    await tester.pumpAndSettle();

    for (final label in const [
      'Sets',
      'Reps',
      'RPE',
      'Rest',
      'Tempo',
      'Notes',
    ]) {
      final field = _textFieldWithLabel(label);
      expect(field, findsOneWidget);
      final width = tester.getSize(field).width;
      expect(width, greaterThanOrEqualTo(280));
      expect(width, lessThanOrEqualTo(360));
    }
    for (final label in const ['Sets', 'RPE']) {
      expect(
        tester.widget<TextField>(_textFieldWithLabel(label)).keyboardType,
        TextInputType.number,
      );
    }
    expect(
      tester.widget<TextField>(_textFieldWithLabel('Reps')).keyboardType,
      isNot(TextInputType.number),
    );
    expect(
      find.byKey(const ValueKey('place-existing-exercise')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps exercise authoring fields usable on a phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final service = TestSpreadsheetValidationService.fromRows([
      [...activeSheetFixedColumns, 'Week 1'],
      [...List.filled(activeSheetFixedColumns.length, ''), 'S1'],
      ['Squat', '3', '5', '8', '3 min', '', '', '', 'Legs', '', ''],
    ]);

    await tester.pumpWidget(
      WorkoutTrackerApp(
        validationService: service,
        initialSpreadsheetText: 'spreadsheet-id',
      ),
    );

    await tester.tap(find.byKey(const ValueKey('validate-spreadsheet')));
    await tester.pump();
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('create-canonical-exercise')));
    await tester.pumpAndSettle();

    for (final key in const [
      ValueKey('exercise-authoring-default-sets'),
      ValueKey('exercise-authoring-default-reps'),
      ValueKey('exercise-authoring-default-rpe'),
    ]) {
      final field = find.byKey(key);
      expect(field, findsOneWidget);
      final width = tester.getSize(field).width;
      expect(width, greaterThanOrEqualTo(280));
      expect(width, lessThanOrEqualTo(360));
    }
    for (final key in const [
      ValueKey('exercise-authoring-default-sets'),
      ValueKey('exercise-authoring-default-rpe'),
    ]) {
      final field = find.byKey(key);
      expect(
        tester
            .widget<EditableText>(
              find.descendant(of: field, matching: find.byType(EditableText)),
            )
            .keyboardType,
        TextInputType.number,
      );
    }
    expect(
      tester
          .widget<EditableText>(
            find.descendant(
              of: find.byKey(const ValueKey('exercise-authoring-default-reps')),
              matching: find.byType(EditableText),
            ),
          )
          .keyboardType,
      isNot(TextInputType.number),
    );

    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('exercise-authoring-submit')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('presents logged current and backup states in the logging flow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final service = TestSpreadsheetValidationService.fromRows([
      [...activeSheetFixedColumns, 'Week 1'],
      [...List.filled(activeSheetFixedColumns.length, ''), 'S1', 'S2'],
      [
        'Pull Up',
        '3',
        '8',
        '8',
        '2 min',
        '',
        'Full hang.',
        '{Reps}',
        'Upper',
        '',
        '12',
        '',
      ],
      [
        'Front Plank',
        '3',
        '45s',
        '8',
        '60s',
        '',
        'Brace hard.',
        '{Seconds}[s@]{RPE}',
        'Upper',
        'TRUE',
        '',
        '',
      ],
    ]);

    await tester.pumpWidget(
      WorkoutTrackerApp(
        validationService: service,
        initialSpreadsheetText: 'spreadsheet-id',
      ),
    );

    await tester.tap(find.byKey(const ValueKey('validate-spreadsheet')));
    await tester.pump();
    await tester.pump();
    await tester.tap(find.text('Pull Up'));
    await tester.pumpAndSettle();

    expect(find.text('Progress 1/2'), findsOneWidget);
    expect(find.text('Logged S1'), findsOneWidget);
    expect(find.text('Current S2'), findsOneWidget);
    expect(find.text('Backup'), findsOneWidget);
    expect(find.text('Front Plank'), findsOneWidget);
  });

  testWidgets(
    'switching to a backup row refreshes structured labels and parsed values',
    (tester) async {
      tester.view.physicalSize = const Size(390, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final service = TestSpreadsheetValidationService.fromRows([
        [...activeSheetFixedColumns, 'Week 1'],
        [...List.filled(activeSheetFixedColumns.length, ''), 'S1'],
        [
          'Pull Up',
          '3',
          '8',
          '8',
          '2 min',
          '',
          'Full hang.',
          '{Reps}',
          'Upper',
          '',
          '12',
        ],
        [
          'Front Plank',
          '3',
          '45s',
          '8',
          '60s',
          '',
          'Brace hard.',
          '{Seconds}[s@]{RPE}',
          'Upper',
          'TRUE',
          '45s@8',
        ],
      ]);

      await tester.pumpWidget(
        WorkoutTrackerApp(
          validationService: service,
          initialSpreadsheetText: 'spreadsheet-id',
        ),
      );

      await tester.tap(find.byKey(const ValueKey('validate-spreadsheet')));
      await tester.pump();
      await tester.pump();
      await tester.tap(find.text('Pull Up'));
      await tester.pumpAndSettle();

      expect(find.text('Front Plank'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('logged-S1-field-Reps')),
        findsOneWidget,
      );
      expect(
        tester
            .widget<TextField>(
              find.byKey(const ValueKey('logged-S1-field-Reps')),
            )
            .controller
            ?.text,
        '12',
      );

      await tester.tap(find.text('Front Plank'));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('set-field-Seconds')), findsOneWidget);
      expect(find.byKey(const ValueKey('set-field-RPE')), findsOneWidget);
      expect(find.byKey(const ValueKey('set-field-Reps')), findsNothing);
      expect(
        tester
            .widget<TextField>(
              find.byKey(const ValueKey('logged-S1-field-Seconds')),
            )
            .controller
            ?.text,
        '45',
      );
      expect(
        tester
            .widget<TextField>(
              find.byKey(const ValueKey('logged-S1-field-RPE')),
            )
            .controller
            ?.text,
        '8',
      );

      await tester.enterText(
        find.byKey(const ValueKey('logged-S1-field-Seconds')),
        '50',
      );
      await tester.tap(find.byTooltip('Save structured set'));
      await tester.pump();
      await tester.pump();

      expect(service.appliedPlans.single.cellUpdates.single.value, '50s@8');

      await tester.tap(find.byTooltip('Clear set'));
      await tester.pump();
      await tester.pump();

      expect(service.appliedPlans.last.cellUpdates.single.value, isEmpty);
    },
  );

  testWidgets('shows a top-right Google account menu for account switching', (
    tester,
  ) async {
    final service = TestSpreadsheetValidationService.fromRows([
      [...activeSheetFixedColumns, 'Week 1'],
      [...List.filled(activeSheetFixedColumns.length, ''), 'S1'],
      ['Squat', '3', '5', '8', '3 min', '', '', '', 'Legs', '', ''],
    ]);
    final accountSession = _FakeGoogleAccountSession(
      const GoogleAccountProfile(
        email: 'wrong@example.com',
        displayName: 'Wrong Account',
      ),
    );

    await tester.pumpWidget(
      WorkoutTrackerApp(
        validationService: service,
        accountSession: accountSession,
        initialSpreadsheetText: 'spreadsheet-id',
      ),
    );

    await tester.tap(find.byTooltip('Google account: wrong@example.com'));
    await tester.pumpAndSettle();

    expect(find.text('Wrong Account'), findsOneWidget);
    expect(find.text('wrong@example.com'), findsOneWidget);

    await tester.tap(find.text('Switch account'));
    await tester.pumpAndSettle();

    expect(accountSession.switchCount, 1);
    expect(accountSession.requestedScopes.single, isEmpty);
    expect(accountSession.currentAccount?.email, 'right@example.com');
  });

  testWidgets('shows the Google account menu in picker mode', (tester) async {
    final service = TestSpreadsheetValidationService.fromRows([
      [...activeSheetFixedColumns, 'Week 1'],
      [...List.filled(activeSheetFixedColumns.length, ''), 'S1'],
      ['Squat', '3', '5', '8', '3 min', '', '', '', 'Legs', '', ''],
    ]);
    final accountSession = _FakeGoogleAccountSession(
      const GoogleAccountProfile(
        email: 'saved@example.com',
        displayName: 'Saved Account',
      ),
    );

    await tester.pumpWidget(
      WorkoutTrackerApp(
        validationService: service,
        accountSession: accountSession,
        spreadsheetPicker: _FakeSpreadsheetPicker(),
      ),
    );
    await tester.pump();

    expect(find.byTooltip('Google account: saved@example.com'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('spreadsheet-selection-input')),
      findsNothing,
    );
  });
}

class _FakeGoogleAccountSession extends ChangeNotifier
    implements GoogleAccountSession {
  _FakeGoogleAccountSession(this._currentAccount, {this.restoredAccount});

  GoogleAccountProfile? _currentAccount;
  final GoogleAccountProfile? restoredAccount;
  int restoreCount = 0;
  int switchCount = 0;
  final requestedScopes = <List<String>>[];

  @override
  GoogleAccountProfile? get currentAccount => _currentAccount;

  @override
  Future<void> restoreAccount() async {
    restoreCount += 1;
    if (restoredAccount != null) {
      _currentAccount = restoredAccount;
      notifyListeners();
    }
  }

  @override
  Future<void> switchAccount({List<String> scopes = const []}) async {
    switchCount += 1;
    requestedScopes.add(scopes);
    _currentAccount = const GoogleAccountProfile(
      email: 'right@example.com',
      displayName: 'Right Account',
    );
    notifyListeners();
  }
}

Finder _textFieldWithLabel(String labelText) {
  return find.byWidgetPredicate(
    (widget) =>
        widget is TextField && widget.decoration?.labelText == labelText,
    description: 'TextField with label "$labelText"',
  );
}

class _MemoryAppStateStore implements AppStateStore {
  _MemoryAppStateStore(this.spreadsheetText, {this.selectedSpreadsheet});

  String? spreadsheetText;
  SelectedSpreadsheet? selectedSpreadsheet;
  WorkoutSelectionState? workoutSelection;
  final writes = <String>[];
  final selectedWrites = <SelectedSpreadsheet>[];
  final workoutSelectionWrites = <WorkoutSelectionState>[];

  @override
  Future<String?> readSpreadsheetText() async {
    return spreadsheetText;
  }

  @override
  Future<void> writeSpreadsheetText(String value) async {
    spreadsheetText = value;
    writes.add(value);
  }

  @override
  Future<SelectedSpreadsheet?> readSelectedSpreadsheet() async {
    return selectedSpreadsheet;
  }

  @override
  Future<void> writeSelectedSpreadsheet(SelectedSpreadsheet value) async {
    selectedSpreadsheet = value;
    selectedWrites.add(value);
  }

  @override
  Future<WorkoutSelectionState?> readWorkoutSelection() async {
    return workoutSelection;
  }

  @override
  Future<void> writeWorkoutSelection(WorkoutSelectionState value) async {
    workoutSelection = value;
    workoutSelectionWrites.add(value);
  }
}

class _FakeSpreadsheetPicker implements SpreadsheetPicker {
  @override
  SpreadsheetPickerAvailability get availability {
    return const SpreadsheetPickerAvailability.available();
  }

  @override
  Future<SelectedSpreadsheet?> chooseSpreadsheet() async {
    return null;
  }

  @override
  Future<SelectedSpreadsheet?> createSpreadsheet() async {
    return null;
  }
}

class _CompletingSpreadsheetPicker implements SpreadsheetPicker {
  final chooseCompleter = Completer<SelectedSpreadsheet?>();
  int chooseCount = 0;

  @override
  SpreadsheetPickerAvailability get availability {
    return const SpreadsheetPickerAvailability.available();
  }

  @override
  Future<SelectedSpreadsheet?> chooseSpreadsheet() {
    chooseCount += 1;
    return chooseCompleter.future;
  }

  @override
  Future<SelectedSpreadsheet?> createSpreadsheet() async {
    return null;
  }
}

class _CountingSpreadsheetPicker implements SpreadsheetPicker {
  int chooseCount = 0;
  int createCount = 0;

  @override
  SpreadsheetPickerAvailability get availability {
    return const SpreadsheetPickerAvailability.available();
  }

  @override
  Future<SelectedSpreadsheet?> chooseSpreadsheet() async {
    chooseCount += 1;
    return null;
  }

  @override
  Future<SelectedSpreadsheet?> createSpreadsheet() async {
    createCount += 1;
    return null;
  }
}

class _RecordingSpreadsheetOpener implements SpreadsheetOpener {
  final openedUrls = <String>[];

  @override
  Future<void> openSpreadsheet(String url) async {
    openedUrls.add(url);
  }
}

class _RevalidatingSpreadsheetValidationService
    implements SpreadsheetValidationService {
  _RevalidatingSpreadsheetValidationService({required this.reports});

  final List<ParsedActiveSheet> reports;
  int _reportIndex = 0;

  @override
  Future<SpreadsheetValidationReport> validateSpreadsheet(
    String spreadsheetId,
  ) async {
    final index = _reportIndex.clamp(0, reports.length - 1);
    _reportIndex += 1;
    return SpreadsheetValidationReport(
      spreadsheetId: spreadsheetId,
      activeSheet: reports[index],
    );
  }

  @override
  Future<SpreadsheetValidationReport> applyActiveSheetWritePlan({
    required String spreadsheetId,
    required ParsedActiveSheet activeSheet,
    required ActiveSheetWritePlan plan,
  }) {
    throw UnimplementedError();
  }
}

ParsedActiveSheet _minimalValidParsedSheet() {
  return parseActiveSheet(
    ActiveSheetInput(
      rows: [
        [...activeSheetFixedColumns, 'Week 1'],
        [...List.filled(activeSheetFixedColumns.length, ''), 'S1'],
        ['Squat', '3', '5', '8', '3 min', '', '', '', 'Legs', '', ''],
      ],
    ),
  );
}

class _CompletingWriteValidationService
    implements SpreadsheetValidationService {
  _CompletingWriteValidationService(this.validSheet);

  final ParsedActiveSheet validSheet;
  final appliedPlans = <ActiveSheetWritePlan>[];
  final writeCompleter = Completer<SpreadsheetValidationReport>();

  @override
  Future<SpreadsheetValidationReport> validateSpreadsheet(
    String spreadsheetId,
  ) async {
    return SpreadsheetValidationReport(
      spreadsheetId: spreadsheetId,
      activeSheet: validSheet,
    );
  }

  @override
  Future<SpreadsheetValidationReport> applyActiveSheetWritePlan({
    required String spreadsheetId,
    required ParsedActiveSheet activeSheet,
    required ActiveSheetWritePlan plan,
  }) {
    appliedPlans.add(plan);
    return writeCompleter.future;
  }
}

class _DamageAfterSaveValidationService
    implements SpreadsheetValidationService {
  _DamageAfterSaveValidationService({
    required this.validSheet,
    required this.damagedSheet,
  });

  final ParsedActiveSheet validSheet;
  final ParsedActiveSheet damagedSheet;
  final appliedPlans = <ActiveSheetWritePlan>[];

  @override
  Future<SpreadsheetValidationReport> validateSpreadsheet(
    String spreadsheetId,
  ) async {
    return SpreadsheetValidationReport(
      spreadsheetId: spreadsheetId,
      activeSheet: validSheet,
    );
  }

  @override
  Future<SpreadsheetValidationReport> applyActiveSheetWritePlan({
    required String spreadsheetId,
    required ParsedActiveSheet activeSheet,
    required ActiveSheetWritePlan plan,
  }) async {
    appliedPlans.add(plan);
    return SpreadsheetValidationReport(
      spreadsheetId: spreadsheetId,
      activeSheet: damagedSheet,
    );
  }
}

class _FormulaRepairValidationService implements SpreadsheetValidationService {
  _FormulaRepairValidationService({
    required this.initialSheet,
    required this.repairedSheet,
  });

  final ParsedActiveSheet initialSheet;
  final ParsedActiveSheet repairedSheet;
  final List<ActiveSheetWritePlan> appliedPlans = [];

  @override
  Future<SpreadsheetValidationReport> validateSpreadsheet(
    String spreadsheetId,
  ) async {
    return SpreadsheetValidationReport(
      spreadsheetId: spreadsheetId,
      activeSheet: initialSheet,
    );
  }

  @override
  Future<SpreadsheetValidationReport> applyActiveSheetWritePlan({
    required String spreadsheetId,
    required ParsedActiveSheet activeSheet,
    required ActiveSheetWritePlan plan,
  }) async {
    appliedPlans.add(plan);
    return SpreadsheetValidationReport(
      spreadsheetId: spreadsheetId,
      activeSheet: repairedSheet,
    );
  }
}

ParsedActiveSheet _parseWorkbookFixture(WorkoutWorkbookFixture fixture) {
  return parseActiveSheet(
    ActiveSheetInput(
      rows: fixture.activeSheet.rows,
      mergedFirstColumnRows: fixture.activeSheet.mergedFirstColumnRows,
      cellFormulas: fixture.activeSheet.cellFormulas.map(
        (formula) => CellFormula(
          sheetRowNumber: formula.sheetRowNumber,
          sheetColumnNumber: formula.sheetColumnNumber,
          formula: formula.formula,
        ),
      ),
      exercisesRows: fixture.exercisesSheet.rows,
    ),
  );
}

ParsedActiveSheet _repairedFormulaDamageFixtureSheet() {
  final fixture = loadFormulaDamageFixture();
  return _parseRepairedFormulaDamageFixtureRows(fixture.activeSheet.rows);
}

ParsedActiveSheet _repairedFormulaDamageFixtureSheetWithBackupViolation() {
  final fixture = loadFormulaDamageFixture();
  final rows = fixture.activeSheet.rows.map((row) => row.toList()).toList();
  rows[2][9] = 'TRUE';
  return _parseRepairedFormulaDamageFixtureRows(rows);
}

ParsedActiveSheet _parseRepairedFormulaDamageFixtureRows(
  List<List<String>> rows,
) {
  final fixture = loadFormulaDamageFixture();
  return parseActiveSheet(
    ActiveSheetInput(
      rows: rows,
      exercisesRows: fixture.exercisesSheet.rows,
      cellFormulas: const [
        CellFormula(
          sheetRowNumber: 3,
          sheetColumnNumber: 1,
          formula: '=Exercises!A2',
        ),
        CellFormula(
          sheetRowNumber: 3,
          sheetColumnNumber: 2,
          formula: '=Exercises!C2',
        ),
        CellFormula(
          sheetRowNumber: 3,
          sheetColumnNumber: 3,
          formula: '=Exercises!D2',
        ),
        CellFormula(
          sheetRowNumber: 3,
          sheetColumnNumber: 4,
          formula: '=Exercises!E2',
        ),
        CellFormula(
          sheetRowNumber: 3,
          sheetColumnNumber: 5,
          formula: '=Exercises!F2',
        ),
        CellFormula(
          sheetRowNumber: 3,
          sheetColumnNumber: 6,
          formula: '=Exercises!G2',
        ),
        CellFormula(
          sheetRowNumber: 3,
          sheetColumnNumber: 7,
          formula: '=Exercises!H2',
        ),
        CellFormula(
          sheetRowNumber: 3,
          sheetColumnNumber: 8,
          formula: '=Exercises!I2',
        ),
      ],
    ),
  );
}
