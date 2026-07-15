import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_tracker/app.dart';
import 'package:workout_tracker/contract.dart';

void main() {
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

    Future<void> advance(String label) async {
      final arrow = find.bySemanticsLabel('Next field $label');
      expect(arrow, findsOneWidget);
      await tester.ensureVisible(arrow);
      await tester.pumpAndSettle();
      await tester.tap(arrow);
      await tester.pumpAndSettle();
    }

    await tester.tap(find.widgetWithText(TextField, 'Sets'));
    await tester.pump();
    await advance('Rest');
    await advance('Tempo');
    await advance('Notes');
    await advance('Seconds');
    await advance('RPE');
    expect(find.byIcon(Icons.arrow_forward), findsNothing);

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
