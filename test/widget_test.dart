import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_tracker/sheet_contract.dart';
import 'package:workout_tracker/workout_tracker_app.dart';

import 'app/test_spreadsheet_validation_service.dart';
import 'fixtures/workout_sheet_fixtures.dart';

import 'support/widget_test_support.dart';

void main() {
  testWidgets('meets Flutter accessibility guidelines across core GUI states', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final service = TestSpreadsheetValidationService.fromRows([
      [...activeSheetFixedColumns, 'Week 1', ''],
      [...List.filled(activeSheetFixedColumns.length, ''), 'S1', 'S2'],
      [
        'Squat',
        '3',
        '5',
        '8',
        '3 min',
        '',
        'Stay braced.',
        '',
        'Legs',
        '',
        '150x5@8',
        '',
      ],
      [
        'Leg Press',
        '3',
        '10',
        '8',
        '2 min',
        '',
        'Backup if racks are busy.',
        '',
        'Legs',
        'TRUE',
        '',
        '',
      ],
    ]);

    await tester.pumpWidget(
      WorkoutTrackerApp(svc: service, initialText: 'spreadsheet-id'),
    );
    await expectFlutterAccessibilityGuidelines(tester);

    await tester.tap(find.byKey(const ValueKey('validate-spreadsheet')));
    await tester.pump();
    await tester.pump();
    await expectFlutterAccessibilityGuidelines(tester);

    await tester.tap(find.byKey(const ValueKey('select-workout-setup')));
    await tester.pumpAndSettle();
    await expectFlutterAccessibilityGuidelines(tester);

    await tester.tap(find.text('Squat').first);
    await tester.pumpAndSettle();
    await expectFlutterAccessibilityGuidelines(tester);

    await tester.tap(find.byTooltip('Back to exercises'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Back to workout setup'));
    await tester.pumpAndSettle();

    final inventoryService = TestSpreadsheetValidationService(
      exerciseInventoryParsedSheet([
        exerciseRow('Squat', description: 'Back squat'),
        exerciseRow('Leg Press', description: 'Machine press'),
        exerciseRow('Cable Row', description: 'Seated row'),
      ]),
    );
    await tester.pumpWidget(
      WorkoutTrackerApp(
        key: const ValueKey('inventory-accessibility-app'),
        svc: inventoryService,
        initialText: 'spreadsheet-id',
      ),
    );
    await tester.tap(find.byKey(const ValueKey('validate-spreadsheet')));
    await tester.pump();
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('open-exercise-manager')));
    await tester.pumpAndSettle();
    await expectFlutterAccessibilityGuidelines(tester);

    await tester.tap(find.byKey(const ValueKey('add-canonical-exercise')));
    await tester.pumpAndSettle();
    await expectFlutterAccessibilityGuidelines(tester);
  });

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
      WorkoutTrackerApp(svc: service, initialText: 'spreadsheet-id'),
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
    final service = CompletingWriteValidationService(minimalValidParsedSheet());

    await tester.pumpWidget(
      WorkoutTrackerApp(svc: service, initialText: 'spreadsheet-id'),
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
    final service = CompletingWriteValidationService(loggedSetParsedSheet());

    await tester.pumpWidget(
      WorkoutTrackerApp(svc: service, initialText: 'spreadsheet-id'),
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
    final service = CompletingWriteValidationService(loggedSetParsedSheet());

    await tester.pumpWidget(
      WorkoutTrackerApp(svc: service, initialText: 'spreadsheet-id'),
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
    final service = FailingWriteValidationService(minimalValidParsedSheet());

    await tester.pumpWidget(
      WorkoutTrackerApp(svc: service, initialText: 'spreadsheet-id'),
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
      final service = RecoverableConfirmationFailureService();

      await tester.pumpWidget(
        WorkoutTrackerApp(svc: service, initialText: 'spreadsheet-id'),
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
      WorkoutTrackerApp(svc: service, initialText: 'spreadsheet-id'),
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
        parseWorkbookFixture(entry.fixture),
      );

      await tester.pumpWidget(
        WorkoutTrackerApp(
          key: ValueKey(entry.key),
          svc: service,
          initialText: 'spreadsheet-id',
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
      final service = FormulaRepairValidationService(
        initialSheet: parseWorkbookFixture(
          loadNoExactMatchFormulaRepairDamageFixture(),
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
    final service = FormulaRepairValidationService(
      initialSheet: parseWorkbookFixture(loadFormulaDamageFixture()),
      repairedSheet: repairedFormulaDamageFixtureSheetWithBackupViolation(),
    );

    await tester.pumpWidget(
      WorkoutTrackerApp(svc: service, initialText: 'spreadsheet-id'),
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
      final opener = RecordingSpreadsheetOpener();
      final service = RevalidatingSpreadsheetValidationService(
        reports: [
          parseWorkbookFixture(entry.fixture),
          minimalValidParsedSheet(),
        ],
      );

      await tester.pumpWidget(
        WorkoutTrackerApp(
          key: ValueKey(entry.expectedText),
          svc: service,
          spreadsheetOpener: opener,
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
      parseWorkbookFixture(loadMalformedHistoryDamageFixture()),
    );

    await tester.pumpWidget(
      WorkoutTrackerApp(svc: service, initialText: 'spreadsheet-id'),
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
      final damagedSheet = parseWorkbookFixture(
        loadBackupGroupingDamageFixture(),
      );
      final service = DamageAfterSaveValidationService(
        validSheet: validSheet,
        damagedSheet: damagedSheet,
      );

      await tester.pumpWidget(
        WorkoutTrackerApp(svc: service, initialText: 'spreadsheet-id'),
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
    final store = MemoryAppStateStore('saved-spreadsheet-id');
    final service = TestSpreadsheetValidationService.fromRows([
      [...activeSheetFixedColumns, 'Week 1'],
      [...List.filled(activeSheetFixedColumns.length, ''), 'S1'],
      ['Squat', '3', '5', '8', '3 min', '', '', '', 'Legs', '', ''],
    ]);

    await tester.pumpWidget(
      WorkoutTrackerApp(
        svc: service,
        appStateStore: store,
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
    final store = MemoryAppStateStore('saved-spreadsheet-id');
    final service = TestSpreadsheetValidationService.fromRows([
      [...activeSheetFixedColumns, 'Week 1'],
      [...List.filled(activeSheetFixedColumns.length, ''), 'S1'],
      ['Squat', '3', '5', '8', '3 min', '', '', '', 'Legs', '', ''],
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
    final store = MemoryAppStateStore(
      'saved-spreadsheet-id',
      selectedSpreadsheet: const SelectedSpreadsheet(
        spreadsheetId: 'selected-spreadsheet-id',
        name: '2026 Workouts',
        drivePath: 'My Drive / Workouts / 2026 Workouts',
        accountEmail: 'saved@example.com',
      ),
      pickerAuth: const PickerAuth(
        accessToken: 'restored-picker-token',
        accountEmail: 'saved@example.com',
      ),
    );
    final accountSession = PickerAuthGateway();
    final service = TestSpreadsheetValidationService.fromRows([
      [...activeSheetFixedColumns, 'Week 1'],
      [...List.filled(activeSheetFixedColumns.length, ''), 'S1'],
      ['Squat', '3', '5', '8', '3 min', '', '', '', 'Legs', '', ''],
    ]);

    await tester.pumpWidget(
      WorkoutTrackerApp(
        svc: service,
        accountSession: accountSession,
        appStateStore: store,
        picker: const DisabledPicker(
          reason: 'Google Drive Picker is missing an OAuth client ID.',
        ),
      ),
    );
    await tester.pump();

    expect(find.text('My Drive / Workouts / 2026 Workouts'), findsOneWidget);
    expect(
      accountSession.currentAuthorization?.accessToken,
      'restored-picker-token',
    );
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
    'restores saved workout and history for a selected sheet visibly',
    (tester) async {
      final store =
          MemoryAppStateStore(
              null,
              selectedSpreadsheet: const SelectedSpreadsheet(
                spreadsheetId: 'selected-spreadsheet-id',
                name: '2026 Workouts',
                accountEmail: 'saved@example.com',
              ),
            )
            ..workoutSelection = const WorkoutSelectionState(
              spreadsheetId: 'selected-spreadsheet-id',
              workout: 'Upper',
              historyBlock: 'Week 1',
            );
      final service = TestSpreadsheetValidationService.fromRows([
        [...activeSheetFixedColumns, 'Week 2', 'Week 1'],
        [...List.filled(activeSheetFixedColumns.length, ''), 'S1', 'S1'],
        ['Squat', '3', '5', '8', '3 min', '', '', '', 'Legs', '', '', ''],
        [
          'Bench Press',
          '4',
          '6',
          '8',
          '3 min',
          '',
          '',
          '',
          'Upper',
          '',
          '',
          '',
        ],
      ]);

      await tester.pumpWidget(
        WorkoutTrackerApp(
          svc: service,
          appStateStore: store,
          picker: FakeSpreadsheetPicker(),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(service.spreadsheetIds, ['selected-spreadsheet-id']);
      expect(
        find.byKey(const ValueKey('select-workout-setup')),
        findsOneWidget,
      );
      final selectors = find.byType(DropdownButtonFormField<String>);
      expect(
        tester.state<FormFieldState<String>>(selectors.first).value,
        'Upper',
      );
      expect(
        tester.state<FormFieldState<String>>(selectors.last).value,
        'Week 1',
      );
    },
  );

  testWidgets(
    'picker sheet selection persists account profile for the avatar',
    (tester) async {
      final store = MemoryAppStateStore(null);
      final accountSession = PickerAuthGateway();
      final picker = AuthorizingSpreadsheetPicker(accountSession);
      final service = TestSpreadsheetValidationService.fromRows([
        [...activeSheetFixedColumns, 'Week 1'],
        [...List.filled(activeSheetFixedColumns.length, ''), 'S1'],
        ['Squat', '3', '5', '8', '3 min', '', '', '', 'Legs', '', ''],
      ]);

      await tester.pumpWidget(
        WorkoutTrackerApp(
          svc: service,
          accountSession: accountSession,
          appStateStore: store,
          picker: picker,
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Choose workout sheet'));
      await tester.pump();
      await tester.pump();

      expect(store.pickerAuth?.accessToken, 'picker-token');
      expect(store.pickerAuth?.accountEmail, 'athlete@example.com');
      expect(store.pickerAuth?.displayName, 'Athlete Name');

      await tester.tap(find.byTooltip('Back to sheet selection'));
      await tester.pumpAndSettle();

      expect(
        find.byTooltip('Google Sheets account: athlete@example.com'),
        findsOneWidget,
      );

      await tester.tap(
        find.byTooltip('Google Sheets account: athlete@example.com'),
      );
      await tester.pumpAndSettle();

      expect(find.text('Athlete Name'), findsOneWidget);
      expect(find.text('athlete@example.com'), findsWidgets);
    },
  );

  testWidgets(
    'first-run setup has one primary sheet choice and secondary alternatives',
    (tester) async {
      final picker = CountingSpreadsheetPicker();
      final service = TestSpreadsheetValidationService.fromRows([
        [...activeSheetFixedColumns, 'Week 1'],
        [...List.filled(activeSheetFixedColumns.length, ''), 'S1'],
        ['Squat', '3', '5', '8', '3 min', '', '', '', 'Legs', '', ''],
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
    'create sheet uses picker authorization before asking for a workbook name',
    (tester) async {
      final picker = CountingSpreadsheetPicker();
      final authorization = Completer<bool>();
      picker.creationAuthorization = authorization.future;
      final accountSession = PickerAuthGateway();
      final service = TestSpreadsheetValidationService.fromRows([
        [...activeSheetFixedColumns, 'Week 1'],
        [...List.filled(activeSheetFixedColumns.length, ''), 'S1'],
        ['Squat', '3', '5', '8', '3 min', '', '', '', 'Legs', '', ''],
      ]);

      await tester.pumpWidget(
        WorkoutTrackerApp(
          svc: service,
          accountSession: accountSession,
          picker: picker,
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Create sheet'));
      await tester.pump();

      expect(picker.creationAuthorizationCount, 1);
      expect(find.text('Sheet name'), findsNothing);
      expect(picker.createCount, 0);

      authorization.complete(true);
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
    },
  );

  testWidgets('create sheet still opens folder picker when already connected', (
    tester,
  ) async {
    final picker = CountingSpreadsheetPicker();
    final accountSession = PickerAuthGateway(
      initial: const PickerAuth(
        accessToken: 'saved-token',
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
        svc: service,
        accountSession: accountSession,
        picker: picker,
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Create sheet'));
    await tester.pumpAndSettle();

    expect(picker.creationAuthorizationCount, 1);
    expect(find.text('Sheet name'), findsOneWidget);
    expect(picker.createCount, 0);

    await tester.enterText(
      find.byKey(const ValueKey('create-spreadsheet-name')),
      'Custom Training Log',
    );
    await tester.tap(find.text('Create'));
    await tester.pump();

    expect(picker.createCount, 1);
    expect(picker.createNames, ['Custom Training Log']);
  });

  testWidgets('returning sheet selection keeps loaded state compact', (
    tester,
  ) async {
    final store = MemoryAppStateStore(
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
        svc: service,
        appStateStore: store,
        picker: FakeSpreadsheetPicker(),
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
      const picker = DisabledPicker(
        reason: 'Google Drive Picker is missing an OAuth client ID.',
      );
      final service = TestSpreadsheetValidationService.fromRows([
        [...activeSheetFixedColumns, 'Week 1'],
        [...List.filled(activeSheetFixedColumns.length, ''), 'S1'],
        ['Squat', '3', '5', '8', '3 min', '', '', '', 'Legs', '', ''],
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
    final picker = CompletingSpreadsheetPicker();
    final service = TestSpreadsheetValidationService.fromRows([
      [...activeSheetFixedColumns, 'Week 1'],
      [...List.filled(activeSheetFixedColumns.length, ''), 'S1'],
      ['Squat', '3', '5', '8', '3 min', '', '', '', 'Legs', '', ''],
    ]);

    await tester.pumpWidget(WorkoutTrackerApp(svc: service, picker: picker));
    await tester.pump();

    await tester.tap(find.text('Choose workout sheet'));
    await tester.tap(find.text('Choose workout sheet'));

    expect(picker.chooseCount, 1);
  });

  testWidgets('does not launch duplicate create actions while creating', (
    tester,
  ) async {
    final picker = CompletingSpreadsheetPicker();
    final service = TestSpreadsheetValidationService.fromRows([
      [...activeSheetFixedColumns, 'Week 1'],
      [...List.filled(activeSheetFixedColumns.length, ''), 'S1'],
      ['Squat', '3', '5', '8', '3 min', '', '', '', 'Legs', '', ''],
    ]);

    await tester.pumpWidget(WorkoutTrackerApp(svc: service, picker: picker));
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
    final accountSession = FakeGoogleAccountSession(
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
        WorkoutTrackerApp(svc: service, initialText: 'spreadsheet-id'),
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
      WorkoutTrackerApp(svc: service, initialText: 'spreadsheet-id'),
    );

    await tester.tap(find.byKey(const ValueKey('validate-spreadsheet')));
    await tester.pump();
    await tester.pump();

    expect(find.text('Upper exercises'), findsOneWidget);
    expect(find.text('Pull Up'), findsOneWidget);

    await tester.tap(find.byTooltip('Exercise actions for Pull Up'));
    await tester.pumpAndSettle();

    expect(find.text('Add backup exercise'), findsOneWidget);
    expect(find.text('Delete exercise'), findsOneWidget);

    await tester.tap(find.text('Add backup exercise'));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Back to workout setup'), findsOneWidget);
    expect(find.text('Add backup exercise'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('existing-exercise-selector')),
      findsOneWidget,
    );
  });

  testWidgets('requires confirmation before deleting a workout exercise', (
    tester,
  ) async {
    final rows = [
      [...activeSheetFixedColumns, 'Week 1'],
      [...List.filled(activeSheetFixedColumns.length, ''), 'S1'],
      ['Pull Up', '3', '8', '8', '2 min', '', '', '', 'Upper', '', '8@8'],
      [
        'Lat Pulldown',
        '3',
        '10',
        '8',
        '90s',
        '',
        '',
        '',
        'Upper',
        'TRUE',
        '100x10@8',
      ],
      ['Row', '3', '10', '8', '2 min', '', '', '', 'Upper', '', '120x10@8'],
    ];
    final service = TestSpreadsheetValidationService.fromRows(rows);
    final authoringService = DeletingWorkoutExerciseAuthoringService(rows);

    await tester.pumpWidget(
      WorkoutTrackerApp(
        svc: CompositeWorkbookCommandService(
          validation: service,
          authoring: authoringService,
        ),
        initialText: 'spreadsheet-id',
      ),
    );

    await tester.tap(find.byKey(const ValueKey('validate-spreadsheet')));
    await tester.pump();
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('select-workout-setup')));
    await tester.pumpAndSettle();

    expect(find.text('Upper - Week 1'), findsOneWidget);
    expect(find.text('Pull Up'), findsOneWidget);
    expect(find.text('Lat Pulldown'), findsOneWidget);

    await tester.tap(find.byTooltip('Exercise actions for Pull Up'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete exercise'));
    await tester.pumpAndSettle();

    expect(find.text('Delete Pull Up?'), findsOneWidget);
    expect(
      find.text(
        'This removes Pull Up from the workout, including associated '
        'backups and logged history for those rows.',
      ),
      findsOneWidget,
    );
    expect(authoringService.deletedRows, isEmpty);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(authoringService.deletedRows, isEmpty);
    expect(find.text('Pull Up'), findsOneWidget);
    expect(find.text('Lat Pulldown'), findsOneWidget);
  });

  testWidgets('confirmed delete removes the primary exercise and backups', (
    tester,
  ) async {
    final rows = [
      [...activeSheetFixedColumns, 'Week 1'],
      [...List.filled(activeSheetFixedColumns.length, ''), 'S1'],
      ['Pull Up', '3', '8', '8', '2 min', '', '', '', 'Upper', '', '8@8'],
      [
        'Lat Pulldown',
        '3',
        '10',
        '8',
        '90s',
        '',
        '',
        '',
        'Upper',
        'TRUE',
        '100x10@8',
      ],
      ['Row', '3', '10', '8', '2 min', '', '', '', 'Upper', '', '120x10@8'],
    ];
    final service = TestSpreadsheetValidationService.fromRows(rows);
    final authoringService = DeletingWorkoutExerciseAuthoringService(rows);

    await tester.pumpWidget(
      WorkoutTrackerApp(
        svc: CompositeWorkbookCommandService(
          validation: service,
          authoring: authoringService,
        ),
        initialText: 'spreadsheet-id',
      ),
    );

    await tester.tap(find.byKey(const ValueKey('validate-spreadsheet')));
    await tester.pump();
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('select-workout-setup')));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Exercise actions for Pull Up'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete exercise'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete exercise'));
    await tester.pumpAndSettle();

    expect(authoringService.deletedRows, [3]);
    expect(find.text('Pull Up'), findsNothing);
    expect(find.text('Lat Pulldown'), findsNothing);
    expect(find.text('Row'), findsOneWidget);
    expect(find.textContaining('Unable to delete exercise'), findsNothing);
  });

  testWidgets('rejected delete leaves the last confirmed overview visible', (
    tester,
  ) async {
    final rows = [
      [...activeSheetFixedColumns, 'Week 1'],
      [...List.filled(activeSheetFixedColumns.length, ''), 'S1'],
      ['Pull Up', '3', '8', '8', '2 min', '', '', '', 'Upper', '', '8@8'],
      [
        'Lat Pulldown',
        '3',
        '10',
        '8',
        '90s',
        '',
        '',
        '',
        'Upper',
        'TRUE',
        '100x10@8',
      ],
      ['Row', '3', '10', '8', '2 min', '', '', '', 'Upper', '', '120x10@8'],
    ];
    final service = TestSpreadsheetValidationService.fromRows(rows);
    final authoringService = DeletingWorkoutExerciseAuthoringService(
      rows,
      rejectDelete: true,
    );

    await tester.pumpWidget(
      WorkoutTrackerApp(
        svc: CompositeWorkbookCommandService(
          validation: service,
          authoring: authoringService,
        ),
        initialText: 'spreadsheet-id',
      ),
    );

    await tester.tap(find.byKey(const ValueKey('validate-spreadsheet')));
    await tester.pump();
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('select-workout-setup')));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Exercise actions for Pull Up'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete exercise'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete exercise'));
    await tester.pumpAndSettle();

    expect(authoringService.deletedRows, [3]);
    expect(find.text('Pull Up'), findsOneWidget);
    expect(find.text('Lat Pulldown'), findsOneWidget);
    expect(find.text('Row'), findsOneWidget);
    expect(
      find.textContaining(
        'Unable to delete exercise: Row 3 no longer matches Pull Up.',
      ),
      findsOneWidget,
    );
  });

  testWidgets(
    'primary exercise menu remains reachable by right-click and long-press',
    (tester) async {
      final service = TestSpreadsheetValidationService.fromRows([
        [...activeSheetFixedColumns, 'Week 1'],
        [...List.filled(activeSheetFixedColumns.length, ''), 'S1'],
        ['Pull Up', '3', '8', '8', '2 min', '', '', '', 'Upper', '', '8@8'],
      ]);
      final authoringService = DeletingWorkoutExerciseAuthoringService([
        [...activeSheetFixedColumns, 'Week 1'],
        [...List.filled(activeSheetFixedColumns.length, ''), 'S1'],
        ['Pull Up', '3', '8', '8', '2 min', '', '', '', 'Upper', '', '8@8'],
      ]);

      await tester.pumpWidget(
        WorkoutTrackerApp(
          svc: CompositeWorkbookCommandService(
            validation: service,
            authoring: authoringService,
          ),
          initialText: 'spreadsheet-id',
        ),
      );

      await tester.tap(find.byKey(const ValueKey('validate-spreadsheet')));
      await tester.pump();
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('select-workout-setup')));
      await tester.pumpAndSettle();

      final tileCenter = tester.getCenter(find.text('Pull Up').first);
      await tester.tapAt(tileCenter, buttons: kSecondaryMouseButton);
      await tester.pumpAndSettle();

      expect(find.text('Add backup exercise'), findsOneWidget);
      expect(find.text('Delete exercise'), findsOneWidget);

      await tester.tapAt(const Offset(1, 1));
      await tester.pumpAndSettle();
      await tester.longPress(find.text('Pull Up').first);
      await tester.pumpAndSettle();

      expect(find.text('Add backup exercise'), findsOneWidget);
      expect(find.text('Delete exercise'), findsOneWidget);
    },
  );

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
      WorkoutTrackerApp(svc: service, initialText: 'spreadsheet-id'),
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
        WorkoutTrackerApp(svc: service, initialText: 'spreadsheet-id'),
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
      WorkoutTrackerApp(svc: service, initialText: 'spreadsheet-id'),
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
      final store = MemoryAppStateStore(
        null,
        selectedSpreadsheet: const SelectedSpreadsheet(
          spreadsheetId: 'selected-spreadsheet-id',
          name: '2026 Workouts',
          drivePath: 'My Drive / Workouts / 2026 Workouts',
          accountEmail: 'saved@example.com',
        ),
      );
      final service = TestSpreadsheetValidationService(activeSheet);
      final authoringService = WorkoutPlacementRecordingService(activeSheet);

      await tester.pumpWidget(
        WorkoutTrackerApp(
          svc: CompositeWorkbookCommandService(
            validation: service,
            authoring: authoringService,
          ),
          appStateStore: store,
          picker: FakeSpreadsheetPicker(),
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
      final authoringService = ReorderingWorkoutExerciseAuthoringService(rows);

      await tester.pumpWidget(
        WorkoutTrackerApp(
          svc: CompositeWorkbookCommandService(
            validation: service,
            authoring: authoringService,
          ),
          initialText: 'spreadsheet-id',
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
        find.byTooltip('Exercise actions for $primaryExercise'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel('Exercise actions for $primaryExercise'),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel('Reorder $primaryExercise'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.byTooltip('Exercise actions for $primaryExercise'));
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
      exerciseInventoryParsedSheet([
        exerciseRow('Squat', description: 'Back squat'),
        exerciseRow('Bench Press', description: 'Competition bench'),
        exerciseRow('Cable Row', description: 'Seated cable row'),
      ]),
    );

    await tester.pumpWidget(
      WorkoutTrackerApp(svc: service, initialText: 'spreadsheet-id'),
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
      emptyExerciseInventoryParsedSheet(),
    );

    await tester.pumpWidget(
      WorkoutTrackerApp(svc: service, initialText: 'spreadsheet-id'),
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
        exerciseInventoryParsedSheet([
          exerciseRow('Squat', description: 'Back squat'),
        ]),
      );
      final authoringService = AppendingExerciseAuthoringService([
        exerciseRow('Squat', description: 'Back squat'),
      ]);

      await tester.pumpWidget(
        WorkoutTrackerApp(
          svc: CompositeWorkbookCommandService(
            validation: validationService,
            authoring: authoringService,
          ),
          initialText: 'spreadsheet-id',
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
        exerciseRow(
          'Seeded Exercise ${index.toString().padLeft(2, '0')}',
          description: 'Seeded library item $index',
        ),
    ];
    final validationService = TestSpreadsheetValidationService(
      exerciseInventoryParsedSheet(seededExercises),
    );
    final authoringService = AppendingExerciseAuthoringService(seededExercises);

    await tester.pumpWidget(
      WorkoutTrackerApp(
        svc: CompositeWorkbookCommandService(
          validation: validationService,
          authoring: authoringService,
        ),
        initialText: 'spreadsheet-id',
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
        exerciseRow(
          'Seeded Exercise ${index.toString().padLeft(2, '0')}',
          description: 'Seeded library item $index',
        ),
    ];
    final validationService = TestSpreadsheetValidationService(
      exerciseInventoryParsedSheet(seededExercises),
    );
    final authoringService = EditingExerciseAuthoringService(seededExercises);

    await tester.pumpWidget(
      WorkoutTrackerApp(
        svc: CompositeWorkbookCommandService(
          validation: validationService,
          authoring: authoringService,
        ),
        initialText: 'spreadsheet-id',
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
        exerciseInventoryParsedSheet([
          exerciseRow('Squat', description: 'Back squat'),
        ]),
      );
      final authoringService = AppendingExerciseAuthoringService([
        exerciseRow('Squat', description: 'Back squat'),
      ]);

      await tester.pumpWidget(
        WorkoutTrackerApp(
          svc: CompositeWorkbookCommandService(
            validation: validationService,
            authoring: authoringService,
          ),
          initialText: 'spreadsheet-id',
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
        exerciseInventoryParsedSheet([
          exerciseRow('Squat', description: 'Back squat'),
          exerciseRow('Bench Press', description: 'Competition bench'),
        ]),
      );
      final authoringService = EditingExerciseAuthoringService([
        exerciseRow('Squat', description: 'Back squat'),
        exerciseRow('Bench Press', description: 'Competition bench'),
      ]);

      await tester.pumpWidget(
        WorkoutTrackerApp(
          svc: CompositeWorkbookCommandService(
            validation: validationService,
            authoring: authoringService,
          ),
          initialText: 'spreadsheet-id',
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
      exerciseInventoryParsedSheet([
        exerciseRow('Squat', description: 'Back squat'),
        exerciseRow('Bench Press', description: 'Competition bench'),
      ]),
    );
    final authoringService = EditingExerciseAuthoringService([
      exerciseRow('Squat', description: 'Back squat'),
      exerciseRow('Bench Press', description: 'Competition bench'),
    ]);

    await tester.pumpWidget(
      WorkoutTrackerApp(
        svc: CompositeWorkbookCommandService(
          validation: validationService,
          authoring: authoringService,
        ),
        initialText: 'spreadsheet-id',
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
      exerciseInventoryParsedSheet([
        exerciseRow('Squat', description: 'Back squat'),
      ]),
    );

    await tester.pumpWidget(
      WorkoutTrackerApp(svc: service, initialText: 'spreadsheet-id'),
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
      exerciseRow('Squat', description: 'Back squat'),
      exerciseRow('Bench Press', description: 'Competition bench'),
      exerciseRow('Cable Row', description: 'Seated cable row'),
    ];
    final validationService = TestSpreadsheetValidationService(
      exerciseInventoryParsedSheet(exercises),
    );
    final authoringService = ReorderingExerciseAuthoringService(exercises);

    await tester.pumpWidget(
      WorkoutTrackerApp(
        svc: CompositeWorkbookCommandService(
          validation: validationService,
          authoring: authoringService,
        ),
        initialText: 'spreadsheet-id',
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
    final authoringService = ReorderingWorkoutExerciseAuthoringService(rows);

    await tester.pumpWidget(
      WorkoutTrackerApp(
        svc: CompositeWorkbookCommandService(
          validation: validationService,
          authoring: authoringService,
        ),
        initialText: 'spreadsheet-id',
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
      WorkoutTrackerApp(svc: service, initialText: 'spreadsheet-id'),
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
    expect(textFieldWithLabel('Raw set text'), findsOneWidget);
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
        WorkoutTrackerApp(svc: service, initialText: 'spreadsheet-id'),
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
      WorkoutTrackerApp(svc: service, initialText: 'spreadsheet-id'),
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
      WorkoutTrackerApp(svc: service, initialText: 'spreadsheet-id'),
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
      WorkoutTrackerApp(svc: service, initialText: 'spreadsheet-id'),
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
      WorkoutTrackerApp(svc: service, initialText: 'spreadsheet-id'),
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
        WorkoutTrackerApp(svc: service, initialText: 'spreadsheet-id'),
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
      await tester.enterText(textFieldWithLabel('Workout name'), 'Push');
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
        textFieldWithLabel('History block label'),
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
        WorkoutTrackerApp(svc: service, initialText: 'spreadsheet-id'),
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

      await tester.enterText(textFieldWithLabel('Workout name'), 'Push');
      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();

      expect(find.text('Push (0/0 done)'), findsOneWidget);

      await tester.tap(find.text('Week 1').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add history block...').last);
      await tester.pumpAndSettle();

      await tester.enterText(
        textFieldWithLabel('History block label'),
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
        WorkoutTrackerApp(svc: service, initialText: 'spreadsheet-id'),
      );

      await tester.tap(find.byKey(const ValueKey('validate-spreadsheet')));
      await tester.pump();
      await tester.pump();

      await tester.tap(find.text('Legs (0/1 done)').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add workout...').last);
      await tester.pumpAndSettle();

      expect(find.text('Add workout'), findsOneWidget);
      final workoutNameField = textFieldWithLabel('Workout name');
      expect(
        editableTextFor(workoutNameField).focusNode.hasPrimaryFocus,
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
        editableTextFor(
          textFieldWithLabel('Workout name'),
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
      WorkoutTrackerApp(svc: service, initialText: 'spreadsheet-id'),
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

    expect(textFieldWithLabel('Sets'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('existing-exercise-selector')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dip').last);
    await tester.pumpAndSettle();

    expect(textFieldWithLabel('Sets'), findsOneWidget);
    expect(textFieldWithLabel('Reps'), findsOneWidget);
    expect(textFieldWithLabel('RPE'), findsOneWidget);

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
      WorkoutTrackerApp(svc: service, initialText: 'spreadsheet-id'),
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

    expect(textFieldWithLabel('Sets'), findsNothing);
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

    expect(textFieldWithLabel('Sets'), findsNothing);
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
    final authoringService = WorkoutPlacementRecordingService(activeSheet);

    await tester.pumpWidget(
      WorkoutTrackerApp(
        svc: CompositeWorkbookCommandService(
          validation: service,
          authoring: authoringService,
        ),
        initialText: 'spreadsheet-id',
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
    expect(textFieldWithLabel('Sets'), findsNothing);

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
      WorkoutTrackerApp(svc: service, initialText: 'spreadsheet-id'),
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

    expect(textFieldWithLabel('Sets'), findsOneWidget);
    expect(textFieldWithLabel('Reps'), findsOneWidget);
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
      WorkoutTrackerApp(svc: service, initialText: 'spreadsheet-id'),
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
      final field = textFieldWithLabel(label);
      expect(field, findsOneWidget);
    }
    for (final label in const ['Sets', 'RPE']) {
      expect(
        tester.widget<TextField>(textFieldWithLabel(label)).keyboardType,
        TextInputType.number,
      );
    }
    expect(
      tester.widget<TextField>(textFieldWithLabel('Reps')).keyboardType,
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
        WorkoutTrackerApp(svc: service, initialText: 'spreadsheet-id'),
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
        exerciseInventoryParsedSheet([
          exerciseRow('Squat', description: 'Back squat'),
        ]),
      );

      await tester.pumpWidget(
        WorkoutTrackerApp(
          svc: validationService,
          initialText: 'spreadsheet-id',
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
          exerciseInventoryParsedSheet([
            exerciseRow('Squat', description: 'Back squat'),
          ]),
        );
        final authoringService = AppendingExerciseAuthoringService([
          exerciseRow('Squat', description: 'Back squat'),
        ]);

        await tester.pumpWidget(
          WorkoutTrackerApp(
            svc: CompositeWorkbookCommandService(
              validation: validationService,
              authoring: authoringService,
            ),
            initialText: 'spreadsheet-id',
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
          final field = textFieldWithLabel(label);
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
      WorkoutTrackerApp(svc: service, initialText: 'spreadsheet-id'),
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
        WorkoutTrackerApp(svc: service, initialText: 'spreadsheet-id'),
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

  testWidgets('shows account summary and logout in the Google Sheets menu', (
    tester,
  ) async {
    final service = TestSpreadsheetValidationService.fromRows([
      [...activeSheetFixedColumns, 'Week 1'],
      [...List.filled(activeSheetFixedColumns.length, ''), 'S1'],
      ['Squat', '3', '5', '8', '3 min', '', '', '', 'Legs', '', ''],
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

    await tester.tap(
      find.byTooltip('Google Sheets account: wrong@example.com'),
    );
    await tester.pumpAndSettle();

    expect(find.text('Wrong Account'), findsOneWidget);
    expect(find.text('wrong@example.com'), findsOneWidget);
    expect(find.text('Switch Google Sheets account'), findsNothing);
    expect(find.text('Log out'), findsOneWidget);
    expect(accountSession.switchCount, 0);
    expect(accountSession.requestedScopes, isEmpty);
  });

  testWidgets('logs out from the Google Sheets account menu', (tester) async {
    final service = TestSpreadsheetValidationService.fromRows([
      [...activeSheetFixedColumns, 'Week 1'],
      [...List.filled(activeSheetFixedColumns.length, ''), 'S1'],
      ['Squat', '3', '5', '8', '3 min', '', '', '', 'Legs', '', ''],
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
        initialText: 'spreadsheet-id',
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
        MemoryAppStateStore(
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
        appStateStore: store,
        picker: FakeSpreadsheetPicker(),
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

  testWidgets('shows only the account summary when logged out', (tester) async {
    final service = TestSpreadsheetValidationService.fromRows([
      [...activeSheetFixedColumns, 'Week 1'],
      [...List.filled(activeSheetFixedColumns.length, ''), 'S1'],
      ['Squat', '3', '5', '8', '3 min', '', '', '', 'Legs', '', ''],
    ]);
    final accountSession = FakeGoogleAccountSession(null);

    await tester.pumpWidget(
      WorkoutTrackerApp(
        svc: service,
        accountSession: accountSession,
        initialText: 'spreadsheet-id',
      ),
    );

    await tester.tap(find.byTooltip('Connect Google Sheets'));
    await tester.pumpAndSettle();

    expect(find.text('No Google Sheets account connected'), findsOneWidget);
    expect(find.text('Connect Google Sheets'), findsNothing);
    expect(find.text('Switch Google Sheets account'), findsNothing);
    expect(find.text('Log out'), findsNothing);
    expect(accountSession.switchCount, 0);
  });

  testWidgets('shows the Google Sheets account menu in picker mode', (
    tester,
  ) async {
    final service = TestSpreadsheetValidationService.fromRows([
      [...activeSheetFixedColumns, 'Week 1'],
      [...List.filled(activeSheetFixedColumns.length, ''), 'S1'],
      ['Squat', '3', '5', '8', '3 min', '', '', '', 'Legs', '', ''],
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
        picker: FakeSpreadsheetPicker(),
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
