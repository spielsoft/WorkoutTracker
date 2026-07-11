import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_tracker/app.dart';
import 'package:workout_tracker/contract.dart';

void main() {
  testWidgets('exercise forms identify whether they create or edit', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        CreateExerciseScreen(
          view: const CreateExerciseView(
            isBusy: false,
            sheetLabel: 'Training',
            origin: CreateOrigin.library,
          ),
          actions: _CreateActions(),
        ),
      ),
    );

    expect(find.text('New exercise'), findsWidgets);
    expect(find.text('Edit exercise'), findsNothing);

    await tester.pumpWidget(
      _app(
        EditExerciseScreen(
          view: const EditExerciseView(
            isBusy: false,
            sheetLabel: 'Training',
            exercise: CanonicalExercise(sheetRowNumber: 2, exercise: 'Squat'),
          ),
          actions: _EditActions(),
        ),
      ),
    );

    expect(find.text('Edit exercise'), findsWidgets);
    expect(find.text('New exercise'), findsNothing);
  });

  testWidgets('exercise creation blocks changes while saving', (tester) async {
    await tester.pumpWidget(
      _app(
        CreateExerciseScreen(
          view: const CreateExerciseView(
            isBusy: true,
            sheetLabel: 'Training',
            origin: CreateOrigin.library,
          ),
          actions: _CreateActions(),
        ),
      ),
    );

    _expectPending(tester);
  });

  testWidgets('exercise editing blocks changes while saving', (tester) async {
    await tester.pumpWidget(
      _app(
        EditExerciseScreen(
          view: const EditExerciseView(
            isBusy: true,
            sheetLabel: 'Training',
            exercise: CanonicalExercise(sheetRowNumber: 2, exercise: 'Squat'),
          ),
          actions: _EditActions(),
        ),
      ),
    );

    _expectPending(tester);
  });
}

void _expectPending(WidgetTester tester) {
  final name = tester.widget<TextFormField>(
    find.byKey(const ValueKey('exercise-authoring-name')),
  );
  final cancel = tester.widget<OutlinedButton>(
    find.widgetWithText(OutlinedButton, 'Cancel'),
  );
  final save = tester.widget<FilledButton>(
    find.widgetWithText(FilledButton, 'Save exercise'),
  );

  expect(name.enabled, isFalse);
  expect(cancel.onPressed, isNull);
  expect(save.onPressed, isNull);
  expect(find.byType(CircularProgressIndicator), findsOneWidget);
}

Widget _app(Widget child) {
  return MaterialApp(
    home: Scaffold(
      body: ListView(padding: const EdgeInsets.all(24), children: [child]),
    ),
  );
}

final class _CreateActions implements CreateExerciseActions {
  @override
  Future<void> close() async {}

  @override
  Future<bool> save(ExerciseDef exercise) async => true;
}

final class _EditActions implements EditExerciseActions {
  @override
  Future<void> close() async {}

  @override
  Future<bool> save(ExerciseDef exercise) async => true;
}
