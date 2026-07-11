import 'package:flutter/material.dart';
import 'package:workout_tracker/contract.dart';

import 'exercise_form.dart';
import 'ui/view.dart';

final class EditExerciseView extends LoadedView {
  const EditExerciseView({
    required super.isBusy,
    required super.sheetLabel,
    required this.exercise,
    super.error,
  });

  final CanonicalExercise exercise;
}

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
    return ExerciseAuthoringScreen(
      a11yLabel: 'Edit exercise ${view.exercise.displayName}',
      title: 'Edit exercise',
      sheetLabel: view.sheetLabel,
      backTooltip: 'Back to edit exercises',
      mode: ExerciseFormMode.edit,
      initialDraft: CanonicalExerciseDraft.fromExercise(view.exercise),
      isBusy: view.isBusy,
      onClose: actions.close,
      onSave: actions.save,
    );
  }
}
