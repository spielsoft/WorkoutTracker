import 'dart:ui' show SemanticsAction;

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
          view: const CreateExerciseView(isBusy: false, sheetLabel: 'Training'),
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

  testWidgets('exercise forms expose saving state and disable changes', (
    tester,
  ) async {
    final screens = <Widget>[
      CreateExerciseScreen(
        view: const CreateExerciseView(isBusy: true, sheetLabel: 'Training'),
        actions: _CreateActions(),
      ),
      EditExerciseScreen(
        view: const EditExerciseView(
          isBusy: true,
          sheetLabel: 'Training',
          exercise: CanonicalExercise(sheetRowNumber: 2, exercise: 'Squat'),
        ),
        actions: _EditActions(),
      ),
    ];

    for (final screen in screens) {
      await tester.pumpWidget(_app(screen));
      _expectPending(tester);
    }
  });

  testWidgets('valid formats show syntax help and a representative preview', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        CreateExerciseScreen(
          view: const CreateExerciseView(isBusy: false, sheetLabel: 'Training'),
          actions: _CreateActions(),
        ),
      ),
    );

    final format = find.byKey(const ValueKey('exercise-authoring-log-format'));
    await tester.scrollUntilVisible(
      format,
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Use {Field}'), findsOneWidget);
    expect(find.text('Preview: 100x8@8'), findsOneWidget);
  });

  testWidgets('invalid formats show feedback and cannot create an exercise', (
    tester,
  ) async {
    final actions = _CreateActions();
    await tester.pumpWidget(
      _app(
        CreateExerciseScreen(
          view: const CreateExerciseView(isBusy: false, sheetLabel: 'Training'),
          actions: actions,
        ),
      ),
    );

    await tester.enterText(
      find.byKey(const ValueKey('exercise-authoring-name')),
      'Broken exercise',
    );
    final format = find.byKey(const ValueKey('exercise-authoring-log-format'));
    await tester.scrollUntilVisible(
      format,
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.enterText(format, '{Weight[x]{Reps}');
    await tester.pump();

    expect(find.text('Field labels cannot contain brackets.'), findsOneWidget);
    expect(find.textContaining('Preview:'), findsNothing);

    final save = find.text('Save exercise');
    await tester.ensureVisible(save);
    await tester.pumpAndSettle();
    await tester.tap(save);
    await tester.pump();
    expect(actions.saved, isNull);
  });

  testWidgets('invalid formats cannot update an exercise', (tester) async {
    final actions = _EditActions();
    await tester.pumpWidget(
      _app(
        EditExerciseScreen(
          view: const EditExerciseView(
            isBusy: false,
            sheetLabel: 'Training',
            exercise: CanonicalExercise(
              sheetRowNumber: 2,
              exercise: 'Squat',
              logFormat: '{Weight}[x]{Reps}[@]{RPE}',
            ),
          ),
          actions: actions,
        ),
      ),
    );

    final format = find.byKey(const ValueKey('exercise-authoring-log-format'));
    await tester.scrollUntilVisible(
      format,
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.enterText(format, 'Weight x Reps');
    await tester.pump();
    final save = find.text('Save exercise');
    await tester.ensureVisible(save);
    await tester.pumpAndSettle();
    await tester.tap(save);
    await tester.pump();

    expect(actions.saved, isNull);
  });

  testWidgets('changed create drafts require explicit discard confirmation', (
    tester,
  ) async {
    final actions = _CreateActions();
    await tester.pumpWidget(
      _app(
        CreateExerciseScreen(
          view: const CreateExerciseView(isBusy: false, sheetLabel: 'Training'),
          actions: actions,
        ),
      ),
    );

    await tester.enterText(
      find.byKey(const ValueKey('exercise-authoring-name')),
      'Draft exercise',
    );
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();

    expect(find.text('Discard changes?'), findsOneWidget);
    expect(actions.closed, isFalse);
    await tester.tap(find.text('Keep editing'));
    await tester.pumpAndSettle();
    expect(actions.closed, isFalse);

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();
    expect(actions.closed, isTrue);
  });

  testWidgets(
    'changed edit drafts require confirmation but unchanged forms close',
    (tester) async {
      final unchanged = _EditActions();
      final view = const EditExerciseView(
        isBusy: false,
        sheetLabel: 'Training',
        exercise: CanonicalExercise(sheetRowNumber: 2, exercise: 'Squat'),
      );
      await tester.pumpWidget(
        _app(EditExerciseScreen(view: view, actions: unchanged)),
      );

      await tester.tap(find.byTooltip('Back to edit exercises'));
      await tester.pump();
      expect(unchanged.closed, isTrue);
      expect(find.text('Discard changes?'), findsNothing);

      final changed = _EditActions();
      await tester.pumpWidget(
        _app(EditExerciseScreen(view: view, actions: changed)),
      );
      await tester.enterText(
        find.byKey(const ValueKey('exercise-authoring-name')),
        'Front Squat',
      );
      final cancel = find.widgetWithText(OutlinedButton, 'Cancel');
      await tester.ensureVisible(cancel);
      await tester.pumpAndSettle();
      await tester.tap(cancel);
      await tester.pumpAndSettle();

      expect(find.text('Discard changes?'), findsOneWidget);
      expect(changed.closed, isFalse);
    },
  );
}

void _expectPending(WidgetTester tester) {
  _expectDisabled(tester, find.bySemanticsLabel('Exercise name'));
  _expectDisabled(tester, find.widgetWithText(OutlinedButton, 'Cancel'));
  _expectDisabled(tester, find.widgetWithText(FilledButton, 'Save exercise'));
  expect(find.byType(CircularProgressIndicator), findsOneWidget);
}

void _expectDisabled(WidgetTester tester, Finder control) {
  final semantics = tester.getSemantics(control.first).getSemanticsData();
  expect(semantics.hasAction(SemanticsAction.tap), isFalse);
}

Widget _app(Widget child) {
  return MaterialApp(
    home: Scaffold(
      body: ListView(padding: const EdgeInsets.all(24), children: [child]),
    ),
  );
}

final class _CreateActions implements CreateExerciseActions {
  ExerciseDef? saved;
  bool closed = false;

  @override
  Future<void> close() async => closed = true;

  @override
  Future<bool> save(ExerciseDef exercise) async {
    saved = exercise;
    return true;
  }
}

final class _EditActions implements EditExerciseActions {
  ExerciseDef? saved;
  bool closed = false;

  @override
  Future<void> close() async => closed = true;

  @override
  Future<bool> save(ExerciseDef exercise) async {
    saved = exercise;
    return true;
  }
}
