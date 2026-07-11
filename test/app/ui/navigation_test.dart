import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_tracker/app.dart';
import 'package:workout_tracker/contract.dart';

import '../service_fake.dart';

void main() {
  testWidgets('workout home is the selected workout exercise list', (
    tester,
  ) async {
    await _openWorkout(tester);

    expect(find.text('Legs exercises'), findsOneWidget);
    expect(find.text('Squat'), findsOneWidget);
    expect(find.text('Select'), findsNothing);
  });

  testWidgets('workout and history choices refresh the visible list', (
    tester,
  ) async {
    await _openRows(tester, [
      [...activeSheetFixedColumns, 'Week 2', 'Week 1'],
      [...List.filled(activeSheetFixedColumns.length, ''), 'S1', 'S1'],
      ['Squat', '3', '5', '8', '3 min', '', '', '', 'Legs', '', '', '225x5@8'],
      [
        'Bench Press',
        '3',
        '5',
        '8',
        '3 min',
        '',
        '',
        '',
        'Upper',
        '',
        '135x5@8',
        '',
      ],
    ]);

    expect(find.text('Squat'), findsOneWidget);
    expect(find.text('0 sets'), findsOneWidget);

    await tester.tap(find.text('Legs (0/1 started)').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Upper (1/1 started)').last);
    await tester.pumpAndSettle();

    expect(find.text('Squat'), findsNothing);
    expect(find.text('Bench Press'), findsOneWidget);
    expect(find.text('1 set'), findsOneWidget);

    await tester.tap(find.text('Week 2').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Week 1').last);
    await tester.pumpAndSettle();

    expect(find.text('Bench Press'), findsOneWidget);
    expect(find.text('0 sets'), findsOneWidget);
  });

  testWidgets('native back pops logging before leaving workout home', (
    tester,
  ) async {
    await _openWorkout(tester);
    await tester.tap(find.text('Squat'));
    await tester.pumpAndSettle();

    expect(find.text('Next set S1'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('Legs exercises'), findsOneWidget);
    expect(find.text('Next set S1'), findsNothing);
  });

  testWidgets('native back returns the exercise library to workout home', (
    tester,
  ) async {
    await _openWorkout(tester);
    await tester.tap(find.byKey(const ValueKey('open-exercise-manager')));
    await tester.pumpAndSettle();

    expect(find.text('Edit exercises'), findsWidgets);
    expect(find.bySemanticsLabel('Search exercises'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('Legs exercises'), findsOneWidget);
    expect(find.bySemanticsLabel('Search exercises'), findsNothing);
  });

  testWidgets('feature history preserves library as create origin', (
    tester,
  ) async {
    await _openWorkout(tester);
    await tester.tap(find.byKey(const ValueKey('open-exercise-manager')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('add-canonical-exercise')));
    await tester.pumpAndSettle();

    expect(find.text('New exercise'), findsWidgets);
    expect(find.text('Save exercise'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('Edit exercises'), findsWidgets);
    expect(find.text('Save exercise'), findsNothing);
  });

  testWidgets(
    'dirty authoring guards native back before returning to library',
    (tester) async {
      await _openWorkout(tester);
      await tester.tap(find.byKey(const ValueKey('open-exercise-manager')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('add-canonical-exercise')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('exercise-authoring-name')),
        'Draft',
      );
      await tester.pump();

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(find.text('Discard changes?'), findsOneWidget);
      expect(find.text('Save exercise'), findsOneWidget);

      await tester.tap(find.text('Discard'));
      await tester.pumpAndSettle();

      expect(find.text('Edit exercises'), findsWidgets);
      expect(find.text('Save exercise'), findsNothing);
    },
  );

  testWidgets('native back returns edit to the launching library', (
    tester,
  ) async {
    await _openWorkout(tester);
    await tester.tap(find.byKey(const ValueKey('open-exercise-manager')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Squat'));
    await tester.pumpAndSettle();

    expect(find.text('Edit exercise'), findsWidgets);
    expect(find.text('Save exercise'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('Edit exercises'), findsWidgets);
    expect(find.text('Save exercise'), findsNothing);
  });

  testWidgets('native back returns placement to the launching workout home', (
    tester,
  ) async {
    await _openWorkout(tester);
    await tester.tap(find.byKey(const ValueKey('add-primary-exercise')));
    await tester.pumpAndSettle();

    expect(find.text('Add to workout'), findsWidgets);
    expect(find.text('Choose exercise'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('Legs exercises'), findsOneWidget);
    expect(find.text('Choose exercise'), findsNothing);
  });

  testWidgets('sheet selection is the workout home parent', (tester) async {
    await _openWorkout(tester);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('spreadsheet-selection-input')),
      findsOneWidget,
    );
  });
}

Future<void> _openWorkout(WidgetTester tester) async {
  final sheet = parseActiveSheet(
    ActiveSheetInput(
      rows: [
        [...activeSheetFixedColumns, 'Week 1'],
        [...List.filled(activeSheetFixedColumns.length, ''), 'S1'],
        ['Squat', '3', '5', '8', '3 min', '', '', '', 'Legs', '', ''],
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
        ['Squat', 'Back squat', '3', '5', '8', '3 min', '', '', ''],
      ],
    ),
  );
  await _openService(tester, TestValSvc(sheet));
}

Future<void> _openRows(WidgetTester tester, List<List<String>> rows) async {
  await _openService(tester, TestValSvc.fromRows(rows));
}

Future<void> _openService(WidgetTester tester, WbkAccess svc) async {
  await tester.pumpWidget(
    WorkoutTrackerApp(svc: svc, initialText: 'spreadsheet-id'),
  );
  await tester.tap(find.byKey(const ValueKey('validate-spreadsheet')));
  await tester.pumpAndSettle();
}
