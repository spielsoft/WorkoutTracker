import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_tracker/app.dart';
import 'package:workout_tracker/contract.dart';

void main() {
  testWidgets('search matches names and descriptions in canonical order', (
    tester,
  ) async {
    await _pumpLibrary(
      tester,
      exercises: const [
        CanonicalExercise(
          sheetRowNumber: 2,
          exercise: 'Overhead Press',
          description: 'Standing shoulder work',
        ),
        CanonicalExercise(
          sheetRowNumber: 3,
          exercise: 'Bench Press',
          description: 'Competition chest press',
        ),
        CanonicalExercise(
          sheetRowNumber: 4,
          exercise: 'Cable Row',
          description: 'PRESSing balance for the upper back',
        ),
        CanonicalExercise(
          sheetRowNumber: 5,
          exercise: 'Back Squat',
          description: 'Knee-dominant leg work',
        ),
      ],
    );

    await tester.enterText(find.bySemanticsLabel('Search exercises'), 'pReSs');
    await tester.pump();

    expect(find.text('Overhead Press'), findsOneWidget);
    expect(find.text('Bench Press'), findsOneWidget);
    expect(find.text('Cable Row'), findsOneWidget);
    expect(find.text('Back Squat'), findsNothing);
    expect(
      tester.getTopLeft(find.text('Overhead Press')).dy,
      lessThan(tester.getTopLeft(find.text('Bench Press')).dy),
    );
    expect(
      tester.getTopLeft(find.text('Bench Press')).dy,
      lessThan(tester.getTopLeft(find.text('Cable Row')).dy),
    );
  });

  testWidgets('empty search explains the result and clear restores browsing', (
    tester,
  ) async {
    final exercises = [
      for (var i = 1; i <= 20; i += 1)
        CanonicalExercise(
          sheetRowNumber: i + 1,
          exercise: 'Exercise $i',
          description: 'Library item $i',
        ),
    ];
    await _pumpLibrary(tester, exercises: exercises);

    await tester.enterText(
      find.bySemanticsLabel('Search exercises'),
      'not in this library',
    );
    await tester.pump();

    expect(find.text('No exercises matched your search.'), findsOneWidget);
    expect(
      find.text('Try another name or description, or clear the search.'),
      findsOneWidget,
    );

    await tester.tap(find.byTooltip('Clear exercise search'));
    await tester.pump();

    expect(find.text('No exercises matched your search.'), findsNothing);
    expect(find.text('Exercise 1'), findsOneWidget);
    expect(find.text('Exercise 2'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Exercise 1')).dy,
      lessThan(tester.getTopLeft(find.text('Exercise 2')).dy),
    );
    await tester.scrollUntilVisible(
      find.text('Exercise 20'),
      300,
      scrollable: find.byWidgetPredicate(
        (widget) =>
            widget is Scrollable && widget.axisDirection == AxisDirection.down,
      ),
    );
    expect(find.text('Exercise 20'), findsOneWidget);
  });

  testWidgets('filtered library cannot expose or emit reorder commands', (
    tester,
  ) async {
    final actions = _Actions();
    await _pumpLibrary(
      tester,
      actions: actions,
      exercises: const [
        CanonicalExercise(sheetRowNumber: 2, exercise: 'Squat'),
        CanonicalExercise(sheetRowNumber: 3, exercise: 'Bench Press'),
        CanonicalExercise(sheetRowNumber: 4, exercise: 'Cable Row'),
      ],
    );

    await tester.enterText(find.bySemanticsLabel('Search exercises'), 'press');
    await tester.pump();

    expect(find.byTooltip('Reorder Bench Press'), findsNothing);
    await tester.drag(find.text('Bench Press'), const Offset(0, 120));
    await tester.pumpAndSettle();
    expect(actions.reorders, isEmpty);

    await tester.tap(find.byTooltip('Clear exercise search'));
    await tester.pump();
    expect(find.byTooltip('Reorder Bench Press'), findsOneWidget);
  });
}

Future<void> _pumpLibrary(
  WidgetTester tester, {
  required List<CanonicalExercise> exercises,
  _Actions? actions,
}) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: ExerciseLibraryScreen(
            view: LibraryView(
              isBusy: false,
              exercises: exercises,
              sheetLabel: 'Training',
              highlightedRow: null,
            ),
            actions: actions ?? _Actions(),
          ),
        ),
      ),
    ),
  );
}

final class _Actions implements LibraryActions {
  final reorders = <ReorderIntent>[];

  @override
  Future<void> close() async {}

  @override
  Future<void> create() async {}

  @override
  Future<void> edit(CanonicalExercise exercise) async {}

  @override
  Future<bool> reorder(ReorderIntent intent) async {
    reorders.add(intent);
    return true;
  }
}
