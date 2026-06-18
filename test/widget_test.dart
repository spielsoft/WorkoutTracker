import 'dart:ui';

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
    expect(find.text('Workout setup'), findsOneWidget);
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

  testWidgets('renders compact spreadsheet controls with desktop scrolling', (
    tester,
  ) async {
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

    final behavior = ScrollConfiguration.of(
      tester.element(find.byKey(const ValueKey('spreadsheet-selection-input'))),
    );
    expect(behavior.dragDevices, contains(PointerDeviceKind.touch));
    expect(behavior.dragDevices, contains(PointerDeviceKind.mouse));
    expect(behavior.dragDevices, contains(PointerDeviceKind.trackpad));
  });

  testWidgets(
    'blocks logging and lists formula issues on the validation screen',
    (tester) async {
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

      expect(find.text('Formula repair needed'), findsOneWidget);
      expect(
        find.text('Row 3, Squat: preselects Exercises row 2.'),
        findsOneWidget,
      );
      expect(find.text('Exercise: missing formula'), findsOneWidget);
      expect(find.text('Reps: broken formula'), findsOneWidget);
      expect(find.text('Workout setup'), findsNothing);
      expect(find.byKey(const ValueKey('select-workout-setup')), findsNothing);
      expect(find.text('Save set'), findsNothing);
    },
  );

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

    expect(find.text('Formula repair needed'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('repair-unambiguous-formulas')),
      findsOneWidget,
    );
    expect(find.text('Workout setup'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('repair-unambiguous-formulas')));
    await tester.pump();
    await tester.pump();

    expect(service.appliedPlans.single.cellUpdates, const [
      CellUpdate(
        sheetRowNumber: 3,
        sheetColumnNumber: 1,
        value: '=Exercises!A2',
      ),
      CellUpdate(
        sheetRowNumber: 3,
        sheetColumnNumber: 3,
        value: '=Exercises!D2',
      ),
    ]);
    expect(find.text('Formula repair needed'), findsNothing);
    expect(find.text('Workout setup'), findsOneWidget);
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
    expect(
      find.text('Row 3, Squat: choose the Exercises row to use.'),
      findsOneWidget,
    );

    final picker = tester.widget<DropdownMenu<int>>(
      find.byKey(const ValueKey('formula-repair-picker-3')),
    );
    expect(picker.enableFilter, isTrue);
    expect(picker.dropdownMenuEntries.map((entry) => entry.label), [
      'Row 2: Squat - Back squat',
      'Row 3: Squat - Safety-bar squat',
    ]);

    final fixButton = tester.widget<FilledButton>(
      find.byKey(const ValueKey('repair-formula-row-3')),
    );
    expect(fixButton.onPressed, isNull);
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
      expect(
        find.text('Row 3, Front Squat: choose the Exercises row to use.'),
        findsOneWidget,
      );

      final picker = tester.widget<DropdownMenu<int>>(
        find.byKey(const ValueKey('formula-repair-picker-3')),
      );
      expect(picker.enableFilter, isTrue);
      expect(picker.dropdownMenuEntries.map((entry) => entry.label), [
        'Row 2: Squat - Back squat',
      ]);

      picker.onSelected?.call(2);
      await tester.pump();

      final fixButton = tester.widget<FilledButton>(
        find.byKey(const ValueKey('repair-formula-row-3')),
      );
      expect(fixButton.onPressed, isNotNull);

      await tester.tap(find.byKey(const ValueKey('repair-formula-row-3')));
      await tester.pump();
      await tester.pump();

      expect(service.appliedPlans.single.cellUpdates, const [
        CellUpdate(
          sheetRowNumber: 3,
          sheetColumnNumber: 1,
          value: '=Exercises!A2',
        ),
      ]);
      expect(find.text('Formula repair needed'), findsNothing);
      expect(find.text('Workout setup'), findsOneWidget);
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

    expect(find.text('Formula repair needed'), findsNothing);
    expect(find.text('Sheet contract issues'), findsOneWidget);
    expect(find.text('Workout setup'), findsNothing);
    expect(find.byKey(const ValueKey('select-workout-setup')), findsNothing);
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

    expect(find.text('Sheet contract issues'), findsOneWidget);
    expect(
      find.text(
        'Row 2, Default: History set column S1 has no history block label.',
      ),
      findsOneWidget,
    );
    expect(
      find.text('Row 1, Default: Duplicate history block label: Week 1.'),
      findsOneWidget,
    );
    expect(
      find.text(
        'Row 2, Default: History block Week 1 skips set label S2 before S3.',
      ),
      findsOneWidget,
    );
    expect(
      find.text(
        'Row 1, Default: History block Empty Block has no set columns.',
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
      expect(find.text('Sheet contract issues'), findsOneWidget);
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

  testWidgets(
    'keeps exercise context, selected rows, recent history, and raw controls',
    (tester) async {
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
      expect(find.text('Target: 3 sets x 40 @ 8'), findsOneWidget);
      expect(find.text('Rest: 90s'), findsOneWidget);
      expect(find.text('Tempo: Smooth'), findsOneWidget);
      expect(find.text('Stay tall.'), findsOneWidget);
      expect(find.text('Next set S2'), findsOneWidget);
      expect(find.text('Logged sets'), findsOneWidget);
      expect(find.byKey(const ValueKey('raw-S1')), findsOneWidget);
      expect(find.text('Recent history'), findsOneWidget);
      expect(find.text('Week 1'), findsWidgets);
      expect(find.text('Week 1 S1: 30@7'), findsNothing);
      expect(find.text('S1: 30@7'), findsOneWidget);
      expect(find.text('S2: 35@8'), findsOneWidget);
    },
  );

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

      final rowSelector = tester.widget<SegmentedButton<int>>(
        find.byWidgetPredicate((widget) => widget is SegmentedButton<int>),
      );
      expect(rowSelector.direction, Axis.vertical);
      final shape = rowSelector.style?.shape?.resolve({});
      expect(shape, isA<RoundedRectangleBorder>());
      expect(
        (shape! as RoundedRectangleBorder).borderRadius,
        BorderRadius.circular(8),
      );
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Text &&
              widget.data == 'Front Plank' &&
              widget.maxLines == 1 &&
              widget.overflow == TextOverflow.ellipsis,
        ),
        findsOneWidget,
      );
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

class _MemoryAppStateStore implements AppStateStore {
  _MemoryAppStateStore(this.spreadsheetText);

  String? spreadsheetText;
  final writes = <String>[];

  @override
  Future<String?> readSpreadsheetText() async {
    return spreadsheetText;
  }

  @override
  Future<void> writeSpreadsheetText(String value) async {
    spreadsheetText = value;
    writes.add(value);
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
