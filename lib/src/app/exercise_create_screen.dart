import 'package:flutter/material.dart';
import 'package:workout_tracker/contract.dart';

import 'exercise_form.dart';
import 'ui/view.dart';
import 'ui/shared/a11y.dart';
import 'ui/shared/header.dart';

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
    return A11yScreen(
      label: 'New exercise',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ScreenHeader(
            title: view.sheetLabel,
            subtitle: 'New exercise',
            compactTitle: true,
            backTooltip: view.origin == CreateOrigin.library
                ? 'Back to edit exercises'
                : 'Back to workout setup',
            onBack: actions.close,
          ),
          const SizedBox(height: 16),
          ExerciseAuthoringForm(
            authoringContext: ExerciseAuthoringContext.canonicalExercise,
            onCancel: actions.close,
            onSubmit: (draft) => actions.save(draft.toDef()),
          ),
        ],
      ),
    );
  }
}
