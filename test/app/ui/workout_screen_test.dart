import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_tracker/contract.dart';
import 'package:workout_tracker/app.dart';

import '../service_fake.dart';
import '../../support/widget.dart';

void main() {
  testWidgets(
    'restores saved workout and history for a selected sheet visibly',
    (tester) async {
      final store =
          MemoryAppStStore(
              null,
              selectedSheet: const SelectedSheet(
                spreadsheetId: 'selected-spreadsheet-id',
                name: '2026 Workouts',
                accountEmail: 'saved@example.com',
              ),
            )
            ..workoutSelection = const WorkoutSelectionSt(
              spreadsheetId: 'selected-spreadsheet-id',
              workout: 'Upper',
              historyBlock: 'Week 1',
            );
      final service = TestValSvc.fromRows([
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
          appStStore: store,
          picker: FakeSheetPicker(),
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
    'labels workouts with selected-block progress and counts backups with parent',
    (tester) async {
      final service = TestValSvc.fromRows([
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
    final service = TestValSvc(activeSheet);

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
    final service = TestValSvc.fromRows(rows);
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
    final service = TestValSvc.fromRows(rows);
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

  testWidgets(
    'primary exercise menu remains reachable by right-click and long-press',
    (tester) async {
      final service = TestValSvc.fromRows([
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

  testWidgets(
    'selecting a workout setup opens the full exercise picker with compact context',
    (tester) async {
      final service = TestValSvc.fromRows([
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
    final service = TestValSvc(activeSheet);

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
    final validationService = TestValSvc.fromRows(rows);
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

  testWidgets(
    'shows setup creation actions in selectors and selects created values',
    (tester) async {
      final service = TestValSvc.fromRows([
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
}
