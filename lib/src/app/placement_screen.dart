import 'package:flutter/material.dart';
import 'package:workout_tracker/contract.dart';

import 'ui/view.dart';
import 'ui/shared/a11y.dart';
import 'ui/shared/header.dart';
import 'ui/shared/role.dart';

enum PlaceKind { primary, backup }

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
    super.error,
  });

  final List<CanonicalExercise> exercises;
  final PlaceIntent intent;
}

abstract interface class PlacementActions {
  Future<void> close();

  Future<void> create();

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
            backTooltip: 'Back',
            onBack: actions.close,
          ),
          const SizedBox(height: 16),
          _PlacementContext(intent: view.intent),
          const SizedBox(height: 16),
          _PlaceForm(
            exercises: view.exercises,
            initialExercise: null,
            isBusy: view.isBusy,
            onCreate: actions.create,
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
                backup ? backupIcon : Icons.fitness_center_outlined,
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
    required this.isBusy,
    required this.onCreate,
    required this.onSubmit,
    required this.onSubmitAndAddAnother,
  });

  final List<CanonicalExercise> exercises;
  final CanonicalExercise? initialExercise;
  final bool isBusy;
  final Future<void> Function() onCreate;
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
  late final TextEditingController _restCtrl;
  late final TextEditingController _tempoCtrl;
  late final TextEditingController _notesCtrl;
  final _targetCtrls = <String, TextEditingController>{};

  @override
  void initState() {
    super.initState();
    _searchCtrl = TextEditingController();
    _searchCtrl.addListener(_handleSearch);
    _setsCtrl = TextEditingController();
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
    _restCtrl.dispose();
    _tempoCtrl.dispose();
    _notesCtrl.dispose();
    for (final controller in _targetCtrls.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _handleSearch() {
    setState(() {});
  }

  void _loadDefaults(CanonicalExercise? exercise) {
    _setsCtrl.text = exercise?.defaultSets ?? '';
    _restCtrl.text = exercise?.defaultRest ?? '';
    _tempoCtrl.text = exercise?.defaultTempo ?? '';
    _notesCtrl.text = exercise?.notes ?? '';
    for (final controller in _targetCtrls.values) {
      controller.dispose();
    }
    _targetCtrls.clear();
    if (exercise == null) {
      return;
    }
    final format = parseLogFormat(exercise.logFormat);
    if (format is ParsedLogFormat) {
      for (final label in format.fieldLabels) {
        _targetCtrls[label] = TextEditingController(
          text: exercise.defaultValues[label] ?? '',
        );
      }
    }
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
      rest: _restCtrl.text.trim(),
      tempo: _tempoCtrl.text.trim(),
      notes: _notesCtrl.text.trim(),
      targetValues: {
        for (final entry in _targetCtrls.entries)
          entry.key: entry.value.text.trim(),
      },
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
                  for (final entry in _targetCtrls.entries)
                    SizedBox(
                      width: fieldWidth,
                      child: _MetaField(
                        key: ValueKey('placement-target-${entry.key}'),
                        controller: entry.value,
                        labelText: entry.key,
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
            OutlinedButton.icon(
              key: const ValueKey('create-exercise-from-placement'),
              onPressed: widget.isBusy ? null : () => widget.onCreate(),
              icon: const Icon(Icons.add_circle_outline),
              label: const Text('New exercise'),
            ),
            FilledButton.icon(
              key: const ValueKey('place-existing-exercise'),
              onPressed: widget.isBusy || selectedExercise == null
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
              onPressed: widget.isBusy || selectedExercise == null
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
    super.key,
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
