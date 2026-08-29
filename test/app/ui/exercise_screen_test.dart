import 'dart:ui' show SemanticsAction;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_tracker/app.dart';
import 'package:workout_tracker/contract.dart';

import '../../support/widget.dart';

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
          view: EditExerciseView(
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
        view: EditExerciseView(
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

  testWidgets('exercise fields expose arrows in declaration order', (
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

    Future<void> advance(String label) async {
      final arrow = find.bySemanticsLabel('Next field $label');
      expect(arrow, findsOneWidget);
      await tester.ensureVisible(arrow);
      await tester.pumpAndSettle();
      await tester.tap(arrow);
      await tester.pumpAndSettle();
    }

    await tester.tap(find.byKey(const ValueKey('exercise-authoring-name')));
    await tester.pump();
    await advance('Description');
    await advance('Default sets');
    await advance('Default tempo');
    await advance('Default rest');
    await advance('Log format');
    await advance('Default Weight');
    await advance('Default Reps');
    await advance('Default RPE');
    await advance('Notes');

    expect(find.byIcon(Icons.arrow_forward), findsNothing);
    expect(tester.testTextInput.isVisible, isTrue);
  });

  testWidgets('valid formats show syntax help and current-value preview', (
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
    expect(find.textContaining('{Weight (lbs)}'), findsOneWidget);
    expect(find.textContaining('numeric defaults'), findsOneWidget);
    expect(find.textContaining('units belong in field names'), findsOneWidget);
    expect(find.text('Preview: x10@8'), findsOneWidget);

    await tester.enterText(format, '({A},{b}){C c}-{D (kg)}/{E}');
    await tester.pump();

    for (final entry in const {
      'A': '1',
      'b': '2',
      'C c': '3',
      'D (kg)': '4',
      'E': '5',
    }.entries) {
      await tester.enterText(
        find.byKey(ValueKey('exercise-authoring-default-${entry.key}')),
        entry.value,
      );
      await tester.pump();
    }

    expect(find.textContaining('all other text is literal'), findsOneWidget);
    expect(find.text('Preview: (1,2)3-4/5'), findsOneWidget);
    expect(find.bySemanticsLabel('Default A'), findsWidgets);
    expect(find.bySemanticsLabel('Default b'), findsWidgets);
    expect(find.bySemanticsLabel('Default C c'), findsWidgets);
    expect(find.bySemanticsLabel('Default D (kg)'), findsWidgets);
    expect(find.bySemanticsLabel('Default E'), findsWidgets);
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
    await tester.enterText(format, '{Weightx{Reps}');
    await tester.pump();

    expect(find.text('Field labels cannot contain braces.'), findsOneWidget);
    expect(find.textContaining('Preview:'), findsNothing);

    final save = find.text('Save exercise');
    await tester.ensureVisible(save);
    await tester.pumpAndSettle();
    await tester.tap(save);
    await tester.pump();
    expect(actions.saved, isNull);
  });

  testWidgets('one Timer heading names a checkbox for every declared field', (
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

    expect(find.text('Timer'), findsOneWidget);
    expect(
      tester.getSemantics(find.bySemanticsLabel('Timer').first),
      isSemantics(label: 'Timer', isHeader: true),
    );
    for (final label in const ['Weight', 'Reps', 'RPE']) {
      expect(
        tester.getSemantics(find.bySemanticsLabel('Timer $label').first),
        isSemantics(
          label: 'Timer $label',
          hasCheckedState: true,
          isChecked: false,
          hasEnabledState: true,
          isEnabled: true,
          hasTapAction: true,
        ),
      );
    }

    final format = find.byKey(const ValueKey('exercise-authoring-log-format'));
    await tester.ensureVisible(format);
    await tester.pumpAndSettle();
    await tester.enterText(format, '({A},{b}){C c}-{D (kg)}/{E}');
    await tester.pump();

    expect(find.text('Timer'), findsOneWidget);
    expect(find.bySemanticsLabel('Timer Weight'), findsNothing);
    const declared = ['A', 'b', 'C c', 'D (kg)', 'E'];
    var previous = tester.getTopLeft(find.bySemanticsLabel('Timer A').first);
    for (final label in declared.skip(1)) {
      final next = tester.getTopLeft(
        find.bySemanticsLabel('Timer $label').first,
      );
      expect(
        next.dy > previous.dy ||
            (next.dy == previous.dy && next.dx > previous.dx),
        isTrue,
        reason: 'Timer $label must read after the field declared before it.',
      );
      previous = next;
    }
  });

  testWidgets('timer selections save in Log Format declaration order', (
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
      'Loaded Carry',
    );
    for (final label in const ['RPE', 'Weight']) {
      final box = find.bySemanticsLabel('Timer $label').first;
      await tester.ensureVisible(box);
      await tester.pumpAndSettle();
      await tester.tap(box);
      await tester.pumpAndSettle();
    }

    final save = find.text('Save exercise');
    await tester.ensureVisible(save);
    await tester.pumpAndSettle();
    await tester.tap(save);
    await tester.pump();

    expect(actions.saved?.timerFields, ['Weight', 'RPE']);
  });

  testWidgets('timer checkboxes stay usable on a narrow large-text phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 1400);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });

    final actions = _CreateActions();
    await tester.pumpWidget(
      _app(
        CreateExerciseScreen(
          view: const CreateExerciseView(isBusy: false, sheetLabel: 'Training'),
          actions: actions,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    final reps = find.bySemanticsLabel('Timer Reps').first;
    await tester.ensureVisible(reps);
    await tester.pumpAndSettle();
    await tester.tap(reps);
    await tester.pumpAndSettle();

    expect(
      tester.getSemantics(find.bySemanticsLabel('Timer Reps').first),
      isSemantics(label: 'Timer Reps', hasCheckedState: true, isChecked: true),
    );
    await expectFlutterAccessibilityGuidelines(tester);
  });

  testWidgets('editing an exercise keeps its canonical Timer Fields', (
    tester,
  ) async {
    final actions = _EditActions();
    await tester.pumpWidget(
      _app(
        EditExerciseScreen(
          view: EditExerciseView(
            isBusy: false,
            sheetLabel: 'Training',
            exercise: CanonicalExercise(
              sheetRowNumber: 2,
              exercise: 'Side Plank',
              logFormat: '{Seconds}s@{RPE}',
              timerFields: const ['Seconds'],
            ),
          ),
          actions: actions,
        ),
      ),
    );

    final notes = find.byKey(const ValueKey('exercise-authoring-notes'));
    await tester.scrollUntilVisible(
      notes,
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.enterText(notes, 'Keep hips stacked.');
    await tester.pump();
    final save = find.text('Save exercise');
    await tester.ensureVisible(save);
    await tester.pumpAndSettle();
    await tester.tap(save);
    await tester.pump();

    expect(actions.saved?.notes, 'Keep hips stacked.');
    expect(actions.saved?.timerFields, ['Seconds']);
  });

  testWidgets('a Log Format change cannot save a timer label it removed', (
    tester,
  ) async {
    final actions = _EditActions();
    await tester.pumpWidget(
      _app(
        EditExerciseScreen(
          view: EditExerciseView(
            isBusy: false,
            sheetLabel: 'Training',
            exercise: CanonicalExercise(
              sheetRowNumber: 2,
              exercise: 'Side Plank',
              logFormat: '{Seconds}s@{RPE}',
              timerFields: const ['Seconds'],
            ),
          ),
          actions: actions,
        ),
      ),
    );

    expect(find.text('Timer'), findsOneWidget);
    expect(
      tester.getSemantics(find.bySemanticsLabel('Timer Seconds').first),
      isSemantics(
        label: 'Timer Seconds',
        hasCheckedState: true,
        isChecked: true,
      ),
    );
    expect(
      tester.getSemantics(find.bySemanticsLabel('Timer RPE').first),
      isSemantics(label: 'Timer RPE', hasCheckedState: true, isChecked: false),
    );

    final rpe = find.bySemanticsLabel('Timer RPE').first;
    await tester.ensureVisible(rpe);
    await tester.pumpAndSettle();
    await tester.tap(rpe);
    await tester.pumpAndSettle();

    final format = find.byKey(const ValueKey('exercise-authoring-log-format'));
    await tester.ensureVisible(format);
    await tester.pumpAndSettle();
    await tester.enterText(format, '{Reps}@{RPE}');
    await tester.pump();

    expect(find.bySemanticsLabel('Timer Seconds'), findsNothing);
    expect(find.bySemanticsLabel('Timer Reps'), findsOneWidget);

    await tester.drag(find.byType(Scrollable).first, const Offset(0, -200));
    await tester.pumpAndSettle();
    final save = find.text('Save exercise');
    await tester.ensureVisible(save);
    await tester.pumpAndSettle();
    await tester.tap(save);
    await tester.pump();

    expect(actions.saved?.logFormat, '{Reps}@{RPE}');
    expect(actions.saved?.timerFields, ['RPE']);
    expect(actions.saved?.renderedTimerFields, "['RPE']");
  });

  testWidgets('invalid formats cannot update an exercise', (tester) async {
    final actions = _EditActions();
    await tester.pumpWidget(
      _app(
        EditExerciseScreen(
          view: EditExerciseView(
            isBusy: false,
            sheetLabel: 'Training',
            exercise: CanonicalExercise(
              sheetRowNumber: 2,
              exercise: 'Squat',
              logFormat: '{Weight}x{Reps}@{RPE}',
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
      final view = EditExerciseView(
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
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -100));
      await tester.pumpAndSettle();
      await tester.ensureVisible(cancel);
      await tester.pumpAndSettle();
      await tester.tap(cancel);
      await tester.pumpAndSettle();

      expect(find.text('Discard changes?'), findsOneWidget);
      expect(changed.closed, isFalse);
    },
  );

  testWidgets(
    'format review names placements and unchanged raw-history impact accessibly',
    (tester) async {
      const oldFormat = '({Height (in)})x{Reps}@{RPE},{Pain}';
      const newFormat = '({Height (in)}, {Weight (lbs)})x{Reps}@{RPE},{Pain}';
      final sheet = parseActiveSheet(
        ActiveSheetInput(
          rows: const [
            [...activeSheetFixedColumns, 'Week 1'],
            ['', '', '', '', '', '', '', '', '', '', 'S1'],
            [
              'DB Step-Up',
              '3',
              '2 min',
              '2-1-1',
              '(14)x10@7,0',
              '',
              oldFormat,
              'Legs',
              '',
              'x',
              '(12)x8@8,0',
            ],
          ],
          exercisesRows: const [
            exercisesSheetColumns,
            [
              'DB Step-Up',
              '',
              '3',
              '2 min',
              '2-1-1',
              '',
              oldFormat,
              '(12)x8@8,0',
            ],
          ],
          cellFormulas: const [
            CellFormula(
              sheetRowNumber: 3,
              sheetColumnNumber: 1,
              formula: '=Exercises!A2',
            ),
          ],
        ),
      );
      final impact = sheet.inspectFormatUpdate(
        selectedExercise: sheet.canonicalExercises.single,
        exercise: ExerciseDef(
          exercise: 'DB Step-Up',
          logFormat: newFormat,
          defaultValues: const {
            'Height (in)': '12',
            'Weight (lbs)': '15',
            'Reps': '8',
            'RPE': '8',
            'Pain': '0',
          },
        ),
      )!;
      final actions = _EditActions();

      await tester.pumpWidget(
        _app(
          EditExerciseScreen(
            view: EditExerciseView(
              isBusy: false,
              sheetLabel: 'Training',
              exercise: sheet.canonicalExercises.single,
              formatImpact: impact,
            ),
            actions: actions,
          ),
        ),
      );

      expect(find.bySemanticsLabel('Review exercise format change'), findsOne);
      expect(find.text('1 placement will receive reviewed Targets.'), findsOne);
      expect(
        find.text(
          '1 existing history entry will become raw text. '
          'History will remain unchanged and editable.',
        ),
        findsOne,
      );
      expect(find.text('Row 3 · Legs · Primary'), findsOne);
      expect(find.text('Current Targets: (14)x10@7,0'), findsOne);
      expect(find.bySemanticsLabel('Row 3 Height (in)'), findsOne);
      expect(find.bySemanticsLabel('Row 3 Weight (lbs)'), findsOne);

      await tester.enterText(
        find.byKey(const ValueKey('format-update-3-Weight (lbs)')),
        '20',
      );
      await tester.pump();
      expect(find.bySemanticsLabel('Next field Row 3 Reps'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('Next field Row 3 Reps'));
      await tester.pump();
      expect(find.bySemanticsLabel('Next field Row 3 RPE'), findsOneWidget);
      final confirm = find.byKey(const ValueKey('confirm-format-update'));
      await tester.scrollUntilVisible(
        confirm,
        400,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -240));
      await tester.pumpAndSettle();
      await tester.tap(confirm);
      await tester.pump();

      expect(actions.confirmed![3]!['Weight (lbs)'], '20');
    },
  );

  testWidgets('returning from format review preserves the proposed draft', (
    tester,
  ) async {
    const format = '({Height (in)}, {Weight (lbs)})x{Reps}@{RPE},{Pain}';
    await tester.pumpWidget(
      _app(
        EditExerciseScreen(
          view: EditExerciseView(
            isBusy: false,
            sheetLabel: 'Training',
            exercise: CanonicalExercise(
              sheetRowNumber: 2,
              exercise: 'DB Step-Up',
              logFormat: '({Height (in)})x{Reps}@{RPE},{Pain}',
            ),
            pendingExercise: ExerciseDef(
              exercise: 'DB Step-Up',
              logFormat: format,
              defaultValues: const {
                'Height (in)': '12',
                'Weight (lbs)': '15',
                'Reps': '8',
                'RPE': '8',
                'Pain': '0',
              },
            ),
          ),
          actions: _EditActions(),
        ),
      ),
    );

    final formatField = find.byKey(
      const ValueKey('exercise-authoring-log-format'),
    );
    await tester.scrollUntilVisible(
      formatField,
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await _expectInput(tester, formatField, format);
    await _expectInput(
      tester,
      find.byKey(const ValueKey('exercise-authoring-default-Weight (lbs)')),
      '15',
    );
  });
}

void _expectPending(WidgetTester tester) {
  _expectDisabled(tester, find.bySemanticsLabel('Exercise name'));
  _expectDisabled(tester, find.bySemanticsLabel('Timer Weight'));
  _expectDisabled(tester, find.widgetWithText(OutlinedButton, 'Cancel'));
  _expectDisabled(tester, find.widgetWithText(FilledButton, 'Save exercise'));
  expect(
    tester.getSemantics(find.bySemanticsLabel('Timer Weight').first),
    isSemantics(
      label: 'Timer Weight',
      hasCheckedState: true,
      isChecked: false,
      hasEnabledState: true,
      isEnabled: false,
    ),
  );
  expect(find.byType(CircularProgressIndicator), findsOneWidget);
}

void _expectDisabled(WidgetTester tester, Finder control) {
  final semantics = tester.getSemantics(control.first).getSemanticsData();
  expect(semantics.hasAction(SemanticsAction.tap), isFalse);
}

Future<void> _expectInput(
  WidgetTester tester,
  Finder field,
  String value,
) async {
  await tester.ensureVisible(field);
  await tester.tap(field);
  await tester.pump();
  expect(tester.testTextInput.editingState, containsPair('text', value));
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
  Map<int, Map<String, String>>? confirmed;
  bool closed = false;

  @override
  Future<void> close() async => closed = true;

  @override
  Future<bool> save(ExerciseDef exercise) async {
    saved = exercise;
    return true;
  }

  @override
  Future<bool> confirmFormatUpdate(
    Map<int, Map<String, String>> valuesByRow,
  ) async {
    confirmed = valuesByRow;
    return true;
  }

  @override
  void cancelFormatUpdate() {}
}
