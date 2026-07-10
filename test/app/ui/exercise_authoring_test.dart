import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_tracker/contract.dart';
import 'package:workout_tracker/app.dart';

import '../service_fake.dart';
import '../../support/widget.dart';

void main() {
  testWidgets(
    'keeps exercise authoring text entry tied to each labeled field',
    (tester) async {
      final semantics = tester.ensureSemantics();
      try {
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
        await tester.tap(find.byKey(const ValueKey('add-canonical-exercise')));
        await tester.pumpAndSettle();

        for (final identifier in const [
          'exercise-authoring-name',
          'exercise-authoring-description',
          'exercise-authoring-default-sets',
          'exercise-authoring-default-reps',
          'exercise-authoring-default-rpe',
          'exercise-authoring-default-rest',
          'exercise-authoring-default-tempo',
          'exercise-authoring-log-format',
          'exercise-authoring-notes',
        ]) {
          expect(find.bySemanticsIdentifier(identifier), findsOneWidget);
        }

        Future<void> enterField(String label, String value) async {
          final field = textFieldWithLabel(label);
          await tester.ensureVisible(field);
          await tester.pumpAndSettle();
          await tester.enterText(field, value);
          await tester.pump();
          expect(
            tester
                .widget<EditableText>(
                  find.descendant(
                    of: field,
                    matching: find.byType(EditableText),
                  ),
                )
                .controller
                .text,
            value,
          );
        }

        await enterField('Exercise name', 'Romanian Deadlift');
        await enterField('Description', 'Hip hinge');
        await enterField('Default sets', '4');
        await enterField('Default reps', '8-10');
        await enterField('Default RPE', '7.5');
        await enterField('Default rest', '90s');
        await enterField('Default tempo', '3-1-1');
        await enterField('Log format', '{Weight}[x]{Reps}');
        await enterField('Notes', 'Use straps after warmups.');

        await tester.ensureVisible(
          find.byKey(const ValueKey('exercise-authoring-submit')),
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const ValueKey('exercise-authoring-submit')),
        );
        await tester.pump();
        await tester.pump();

        expect(authoringService.createdExercises, [
          const ExerciseDef(
            exercise: 'Romanian Deadlift',
            description: 'Hip hinge',
            defaultSets: '4',
            defaultReps: '8-10',
            defaultRpe: '7.5',
            defaultRest: '90s',
            defaultTempo: '3-1-1',
            notes: 'Use straps after warmups.',
            logFormat: '{Weight}[x]{Reps}',
          ),
        ]);
      } finally {
        semantics.dispose();
      }
    },
  );
}
