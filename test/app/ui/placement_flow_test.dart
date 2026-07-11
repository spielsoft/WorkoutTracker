import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_tracker/contract.dart';
import 'package:workout_tracker/app.dart';

import '../service_fake.dart';
import '../../support/widget.dart';

void main() {
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
      final store = MemoryAppStStore(
        null,
        selectedSheet: const SelectedSheet(
          spreadsheetId: 'selected-spreadsheet-id',
          name: '2026 Workouts',
          drivePath: 'My Drive / Workouts / 2026 Workouts',
          accountEmail: 'saved@example.com',
        ),
      );
      final service = TestValSvc(activeSheet);
      final authoringService = WorkoutPlacementRecordingService(activeSheet);

      await tester.pumpWidget(
        WorkoutTrackerApp(
          svc: CompositeWorkbookCommandService(
            validation: service,
            authoring: authoringService,
          ),
          appStStore: store,
          picker: FakeSheetPicker(),
        ),
      );
      await tester.pump();
      await tester.pump();

      await tester.tap(find.text('Week 2'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Week 1').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Legs (0/1 started)').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Upper (0/1 started)').last);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('add-primary-exercise')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('exercise-picker-search')),
        'romanian',
      );
      await tester.pump();

      expect(find.byTooltip('Back'), findsOneWidget);
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();

      expect(find.text('Upper exercises'), findsOneWidget);
      expect(find.text('Week 1'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('spreadsheet-selection-input')),
        findsNothing,
      );
      expect(find.text('Return to workout'), findsNothing);

      await tester.tap(find.byKey(const ValueKey('add-primary-exercise')));
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
    final service = TestValSvc(activeSheet);

    await tester.pumpWidget(
      WorkoutTrackerApp(svc: service, initialText: 'spreadsheet-id'),
    );

    await tester.tap(find.byKey(const ValueKey('validate-spreadsheet')));
    await tester.pump();
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('add-primary-exercise')));
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
    final service = TestValSvc(activeSheet);
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
    await tester.tap(find.byKey(const ValueKey('add-primary-exercise')));
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
    final service = TestValSvc(activeSheet);

    await tester.pumpWidget(
      WorkoutTrackerApp(svc: service, initialText: 'spreadsheet-id'),
    );

    await tester.tap(find.byKey(const ValueKey('validate-spreadsheet')));
    await tester.pump();
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('add-primary-exercise')));
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
}
