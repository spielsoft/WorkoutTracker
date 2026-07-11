import 'package:flutter/material.dart';
import 'package:workout_tracker/contract.dart';

import 'exercise_form.dart';
import 'ui/view.dart';

enum CreateOrigin { setup, library }

final class CreateExerciseView extends LoadedView {
  const CreateExerciseView({
    required super.isBusy,
    required super.sheetLabel,
    required this.origin,
    super.error,
  });

  final CreateOrigin origin;
}

abstract interface class CreateExerciseActions {
  Future<void> close();

  Future<bool> save(ExerciseDef exercise);
}

class CreateExerciseScreen extends StatelessWidget {
  const CreateExerciseScreen({
    required this.view,
    required this.actions,
    super.key,
  });

  final CreateExerciseView view;
  final CreateExerciseActions actions;

  @override
  Widget build(BuildContext context) {
    return ExerciseAuthoringScreen(
      a11yLabel: 'New exercise',
      title: 'New exercise',
      sheetLabel: view.sheetLabel,
      backTooltip: view.origin == CreateOrigin.library
          ? 'Back to edit exercises'
          : 'Back to workout setup',
      mode: ExerciseFormMode.create,
      initialDraft: CanonicalExerciseDraft.defaults,
      isBusy: view.isBusy,
      onClose: actions.close,
      onSave: actions.save,
    );
  }
}
