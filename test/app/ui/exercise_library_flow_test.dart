import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_tracker/contract.dart';
import 'package:workout_tracker/app.dart';

import '../service_fake.dart';
import '../../support/widget.dart';

void main() {
  testWidgets('opens an exercise manager inventory in canonical sheet order', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final service = TestValSvc(
      exerciseInventoryParsedSheet([
        exerciseRow('Squat', description: 'Back squat'),
        exerciseRow('Bench Press', description: 'Competition bench'),
        exerciseRow('Cable Row', description: 'Seated cable row'),
      ]),
    );

    await tester.pumpWidget(
      WorkoutTrackerApp(svc: service, initialText: 'spreadsheet-id'),
    );

    await tester.tap(find.byKey(const ValueKey('validate-spreadsheet')));
    await tester.pump();
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('open-exercise-manager')));
    await tester.pumpAndSettle();

    expect(find.text('Edit exercises'), findsWidgets);
    expect(find.byTooltip('Back to workout'), findsOneWidget);
    expect(find.byTooltip('Create exercise'), findsOneWidget);
    expect(find.text('Squat'), findsOneWidget);
    expect(find.text('Back squat'), findsOneWidget);
    expect(find.byTooltip('Edit Squat'), findsOneWidget);
    expect(find.text('Bench Press'), findsOneWidget);
    expect(find.text('Competition bench'), findsOneWidget);
    expect(find.byTooltip('Edit Bench Press'), findsOneWidget);
    expect(find.text('Cable Row'), findsOneWidget);
    expect(find.text('Seated cable row'), findsOneWidget);
    expect(find.byTooltip('Edit Cable Row'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Squat')).dy,
      lessThan(tester.getTopLeft(find.text('Bench Press')).dy),
    );
    expect(
      tester.getTopLeft(find.text('Bench Press')).dy,
      lessThan(tester.getTopLeft(find.text('Cable Row')).dy),
    );
  });

  testWidgets(
    'adds a canonical exercise from the exercise manager and returns to the updated list',
    (tester) async {
      final validationService = TestValSvc(
        exerciseInventoryParsedSheet([
          exerciseRow('Squat', description: 'Back squat'),
        ]),
      );
      final authoringService = AppendingExerciseAuthoringService([
        exerciseRow('Squat', description: 'Back squat'),
      ]);

      await tester.pumpWidget(
        WorkoutTrackerApp(
          svc: CompositeWorkbookCommandService(
            validation: validationService,
            authoring: authoringService,
          ),
          initialText: 'spreadsheet-id',
        ),
      );

      await tester.tap(find.byKey(const ValueKey('validate-spreadsheet')));
      await tester.pump();
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('open-exercise-manager')));
      await tester.pumpAndSettle();

      expect(find.text('Squat'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('add-canonical-exercise')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const ValueKey('add-canonical-exercise')));
      await tester.pumpAndSettle();

      expect(find.text('New exercise'), findsWidgets);
      expect(find.byTooltip('Back'), findsOneWidget);

      await tester.enterText(
        find.byKey(const ValueKey('exercise-authoring-name')),
        'Romanian Deadlift',
      );
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -500));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const ValueKey('exercise-authoring-submit')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('exercise-authoring-submit')));
      await tester.pumpAndSettle();

      expect(authoringService.createdExercises, [
        const ExerciseDef(
          exercise: 'Romanian Deadlift',
          defaultSets: '3',
          defaultReps: '10',
          defaultRpe: '8',
          defaultRest: '2 min',
          logFormat: '{Weight}[x]{Reps}[@]{RPE}',
        ),
      ]);
      expect(find.text('Edit exercises'), findsWidgets);
      expect(find.text('Squat'), findsOneWidget);
      expect(find.text('Romanian Deadlift'), findsOneWidget);
      expect(find.text('New exercise'), findsNothing);
    },
  );

  testWidgets('keeps an edited exercise visible in a long library', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final seededExercises = [
      for (var index = 1; index <= 24; index += 1)
        exerciseRow(
          'Seeded Exercise ${index.toString().padLeft(2, '0')}',
          description: 'Seeded library item $index',
        ),
    ];
    final validationService = TestValSvc(
      exerciseInventoryParsedSheet(seededExercises),
    );
    final authoringService = EditingExerciseAuthoringService(seededExercises);

    await tester.pumpWidget(
      WorkoutTrackerApp(
        svc: CompositeWorkbookCommandService(
          validation: validationService,
          authoring: authoringService,
        ),
        initialText: 'spreadsheet-id',
      ),
    );

    await tester.tap(find.byKey(const ValueKey('validate-spreadsheet')));
    await tester.pump();
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('open-exercise-manager')));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Seeded Exercise 24'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Seeded Exercise 24'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('exercise-authoring-name')),
      'Custom Rope Row',
    );
    await tester.ensureVisible(
      find.byKey(const ValueKey('exercise-authoring-submit')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('exercise-authoring-submit')));
    await tester.pumpAndSettle();

    expect(find.text('Custom Rope Row'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('saved-exercise-highlight')),
      findsOneWidget,
    );
    final highlightRect = tester.getRect(
      find.byKey(const ValueKey('saved-exercise-highlight')),
    );
    expect(highlightRect.top, greaterThanOrEqualTo(0));
    expect(highlightRect.bottom, lessThanOrEqualTo(844));
  });

  testWidgets(
    'edits a canonical exercise from the exercise manager without creating a duplicate',
    (tester) async {
      final validationService = TestValSvc(
        exerciseInventoryParsedSheet([
          exerciseRow('Squat', description: 'Back squat'),
          exerciseRow('Bench Press', description: 'Competition bench'),
        ]),
      );
      final authoringService = EditingExerciseAuthoringService([
        exerciseRow('Squat', description: 'Back squat'),
        exerciseRow('Bench Press', description: 'Competition bench'),
      ]);

      await tester.pumpWidget(
        WorkoutTrackerApp(
          svc: CompositeWorkbookCommandService(
            validation: validationService,
            authoring: authoringService,
          ),
          initialText: 'spreadsheet-id',
        ),
      );

      await tester.tap(find.byKey(const ValueKey('validate-spreadsheet')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('open-exercise-manager')));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Squat'));
      await tester.pumpAndSettle();

      expect(find.text('Edit exercise'), findsWidgets);
      expect(find.byTooltip('Back to edit exercises'), findsOneWidget);
      expect(find.text('Squat'), findsOneWidget);
      expect(find.text('Back squat'), findsOneWidget);

      await tester.enterText(
        find.byKey(const ValueKey('exercise-authoring-name')),
        'High Bar Squat',
      );
      await tester.enterText(
        find.byKey(const ValueKey('exercise-authoring-description')),
        'High bar back squat',
      );
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -500));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const ValueKey('exercise-authoring-submit')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('exercise-authoring-submit')));
      await tester.pumpAndSettle();

      expect(authoringService.createdExercises, isEmpty);
      expect(authoringService.updatedExercises, [
        (
          row: 2,
          exercise: const ExerciseDef(
            exercise: 'High Bar Squat',
            description: 'High bar back squat',
            defaultSets: '3',
            defaultReps: '10',
            defaultRpe: '8',
            defaultRest: '2 min',
            logFormat: '{Weight}[x]{Reps}[@]{RPE}',
          ),
        ),
      ]);
      expect(find.text('Edit exercises'), findsWidgets);
      expect(find.text('High Bar Squat'), findsOneWidget);
      expect(find.text('High bar back squat'), findsOneWidget);
      expect(find.text('Squat'), findsNothing);
      expect(find.text('Bench Press'), findsOneWidget);
      expect(authoringService.exerciseCount, 2);
    },
  );

  testWidgets('canceling exercise manager edit leaves the exercise unchanged', (
    tester,
  ) async {
    final validationService = TestValSvc(
      exerciseInventoryParsedSheet([
        exerciseRow('Squat', description: 'Back squat'),
        exerciseRow('Bench Press', description: 'Competition bench'),
      ]),
    );
    final authoringService = EditingExerciseAuthoringService([
      exerciseRow('Squat', description: 'Back squat'),
      exerciseRow('Bench Press', description: 'Competition bench'),
    ]);

    await tester.pumpWidget(
      WorkoutTrackerApp(
        svc: CompositeWorkbookCommandService(
          validation: validationService,
          authoring: authoringService,
        ),
        initialText: 'spreadsheet-id',
      ),
    );

    await tester.tap(find.byKey(const ValueKey('validate-spreadsheet')));
    await tester.pump();
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('open-exercise-manager')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Squat'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('exercise-authoring-name')),
      'High Bar Squat',
    );
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -500));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Discard changes?'), findsOneWidget);
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();

    expect(authoringService.updatedExercises, isEmpty);
    expect(authoringService.createdExercises, isEmpty);
    expect(find.text('Edit exercises'), findsWidgets);
    expect(find.text('Squat'), findsOneWidget);
    expect(find.text('Back squat'), findsOneWidget);
    expect(find.text('High Bar Squat'), findsNothing);
    expect(authoringService.exerciseCount, 2);
  });

  testWidgets('does not expose delete controls in the exercise manager', (
    tester,
  ) async {
    final service = TestValSvc(
      exerciseInventoryParsedSheet([
        exerciseRow('Squat', description: 'Back squat'),
      ]),
    );

    await tester.pumpWidget(
      WorkoutTrackerApp(svc: service, initialText: 'spreadsheet-id'),
    );

    await tester.tap(find.byKey(const ValueKey('validate-spreadsheet')));
    await tester.pump();
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('open-exercise-manager')));
    await tester.pumpAndSettle();

    expect(find.text('Squat'), findsOneWidget);
    expect(find.textContaining('delete', findRichText: true), findsNothing);
    expect(find.textContaining('Delete', findRichText: true), findsNothing);
    expect(find.byTooltip('Delete exercise'), findsNothing);
    expect(find.byIcon(Icons.delete_outline), findsNothing);
    expect(find.byType(Dismissible), findsNothing);
    expect(find.byType(PopupMenuButton), findsNothing);
  });

  testWidgets('reorders canonical exercises from the exercise manager', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final exercises = [
      exerciseRow('Squat', description: 'Back squat'),
      exerciseRow('Bench Press', description: 'Competition bench'),
      exerciseRow('Cable Row', description: 'Seated cable row'),
    ];
    final validationService = TestValSvc(
      exerciseInventoryParsedSheet(exercises),
    );
    final authoringService = ReorderingExerciseAuthoringService(exercises);

    await tester.pumpWidget(
      WorkoutTrackerApp(
        svc: CompositeWorkbookCommandService(
          validation: validationService,
          authoring: authoringService,
        ),
        initialText: 'spreadsheet-id',
      ),
    );

    await tester.tap(find.byKey(const ValueKey('validate-spreadsheet')));
    await tester.pump();
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('open-exercise-manager')));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Reorder Squat'), findsOneWidget);
    expect(find.byIcon(Icons.drag_handle_outlined), findsNWidgets(3));

    await tester.drag(find.byTooltip('Reorder Squat'), const Offset(0, 170));
    await tester.pumpAndSettle();

    expect(authoringService.reorderIntents, [
      const ReorderIntent(fromIndex: 0, toIndex: 2),
    ]);
    expect(
      tester.getTopLeft(find.text('Bench Press')).dy,
      lessThan(tester.getTopLeft(find.text('Cable Row')).dy),
    );
    expect(
      tester.getTopLeft(find.text('Cable Row')).dy,
      lessThan(tester.getTopLeft(find.text('Squat')).dy),
    );
  });
}
