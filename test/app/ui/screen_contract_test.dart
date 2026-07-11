import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_tracker/app.dart';
import 'package:workout_tracker/contract.dart';

void main() {
  testWidgets('workout setup emits its typed selection command', (
    tester,
  ) async {
    final actions = _SetupActions();
    await tester.pumpWidget(
      _app(
        SetupScreen(
          view: SetupView(
            isBusy: false,
            setup: _setup(),
            sheetLabel: 'Training',
          ),
          actions: actions,
        ),
      ),
    );

    await tester.tap(find.text('Select'));

    expect(actions.seen.single, const OpenSelectedWorkout());
  });

  testWidgets('workout execution emits only its typed actions', (tester) async {
    final actions = _WorkoutActions();
    await tester.pumpWidget(
      _app(
        WorkoutScreen(
          view: WorkoutView(
            isBusy: false,
            setup: _setup(),
            sheetLabel: 'Training',
          ),
          actions: actions,
        ),
      ),
    );

    await tester.tap(find.text('Squat'));

    expect((actions.seen.single as OpenWorkoutLog).primaryRow, 3);
  });

  testWidgets('workout execution exposes typed backup and back actions', (
    tester,
  ) async {
    final actions = _WorkoutActions();
    await tester.pumpWidget(
      _app(
        WorkoutScreen(
          view: WorkoutView(
            isBusy: false,
            setup: _setup(),
            sheetLabel: 'Training',
          ),
          actions: actions,
        ),
      ),
    );

    await tester.tap(find.byTooltip('Exercise actions for Squat'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add backup exercise'));
    await tester.pumpAndSettle();

    expect((actions.seen.single as AddWorkoutBackup).slot.exercise, 'Squat');

    actions.seen.clear();
    await tester.tap(find.byTooltip('Back to workout setup'));

    expect(actions.seen.single, const BackToWorkoutSetup());
  });

  testWidgets('exercise library emits only exercise commands', (tester) async {
    final cmds = <ExerciseCmd>[];
    await tester.pumpWidget(
      _app(
        ExerciseLibraryScreen(
          view: LibraryView(
            isBusy: false,
            setup: _setup(),
            sheetLabel: 'Training',
            highlightedRow: null,
          ),
          run: (cmd) async {
            cmds.add(cmd);
            return const CmdResult.done();
          },
        ),
      ),
    );

    await tester.tap(find.text('Squat'));
    expect(cmds.single, isA<OpenExerciseEdit>());

    cmds.clear();
    await tester.tap(find.byTooltip('Back to workout setup'));
    expect(cmds.single, isA<CloseLibrary>());
  });

  testWidgets('placement emits selected exercise metadata', (tester) async {
    final cmds = <ExerciseCmd>[];
    await tester.pumpWidget(
      _app(
        PlacementScreen(
          view: PlacementView(
            isBusy: false,
            setup: _setup(),
            sheetLabel: 'Training',
            intent: const PlaceIntent.primary(workout: 'Legs'),
            returnRoute: AppRoute.workout,
          ),
          run: (cmd) async {
            cmds.add(cmd);
            return const CmdResult.done();
          },
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('existing-exercise-selector')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Squat').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('place-existing-exercise')));

    final save = cmds.single as SavePlacement;
    expect(save.exercise.exercise, 'Squat');
    expect(save.metadata.sets, '3');
    expect(save.metadata.reps, '5');
  });
}

final class _SetupActions implements SetupActions {
  final seen = <SetupAction>[];

  @override
  Future<void> run(SetupAction action) async {
    seen.add(action);
  }

  @override
  Future<bool> reorder(ReorderIntent intent) async => true;
}

final class _WorkoutActions implements WorkoutActions {
  final seen = <WorkoutAction>[];

  @override
  Future<void> run(WorkoutAction action) async {
    seen.add(action);
  }

  @override
  Future<bool> reorder(ReorderIntent intent) async => true;
}

Widget _app(Widget child) {
  return MaterialApp(
    home: Scaffold(
      body: ListView(padding: const EdgeInsets.all(24), children: [child]),
    ),
  );
}

WorkoutSetupReadModel _setup() {
  final active = parseActiveSheet(
    ActiveSheetInput(
      rows: [
        [...activeSheetFixedColumns, 'Week 1'],
        [...List.filled(activeSheetFixedColumns.length, ''), 'S1'],
        ['Squat', '3', '5', '8', '3 min', '', '', '', 'Legs', '', ''],
      ],
      exercisesRows: const [
        exercisesSheetColumns,
        ['Squat', 'Back squat', '3', '5', '8', '3 min', '', '', ''],
      ],
    ),
  );
  return WorkoutSetupReadModel(
    activeSheet: active,
    workouts: const ['Legs'],
    historyBlocks: active.historyBlocks,
    selectedWorkout: 'Legs',
    selectedHistoryBlock: 'Week 1',
    overview: active.buildWorkoutOverview(
      workout: 'Legs',
      blockLabel: 'Week 1',
    ),
    progressByWorkout: const {'Legs': WorkoutSetupProgress(done: 0, total: 3)},
    loggingTarget: null,
  );
}
