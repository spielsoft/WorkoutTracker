import 'package:flutter/material.dart';
import 'package:workout_tracker/contract.dart';

import 'ui/view.dart';
import 'ui/shared/a11y.dart';
import 'ui/shared/header.dart';

enum PlaceKind { primary, backup }

enum PlaceOrigin { setup, workout }

class PlaceIntent {
  const PlaceIntent.primary({required this.workout})
    : kind = PlaceKind.primary,
      primaryRow = null,
      primaryExercise = null;

  const PlaceIntent.backup({
    required this.workout,
    required this.primaryRow,
    required this.primaryExercise,
  }) : kind = PlaceKind.backup;

  final PlaceKind kind;
  final String workout;
  final int? primaryRow;
  final String? primaryExercise;
}

final class PlacementView extends LoadedView {
  const PlacementView({
    required super.isBusy,
    required this.exercises,
    required super.sheetLabel,
    required this.intent,
    required this.origin,
    super.error,
  });

  final List<CanonicalExercise> exercises;
  final PlaceIntent intent;
  final PlaceOrigin origin;
}

abstract interface class PlacementActions {
  Future<void> close();

  Future<bool> place(
    CanonicalExercise exercise,
    WorkoutPlacementMetadata metadata, {
    bool keepAdding = false,
  });
}

class PlacementScreen extends StatelessWidget {
  const PlacementScreen({required this.view, required this.actions, super.key});

  final PlacementView view;
  final PlacementActions actions;

  @override
  Widget build(BuildContext context) {
    final isBackup = view.intent.kind == PlaceKind.backup;
    return A11yScreen(
      label: isBackup ? 'Add backup exercise' : 'Add exercise to workout',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ScreenHeader(
            title: view.sheetLabel,
            subtitle: isBackup ? 'Add backup exercise' : 'Add to workout',
            compactTitle: true,
            backTooltip: view.origin == PlaceOrigin.setup
                ? 'Back to workout setup'
                : 'Back to workout',
            onBack: actions.close,
          ),
          const SizedBox(height: 16),
          _PlacementContext(intent: view.intent),
          const SizedBox(height: 16),
          _PlaceForm(
            exercises: view.exercises,
            initialExercise: null,
            onSubmit: (draft) => actions.place(draft.exercise, draft.metadata),
            onSubmitAndAddAnother: (draft) =>
                actions.place(draft.exercise, draft.metadata, keepAdding: true),
          ),
        ],
      ),
    );
  }
}

class _PlacementContext extends StatelessWidget {
  const _PlacementContext({required this.intent});

  final PlaceIntent intent;

  @override
  Widget build(BuildContext context) {
    final backup = intent.kind == PlaceKind.backup;
    final title = backup
        ? 'Backup for ${intent.primaryExercise}'
        : 'Primary exercise';
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      container: true,
      label: '$title, ${intent.workout} workout',
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.secondaryContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(
                backup
                    ? Icons.account_tree_outlined
                    : Icons.fitness_center_outlined,
                color: colors.onSecondaryContainer,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: colors.onSecondaryContainer,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '${intent.workout} workout',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colors.onSecondaryContainer,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlaceForm extends StatefulWidget {
  const _PlaceForm({
    required this.exercises,
    required this.initialExercise,
    required this.onSubmit,
    required this.onSubmitAndAddAnother,
  });

  final List<CanonicalExercise> exercises;
  final CanonicalExercise? initialExercise;
  final ValueChanged<_ExercisePlacementDraft> onSubmit;
  final Future<bool> Function(_ExercisePlacementDraft draft)
  onSubmitAndAddAnother;

  @override
  State<_PlaceForm> createState() => _PlaceFormSt();
}

class _PlaceFormSt extends State<_PlaceForm> {
  CanonicalExercise? _selectedExercise;
  late final TextEditingController _searchCtrl;
  late final TextEditingController _setsCtrl;
  late final TextEditingController _repsCtrl;
  late final TextEditingController _rpeCtrl;
  late final TextEditingController _restCtrl;
  late final TextEditingController _tempoCtrl;
  late final TextEditingController _notesCtrl;

  @override
  void initState() {
    super.initState();
    _searchCtrl = TextEditingController();
    _searchCtrl.addListener(_handleSearch);
    _setsCtrl = TextEditingController();
    _repsCtrl = TextEditingController();
    _rpeCtrl = TextEditingController();
    _restCtrl = TextEditingController();
    _tempoCtrl = TextEditingController();
    _notesCtrl = TextEditingController();
    _selectedExercise = widget.initialExercise;
    _loadDefaults(_selectedExercise);
  }

  @override
  void didUpdateWidget(_PlaceForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.exercises.contains(_selectedExercise)) {
      _selectedExercise = widget.initialExercise;
      _loadDefaults(_selectedExercise);
    }
  }

  @override
  void dispose() {
    _searchCtrl.removeListener(_handleSearch);
    _searchCtrl.dispose();
    _setsCtrl.dispose();
    _repsCtrl.dispose();
    _rpeCtrl.dispose();
    _restCtrl.dispose();
    _tempoCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  void _handleSearch() {
    setState(() {});
  }

  void _loadDefaults(CanonicalExercise? exercise) {
    _setsCtrl.text = exercise?.defaultSets ?? '';
    _repsCtrl.text = exercise?.defaultReps ?? '';
    _rpeCtrl.text = exercise?.defaultRpe ?? '';
    _restCtrl.text = exercise?.defaultRest ?? '';
    _tempoCtrl.text = exercise?.defaultTempo ?? '';
    _notesCtrl.text = exercise?.notes ?? '';
  }

  void _clearForNext() {
    setState(() {
      _selectedExercise = null;
      _searchCtrl.clear();
      _loadDefaults(null);
    });
  }

  WorkoutPlacementMetadata _metadata() {
    return WorkoutPlacementMetadata(
      sets: _setsCtrl.text.trim(),
      reps: _repsCtrl.text.trim(),
      rpe: _rpeCtrl.text.trim(),
      rest: _restCtrl.text.trim(),
      tempo: _tempoCtrl.text.trim(),
      notes: _notesCtrl.text.trim(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final exercises = widget.exercises;
    final selectedExercise = _selectedExercise;
    final exerciseQuery = _searchCtrl.text.trim().toLowerCase();
    final matchingExercises = exerciseQuery.isEmpty
        ? exercises
        : exercises.where((exercise) {
            return exercise.displayName.toLowerCase().contains(exerciseQuery) ||
                exercise.description.toLowerCase().contains(exerciseQuery);
          }).toList();
    final selectableExercises =
        selectedExercise != null &&
            !matchingExercises.contains(selectedExercise)
        ? [selectedExercise, ...matchingExercises]
        : matchingExercises;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        A11yTextField(
          label: 'Search exercises',
          valueListenable: _searchCtrl,
          child: TextField(
            key: const ValueKey('exercise-picker-search'),
            controller: _searchCtrl,
            decoration: InputDecoration(
              labelText: 'Search exercises',
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.search_outlined),
              suffixIcon: exerciseQuery.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear exercise search',
                      onPressed: _searchCtrl.clear,
                      icon: const Icon(Icons.clear_outlined),
                    ),
            ),
            textInputAction: TextInputAction.search,
          ),
        ),
        const SizedBox(height: 12),
        Semantics(
          label: 'Exercise selector',
          value: selectedExercise?.displayName ?? 'No exercise selected',
          hint: 'Choose an exercise',
          child: DropdownButtonFormField<CanonicalExercise>(
            key: const ValueKey('existing-exercise-selector'),
            initialValue: selectedExercise,
            hint: Text(
              exerciseQuery.isEmpty || selectableExercises.isNotEmpty
                  ? 'Choose exercise'
                  : 'No matching exercises',
            ),
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Exercise',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.fitness_center_outlined),
            ),
            items: [
              for (final exercise in selectableExercises)
                DropdownMenuItem(
                  value: exercise,
                  child: Text(
                    exercise.displayName,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: selectableExercises.isEmpty
                ? null
                : (exercise) {
                    setState(() {
                      _selectedExercise = exercise;
                      _loadDefaults(exercise);
                    });
                  },
          ),
        ),
        if (selectedExercise != null) ...[
          const SizedBox(height: 12),
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
                    child: _MetaField(
                      controller: _setsCtrl,
                      labelText: 'Sets',
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  SizedBox(
                    width: fieldWidth,
                    child: _MetaField(controller: _repsCtrl, labelText: 'Reps'),
                  ),
                  SizedBox(
                    width: fieldWidth,
                    child: _MetaField(
                      controller: _rpeCtrl,
                      labelText: 'RPE',
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  SizedBox(
                    width: fieldWidth,
                    child: _MetaField(controller: _restCtrl, labelText: 'Rest'),
                  ),
                  SizedBox(
                    width: fieldWidth,
                    child: _MetaField(
                      controller: _tempoCtrl,
                      labelText: 'Tempo',
                    ),
                  ),
                  SizedBox(
                    width: fieldWidth,
                    child: _MetaField(
                      controller: _notesCtrl,
                      labelText: 'Notes',
                    ),
                  ),
                ],
              );
            },
          ),
        ],
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              key: const ValueKey('place-existing-exercise'),
              onPressed: selectedExercise == null
                  ? null
                  : () => widget.onSubmit(
                      _ExercisePlacementDraft(
                        exercise: selectedExercise,
                        metadata: _metadata(),
                      ),
                    ),
              icon: const Icon(Icons.playlist_add_outlined),
              label: const Text('Add to workout'),
            ),
            OutlinedButton.icon(
              key: const ValueKey('place-existing-exercise-add-another'),
              onPressed: selectedExercise == null
                  ? null
                  : () async {
                      final added = await widget.onSubmitAndAddAnother(
                        _ExercisePlacementDraft(
                          exercise: selectedExercise,
                          metadata: _metadata(),
                        ),
                      );
                      if (added) {
                        _clearForNext();
                      }
                    },
              icon: const Icon(Icons.add_outlined),
              label: const Text('Add another'),
            ),
          ],
        ),
      ],
    );
  }
}

class _ExercisePlacementDraft {
  const _ExercisePlacementDraft({
    required this.exercise,
    required this.metadata,
  });

  final CanonicalExercise exercise;
  final WorkoutPlacementMetadata metadata;
}

class _MetaField extends StatelessWidget {
  const _MetaField({
    required this.controller,
    required this.labelText,
    this.keyboardType,
  });

  final TextEditingController controller;
  final String labelText;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return A11yTextField(
      label: labelText,
      valueListenable: controller,
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: labelText,
          border: const OutlineInputBorder(),
        ),
        textInputAction: TextInputAction.next,
      ),
    );
  }
}
