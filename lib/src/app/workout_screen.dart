import 'package:flutter/material.dart';
import 'package:workout_tracker/contract.dart';

import 'repair.dart';
import 'ui/flow.dart';
import 'ui/shared/a11y.dart';
import 'ui/shared/header.dart';
import 'workout.dart';

abstract interface class WorkoutActions {
  Future<void> run(WorkoutAction action);

  Future<bool> reorder(ReorderIntent intent);
}

sealed class WorkoutAction {
  const WorkoutAction();
}

final class BackToWorkoutSetup extends WorkoutAction {
  const BackToWorkoutSetup();
}

final class AddWorkoutPrimary extends WorkoutAction {
  const AddWorkoutPrimary(this.workout);

  final String workout;
}

final class OpenWorkoutLog extends WorkoutAction {
  const OpenWorkoutLog(this.primaryRow);

  final int primaryRow;
}

final class AddWorkoutBackup extends WorkoutAction {
  const AddWorkoutBackup(this.slot);

  final WorkoutOverviewSlot slot;
}

final class DeleteWorkoutRow extends WorkoutAction {
  const DeleteWorkoutRow(this.primaryRow);

  final int primaryRow;
}

class WorkoutScreen extends StatelessWidget {
  const WorkoutScreen({required this.view, required this.actions, super.key});

  final WorkoutView view;
  final WorkoutActions actions;

  @override
  Widget build(BuildContext context) {
    final setup = view.setup;
    final workout = setup.selectedWorkout;
    final history = setup.selectedHistoryBlock;
    final title = workout == null || history == null
        ? 'Exercises'
        : '$workout - $history';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (view.error case final error?) ...[
          IssuePanel(
            icon: Icons.error_outline,
            title: 'Connection or validation failed',
            lines: [error],
            tone: IssueTone.error,
          ),
          const SizedBox(height: 16),
        ],
        A11yScreen(
          label: '$title exercise list',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ScreenHeader(
                title: view.sheetLabel,
                subtitle: title,
                compactTitle: true,
                backTooltip: 'Back to workout setup',
                onBack: () => actions.run(const BackToWorkoutSetup()),
                trailing: workout == null
                    ? null
                    : IconButton.filled(
                        key: const ValueKey('add-primary-exercise'),
                        tooltip: 'Add to workout',
                        onPressed: () =>
                            actions.run(AddWorkoutPrimary(workout)),
                        icon: const Icon(Icons.add_outlined),
                      ),
              ),
              const SizedBox(height: 12),
              if (setup.overview case final overview?)
                WorkoutList(
                  key: const ValueKey('full-workout-overview'),
                  overview: overview,
                  onOpenExercise: (row) => actions.run(OpenWorkoutLog(row)),
                  onAddBackup: (slot) => actions.run(AddWorkoutBackup(slot)),
                  onDeleteExercise: view.isBusy
                      ? null
                      : (slot) => _delete(context, slot),
                  onReorderExercises: view.isBusy ? null : actions.reorder,
                  showTitle: false,
                ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _delete(BuildContext context, WorkoutOverviewSlot slot) async {
    if (await confirmWorkoutDelete(context, slot)) {
      await actions.run(DeleteWorkoutRow(slot.sheetRowNumber));
    }
  }
}
