import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_tracker/contract.dart';
import 'package:workout_tracker/app.dart';

import '../service_fake.dart';
import '../../support/widget.dart';

void main() {
  testWidgets('history selection precedes workout selection responsively', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final service = TestValSvc.fromRows([
      [...activeSheetFixedColumns, 'Week 1'],
      [...List.filled(activeSheetFixedColumns.length, ''), 'S1'],
      ['Squat', '3', '3 min', '', 'x5@8', '', '', 'Legs', '', 'x', ''],
    ]);

    await tester.pumpWidget(
      WorkoutTrackerApp(svc: service, initialText: 'spreadsheet-id'),
    );
    await tester.tap(find.byKey(const ValueKey('validate-spreadsheet')));
    await tester.pump();
    await tester.pump();

    var history = tester.getRect(find.text('History block'));
    var workout = tester.getRect(find.text('Workout'));
    expect(history.top, lessThan(workout.top));

    tester.view.physicalSize = const Size(900, 700);
    await tester.pumpAndSettle();

    history = tester.getRect(find.text('History block'));
    workout = tester.getRect(find.text('Workout'));
    expect(history.left, lessThan(workout.left));
    expect(history.top, workout.top);
  });

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
        ['Squat', '3', '3 min', '', 'x5@8', '', '', 'Legs', '', 'x', '', ''],
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
      expect(find.text('Exercises'), findsOneWidget);
      expect(find.text('Bench Press'), findsOneWidget);
      expect(find.text('Squat'), findsNothing);
      expect(find.text('Week 1'), findsOneWidget);
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
          '{Seconds}s@{RPE}',
          'Upper',
          'TRUE',
          '45s@8',
        ],
        ['Squat', '3', '3 min', '', 'x5@8', '', '', 'Legs', '', 'x', ''],
      ]);

      await tester.pumpWidget(
        WorkoutTrackerApp(svc: service, initialText: 'spreadsheet-id'),
      );

      await tester.tap(find.byKey(const ValueKey('validate-spreadsheet')));
      await tester.pump();
      await tester.pump();

      expect(find.text('Upper'), findsOneWidget);
      expect(find.text('1/1'), findsOneWidget);
      await tester.tap(find.text('Upper'));
      await tester.pumpAndSettle();
      expect(find.text('Legs'), findsOneWidget);
      expect(find.text('0/1'), findsOneWidget);
    },
  );

  testWidgets('shows exercise and long-name workout progress unambiguously', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    const workout = 'Functional Athleticism and Upper Pull Exercises';
    final service = TestValSvc.fromRows([
      [...activeSheetFixedColumns, 'Week 1', '', ''],
      [...List.filled(activeSheetFixedColumns.length, ''), 'S1', 'S2', 'S3'],
      ['Squat', '3', '3 min', '', 'x5@8', '', '', workout, '', 'x', '', '', ''],
      [
        'Bench Press',
        '3',
        '3 min',
        '',
        'x5@8',
        '',
        '',
        workout,
        '',
        'x',
        '135x5@8',
        '135x5@8',
        '135x5@8',
      ],
      [
        'Plank',
        'AMRAP',
        '60s',
        '',
        '45@8',
        '',
        '{Seconds}@{RPE}',
        workout,
        '',
        'x',
        '45@8',
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

    expect(find.text('0 of 3 sets'), findsOneWidget);
    expect(find.text('3 of 3 sets'), findsOneWidget);
    expect(find.text('1 set logged'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp(r'0 of 3 sets')), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp(r'3 of 3 sets')), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp(r'1 set logged')), findsOneWidget);

    expect(find.text(workout), findsOneWidget);
    expect(find.text('2/3'), findsOneWidget);
    final name = tester.widget<Text>(find.text(workout));
    expect(name.maxLines, 1);
    expect(name.overflow, TextOverflow.ellipsis);
    expect(tester.takeException(), isNull);

    final selector = tester.getSemantics(
      find.bySemanticsLabel(RegExp(r'Workout selector')),
    );
    expect(selector.value, '$workout (2/3 started)');

    final historyTop = tester.getTopLeft(find.text('History block')).dy;
    final workoutTop = tester.getTopLeft(find.text('Workout')).dy;
    expect(historyTop, lessThan(workoutTop));
  });

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
            '2 min',
            '',
            '8',
            'Full hang.',
            '{Reps}',
            'Upper',
            '',
            'x',
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
            sheetColumnNumber: 7,
            formula: '=Exercises!G2',
          ),
        ],
        exercisesRows: const [
          exercisesSheetColumns,
          [
            'Pull Up',
            'Bodyweight pull',
            '3',
            '2 min',
            '2-1-1',
            'Full hang.',
            '{Reps}',
            '8',
          ],
          [
            'Front Plank',
            'Core hold',
            '3',
            '60s',
            'hold',
            'Brace hard.',
            '{Seconds}s@{RPE}',
            '45s@8',
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

    expect(find.text('Exercises'), findsOneWidget);
    expect(find.text('Pull Up'), findsOneWidget);

    await tester.tap(find.byTooltip('Exercise actions for Pull Up'));
    await tester.pumpAndSettle();

    expect(find.text('Add backup exercise'), findsOneWidget);
    expect(find.text('Delete exercise'), findsOneWidget);

    await tester.tap(find.text('Add backup exercise'));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Back'), findsOneWidget);
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
      ['Pull Up', '3', '2 min', '', 'x8@8', '', '', 'Upper', '', 'x', '8@8'],
      [
        'Lat Pulldown',
        '3',
        '90s',
        '',
        'x10@8',
        '',
        '',
        'Upper',
        'TRUE',
        'x',
        '100x10@8',
      ],
      ['Row', '3', '2 min', '', 'x10@8', '', '', 'Upper', '', 'x', '120x10@8'],
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
    expect(find.text('Exercises'), findsOneWidget);
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
      ['Pull Up', '3', '2 min', '', 'x8@8', '', '', 'Upper', '', 'x', '8@8'],
      [
        'Lat Pulldown',
        '3',
        '90s',
        '',
        'x10@8',
        '',
        '',
        'Upper',
        'TRUE',
        'x',
        '100x10@8',
      ],
      ['Row', '3', '2 min', '', 'x10@8', '', '', 'Upper', '', 'x', '120x10@8'],
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

  testWidgets('workout home combines selection and the full exercise list', (
    tester,
  ) async {
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

    expect(find.text('Exercises'), findsOneWidget);
    expect(find.text('Bulgarian Split Squat'), findsOneWidget);
    expect(find.text('Reverse Lunge'), findsOneWidget);
  });

  testWidgets('back from adding to a selected workout returns to workout', (
    tester,
  ) async {
    final activeSheet = parseActiveSheet(
      ActiveSheetInput(
        rows: [
          [...activeSheetFixedColumns, 'Week 1'],
          [...List.filled(activeSheetFixedColumns.length, ''), 'S1'],
          ['Pull Up', '3', '2 min', '', '8', '', '{Reps}', 'Legs', '', 'x', ''],
        ],
        cellFormulas: const [
          CellFormula(
            sheetRowNumber: 3,
            sheetColumnNumber: 1,
            formula: '=Exercises!A2',
          ),
          CellFormula(
            sheetRowNumber: 3,
            sheetColumnNumber: 7,
            formula: '=Exercises!G2',
          ),
        ],
        exercisesRows: const [
          exercisesSheetColumns,
          [
            'Pull Up',
            'Bodyweight pull',
            '3',
            '2 min',
            '2-1-1',
            'Full hang.',
            '{Reps}',
            '8',
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
    await tester.tap(find.byKey(const ValueKey('add-primary-exercise')));
    await tester.pumpAndSettle();

    expect(find.text('Add to workout'), findsWidgets);
    expect(find.byTooltip('Back'), findsOneWidget);

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('workout-home')), findsOneWidget);
    expect(find.text('Exercises'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('spreadsheet-selection-input')),
      findsNothing,
    );
  });

  testWidgets('auto-scrolls while reordering a long workout list', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 500);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final rows = <List<String>>[
      [...activeSheetFixedColumns, 'Week 1'],
      [...List.filled(activeSheetFixedColumns.length, ''), 'S1'],
      for (var i = 1; i <= 20; i++)
        [
          'Exercise $i',
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

    final handle = find.byTooltip('Reorder Exercise 1');
    final gesture = await tester.startGesture(tester.getCenter(handle));
    await tester.pump();
    await gesture.moveBy(const Offset(0, 500));
    await tester.pump(const Duration(milliseconds: 200));
    await gesture.moveBy(const Offset(0, 50));
    for (var tick = 0; tick < 20; tick++) {
      await tester.pump(const Duration(milliseconds: 51));
    }
    await gesture.up();
    await tester.pumpAndSettle();

    expect(authoringService.reorderIntents, hasLength(1));
    expect(authoringService.reorderIntents.single.fromIndex, 0);
    expect(authoringService.reorderIntents.single.toIndex, greaterThan(3));
  });

  testWidgets(
    'shows creation actions in selectors and selects created values',
    (tester) async {
      final service = TestValSvc.fromRows([
        [...activeSheetFixedColumns, 'Week 1'],
        [...List.filled(activeSheetFixedColumns.length, ''), 'S1'],
        ['Squat', '3', '3 min', '', 'x5@8', '', '', 'Legs', '', 'x', ''],
      ]);

      await tester.pumpWidget(
        WorkoutTrackerApp(svc: service, initialText: 'spreadsheet-id'),
      );

      await tester.tap(find.byKey(const ValueKey('validate-spreadsheet')));
      await tester.pump();
      await tester.pump();

      expect(find.byKey(const ValueKey('add-workout')), findsNothing);
      expect(find.byKey(const ValueKey('add-history-block')), findsNothing);

      await tester.tap(find.text('Legs').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add workout...').last);
      await tester.pumpAndSettle();

      await tester.enterText(textFieldWithLabel('Workout name'), 'Push');
      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();

      expect(find.text('Push'), findsOneWidget);
      expect(find.text('0/0'), findsOneWidget);

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
      expect(find.text('Week 2'), findsOneWidget);
    },
  );

  testWidgets('duplicate history errors dismiss and do not follow navigation', (
    tester,
  ) async {
    final service = TestValSvc.fromRows([
      [...activeSheetFixedColumns, 'Week 1'],
      [...List.filled(activeSheetFixedColumns.length, ''), 'S1'],
      ['Squat', '3', '3 min', '', 'x5@8', '', '', 'Legs', '', 'x', ''],
    ]);

    await tester.pumpWidget(
      WorkoutTrackerApp(svc: service, initialText: 'spreadsheet-id'),
    );
    await tester.tap(find.byKey(const ValueKey('validate-spreadsheet')));
    await tester.pump();
    await tester.pump();

    Future<void> createDuplicate() async {
      await tester.tap(find.text('Week 1').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add history block...').last);
      await tester.pumpAndSettle();
      await tester.enterText(
        textFieldWithLabel('History block label'),
        'Week 1',
      );
      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();
    }

    await createDuplicate();
    expect(find.text('History block already exists'), findsOneWidget);
    expect(find.text('Week 1 already exists.'), findsOneWidget);
    expect(find.text('Connection or validation failed'), findsNothing);

    await tester.tap(find.bySemanticsLabel('Dismiss error'));
    await tester.pump();
    expect(find.text('History block already exists'), findsNothing);

    await createDuplicate();
    expect(find.text('History block already exists'), findsOneWidget);
    await tester.tap(find.text('Squat'));
    await tester.pumpAndSettle();

    expect(find.text('Save set S1'), findsOneWidget);
    expect(find.text('History block already exists'), findsNothing);
    expect(find.text('Week 1 already exists.'), findsNothing);
  });
}
