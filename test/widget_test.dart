import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_tracker/google_sheets.dart';
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
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -300));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save set'));
    await tester.pump();
    await tester.pump();

    expect(service.appliedPlans, hasLength(1));
    expect(service.appliedPlans.single.cellUpdates.single.value, '155x6@8');
    expect(find.text('Next set S2'), findsOneWidget);
  });

  testWidgets('does not launch duplicate Save set actions while pending', (
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

  testWidgets('does not launch duplicate logged set edits while pending', (
    tester,
  ) async {
    final service = _CompletingWriteValidationService(_loggedSetParsedSheet());

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
      find.byKey(const ValueKey('logged-S1-field-Weight')),
      '160',
    );
    await tester.tap(find.byTooltip('Save structured set'));
    await tester.pump();

    expect(
      tester
          .widget<IconButton>(find.byKey(const ValueKey('save-S1')))
          .onPressed,
      isNull,
    );

    await tester.tap(find.byTooltip('Save structured set'));

    expect(service.appliedPlans, hasLength(1));
  });

  testWidgets('does not launch duplicate logged set clears while pending', (
    tester,
  ) async {
    final service = _CompletingWriteValidationService(_loggedSetParsedSheet());

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

    await tester.tap(find.byTooltip('Clear set'));
    await tester.pump();

    expect(
      tester
          .widget<IconButton>(find.byKey(const ValueKey('clear-S1')))
          .onPressed,
      isNull,
    );

    await tester.tap(find.byTooltip('Clear set'));

    expect(service.appliedPlans, hasLength(1));
    expect(service.appliedPlans.single.cellUpdates.single.value, isEmpty);
  });

  testWidgets('shows failed Save set writes near logging controls', (
    tester,
  ) async {
    final service = _FailingWriteValidationService(_minimalValidParsedSheet());

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
    expect(find.byKey(const ValueKey('logging-write-error')), findsOneWidget);
    expect(find.text('Unable to save set. Try again.'), findsOneWidget);
  });

  testWidgets(
    'keeps attempted next-set input recoverable after confirmation conflict',
    (tester) async {
      final service = _RecoverableConfirmationFailureService();

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
      expect(service.appliedPlans.single.nextSetPosition?.setNumber, 3);
      expect(find.byKey(const ValueKey('logging-write-error')), findsOneWidget);
      expect(find.text('Next set S2'), findsOneWidget);
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('set-field-Weight')))
            .controller
            ?.text,
        '155',
      );
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('set-field-Reps')))
            .controller
            ?.text,
        '6',
      );
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('set-field-RPE')))
            .controller
            ?.text,
        '8',
      );

      await tester.tap(find.text('Save set'));
      await tester.pump();
      await tester.pump();

      expect(service.appliedPlans, hasLength(2));
      expect(
        service.appliedPlans.map((plan) => plan.nextSetPosition?.setNumber),
        [3, 3],
      );
      expect(find.byKey(const ValueKey('logging-write-error')), findsNothing);
      expect(find.text('Next set S3'), findsOneWidget);
    },
  );

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
    'keeps typed logging input recoverable after damaged confirmation refresh',
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
      expect(find.byKey(const ValueKey('logging-write-error')), findsOneWidget);
      expect(find.text('Unable to save set. Try again.'), findsOneWidget);
      expect(find.text('Fix the active sheet structure'), findsNothing);
      expect(find.text('Next set S1'), findsOneWidget);
      expect(find.text('Save set'), findsOneWidget);
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('set-field-Weight')))
            .controller
            ?.text,
        '155',
      );
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('set-field-Reps')))
            .controller
            ?.text,
        '6',
      );
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('set-field-RPE')))
            .controller
            ?.text,
        '8',
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

    await tester.tap(find.text('Select'));
    await tester.pump();
    await tester.pump();

    expect(service.spreadsheetIds, ['saved-spreadsheet-id']);

    await tester.tap(find.byTooltip('Back to sheet selection'));
    await tester.pumpAndSettle();

    final input = find.byKey(const ValueKey('spreadsheet-selection-input'));

    await tester.enterText(input, 'edited-spreadsheet-id');
    await tester.pump();

    expect(
      store.accessStateWrites.last.spreadsheetText,
      'edited-spreadsheet-id',
    );
    expect(store.accessStateWrites.last.selectedSpreadsheet, isNull);
    expect(store.accessStateWrites.last.workoutSelection, isNull);
  });

  testWidgets('editing the sheet selection preserves Google login', (
    tester,
  ) async {
    final store = _MemoryAppStateStore('saved-spreadsheet-id');
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
        appStateStore: store,
      ),
    );
    await tester.pump();

    await tester.enterText(
      find.byKey(const ValueKey('spreadsheet-selection-input')),
      'other-spreadsheet-id',
    );
    await tester.pump();

    expect(store.spreadsheetText, 'other-spreadsheet-id');
    expect(store.selectedSpreadsheet, isNull);
    expect(accountSession.signOutCount, 0);
    expect(accountSession.currentAccount?.email, 'saved@example.com');
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
        spreadsheetPicker: const DisabledSpreadsheetPicker(
          reason: 'Google Drive Picker is missing an OAuth client ID.',
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

  testWidgets('create sheet prompts for a workbook name before creating', (
    tester,
  ) async {
    final picker = _CountingSpreadsheetPicker();
    final service = TestSpreadsheetValidationService.fromRows([
      [...activeSheetFixedColumns, 'Week 1'],
      [...List.filled(activeSheetFixedColumns.length, ''), 'S1'],
      ['Squat', '3', '5', '8', '3 min', '', '', '', 'Legs', '', ''],
    ]);

    await tester.pumpWidget(
      WorkoutTrackerApp(validationService: service, spreadsheetPicker: picker),
    );
    await tester.pump();

    await tester.tap(find.text('Create sheet'));
    await tester.pumpAndSettle();

    expect(find.text('Sheet name'), findsOneWidget);
    final nameField = find.byKey(const ValueKey('create-spreadsheet-name'));
    expect(nameField, findsOneWidget);
    expect(tester.widget<TextField>(nameField).controller!.text, isNotEmpty);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(picker.createCount, 0);
    expect(picker.createNames, isEmpty);

    await tester.tap(find.text('Create sheet'));
    await tester.pumpAndSettle();
    await tester.enterText(nameField, 'Custom Training Log');
    await tester.tap(find.text('Create'));
    await tester.pump();

    expect(picker.createCount, 1);
    expect(picker.createNames, ['Custom Training Log']);
  });

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
      find.text('Google Drive Picker is missing an OAuth client ID.'),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('spreadsheet-selection-input')),
      findsNothing,
    );
  });

  testWidgets(
    'exposes pasted sheet validation when picker choosing is unavailable',
    (tester) async {
      const picker = DisabledSpreadsheetPicker(
        reason: 'Google Drive Picker is missing an OAuth client ID.',
      );
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
        find.text('Google Drive Picker is missing an OAuth client ID.'),
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
      expect(
        find.byKey(const ValueKey('select-workout-setup')),
        findsOneWidget,
      );
    },
  );

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

  testWidgets('does not launch duplicate create actions while creating', (
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

    await tester.tap(find.text('Create sheet'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create'));
    await tester.pump();

    expect(picker.createCount, 1);
    expect(picker.createNames.single, isNotEmpty);
    expect(
      tester
          .widget<OutlinedButton>(
            find.byKey(const ValueKey('create-google-spreadsheet')),
          )
          .onPressed,
      isNull,
    );

    await tester.tap(find.byKey(const ValueKey('create-google-spreadsheet')));

    expect(picker.createCount, 1);
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
    expect(
      find.byTooltip('Google Sheets account: saved@example.com'),
      findsOneWidget,
    );
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

    expect(find.byTooltip('Back to workout setup'), findsOneWidget);
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

    expect(find.text('Pull Up'), findsOneWidget);
    expect(find.text('1 set'), findsOneWidget);
    expect(find.text('2 backups'), findsOneWidget);
    expect(find.text(longBackupName), findsNothing);
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
      expect(find.text('Legs exercises'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('select-workout-setup')));
      await tester.pumpAndSettle();

      expect(find.byTooltip('Back to workout setup'), findsOneWidget);
      expect(find.text('Legs - Week 1'), findsOneWidget);
      expect(find.text('Legs exercises'), findsNothing);
      expect(find.text('Bulgarian Split Squat'), findsOneWidget);
      expect(find.text('Reverse Lunge'), findsOneWidget);
    },
  );

  testWidgets('back from adding to a selected workout returns to setup', (
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
    await tester.tap(find.byKey(const ValueKey('select-workout-setup')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('add-primary-exercise')));
    await tester.pumpAndSettle();

    expect(find.text('Add to workout'), findsWidgets);
    expect(find.byTooltip('Back to workout setup'), findsOneWidget);

    await tester.tap(find.byTooltip('Back to workout setup'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('select-workout-setup')), findsOneWidget);
    expect(find.text('Legs exercises'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('spreadsheet-selection-input')),
      findsNothing,
    );
    expect(find.text('Legs - Week 1'), findsNothing);
  });

  testWidgets(
    'add-to-workout search and placement preserve selected sheet context',
    (tester) async {
      final activeSheet = parseActiveSheet(
        ActiveSheetInput(
          rows: [
            [...activeSheetFixedColumns, 'Week 2', 'Week 1'],
            [...List.filled(activeSheetFixedColumns.length, ''), 'S1', 'S1'],
            [
              'Pull Up',
              '3',
              '8',
              '8',
              '2 min',
              '',
              '',
              '{Reps}',
              'Legs',
              '',
              '',
              '',
            ],
            [
              'Bench Press',
              '4',
              '6',
              '8',
              '3 min',
              '',
              '',
              '{Weight}[x]{Reps}[@]{RPE}',
              'Upper',
              '',
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
            CellFormula(
              sheetRowNumber: 4,
              sheetColumnNumber: 1,
              formula: '=Exercises!A3',
            ),
            CellFormula(
              sheetRowNumber: 4,
              sheetColumnNumber: 8,
              formula: '=Exercises!I3',
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
              'Bench Press',
              'Competition bench',
              '4',
              '6',
              '8',
              '3 min',
              '',
              '',
              '{Weight}[x]{Reps}[@]{RPE}',
            ],
            [
              'Romanian Deadlift',
              'Hip hinge',
              '3',
              '10',
              '7',
              '2 min',
              '',
              '',
              '{Weight}[x]{Reps}[@]{RPE}',
            ],
          ],
        ),
      );
      final store = _MemoryAppStateStore(
        null,
        selectedSpreadsheet: const SelectedSpreadsheet(
          spreadsheetId: 'selected-spreadsheet-id',
          name: '2026 Workouts',
          drivePath: 'My Drive / Workouts / 2026 Workouts',
          accountEmail: 'saved@example.com',
        ),
      );
      final service = TestSpreadsheetValidationService(activeSheet);
      final authoringService = _WorkoutPlacementRecordingService(activeSheet);

      await tester.pumpWidget(
        WorkoutTrackerApp(
          validationService: service,
          exerciseAuthoringService: authoringService,
          appStateStore: store,
          spreadsheetPicker: _FakeSpreadsheetPicker(),
        ),
      );
      await tester.pump();
      await tester.pump();

      await tester.tap(find.text('Week 2'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Week 1').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Legs (0/1 done)').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Upper (0/1 done)').last);
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey('add-primary-exercise-from-setup')),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('exercise-picker-search')),
        'romanian',
      );
      await tester.pump();

      expect(find.byTooltip('Back to workout setup'), findsOneWidget);
      await tester.tap(find.byTooltip('Back to workout setup'));
      await tester.pumpAndSettle();

      expect(find.text('Upper exercises'), findsOneWidget);
      expect(find.text('Week 1'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('spreadsheet-selection-input')),
        findsNothing,
      );
      expect(find.text('Return to workout'), findsNothing);

      await tester.tap(
        find.byKey(const ValueKey('add-primary-exercise-from-setup')),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('exercise-picker-search')),
        'romanian',
      );
      await tester.pump();
      await tester.tap(
        find.byKey(const ValueKey('existing-exercise-selector')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Romanian Deadlift').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('place-existing-exercise')));
      await tester.pumpAndSettle();

      expect(authoringService.placements.single.exercise, 'Romanian Deadlift');
      expect(authoringService.placements.single.workout, 'Upper');
      expect(find.text('Upper exercises'), findsOneWidget);
      expect(find.text('Week 1'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('spreadsheet-selection-input')),
        findsNothing,
      );
      expect(find.text('Return to workout'), findsNothing);

      await tester.tap(find.byTooltip('Back to sheet selection'));
      await tester.pumpAndSettle();

      expect(find.text('My Drive / Workouts / 2026 Workouts'), findsOneWidget);
      expect(find.text('Return to workout'), findsOneWidget);
      expect(find.text('Change sheet'), findsOneWidget);
    },
  );

  testWidgets(
    'keeps exercise picker backup actions reachable on a narrow phone',
    (tester) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      const primaryExercise =
          'Very Long Bulgarian Split Squat Name For A Narrow Phone';
      const backupExercise =
          'Long Reverse Lunge Backup Option For Crowded Gym Days';
      final rows = [
        [...activeSheetFixedColumns, 'Week 1'],
        [...List.filled(activeSheetFixedColumns.length, ''), 'S1'],
        [primaryExercise, '3', '8', '8', '90s', '', '', '', 'Legs', '', ''],
        [backupExercise, '3', '8', '8', '90s', '', '', '', 'Legs', 'TRUE', ''],
      ];
      final service = TestSpreadsheetValidationService.fromRows(rows);
      final authoringService = _ReorderingWorkoutExerciseAuthoringService(rows);

      await tester.pumpWidget(
        WorkoutTrackerApp(
          validationService: service,
          exerciseAuthoringService: authoringService,
          initialSpreadsheetText: 'spreadsheet-id',
        ),
      );

      await tester.tap(find.byKey(const ValueKey('validate-spreadsheet')));
      await tester.pump();
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('select-workout-setup')));
      await tester.pumpAndSettle();

      expect(find.text('Legs - Week 1'), findsOneWidget);
      expect(find.text(primaryExercise), findsOneWidget);
      expect(find.text(backupExercise), findsOneWidget);
      expect(find.byTooltip('Add to workout'), findsOneWidget);
      expect(find.byTooltip('Add exercise'), findsNothing);
      expect(
        find.byTooltip('Open logging for $primaryExercise'),
        findsOneWidget,
      );
      expect(find.text('Open log'), findsOneWidget);
      expect(
        find.byTooltip('Backup actions for $primaryExercise'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel('Backup actions for $primaryExercise'),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel('Reorder $primaryExercise'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.byTooltip('Backup actions for $primaryExercise'));
      await tester.pumpAndSettle();

      expect(find.text('Add backup exercise'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('opens an exercise manager inventory in canonical sheet order', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final service = TestSpreadsheetValidationService(
      _exerciseInventoryParsedSheet([
        _exerciseRow('Squat', description: 'Back squat'),
        _exerciseRow('Bench Press', description: 'Competition bench'),
        _exerciseRow('Cable Row', description: 'Seated cable row'),
      ]),
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

    await tester.tap(find.byKey(const ValueKey('open-exercise-manager')));
    await tester.pumpAndSettle();

    expect(find.text('Edit exercises'), findsWidgets);
    expect(find.byTooltip('Back to workout setup'), findsOneWidget);
    expect(find.byTooltip('Create exercise'), findsOneWidget);
    expect(find.text('Squat'), findsOneWidget);
    expect(find.text('Back squat'), findsOneWidget);
    expect(find.byTooltip('Edit Squat'), findsOneWidget);
    expect(find.text('Bench Press'), findsOneWidget);
    expect(find.text('Competition bench'), findsOneWidget);
    expect(find.byTooltip('Edit Bench Press'), findsOneWidget);
    expect(find.text('Cable Row'), findsOneWidget);
    expect(find.text('Seated cable row'), findsOneWidget);
    expect(find.byTooltip('Edit Cable Row'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Squat')).dy,
      lessThan(tester.getTopLeft(find.text('Bench Press')).dy),
    );
    expect(
      tester.getTopLeft(find.text('Bench Press')).dy,
      lessThan(tester.getTopLeft(find.text('Cable Row')).dy),
    );
  });

  testWidgets('shows an empty state for an empty exercise library', (
    tester,
  ) async {
    final service = TestSpreadsheetValidationService(
      _emptyExerciseInventoryParsedSheet(),
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

    await tester.tap(find.byKey(const ValueKey('open-exercise-manager')));
    await tester.pumpAndSettle();

    expect(find.text('Edit exercises'), findsWidgets);
    expect(find.text('No exercises in this sheet.'), findsOneWidget);
    expect(find.text('Squat'), findsNothing);
  });

  testWidgets(
    'adds a canonical exercise from the exercise manager and returns to the updated list',
    (tester) async {
      final validationService = TestSpreadsheetValidationService(
        _exerciseInventoryParsedSheet([
          _exerciseRow('Squat', description: 'Back squat'),
        ]),
      );
      final authoringService = _AppendingExerciseAuthoringService([
        _exerciseRow('Squat', description: 'Back squat'),
      ]);

      await tester.pumpWidget(
        WorkoutTrackerApp(
          validationService: validationService,
          exerciseAuthoringService: authoringService,
          initialSpreadsheetText: 'spreadsheet-id',
        ),
      );

      await tester.tap(find.byKey(const ValueKey('validate-spreadsheet')));
      await tester.pump();
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('open-exercise-manager')));
      await tester.pumpAndSettle();

      expect(find.text('Squat'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('add-canonical-exercise')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const ValueKey('add-canonical-exercise')));
      await tester.pumpAndSettle();

      expect(find.text('New exercise'), findsWidgets);
      expect(find.byTooltip('Back to edit exercises'), findsOneWidget);

      await tester.enterText(
        find.byKey(const ValueKey('exercise-authoring-name')),
        'Romanian Deadlift',
      );
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -500));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const ValueKey('exercise-authoring-submit')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('exercise-authoring-submit')));
      await tester.pump();
      await tester.pump();

      expect(authoringService.createdExercises, [
        const CanonicalExerciseDefinition(
          exercise: 'Romanian Deadlift',
          defaultSets: '3',
          defaultReps: '10',
          defaultRpe: '8',
          defaultRest: '2 min',
          logFormat: '{Weight}[x]{Reps}[@]{RPE}',
        ),
      ]);
      expect(find.text('Edit exercises'), findsWidgets);
      expect(find.text('Squat'), findsOneWidget);
      expect(find.text('Romanian Deadlift'), findsOneWidget);
      expect(find.text('New exercise'), findsNothing);
    },
  );

  testWidgets('keeps a newly saved exercise visible in a long library', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final seededExercises = [
      for (var index = 1; index <= 24; index += 1)
        _exerciseRow(
          'Seeded Exercise ${index.toString().padLeft(2, '0')}',
          description: 'Seeded library item $index',
        ),
    ];
    final validationService = TestSpreadsheetValidationService(
      _exerciseInventoryParsedSheet(seededExercises),
    );
    final authoringService = _AppendingExerciseAuthoringService(
      seededExercises,
    );

    await tester.pumpWidget(
      WorkoutTrackerApp(
        validationService: validationService,
        exerciseAuthoringService: authoringService,
        initialSpreadsheetText: 'spreadsheet-id',
      ),
    );

    await tester.tap(find.byKey(const ValueKey('validate-spreadsheet')));
    await tester.pump();
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('open-exercise-manager')));
    await tester.pumpAndSettle();

    expect(find.text('Seeded Exercise 01'), findsOneWidget);
    expect(find.text('Custom Sled Push'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('add-canonical-exercise')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('exercise-authoring-name')),
      'Custom Sled Push',
    );
    await tester.ensureVisible(
      find.byKey(const ValueKey('exercise-authoring-submit')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('exercise-authoring-submit')));
    await tester.pumpAndSettle();

    expect(find.text('Edit exercises'), findsWidgets);
    expect(find.text('Custom Sled Push'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('saved-exercise-highlight')),
      findsOneWidget,
    );
    final highlightRect = tester.getRect(
      find.byKey(const ValueKey('saved-exercise-highlight')),
    );
    expect(highlightRect.top, greaterThanOrEqualTo(0));
    expect(highlightRect.bottom, lessThanOrEqualTo(844));
  });

  testWidgets('keeps an edited exercise visible in a long library', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final seededExercises = [
      for (var index = 1; index <= 24; index += 1)
        _exerciseRow(
          'Seeded Exercise ${index.toString().padLeft(2, '0')}',
          description: 'Seeded library item $index',
        ),
    ];
    final validationService = TestSpreadsheetValidationService(
      _exerciseInventoryParsedSheet(seededExercises),
    );
    final authoringService = _EditingExerciseAuthoringService(seededExercises);

    await tester.pumpWidget(
      WorkoutTrackerApp(
        validationService: validationService,
        exerciseAuthoringService: authoringService,
        initialSpreadsheetText: 'spreadsheet-id',
      ),
    );

    await tester.tap(find.byKey(const ValueKey('validate-spreadsheet')));
    await tester.pump();
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('open-exercise-manager')));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Seeded Exercise 24'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Seeded Exercise 24'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('exercise-authoring-name')),
      'Custom Rope Row',
    );
    await tester.ensureVisible(
      find.byKey(const ValueKey('exercise-authoring-submit')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('exercise-authoring-submit')));
    await tester.pumpAndSettle();

    expect(find.text('Edit exercises'), findsWidgets);
    expect(find.text('Custom Rope Row'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('saved-exercise-highlight')),
      findsOneWidget,
    );
    final highlightRect = tester.getRect(
      find.byKey(const ValueKey('saved-exercise-highlight')),
    );
    expect(highlightRect.top, greaterThanOrEqualTo(0));
    expect(highlightRect.bottom, lessThanOrEqualTo(844));
  });

  testWidgets(
    'canceling exercise manager add leaves the exercise library unchanged',
    (tester) async {
      final validationService = TestSpreadsheetValidationService(
        _exerciseInventoryParsedSheet([
          _exerciseRow('Squat', description: 'Back squat'),
        ]),
      );
      final authoringService = _AppendingExerciseAuthoringService([
        _exerciseRow('Squat', description: 'Back squat'),
      ]);

      await tester.pumpWidget(
        WorkoutTrackerApp(
          validationService: validationService,
          exerciseAuthoringService: authoringService,
          initialSpreadsheetText: 'spreadsheet-id',
        ),
      );

      await tester.tap(find.byKey(const ValueKey('validate-spreadsheet')));
      await tester.pump();
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('open-exercise-manager')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('add-canonical-exercise')));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey('exercise-authoring-name')),
        'Romanian Deadlift',
      );
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -500));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(authoringService.createdExercises, isEmpty);
      expect(find.text('Edit exercises'), findsWidgets);
      expect(find.text('Squat'), findsOneWidget);
      expect(find.text('Romanian Deadlift'), findsNothing);
      expect(find.text('New exercise'), findsNothing);
    },
  );

  testWidgets(
    'edits a canonical exercise from the exercise manager without creating a duplicate',
    (tester) async {
      final validationService = TestSpreadsheetValidationService(
        _exerciseInventoryParsedSheet([
          _exerciseRow('Squat', description: 'Back squat'),
          _exerciseRow('Bench Press', description: 'Competition bench'),
        ]),
      );
      final authoringService = _EditingExerciseAuthoringService([
        _exerciseRow('Squat', description: 'Back squat'),
        _exerciseRow('Bench Press', description: 'Competition bench'),
      ]);

      await tester.pumpWidget(
        WorkoutTrackerApp(
          validationService: validationService,
          exerciseAuthoringService: authoringService,
          initialSpreadsheetText: 'spreadsheet-id',
        ),
      );

      await tester.tap(find.byKey(const ValueKey('validate-spreadsheet')));
      await tester.pump();
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('open-exercise-manager')));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Squat'));
      await tester.pumpAndSettle();

      expect(find.text('Edit exercise'), findsWidgets);
      expect(find.byTooltip('Back to edit exercises'), findsOneWidget);
      expect(find.text('Squat'), findsOneWidget);
      expect(find.text('Back squat'), findsOneWidget);

      await tester.enterText(
        find.byKey(const ValueKey('exercise-authoring-name')),
        'High Bar Squat',
      );
      await tester.enterText(
        find.byKey(const ValueKey('exercise-authoring-description')),
        'High bar back squat',
      );
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -500));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const ValueKey('exercise-authoring-submit')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('exercise-authoring-submit')));
      await tester.pump();
      await tester.pump();

      expect(authoringService.createdExercises, isEmpty);
      expect(authoringService.updatedExercises, [
        (
          row: 2,
          exercise: const CanonicalExerciseDefinition(
            exercise: 'High Bar Squat',
            description: 'High bar back squat',
            defaultSets: '3',
            defaultReps: '10',
            defaultRpe: '8',
            defaultRest: '2 min',
            logFormat: '{Weight}[x]{Reps}[@]{RPE}',
          ),
        ),
      ]);
      expect(find.text('Edit exercises'), findsWidgets);
      expect(find.text('High Bar Squat'), findsOneWidget);
      expect(find.text('High bar back squat'), findsOneWidget);
      expect(find.text('Squat'), findsNothing);
      expect(find.text('Bench Press'), findsOneWidget);
      expect(authoringService.exerciseCount, 2);
    },
  );

  testWidgets('canceling exercise manager edit leaves the exercise unchanged', (
    tester,
  ) async {
    final validationService = TestSpreadsheetValidationService(
      _exerciseInventoryParsedSheet([
        _exerciseRow('Squat', description: 'Back squat'),
        _exerciseRow('Bench Press', description: 'Competition bench'),
      ]),
    );
    final authoringService = _EditingExerciseAuthoringService([
      _exerciseRow('Squat', description: 'Back squat'),
      _exerciseRow('Bench Press', description: 'Competition bench'),
    ]);

    await tester.pumpWidget(
      WorkoutTrackerApp(
        validationService: validationService,
        exerciseAuthoringService: authoringService,
        initialSpreadsheetText: 'spreadsheet-id',
      ),
    );

    await tester.tap(find.byKey(const ValueKey('validate-spreadsheet')));
    await tester.pump();
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('open-exercise-manager')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Squat'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('exercise-authoring-name')),
      'High Bar Squat',
    );
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -500));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(authoringService.updatedExercises, isEmpty);
    expect(authoringService.createdExercises, isEmpty);
    expect(find.text('Edit exercises'), findsWidgets);
    expect(find.text('Squat'), findsOneWidget);
    expect(find.text('Back squat'), findsOneWidget);
    expect(find.text('High Bar Squat'), findsNothing);
    expect(authoringService.exerciseCount, 2);
  });

  testWidgets('does not expose delete controls in the exercise manager', (
    tester,
  ) async {
    final service = TestSpreadsheetValidationService(
      _exerciseInventoryParsedSheet([
        _exerciseRow('Squat', description: 'Back squat'),
      ]),
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
    await tester.tap(find.byKey(const ValueKey('open-exercise-manager')));
    await tester.pumpAndSettle();

    expect(find.text('Squat'), findsOneWidget);
    expect(find.textContaining('delete', findRichText: true), findsNothing);
    expect(find.textContaining('Delete', findRichText: true), findsNothing);
    expect(find.byTooltip('Delete exercise'), findsNothing);
    expect(find.byIcon(Icons.delete_outline), findsNothing);
    expect(find.byType(Dismissible), findsNothing);
    expect(find.byType(PopupMenuButton), findsNothing);
  });

  testWidgets('reorders canonical exercises from the exercise manager', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final exercises = [
      _exerciseRow('Squat', description: 'Back squat'),
      _exerciseRow('Bench Press', description: 'Competition bench'),
      _exerciseRow('Cable Row', description: 'Seated cable row'),
    ];
    final validationService = TestSpreadsheetValidationService(
      _exerciseInventoryParsedSheet(exercises),
    );
    final authoringService = _ReorderingExerciseAuthoringService(exercises);

    await tester.pumpWidget(
      WorkoutTrackerApp(
        validationService: validationService,
        exerciseAuthoringService: authoringService,
        initialSpreadsheetText: 'spreadsheet-id',
      ),
    );

    await tester.tap(find.byKey(const ValueKey('validate-spreadsheet')));
    await tester.pump();
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('open-exercise-manager')));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Reorder Squat'), findsOneWidget);
    expect(find.byIcon(Icons.drag_handle_outlined), findsNWidgets(3));

    await tester.drag(find.byTooltip('Reorder Squat'), const Offset(0, 170));
    await tester.pumpAndSettle();

    expect(authoringService.reorderIntents, [
      const ReorderIntent(fromIndex: 0, toIndex: 2),
    ]);
    expect(
      tester.getTopLeft(find.text('Bench Press')).dy,
      lessThan(tester.getTopLeft(find.text('Cable Row')).dy),
    );
    expect(
      tester.getTopLeft(find.text('Cable Row')).dy,
      lessThan(tester.getTopLeft(find.text('Squat')).dy),
    );
  });

  testWidgets('reorders workout exercises from the workout list', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final rows = [
      [...activeSheetFixedColumns, 'Week 1'],
      [...List.filled(activeSheetFixedColumns.length, ''), 'S1'],
      [
        'Squat',
        '3',
        '5',
        '8',
        '3 min',
        '',
        '',
        defaultExerciseLogFormat,
        'Legs',
        '',
        '',
      ],
      [
        'Leg Press',
        '3',
        '12',
        '8',
        '2 min',
        '',
        '',
        '{Reps}[@]{RPE}',
        'Legs',
        'TRUE',
        '',
      ],
      [
        'Lunge',
        '2',
        '10',
        '7',
        '90s',
        '',
        '',
        defaultExerciseLogFormat,
        'Legs',
        '',
        '',
      ],
    ];
    final validationService = TestSpreadsheetValidationService.fromRows(rows);
    final authoringService = _ReorderingWorkoutExerciseAuthoringService(rows);

    await tester.pumpWidget(
      WorkoutTrackerApp(
        validationService: validationService,
        exerciseAuthoringService: authoringService,
        initialSpreadsheetText: 'spreadsheet-id',
      ),
    );

    await tester.tap(find.byKey(const ValueKey('validate-spreadsheet')));
    await tester.pump();
    await tester.pump();

    expect(find.byTooltip('Reorder Squat'), findsOneWidget);
    expect(find.byIcon(Icons.drag_handle_outlined), findsNWidgets(2));

    await tester.drag(find.byTooltip('Reorder Squat'), const Offset(0, 320));
    await tester.pumpAndSettle();

    expect(authoringService.reorderIntents, [
      const ReorderIntent(fromIndex: 0, toIndex: 1),
    ]);
    expect(
      tester.getTopLeft(find.text('Lunge')).dy,
      lessThan(tester.getTopLeft(find.text('Squat')).dy),
    );
    expect(find.text('1 backup'), findsOneWidget);
  });

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
    expect(_textFieldWithLabel('Raw set text'), findsOneWidget);
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
      final progress = find.text('Progress 1/3');
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

  testWidgets('keeps logging fields usable as numeric phone inputs', (
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
      expect(
        tester.widget<TextField>(field).keyboardType,
        TextInputType.number,
      );
    }

    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps logged structured set fields usable on a phone', (
    tester,
  ) async {
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
      expect(
        tester.widget<TextField>(field).keyboardType,
        TextInputType.number,
      );
    }
    expect(find.byTooltip('Save structured set'), findsOneWidget);
    expect(find.byTooltip('Clear set'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps workout setup controls usable across phone width', (
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

    expect(find.text('Workout'), findsOneWidget);
    expect(find.text('History block'), findsOneWidget);
    expect(find.text('Add workout'), findsNothing);
    expect(find.text('Add history'), findsNothing);
    expect(find.text('Edit exercises'), findsNothing);
    expect(find.byTooltip('Edit exercise library'), findsOneWidget);
    expect(find.byKey(const ValueKey('select-workout-setup')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'keeps empty workout setup selectors labeled through focus and creation',
    (tester) async {
      final service = TestSpreadsheetValidationService.fromRows([
        activeSheetFixedColumns,
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

      expect(find.text('Workout'), findsOneWidget);
      expect(find.text('History block'), findsOneWidget);
      expect(find.text('Add workout...'), findsOneWidget);
      expect(find.text('Add history block...'), findsOneWidget);
      final initialWorkoutLabelTopLeft = tester.getTopLeft(
        find.text('Workout'),
      );
      final initialHistoryLabelTopLeft = tester.getTopLeft(
        find.text('History block'),
      );
      final selectors = find.byType(DropdownButtonFormField<String>);

      await tester.tap(selectors.first);
      await tester.pumpAndSettle();

      expect(find.text('Add workout...'), findsWidgets);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(find.text('Workout'), findsOneWidget);
      expect(find.text('History block'), findsOneWidget);
      expect(find.text('Add workout...'), findsOneWidget);
      expect(find.text('Add history block...'), findsOneWidget);
      expect(
        (tester.getTopLeft(find.text('Workout')) - initialWorkoutLabelTopLeft)
            .distance,
        lessThan(1),
      );
      expect(
        (tester.getTopLeft(find.text('History block')) -
                initialHistoryLabelTopLeft)
            .distance,
        lessThan(1),
      );

      await tester.tap(selectors.first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add workout...').last);
      await tester.pumpAndSettle();
      await tester.enterText(_textFieldWithLabel('Workout name'), 'Push');
      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();

      expect(find.text('Push (0/0 done)'), findsOneWidget);
      expect(find.text('Add workout...'), findsNothing);
      expect(find.text('Add history block...'), findsOneWidget);

      await tester.tap(selectors.last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add history block...').last);
      await tester.pumpAndSettle();
      await tester.enterText(
        _textFieldWithLabel('History block label'),
        'Week 1',
      );
      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();

      expect(service.appliedPlans, hasLength(1));
      expect(find.text('Push (0/0 done)'), findsOneWidget);
      expect(find.text('Week 1'), findsOneWidget);
      expect(find.text('Add history block...'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'shows setup creation actions in selectors and selects created values',
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

      expect(find.byKey(const ValueKey('add-workout')), findsNothing);
      expect(find.byKey(const ValueKey('add-history-block')), findsNothing);

      await tester.tap(find.text('Legs (0/1 done)').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add workout...').last);
      await tester.pumpAndSettle();

      await tester.enterText(_textFieldWithLabel('Workout name'), 'Push');
      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();

      expect(find.text('Push (0/0 done)'), findsOneWidget);

      await tester.tap(find.text('Week 1').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add history block...').last);
      await tester.pumpAndSettle();

      await tester.enterText(
        _textFieldWithLabel('History block label'),
        'Week 2',
      );
      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();

      expect(service.appliedPlans, hasLength(1));
      final historyField = find.byType(DropdownButtonFormField<String>).last;
      expect(
        tester.state<FormFieldState<String>>(historyField).value,
        'Week 2',
      );
    },
  );

  testWidgets(
    'name prompts opened from selectors keep focus and dismiss cleanly',
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

      await tester.tap(find.text('Legs (0/1 done)').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add workout...').last);
      await tester.pumpAndSettle();

      expect(find.text('Add workout'), findsOneWidget);
      final workoutNameField = _textFieldWithLabel('Workout name');
      expect(
        _editableTextFor(workoutNameField).focusNode.hasPrimaryFocus,
        isTrue,
      );

      tester.testTextInput.enterText('Push');
      await tester.pump();
      expect(find.text('Push'), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(find.text('Add workout'), findsNothing);
      expect(find.text('Legs (0/1 done)'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('select-workout-setup')),
        findsOneWidget,
      );

      await tester.tap(find.text('Legs (0/1 done)').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add workout...').last);
      await tester.pumpAndSettle();
      expect(
        _editableTextFor(
          _textFieldWithLabel('Workout name'),
        ).focusNode.hasPrimaryFocus,
        isTrue,
      );

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('Add workout'), findsNothing);
      expect(find.text('Legs (0/1 done)'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('select-workout-setup')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
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

    expect(find.text('Add to workout'), findsWidgets);
    expect(find.text('Add exercise'), findsNothing);

    await tester.ensureVisible(
      find.byKey(const ValueKey('place-existing-exercise')),
    );
    await tester.tap(find.byKey(const ValueKey('place-existing-exercise')));
    await tester.pump();

    expect(_textFieldWithLabel('Sets'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('existing-exercise-selector')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dip').last);
    await tester.pumpAndSettle();

    expect(_textFieldWithLabel('Sets'), findsOneWidget);
    expect(_textFieldWithLabel('Reps'), findsOneWidget);
    expect(_textFieldWithLabel('RPE'), findsOneWidget);

    await tester.ensureVisible(
      find.byKey(const ValueKey('place-existing-exercise')),
    );
    expect(find.text('Add to workout'), findsWidgets);
    expect(find.text('Add exercise'), findsNothing);
  });

  testWidgets('does not choose an exercise from an unopened picker on Return', (
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
            'Bulgarian Split Squat',
            'Rear-foot elevated split squat',
            '3',
            '10',
            '8',
            '2 min',
            '',
            '',
            '{Weight}[x]{Reps}[@]{RPE}',
          ],
          [
            'Dip',
            'Parallel bar dip',
            '3',
            '10',
            '8',
            '2 min',
            '',
            '',
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

    final selector = find.byKey(const ValueKey('exercise-picker-search'));
    await tester.tap(selector);
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(_textFieldWithLabel('Sets'), findsNothing);
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const ValueKey('place-existing-exercise')),
          )
          .onPressed,
      isNull,
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(_textFieldWithLabel('Sets'), findsNothing);
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const ValueKey('place-existing-exercise')),
          )
          .onPressed,
      isNull,
    );
  });

  testWidgets('adds another workout exercise without leaving placement', (
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
            'Bench Press',
            'Competition bench',
            '4',
            '6',
            '8',
            '3 min',
            '',
            '',
            '{Weight}[x]{Reps}[@]{RPE}',
          ],
          [
            'Romanian Deadlift',
            'Hip hinge',
            '3',
            '10',
            '7',
            '2 min',
            '',
            '',
            '{Weight}[x]{Reps}[@]{RPE}',
          ],
        ],
      ),
    );
    final service = TestSpreadsheetValidationService(activeSheet);
    final authoringService = _WorkoutPlacementRecordingService(activeSheet);

    await tester.pumpWidget(
      WorkoutTrackerApp(
        validationService: service,
        exerciseAuthoringService: authoringService,
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
    await tester.tap(find.text('Bench Press').last);
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('place-existing-exercise-add-another')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Add to workout'), findsWidgets);
    expect(
      find.byKey(const ValueKey('existing-exercise-selector')),
      findsOneWidget,
    );
    expect(_textFieldWithLabel('Sets'), findsNothing);

    await tester.enterText(
      find.byKey(const ValueKey('exercise-picker-search')),
      'romanian',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('existing-exercise-selector')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Romanian Deadlift').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('place-existing-exercise')));
    await tester.pumpAndSettle();

    expect(authoringService.placements.map((placement) => placement.exercise), [
      'Bench Press',
      'Romanian Deadlift',
    ]);
    expect(authoringService.placements.map((placement) => placement.workout), [
      'Legs',
      'Legs',
    ]);
    expect(find.text('Legs exercises'), findsOneWidget);
  });

  testWidgets('filters the workout exercise picker before placement', (
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
            'Bench Press',
            'Competition bench',
            '4',
            '6',
            '8',
            '3 min',
            '',
            '',
            '{Weight}[x]{Reps}[@]{RPE}',
          ],
          [
            'Romanian Deadlift',
            'Hip hinge',
            '3',
            '10',
            '7',
            '2 min',
            '',
            '',
            '{Weight}[x]{Reps}[@]{RPE}',
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

    await tester.enterText(
      find.byKey(const ValueKey('exercise-picker-search')),
      'romanian',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('existing-exercise-selector')));
    await tester.pumpAndSettle();

    expect(find.text('Romanian Deadlift'), findsOneWidget);
    expect(find.text('Bench Press'), findsNothing);

    await tester.tap(find.text('Romanian Deadlift').last);
    await tester.pumpAndSettle();

    expect(_textFieldWithLabel('Sets'), findsOneWidget);
    expect(_textFieldWithLabel('Reps'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('10'), findsOneWidget);
  });

  testWidgets('keeps workout placement fields usable on a phone', (
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

  testWidgets(
    'keeps exercise authoring fields and submit action usable on a phone',
    (tester) async {
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
      await tester.tap(find.byKey(const ValueKey('open-exercise-manager')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('add-canonical-exercise')));
      await tester.pumpAndSettle();

      for (final key in const [
        ValueKey('exercise-authoring-default-sets'),
        ValueKey('exercise-authoring-default-reps'),
        ValueKey('exercise-authoring-default-rpe'),
      ]) {
        expect(find.byKey(key), findsOneWidget);
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
                of: find.byKey(
                  const ValueKey('exercise-authoring-default-reps'),
                ),
                matching: find.byType(EditableText),
              ),
            )
            .keyboardType,
        isNot(TextInputType.number),
      );

      await tester.drag(find.byType(Scrollable).first, const Offset(0, -500));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('exercise-authoring-submit')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'selects default exercise authoring field text on focus for replacement',
    (tester) async {
      final validationService = TestSpreadsheetValidationService(
        _exerciseInventoryParsedSheet([
          _exerciseRow('Squat', description: 'Back squat'),
        ]),
      );

      await tester.pumpWidget(
        WorkoutTrackerApp(
          validationService: validationService,
          initialSpreadsheetText: 'spreadsheet-id',
        ),
      );

      await tester.tap(find.byKey(const ValueKey('validate-spreadsheet')));
      await tester.pump();
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('open-exercise-manager')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('add-canonical-exercise')));
      await tester.pumpAndSettle();

      final defaultReps = find.byKey(
        const ValueKey('exercise-authoring-default-reps'),
      );
      await tester.tap(defaultReps);
      await tester.pump();

      final editableText = tester.widget<EditableText>(
        find.descendant(of: defaultReps, matching: find.byType(EditableText)),
      );
      expect(editableText.controller.selection.textInside('10'), '10');

      tester.testTextInput.enterText('12');
      await tester.pump();

      expect(editableText.controller.text, '12');
    },
  );

  testWidgets(
    'keeps exercise authoring text entry tied to each labeled field',
    (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        final validationService = TestSpreadsheetValidationService(
          _exerciseInventoryParsedSheet([
            _exerciseRow('Squat', description: 'Back squat'),
          ]),
        );
        final authoringService = _AppendingExerciseAuthoringService([
          _exerciseRow('Squat', description: 'Back squat'),
        ]);

        await tester.pumpWidget(
          WorkoutTrackerApp(
            validationService: validationService,
            exerciseAuthoringService: authoringService,
            initialSpreadsheetText: 'spreadsheet-id',
          ),
        );

        await tester.tap(find.byKey(const ValueKey('validate-spreadsheet')));
        await tester.pump();
        await tester.pump();
        await tester.tap(find.byKey(const ValueKey('open-exercise-manager')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('add-canonical-exercise')));
        await tester.pumpAndSettle();

        for (final identifier in const [
          'exercise-authoring-name',
          'exercise-authoring-description',
          'exercise-authoring-default-sets',
          'exercise-authoring-default-reps',
          'exercise-authoring-default-rpe',
          'exercise-authoring-default-rest',
          'exercise-authoring-default-tempo',
          'exercise-authoring-log-format',
          'exercise-authoring-notes',
        ]) {
          expect(find.bySemanticsIdentifier(identifier), findsOneWidget);
        }

        Future<void> enterField(String label, String value) async {
          final field = _textFieldWithLabel(label);
          await tester.ensureVisible(field);
          await tester.pumpAndSettle();
          await tester.enterText(field, value);
          await tester.pump();
          expect(
            tester
                .widget<EditableText>(
                  find.descendant(
                    of: field,
                    matching: find.byType(EditableText),
                  ),
                )
                .controller
                .text,
            value,
          );
        }

        await enterField('Exercise name', 'Romanian Deadlift');
        await enterField('Description', 'Hip hinge');
        await enterField('Default sets', '4');
        await enterField('Default reps', '8-10');
        await enterField('Default RPE', '7.5');
        await enterField('Default rest', '90s');
        await enterField('Default tempo', '3-1-1');
        await enterField('Log format', '{Weight}[x]{Reps}');
        await enterField('Notes', 'Use straps after warmups.');

        await tester.ensureVisible(
          find.byKey(const ValueKey('exercise-authoring-submit')),
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const ValueKey('exercise-authoring-submit')),
        );
        await tester.pump();
        await tester.pump();

        expect(authoringService.createdExercises, [
          const CanonicalExerciseDefinition(
            exercise: 'Romanian Deadlift',
            description: 'Hip hinge',
            defaultSets: '4',
            defaultReps: '8-10',
            defaultRpe: '7.5',
            defaultRest: '90s',
            defaultTempo: '3-1-1',
            notes: 'Use straps after warmups.',
            logFormat: '{Weight}[x]{Reps}',
          ),
        ]);
      } finally {
        semantics.dispose();
      }
    },
  );

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

    expect(find.text('Progress 1/3'), findsOneWidget);
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

      await tester.tap(find.text('Front Plank'));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('set-field-Seconds')), findsOneWidget);
      expect(find.byKey(const ValueKey('set-field-RPE')), findsOneWidget);
      expect(find.byKey(const ValueKey('set-field-Reps')), findsNothing);

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

  testWidgets('shows a top-right Google Sheets authorization menu', (
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

    await tester.tap(
      find.byTooltip('Google Sheets account: wrong@example.com'),
    );
    await tester.pumpAndSettle();

    expect(find.text('Wrong Account'), findsOneWidget);
    expect(find.text('wrong@example.com'), findsOneWidget);

    await tester.tap(find.text('Switch Google Sheets account'));
    await tester.pumpAndSettle();

    expect(accountSession.switchCount, 1);
    expect(
      accountSession.requestedScopes.single,
      GoogleApisSheetsWriteClient.writeScopes,
    );
    expect(accountSession.currentAccount?.email, 'right@example.com');
  });

  testWidgets('logs out from the Google Sheets account menu', (tester) async {
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
        initialSpreadsheetText: 'spreadsheet-id',
      ),
    );

    await tester.tap(
      find.byTooltip('Google Sheets account: saved@example.com'),
    );
    await tester.pumpAndSettle();

    expect(find.text('Log out'), findsOneWidget);

    await tester.tap(find.text('Log out'));
    await tester.pumpAndSettle();

    expect(accountSession.signOutCount, 1);
    expect(accountSession.currentAccount, isNull);
    expect(find.byTooltip('Connect Google Sheets'), findsOneWidget);
  });

  testWidgets('logging out disconnects the selected workout sheet', (
    tester,
  ) async {
    final store =
        _MemoryAppStateStore(
            null,
            selectedSpreadsheet: const SelectedSpreadsheet(
              spreadsheetId: 'selected-spreadsheet-id',
              name: 'development',
              accountEmail: 'saved@example.com',
            ),
          )
          ..workoutSelection = const WorkoutSelectionState(
            spreadsheetId: 'selected-spreadsheet-id',
            workout: 'Legs',
            historyBlock: 'Week 1',
          );
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
        appStateStore: store,
        spreadsheetPicker: _FakeSpreadsheetPicker(),
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
    expect(store.selectedSpreadsheet, isNull);
    expect(store.spreadsheetText, isNull);
    expect(store.workoutSelection, isNull);
    expect(find.text('development'), findsNothing);
    expect(find.text('Return to workout'), findsNothing);
    expect(find.text('No workout sheet selected'), findsOneWidget);
  });

  testWidgets('frames missing account state as Google Sheets authorization', (
    tester,
  ) async {
    final service = TestSpreadsheetValidationService.fromRows([
      [...activeSheetFixedColumns, 'Week 1'],
      [...List.filled(activeSheetFixedColumns.length, ''), 'S1'],
      ['Squat', '3', '5', '8', '3 min', '', '', '', 'Legs', '', ''],
    ]);
    final accountSession = _FakeGoogleAccountSession(null);

    await tester.pumpWidget(
      WorkoutTrackerApp(
        validationService: service,
        accountSession: accountSession,
        initialSpreadsheetText: 'spreadsheet-id',
      ),
    );

    await tester.tap(find.byTooltip('Connect Google Sheets'));
    await tester.pumpAndSettle();

    expect(find.text('No Google Sheets account connected'), findsOneWidget);

    await tester.tap(find.text('Connect Google Sheets'));
    await tester.pumpAndSettle();

    expect(accountSession.switchCount, 1);
    expect(
      accountSession.requestedScopes.single,
      GoogleApisSheetsWriteClient.writeScopes,
    );
    expect(accountSession.currentAccount?.email, 'right@example.com');
  });

  testWidgets('shows the Google Sheets account menu in picker mode', (
    tester,
  ) async {
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

class _FakeGoogleAccountSession extends ChangeNotifier
    implements GoogleAccountSession {
  _FakeGoogleAccountSession(this._currentAccount, {this.restoredAccount});

  GoogleAccountProfile? _currentAccount;
  final GoogleAccountProfile? restoredAccount;
  int restoreCount = 0;
  int switchCount = 0;
  int signOutCount = 0;
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

  @override
  Future<void> signOut() async {
    signOutCount += 1;
    _currentAccount = null;
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

EditableText _editableTextFor(Finder textField) {
  return find
          .descendant(of: textField, matching: find.byType(EditableText))
          .evaluate()
          .single
          .widget
      as EditableText;
}

class _MemoryAppStateStore implements AppStateStore {
  _MemoryAppStateStore(this.spreadsheetText, {this.selectedSpreadsheet});

  String? spreadsheetText;
  SelectedSpreadsheet? selectedSpreadsheet;
  WorkoutSelectionState? workoutSelection;
  final accessStateWrites = <GoogleWorkspaceAccessState>[];
  int clearCount = 0;

  @override
  Future<GoogleWorkspaceAccessState> readGoogleWorkspaceAccessState() async {
    return GoogleWorkspaceAccessState(
      spreadsheetText: spreadsheetText,
      selectedSpreadsheet: selectedSpreadsheet,
      workoutSelection: workoutSelection,
    );
  }

  @override
  Future<void> writeGoogleWorkspaceAccessState(
    GoogleWorkspaceAccessState value,
  ) async {
    spreadsheetText = value.spreadsheetText;
    selectedSpreadsheet = value.selectedSpreadsheet;
    workoutSelection = value.workoutSelection;
    accessStateWrites.add(value);
  }

  @override
  Future<void> clearGoogleWorkspaceAccessState() async {
    clearCount += 1;
    spreadsheetText = null;
    selectedSpreadsheet = null;
    workoutSelection = null;
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
  Future<SelectedSpreadsheet?> createSpreadsheet({String? name}) async {
    return null;
  }
}

class _CompletingSpreadsheetPicker implements SpreadsheetPicker {
  final chooseCompleter = Completer<SelectedSpreadsheet?>();
  final createCompleter = Completer<SelectedSpreadsheet?>();
  int chooseCount = 0;
  int createCount = 0;
  final createNames = <String?>[];

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
  Future<SelectedSpreadsheet?> createSpreadsheet({String? name}) {
    createCount += 1;
    createNames.add(name);
    return createCompleter.future;
  }
}

class _AppendingExerciseAuthoringService implements ExerciseAuthoringService {
  _AppendingExerciseAuthoringService(List<List<String>> exercises)
    : _exercises = exercises.map((row) => row.toList()).toList();

  final List<List<String>> _exercises;
  final createdExercises = <CanonicalExerciseDefinition>[];

  @override
  Future<SpreadsheetValidationReport> createCanonicalExercise({
    required String spreadsheetId,
    required ParsedActiveSheet activeSheet,
    required CanonicalExerciseDefinition exercise,
  }) async {
    createdExercises.add(exercise);
    _exercises.add([
      exercise.exercise,
      exercise.description,
      exercise.defaultSets,
      exercise.defaultReps,
      exercise.defaultRpe,
      exercise.defaultRest,
      exercise.defaultTempo,
      exercise.notes,
      exercise.resolvedLogFormat,
    ]);
    return SpreadsheetValidationReport(
      spreadsheetId: spreadsheetId,
      activeSheet: _exerciseInventoryParsedSheet(_exercises),
    );
  }

  @override
  Future<SpreadsheetValidationReport> updateCanonicalExercise({
    required String spreadsheetId,
    required ParsedActiveSheet activeSheet,
    required CanonicalExercise selectedExercise,
    required CanonicalExerciseDefinition exercise,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<SpreadsheetValidationReport> addExistingExerciseToWorkout({
    required String spreadsheetId,
    required ParsedActiveSheet activeSheet,
    required CanonicalExercise exercise,
    required WorkoutPlacementMetadata metadata,
    required ExercisePlacementTarget placement,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<SpreadsheetValidationReport> reorderCanonicalExercises({
    required String spreadsheetId,
    required ParsedActiveSheet activeSheet,
    required ReorderIntent intent,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<SpreadsheetValidationReport> reorderWorkoutExercises({
    required String spreadsheetId,
    required ParsedActiveSheet activeSheet,
    required String workout,
    required ReorderIntent intent,
  }) {
    throw UnimplementedError();
  }
}

class _EditingExerciseAuthoringService
    extends _AppendingExerciseAuthoringService {
  _EditingExerciseAuthoringService(super.exercises);

  final updatedExercises =
      <({int row, CanonicalExerciseDefinition exercise})>[];

  int get exerciseCount => _exercises.length;

  @override
  Future<SpreadsheetValidationReport> updateCanonicalExercise({
    required String spreadsheetId,
    required ParsedActiveSheet activeSheet,
    required CanonicalExercise selectedExercise,
    required CanonicalExerciseDefinition exercise,
  }) async {
    updatedExercises.add((
      row: selectedExercise.sheetRowNumber,
      exercise: exercise,
    ));
    _exercises[selectedExercise.sheetRowNumber - 2] = [
      exercise.exercise,
      exercise.description,
      exercise.defaultSets,
      exercise.defaultReps,
      exercise.defaultRpe,
      exercise.defaultRest,
      exercise.defaultTempo,
      exercise.notes,
      exercise.resolvedLogFormat,
    ];
    return SpreadsheetValidationReport(
      spreadsheetId: spreadsheetId,
      activeSheet: _exerciseInventoryParsedSheet(_exercises),
    );
  }
}

class _WorkoutPlacementRecordingService
    extends _AppendingExerciseAuthoringService {
  _WorkoutPlacementRecordingService(this._activeSheet) : super(const []);

  ParsedActiveSheet _activeSheet;
  final placements = <({String exercise, String? workout, bool isBackup})>[];

  @override
  Future<SpreadsheetValidationReport> addExistingExerciseToWorkout({
    required String spreadsheetId,
    required ParsedActiveSheet activeSheet,
    required CanonicalExercise exercise,
    required WorkoutPlacementMetadata metadata,
    required ExercisePlacementTarget placement,
  }) async {
    placements.add((
      exercise: exercise.displayName,
      workout: placement.workout,
      isBackup: placement.isBackup,
    ));
    return SpreadsheetValidationReport(
      spreadsheetId: spreadsheetId,
      activeSheet: _activeSheet,
    );
  }
}

class _ReorderingExerciseAuthoringService
    extends _AppendingExerciseAuthoringService {
  _ReorderingExerciseAuthoringService(super.exercises);

  final reorderIntents = <ReorderIntent>[];

  @override
  Future<SpreadsheetValidationReport> reorderCanonicalExercises({
    required String spreadsheetId,
    required ParsedActiveSheet activeSheet,
    required ReorderIntent intent,
  }) async {
    reorderIntents.add(intent);
    final plan = activeSheet.planCanonicalExerciseReorder(intent);
    final previewRows = plan.previewRowsAfterApplying([
      exercisesSheetColumns,
      ..._exercises,
    ]);
    _exercises
      ..clear()
      ..addAll(previewRows.skip(1).map((row) => row.toList()));
    return SpreadsheetValidationReport(
      spreadsheetId: spreadsheetId,
      activeSheet: _exerciseInventoryParsedSheet(
        _exercises,
        cellFormulas: plan.activeSheetFormulaUpdates
            .map(
              (update) => CellFormula(
                sheetRowNumber: update.sheetRowNumber,
                sheetColumnNumber: update.sheetColumnNumber,
                formula: update.value,
              ),
            )
            .toList(),
      ),
    );
  }

  @override
  Future<SpreadsheetValidationReport> reorderWorkoutExercises({
    required String spreadsheetId,
    required ParsedActiveSheet activeSheet,
    required String workout,
    required ReorderIntent intent,
  }) {
    throw UnimplementedError();
  }
}

class _ReorderingWorkoutExerciseAuthoringService
    extends _AppendingExerciseAuthoringService {
  _ReorderingWorkoutExerciseAuthoringService(List<List<String>> rows)
    : _rows = rows.map((row) => row.toList()).toList(),
      super(const []);

  final List<List<String>> _rows;
  final reorderIntents = <ReorderIntent>[];

  @override
  Future<SpreadsheetValidationReport> reorderWorkoutExercises({
    required String spreadsheetId,
    required ParsedActiveSheet activeSheet,
    required String workout,
    required ReorderIntent intent,
  }) async {
    reorderIntents.add(intent);
    final plan = activeSheet.planWorkoutExerciseReorder(
      workout: workout,
      intent: intent,
    );
    final previewRows = plan.previewRowsAfterApplying(_rows);
    _rows
      ..clear()
      ..addAll(previewRows.map((row) => row.toList()));
    return SpreadsheetValidationReport(
      spreadsheetId: spreadsheetId,
      activeSheet: parseActiveSheet(ActiveSheetInput(rows: _rows)),
    );
  }
}

class _CountingSpreadsheetPicker implements SpreadsheetPicker {
  int chooseCount = 0;
  int createCount = 0;
  final createNames = <String?>[];

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
  Future<SelectedSpreadsheet?> createSpreadsheet({String? name}) async {
    createCount += 1;
    createNames.add(name);
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

ParsedActiveSheet _loggedSetParsedSheet() {
  return parseActiveSheet(
    ActiveSheetInput(
      rows: [
        [...activeSheetFixedColumns, 'Week 1'],
        [...List.filled(activeSheetFixedColumns.length, ''), 'S1'],
        ['Squat', '3', '5', '8', '3 min', '', '', '', 'Legs', '', '150x5@8'],
      ],
    ),
  );
}

ParsedActiveSheet _twoSetLoggingSheet({required String s2Value}) {
  return parseActiveSheet(
    ActiveSheetInput(
      rows: [
        [...activeSheetFixedColumns, 'Week 1', ''],
        [...List.filled(activeSheetFixedColumns.length, ''), 'S1', 'S2'],
        [
          'Squat',
          '3',
          '5',
          '8',
          '3 min',
          '',
          '',
          '',
          'Legs',
          '',
          '150x5@8',
          s2Value,
        ],
      ],
    ),
  );
}

ParsedActiveSheet _exerciseInventoryParsedSheet(
  List<List<String>> exercises, {
  Iterable<CellFormula> cellFormulas = const [
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
}) {
  return parseActiveSheet(
    ActiveSheetInput(
      rows: [
        [...activeSheetFixedColumns, 'Week 1'],
        [...List.filled(activeSheetFixedColumns.length, ''), 'S1'],
        ['Squat', '3', '5', '8', '3 min', '', '', '', 'Legs', '', ''],
      ],
      cellFormulas: cellFormulas,
      exercisesRows: [exercisesSheetColumns, ...exercises],
    ),
  );
}

ParsedActiveSheet _emptyExerciseInventoryParsedSheet() {
  return parseActiveSheet(
    ActiveSheetInput(
      rows: [
        [...activeSheetFixedColumns, 'Week 1'],
        [...List.filled(activeSheetFixedColumns.length, ''), 'S1'],
      ],
      exercisesRows: const [exercisesSheetColumns],
    ),
  );
}

List<String> _exerciseRow(
  String name, {
  String description = '',
  String defaultSets = '3',
  String defaultReps = '10',
  String defaultRpe = '8',
  String defaultRest = '2 min',
  String defaultTempo = '',
  String notes = '',
  String logFormat = '{Weight}[x]{Reps}[@]{RPE}',
}) {
  return [
    name,
    description,
    defaultSets,
    defaultReps,
    defaultRpe,
    defaultRest,
    defaultTempo,
    notes,
    logFormat,
  ];
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

class _FailingWriteValidationService implements SpreadsheetValidationService {
  _FailingWriteValidationService(this.validSheet);

  final ParsedActiveSheet validSheet;
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
    throw StateError('network unavailable');
  }
}

class _RecoverableConfirmationFailureService
    implements SpreadsheetValidationService {
  _RecoverableConfirmationFailureService()
    : initialSheet = _twoSetLoggingSheet(s2Value: ''),
      conflictingSheet = _twoSetLoggingSheet(s2Value: '95x10@7'),
      savedSheet = _twoSetLoggingSheet(s2Value: '155x6@8');

  final ParsedActiveSheet initialSheet;
  final ParsedActiveSheet conflictingSheet;
  final ParsedActiveSheet savedSheet;
  final appliedPlans = <ActiveSheetWritePlan>[];

  @override
  Future<SpreadsheetValidationReport> validateSpreadsheet(
    String spreadsheetId,
  ) async {
    final activeSheet = switch (appliedPlans.length) {
      0 => initialSheet,
      1 => conflictingSheet,
      _ => savedSheet,
    };
    return SpreadsheetValidationReport(
      spreadsheetId: spreadsheetId,
      activeSheet: activeSheet,
    );
  }

  @override
  Future<SpreadsheetValidationReport> applyActiveSheetWritePlan({
    required String spreadsheetId,
    required ParsedActiveSheet activeSheet,
    required ActiveSheetWritePlan plan,
  }) async {
    appliedPlans.add(plan);
    final activeSheet = appliedPlans.length == 1
        ? conflictingSheet
        : savedSheet;
    return SpreadsheetValidationReport(
      spreadsheetId: spreadsheetId,
      activeSheet: activeSheet,
    );
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
