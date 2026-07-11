import 'package:flutter/material.dart';
import 'package:workout_tracker/contract.dart';

import 'controller.dart';
import 'repair.dart';
import 'ui/shared/a11y.dart';
import 'ui/shared/header.dart';
import 'ui/shared/name_dialog.dart';
import 'workout.dart';
import 'ui/view.dart';

final class WorkoutHomeView extends LoadedView {
  const WorkoutHomeView({
    required super.isBusy,
    required this.setup,
    required super.sheetLabel,
    super.error,
  });

  final WorkoutSetupReadModel setup;
}

const _addWorkoutValue = '__workout_tracker_add_workout__';
const _addHistoryValue = '__workout_tracker_add_history_block__';

abstract interface class WorkoutHomeActions {
  Future<void> home(WorkoutHomeAction action);

  Future<bool> reorder(ReorderIntent intent);
}

sealed class WorkoutHomeAction {
  const WorkoutHomeAction();
}

final class BackToSheets extends WorkoutHomeAction {
  const BackToSheets();
}

final class OpenExerciseLibrary extends WorkoutHomeAction {
  const OpenExerciseLibrary();
}

final class ChooseWorkout extends WorkoutHomeAction {
  const ChooseWorkout(this.workout);

  final String? workout;
}

final class ChooseHistory extends WorkoutHomeAction {
  const ChooseHistory(this.block);

  final String? block;
}

final class CreateWorkout extends WorkoutHomeAction {
  const CreateWorkout(this.name);

  final String name;
}

final class CreateHistory extends WorkoutHomeAction {
  const CreateHistory(this.label);

  final String label;
}

final class OpenWorkoutLog extends WorkoutHomeAction {
  const OpenWorkoutLog(this.primaryRow);

  final int primaryRow;
}

final class AddWorkoutPrimary extends WorkoutHomeAction {
  const AddWorkoutPrimary(this.workout);

  final String workout;
}

final class AddWorkoutBackup extends WorkoutHomeAction {
  const AddWorkoutBackup(this.slot);

  final WorkoutOverviewSlot slot;
}

final class DeleteWorkoutExercise extends WorkoutHomeAction {
  const DeleteWorkoutExercise(this.primaryRow);

  final int primaryRow;
}

class WorkoutHomeScreen extends StatelessWidget {
  const WorkoutHomeScreen({
    required this.view,
    required this.actions,
    super.key,
  });

  final WorkoutHomeView view;
  final WorkoutHomeActions actions;

  @override
  Widget build(BuildContext context) {
    final setup = view.setup;
    final selectedWorkout = setup.selectedWorkout;
    final overview = setup.overview;
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
          compactTitle: true,
          backTooltip: 'Back to sheet selection',
          onBack: () => actions.home(const BackToSheets()),
          trailing: IconButton.filledTonal(
            key: const ValueKey('open-exercise-manager'),
            tooltip: 'Edit exercise library',
            onPressed: () => actions.home(const OpenExerciseLibrary()),
            icon: const Icon(Icons.fitness_center_outlined),
          ),
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final twoColumn = constraints.maxWidth >= 620;
            final fieldWidth = twoColumn
                ? (constraints.maxWidth - 12) / 2
                : constraints.maxWidth;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: fieldWidth,
                  child: _WorkoutField(
                    workouts: setup.workouts,
                    selected: selectedWorkout,
                    progress: setup.progressByWorkout,
                    onChanged: (value) => actions.home(ChooseWorkout(value)),
                    onAdd: view.isBusy ? null : () => _addWorkout(context),
                  ),
                ),
                SizedBox(
                  width: fieldWidth,
                  child: _HistoryField(
                    blocks: setup.historyBlocks,
                    selected: setup.selectedHistoryBlock,
                    onChanged: (value) => actions.home(ChooseHistory(value)),
                    onAdd: view.isBusy ? null : () => _addHistory(context),
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 16),
      ],
    );
    if (overview == null) {
      return A11yScreen(
        label: 'Workout home',
        child: ListView(children: [header]),
      );
    }
    return WorkoutList(
      key: const ValueKey('workout-home'),
      label: '${overview.workout} exercise list',
      header: header,
      overview: overview,
      onOpenExercise: (row) => actions.home(OpenWorkoutLog(row)),
      onAddPrimary: view.isBusy || selectedWorkout == null
          ? null
          : () => actions.home(AddWorkoutPrimary(selectedWorkout)),
      onAddBackup: view.isBusy
          ? null
          : (slot) => actions.home(AddWorkoutBackup(slot)),
      onDeleteExercise: view.isBusy ? null : (slot) => _delete(context, slot),
      onReorderExercises: view.isBusy ? null : actions.reorder,
    );
  }

  Future<void> _addWorkout(BuildContext context) async {
    final name = await _prompt(context, 'Add workout', 'Workout name');
    if (name != null) {
      await actions.home(CreateWorkout(name));
    }
  }

  Future<void> _addHistory(BuildContext context) async {
    final name = await _prompt(
      context,
      'Add history block',
      'History block label',
    );
    if (name != null) {
      await actions.home(CreateHistory(name));
    }
  }

  Future<String?> _prompt(
    BuildContext context,
    String title,
    String label,
  ) async {
    final value = await showDialog<String>(
      context: context,
      builder: (context) => NameDialog(title: title, label: label),
    );
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  Future<void> _delete(BuildContext context, WorkoutOverviewSlot slot) async {
    if (await confirmWorkoutDelete(context, slot)) {
      await actions.home(DeleteWorkoutExercise(slot.sheetRowNumber));
    }
  }
}

class _WorkoutField extends StatelessWidget {
  const _WorkoutField({
    required this.workouts,
    required this.selected,
    required this.progress,
    required this.onChanged,
    required this.onAdd,
  });

  final List<String> workouts;
  final String? selected;
  final Map<String, WorkoutSetupProgress> progress;
  final ValueChanged<String?> onChanged;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    return _Selector(
      keyPrefix: 'workout-selector',
      label: 'Workout',
      emptyPrompt: 'Add workout...',
      prefixIcon: Icons.fitness_center_outlined,
      selected: selected,
      addValue: _addWorkoutValue,
      onAdd: onAdd,
      onChanged: onChanged,
      items: [
        for (final workout in workouts)
          DropdownMenuItem(
            value: workout,
            child: Text(
              '$workout ${progress[workout]!.label}',
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
    );
  }
}

class _HistoryField extends StatelessWidget {
  const _HistoryField({
    required this.blocks,
    required this.selected,
    required this.onChanged,
    required this.onAdd,
  });

  final List<HistoryBlock> blocks;
  final String? selected;
  final ValueChanged<String?> onChanged;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    return _Selector(
      keyPrefix: 'history-block-selector',
      label: 'History block',
      emptyPrompt: 'Add history block...',
      prefixIcon: Icons.history_outlined,
      selected: selected,
      addValue: _addHistoryValue,
      onAdd: onAdd,
      onChanged: onChanged,
      items: [
        for (final block in blocks)
          DropdownMenuItem(
            value: block.label,
            child: Text(block.label, overflow: TextOverflow.ellipsis),
          ),
      ],
    );
  }
}

class _Selector extends StatefulWidget {
  const _Selector({
    required this.keyPrefix,
    required this.label,
    required this.emptyPrompt,
    required this.prefixIcon,
    required this.selected,
    required this.addValue,
    required this.items,
    required this.onChanged,
    required this.onAdd,
  });

  final String keyPrefix;
  final String label;
  final String emptyPrompt;
  final IconData prefixIcon;
  final String? selected;
  final String addValue;
  final List<DropdownMenuItem<String>> items;
  final ValueChanged<String?> onChanged;
  final VoidCallback? onAdd;

  @override
  State<_Selector> createState() => _SelectorSt();
}

class _SelectorSt extends State<_Selector> {
  int _resetEpoch = 0;

  void _openAddAfterClose() {
    setState(() => _resetEpoch += 1);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        widget.onAdd?.call();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '${widget.label} selector',
      value: widget.selected ?? 'No ${widget.label.toLowerCase()} selected',
      hint: 'Choose ${widget.label.toLowerCase()}',
      child: DropdownButtonFormField<String>(
        key: ValueKey('${widget.keyPrefix}-${widget.selected}-$_resetEpoch'),
        initialValue: widget.selected,
        isExpanded: true,
        hint: Text(widget.emptyPrompt, overflow: TextOverflow.ellipsis),
        decoration: InputDecoration(
          labelText: widget.label,
          floatingLabelBehavior: FloatingLabelBehavior.always,
          border: const OutlineInputBorder(),
          prefixIcon: Icon(widget.prefixIcon),
        ),
        items: [
          ...widget.items,
          if (widget.onAdd != null)
            DropdownMenuItem(
              value: widget.addValue,
              child: Row(
                children: [
                  const Icon(Icons.add_outlined),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.emptyPrompt,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
        ],
        onChanged: (value) {
          if (value == widget.addValue) {
            _openAddAfterClose();
            return;
          }
          widget.onChanged(value);
        },
      ),
    );
  }
}
