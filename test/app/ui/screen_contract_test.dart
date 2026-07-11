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
      _boundedApp(
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
      _boundedApp(
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

    expect(find.text('Open log'), findsNothing);
    await tester.tap(find.text('Squat'));

    expect((actions.seen.single as OpenWorkoutLog).primaryRow, 3);
  });

  testWidgets('workout list auto-scrolls while reordering at an edge', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 500);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(
      _boundedApp(
        WorkoutScreen(
          view: WorkoutView(
            isBusy: false,
            setup: _longSetup(),
            sheetLabel: 'Training',
          ),
          actions: _WorkoutActions(),
        ),
      ),
    );

    final scrollable = find.descendant(
      of: find.byType(WorkoutScreen),
      matching: find.byType(Scrollable),
    );
    final position = tester.state<ScrollableState>(scrollable).position;
    final handle = find.byTooltip('Reorder Exercise 1');
    final gesture = await tester.startGesture(tester.getCenter(handle));
    await tester.pump();
    await gesture.moveBy(const Offset(0, 500));
    await tester.pump(const Duration(milliseconds: 200));
    await gesture.moveBy(const Offset(0, 50));
    for (var tick = 0; tick < 20; tick++) {
      await tester.pump(const Duration(milliseconds: 51));
    }

    expect(position.pixels, greaterThan(0));
    await gesture.up();
  });

  testWidgets('exercise library auto-scrolls while reordering at an edge', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 500);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final actions = _LibraryActions();
    final exercises = [
      for (var index = 0; index < 20; index++)
        CanonicalExercise(
          sheetRowNumber: index + 2,
          exercise: 'Exercise ${index + 1}',
        ),
    ];
    await tester.pumpWidget(
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
              actions: actions,
            ),
          ),
        ),
      ),
    );

    final scrollable = find.descendant(
      of: find.byType(ExerciseLibraryScreen),
      matching: find.byType(Scrollable),
    );
    final position = tester.state<ScrollableState>(scrollable).position;
    final handle = find.byTooltip('Reorder Exercise 1');
    final gesture = await tester.startGesture(tester.getCenter(handle));
    await tester.pump();
    await gesture.moveBy(const Offset(0, 500));
    await tester.pump(const Duration(milliseconds: 200));
    await gesture.moveBy(const Offset(0, 50));
    for (var tick = 0; tick < 20; tick++) {
      await tester.pump(const Duration(milliseconds: 51));
    }

    expect(position.pixels, greaterThan(0));
    await gesture.up();
  });

  testWidgets('workout execution exposes typed backup and back actions', (
    tester,
  ) async {
    final actions = _WorkoutActions();
    await tester.pumpWidget(
      _boundedApp(
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

  testWidgets('exercise library exposes only library actions', (tester) async {
    final actions = _LibraryActions();
    await tester.pumpWidget(
      _boundedApp(
        ExerciseLibraryScreen(
          view: LibraryView(
            isBusy: false,
            exercises: _setup().activeSheet.canonicalExercises,
            sheetLabel: 'Training',
            highlightedRow: null,
          ),
          actions: actions,
        ),
      ),
    );

    await tester.tap(find.text('Squat'));
    expect(actions.edited.single.exercise, 'Squat');

    await tester.tap(find.byTooltip('Back to workout setup'));
    expect(actions.closed, isTrue);

    await tester.tap(find.byTooltip('Create exercise'));
    expect(actions.created, isTrue);
  });

  testWidgets('exercise creation exposes only create actions', (tester) async {
    final actions = _CreateActions();
    await tester.pumpWidget(
      _app(
        CreateExerciseScreen(
          view: CreateExerciseView(
            isBusy: false,
            sheetLabel: 'Training',
            origin: CreateOrigin.library,
          ),
          actions: actions,
        ),
      ),
    );

    await tester.enterText(
      find.bySemanticsLabel('Exercise name'),
      'Romanian Deadlift',
    );
    final submit = find.text('Save exercise');
    await tester.scrollUntilVisible(
      submit,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(submit);

    expect(actions.saved!.exercise, 'Romanian Deadlift');
  });

  testWidgets('blank exercise defaults keep their labels on the border', (
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
    final field = find.byKey(
      const ValueKey('exercise-authoring-default-tempo'),
    );
    await tester.scrollUntilVisible(
      field,
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    final fieldRect = tester.getRect(field);
    final labelRect = tester.getRect(find.text('Default tempo'));
    expect(labelRect.center.dy, lessThan(fieldRect.top + 18));
  });

  testWidgets('exercise editing exposes only edit actions', (tester) async {
    final actions = _EditActions();
    final exercise = _setup().activeSheet.canonicalExercises.single;
    await tester.pumpWidget(
      _app(
        EditExerciseScreen(
          view: EditExerciseView(
            isBusy: false,
            sheetLabel: 'Training',
            exercise: exercise,
          ),
          actions: actions,
        ),
      ),
    );

    await tester.enterText(
      find.bySemanticsLabel('Exercise name'),
      'Front Squat',
    );
    final submit = find.text('Save exercise');
    await tester.scrollUntilVisible(
      submit,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(submit);

    expect(actions.saved!.exercise, 'Front Squat');
  });

  testWidgets('placement emits selected exercise metadata', (tester) async {
    final actions = _PlacementActions();
    await tester.pumpWidget(
      _app(
        PlacementScreen(
          view: PlacementView(
            isBusy: false,
            exercises: _setup().activeSheet.canonicalExercises,
            sheetLabel: 'Training',
            intent: const PlaceIntent.primary(workout: 'Legs'),
            origin: PlaceOrigin.workout,
          ),
          actions: actions,
        ),
      ),
    );

    await tester.tap(
      find.widgetWithText(
        DropdownButtonFormField<CanonicalExercise>,
        'Choose exercise',
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Squat').last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Add to workout'));

    expect(actions.exercise!.exercise, 'Squat');
    expect(actions.metadata!.sets, '3');
    expect(actions.metadata!.reps, '5');
  });
}

final class _LibraryActions implements LibraryActions {
  final edited = <CanonicalExercise>[];
  bool closed = false;
  bool created = false;

  @override
  Future<void> close() async => closed = true;

  @override
  Future<void> create() async => created = true;

  @override
  Future<void> edit(CanonicalExercise exercise) async => edited.add(exercise);

  @override
  Future<bool> reorder(ReorderIntent intent) async => true;
}

final class _CreateActions implements CreateExerciseActions {
  ExerciseDef? saved;

  @override
  Future<void> close() async {}

  @override
  Future<bool> save(ExerciseDef exercise) async {
    saved = exercise;
    return true;
  }
}

final class _EditActions implements EditExerciseActions {
  ExerciseDef? saved;

  @override
  Future<void> close() async {}

  @override
  Future<bool> save(ExerciseDef exercise) async {
    saved = exercise;
    return true;
  }
}

final class _PlacementActions implements PlacementActions {
  CanonicalExercise? exercise;
  WorkoutPlacementMetadata? metadata;

  @override
  Future<void> close() async {}

  @override
  Future<bool> place(
    CanonicalExercise exercise,
    WorkoutPlacementMetadata metadata, {
    bool keepAdding = false,
  }) async {
    this.exercise = exercise;
    this.metadata = metadata;
    return true;
  }
}

final class _SetupActions implements SetupActions {
  final seen = <SetupAction>[];

  @override
  Future<void> setup(SetupAction action) async {
    seen.add(action);
  }

  @override
  Future<bool> reorder(ReorderIntent intent) async => true;
}

final class _WorkoutActions implements WorkoutActions {
  final seen = <WorkoutAction>[];

  @override
  Future<void> workout(WorkoutAction action) async {
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

Widget _boundedApp(Widget child) {
  return MaterialApp(
    home: Scaffold(
      body: Padding(padding: const EdgeInsets.all(24), child: child),
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

WorkoutSetupReadModel _longSetup() {
  final setup = _setup();
  return WorkoutSetupReadModel(
    activeSheet: setup.activeSheet,
    workouts: setup.workouts,
    historyBlocks: setup.historyBlocks,
    selectedWorkout: setup.selectedWorkout,
    selectedHistoryBlock: setup.selectedHistoryBlock,
    overview: WorkoutOverview(
      workout: 'Legs',
      slots: [
        for (var index = 0; index < 20; index++)
          WorkoutOverviewSlot(
            sheetRowNumber: index + 3,
            exercise: 'Exercise ${index + 1}',
            setCount: 3,
          ),
      ],
    ),
    progressByWorkout: setup.progressByWorkout,
    loggingTarget: null,
  );
}
