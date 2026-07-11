import 'package:flutter/material.dart';
import 'package:workout_tracker/contract.dart';

import 'controller.dart';
import 'repair.dart';
import 'ui/shared/a11y.dart';
import 'ui/shared/header.dart';
import 'workout.dart';
import 'ui/view.dart';

final class WorkoutView extends LoadedView {
  const WorkoutView({
    required super.isBusy,
    required this.setup,
    required super.sheetLabel,
    super.error,
  });

  final WorkoutSetupReadModel setup;
}

abstract interface class WorkoutActions {
  Future<void> workout(WorkoutAction action);

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
    final header = Column(
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
        ScreenHeader(
          title: view.sheetLabel,
          subtitle: title,
          compactTitle: true,
          backTooltip: 'Back to workout setup',
          onBack: () => actions.workout(const BackToWorkoutSetup()),
          trailing: workout == null
              ? null
              : IconButton.filled(
                  key: const ValueKey('add-primary-exercise'),
                  tooltip: 'Add to workout',
                  onPressed: () => actions.workout(AddWorkoutPrimary(workout)),
                  icon: const Icon(Icons.add_outlined),
                ),
        ),
        const SizedBox(height: 12),
      ],
    );
    final overview = setup.overview;
    if (overview == null) {
      return A11yScreen(
        label: '$title exercise list',
        child: ListView(children: [header]),
      );
    }
    return WorkoutList(
      key: const ValueKey('full-workout-overview'),
      label: '$title exercise list',
      header: header,
      overview: overview,
      onOpenExercise: (row) => actions.workout(OpenWorkoutLog(row)),
      onAddBackup: (slot) => actions.workout(AddWorkoutBackup(slot)),
      onDeleteExercise: view.isBusy ? null : (slot) => _delete(context, slot),
      onReorderExercises: view.isBusy ? null : actions.reorder,
      showTitle: false,
    );
  }

  Future<void> _delete(BuildContext context, WorkoutOverviewSlot slot) async {
    if (await confirmWorkoutDelete(context, slot)) {
      await actions.workout(DeleteWorkoutRow(slot.sheetRowNumber));
    }
  }
}
