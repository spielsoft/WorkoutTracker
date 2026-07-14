import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_tracker/app.dart';
import 'package:workout_tracker/contract.dart';
import 'package:workout_tracker/sheets.dart';

void main() {
  testWidgets('places five DB Step-Up targets from the new workbook', (
    tester,
  ) async {
    final workbook = await loadWbkTmpl();
    final sheet = parseActiveSheet(
      ActiveSheetInput(
        rows: [
          workbook.activeSheet.rows.single,
          List.filled(activeSheetFixedColumns.length, ''),
        ],
        exercisesRows: workbook.exercisesSheet.rows,
        validateWorkbook: true,
        schemaVersion: '1.0',
      ),
    );
    final stepUp = sheet.canonicalExercises.singleWhere(
      (exercise) => exercise.exercise == 'DB Step-Up',
    );
    final actions = _Actions();

    await tester.pumpWidget(
      _app(
        PlacementScreen(
          view: PlacementView(
            isBusy: false,
            sheetLabel: 'Training',
            intent: const PlaceIntent.primary(workout: 'Legs'),
            exercises: [stepUp],
          ),
          actions: actions,
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('existing-exercise-selector')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('DB Step-Up').last);
    await tester.pumpAndSettle();

    const targets = {
      'Height (in)': '12',
      'Weight (lbs)': '15',
      'Reps': '8',
      'RPE': '8',
      'Pain': '0',
    };
    for (final entry in targets.entries) {
      final field = find.byKey(ValueKey('placement-target-${entry.key}'));
      expect(field, findsOneWidget);
      final textField = find.descendant(
        of: field,
        matching: find.byType(TextField),
      );
      expect(tester.widget<TextField>(textField).controller?.text, entry.value);
    }

    await tester.ensureVisible(
      find.byKey(const ValueKey('place-existing-exercise')),
    );
    await tester.tap(find.byKey(const ValueKey('place-existing-exercise')));

    expect(actions.placed.single.metadata.targetValues, targets);
    final plan = sheet.planPrimaryPlacement(
      exercise: stepUp,
      workout: 'Legs',
      metadata: actions.placed.single.metadata,
    );
    expect(
      plan.cellUpdates,
      contains(
        const CellUpdate(
          sheetRowNumber: 3,
          sheetColumnNumber: 5,
          value: '(12, 15)x8@8,0',
        ),
      ),
    );
  });

  testWidgets('placement exposes selected exercise dynamic targets', (
    tester,
  ) async {
    final actions = _Actions();
    await tester.pumpWidget(
      _app(
        PlacementScreen(
          view: PlacementView(
            isBusy: false,
            sheetLabel: 'Training',
            intent: const PlaceIntent.primary(workout: 'Core'),
            exercises: [
              CanonicalExercise(
                sheetRowNumber: 2,
                exercise: 'Side Plank',
                defaultSets: '2',
                defaultRest: '45s',
                defaultTempo: 'hold',
                logFormat: '{Seconds}@{RPE}',
                defaultValues: const {'Seconds': '30', 'RPE': '8'},
              ),
            ],
          ),
          actions: actions,
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('existing-exercise-selector')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Side Plank').last);
    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextField, 'Sets'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Rest'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Tempo'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Seconds'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'RPE'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Reps'), findsNothing);

    await tester.enterText(find.widgetWithText(TextField, 'Seconds'), '45');
    await tester.ensureVisible(
      find.byKey(const ValueKey('place-existing-exercise')),
    );
    await tester.tap(find.byKey(const ValueKey('place-existing-exercise')));

    expect(actions.placed.single.exercise, 'Side Plank');
    expect(actions.placed.single.metadata.targetValues, {
      'Seconds': '45',
      'RPE': '8',
    });
  });

  testWidgets('placement keeps the format routed by a declared 0.9 workbook', (
    tester,
  ) async {
    const oldFormat = '{Seconds}[s}@]{RPE}';
    final sheet = parseActiveSheet(
      ActiveSheetInput(
        rows: [
          activeSheetFixedColumns,
          List.filled(activeSheetFixedColumns.length, ''),
        ],
        exercisesRows: const [
          exercisesSheetColumns,
          ['Side Plank', '', '2', '45s', 'hold', '', oldFormat, '30s}@8'],
        ],
        validateWorkbook: true,
        schemaVersion: '0.9',
      ),
    );
    final exercise = sheet.canonicalExercises.single;

    expect(sheet.schemaViolations, isEmpty);
    expect((exercise.format as ParsedLogFormat).literalSegments, ['s}@']);
    await tester.pumpWidget(
      _app(
        PlacementScreen(
          view: PlacementView(
            isBusy: false,
            sheetLabel: 'Training',
            intent: const PlaceIntent.primary(workout: 'Core'),
            exercises: [exercise],
          ),
          actions: _Actions(),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('existing-exercise-selector')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Side Plank').last);
    await tester.pumpAndSettle();

    final seconds = tester.widget<TextField>(
      find.widgetWithText(TextField, 'Seconds'),
    );
    final rpe = tester.widget<TextField>(find.widgetWithText(TextField, 'RPE'));
    expect(seconds.controller?.text, '30');
    expect(rpe.controller?.text, '8');
  });

  testWidgets('backup placement identifies its parent and supports creation', (
    tester,
  ) async {
    final actions = _Actions();
    await tester.pumpWidget(
      _app(
        PlacementScreen(
          view: const PlacementView(
            isBusy: false,
            sheetLabel: 'Training',
            intent: PlaceIntent.backup(
              workout: 'Legs',
              primaryRow: 3,
              primaryExercise: 'Squat',
            ),
            exercises: [],
          ),
          actions: actions,
        ),
      ),
    );

    expect(find.text('Backup for Squat'), findsOneWidget);
    expect(find.text('Legs workout'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey('create-exercise-from-placement')),
    );
    expect(actions.createCount, 1);
  });
}

Widget _app(Widget child) {
  return MaterialApp(
    theme: ThemeData.dark(),
    home: Scaffold(body: SingleChildScrollView(child: child)),
  );
}

class _Actions implements PlacementActions {
  final placed = <({String exercise, WorkoutPlacementMetadata metadata})>[];
  int createCount = 0;

  @override
  Future<void> close() async {}

  @override
  Future<void> create() async => createCount += 1;

  @override
  Future<bool> place(
    CanonicalExercise exercise,
    WorkoutPlacementMetadata metadata, {
    bool keepAdding = false,
  }) async {
    placed.add((exercise: exercise.exercise, metadata: metadata));
    return true;
  }
}
