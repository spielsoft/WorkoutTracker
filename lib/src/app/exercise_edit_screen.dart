import 'package:flutter/material.dart';
import 'package:workout_tracker/contract.dart';

import 'exercise_form.dart';
import 'ui/flow.dart';
import 'ui/shared/a11y.dart';
import 'ui/shared/header.dart';

abstract interface class EditExerciseActions {
  Future<void> close();

  Future<bool> save(ExerciseDef exercise);
}

class EditExerciseScreen extends StatelessWidget {
  const EditExerciseScreen({
    required this.view,
    required this.actions,
    super.key,
  });

  final EditExerciseView view;
  final EditExerciseActions actions;

  @override
  Widget build(BuildContext context) {
    return A11yScreen(
      label: 'Edit exercise ${view.exercise.displayName}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ScreenHeader(
            title: view.sheetLabel,
            subtitle: 'Edit exercise',
            compactTitle: true,
            backTooltip: 'Back to edit exercises',
            onBack: actions.close,
          ),
          const SizedBox(height: 16),
          ExerciseAuthoringForm(
            authoringContext: ExerciseAuthoringContext.canonicalExercise,
            initialDraft: CanonicalExerciseDraft.fromExercise(view.exercise),
            onCancel: actions.close,
            onSubmit: (draft) => actions.save(draft.toDef()),
          ),
        ],
      ),
    );
  }
}
