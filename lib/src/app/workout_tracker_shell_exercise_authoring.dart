part of 'workout_tracker_shell.dart';

const workoutTrackerDefaultLogFormat = '{Weight}[x]{Reps}[@]{RPE}';

enum ExerciseAuthoringContext { canonicalExercise, workoutPlacement }

class CanonicalExerciseDraft {
  const CanonicalExerciseDraft({
    required this.exerciseName,
    required this.description,
    required this.defaultSets,
    required this.defaultReps,
    required this.defaultRPE,
    required this.defaultRest,
    required this.defaultTempo,
    required this.notes,
    required this.logFormat,
  });

  static const defaults = CanonicalExerciseDraft(
    exerciseName: '',
    description: '',
    defaultSets: '3',
    defaultReps: '10',
    defaultRPE: '8',
    defaultRest: '2 min',
    defaultTempo: '',
    notes: '',
    logFormat: workoutTrackerDefaultLogFormat,
  );

  factory CanonicalExerciseDraft.fromExercise(CanonicalExercise exercise) {
    return CanonicalExerciseDraft(
      exerciseName: exercise.exercise,
      description: exercise.description,
      defaultSets: exercise.defaultSets,
      defaultReps: exercise.defaultReps,
      defaultRPE: exercise.defaultRpe,
      defaultRest: exercise.defaultRest,
      defaultTempo: exercise.defaultTempo,
      notes: exercise.notes,
      logFormat: exercise.logFormat,
    );
  }

  final String exerciseName;
  final String description;
  final String defaultSets;
  final String defaultReps;
  final String defaultRPE;
  final String defaultRest;
  final String defaultTempo;
  final String notes;
  final String logFormat;

  CanonicalExerciseDraft normalized() {
    final trimmedLogFormat = logFormat.trim();
    return CanonicalExerciseDraft(
      exerciseName: exerciseName.trim(),
      description: description.trim(),
      defaultSets: defaultSets.trim(),
      defaultReps: defaultReps.trim(),
      defaultRPE: defaultRPE.trim(),
      defaultRest: defaultRest.trim(),
      defaultTempo: defaultTempo.trim(),
      notes: notes.trim(),
      logFormat: trimmedLogFormat.isEmpty
          ? workoutTrackerDefaultLogFormat
          : trimmedLogFormat,
    );
  }

  CanonicalExerciseDefinition toCanonicalExerciseDefinition() {
    final draft = normalized();
    return CanonicalExerciseDefinition(
      exercise: draft.exerciseName,
      description: draft.description,
      defaultSets: draft.defaultSets,
      defaultReps: draft.defaultReps,
      defaultRpe: draft.defaultRPE,
      defaultRest: draft.defaultRest,
      defaultTempo: draft.defaultTempo,
      notes: draft.notes,
      logFormat: draft.logFormat,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is CanonicalExerciseDraft &&
            exerciseName == other.exerciseName &&
            description == other.description &&
            defaultSets == other.defaultSets &&
            defaultReps == other.defaultReps &&
            defaultRPE == other.defaultRPE &&
            defaultRest == other.defaultRest &&
            defaultTempo == other.defaultTempo &&
            notes == other.notes &&
            logFormat == other.logFormat;
  }

  @override
  int get hashCode {
    return Object.hash(
      exerciseName,
      description,
      defaultSets,
      defaultReps,
      defaultRPE,
      defaultRest,
      defaultTempo,
      notes,
      logFormat,
    );
  }
}

class ExerciseAuthoringScreen extends StatelessWidget {
  const ExerciseAuthoringScreen({
    required this.onSubmit,
    this.authoringContext = ExerciseAuthoringContext.canonicalExercise,
    this.initialDraft = CanonicalExerciseDraft.defaults,
    this.onCancel,
    this.isBusy = false,
    super.key,
  });

  final ExerciseAuthoringContext authoringContext;
  final CanonicalExerciseDraft initialDraft;
  final ValueChanged<CanonicalExerciseDraft> onSubmit;
  final VoidCallback? onCancel;
  final bool isBusy;

  @override
  Widget build(BuildContext context) {
    final title = _exerciseAuthoringTitle(authoringContext);
    return Scaffold(
      appBar: AppBar(
        leading: onCancel == null
            ? null
            : IconButton(
                tooltip: 'Cancel',
                onPressed: onCancel,
                icon: const Icon(Icons.close_outlined),
              ),
        title: Text(title),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 840),
              child: ExerciseAuthoringForm(
                authoringContext: authoringContext,
                initialDraft: initialDraft,
                onSubmit: onSubmit,
                onCancel: onCancel,
                isBusy: isBusy,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ExerciseAuthoringForm extends StatefulWidget {
  const ExerciseAuthoringForm({
    required this.onSubmit,
    this.authoringContext = ExerciseAuthoringContext.canonicalExercise,
    this.initialDraft = CanonicalExerciseDraft.defaults,
    this.onCancel,
    this.isBusy = false,
    super.key,
  });

  final ExerciseAuthoringContext authoringContext;
  final CanonicalExerciseDraft initialDraft;
  final ValueChanged<CanonicalExerciseDraft> onSubmit;
  final VoidCallback? onCancel;
  final bool isBusy;

  @override
  State<ExerciseAuthoringForm> createState() => _ExerciseAuthoringFormState();
}

class _ExerciseAuthoringFormState extends State<ExerciseAuthoringForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _exerciseNameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _defaultSetsController;
  late final TextEditingController _defaultRepsController;
  late final TextEditingController _defaultRPEController;
  late final TextEditingController _defaultRestController;
  late final TextEditingController _defaultTempoController;
  late final TextEditingController _notesController;
  late final TextEditingController _logFormatController;

  @override
  void initState() {
    super.initState();
    _exerciseNameController = TextEditingController();
    _descriptionController = TextEditingController();
    _defaultSetsController = TextEditingController();
    _defaultRepsController = TextEditingController();
    _defaultRPEController = TextEditingController();
    _defaultRestController = TextEditingController();
    _defaultTempoController = TextEditingController();
    _notesController = TextEditingController();
    _logFormatController = TextEditingController();
    _loadDraft(widget.initialDraft);
  }

  @override
  void didUpdateWidget(ExerciseAuthoringForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialDraft != widget.initialDraft) {
      _loadDraft(widget.initialDraft);
    }
  }

  @override
  void dispose() {
    _exerciseNameController.dispose();
    _descriptionController.dispose();
    _defaultSetsController.dispose();
    _defaultRepsController.dispose();
    _defaultRPEController.dispose();
    _defaultRestController.dispose();
    _defaultTempoController.dispose();
    _notesController.dispose();
    _logFormatController.dispose();
    super.dispose();
  }

  void _loadDraft(CanonicalExerciseDraft draft) {
    _exerciseNameController.text = draft.exerciseName;
    _descriptionController.text = draft.description;
    _defaultSetsController.text = draft.defaultSets;
    _defaultRepsController.text = draft.defaultReps;
    _defaultRPEController.text = draft.defaultRPE;
    _defaultRestController.text = draft.defaultRest;
    _defaultTempoController.text = draft.defaultTempo;
    _notesController.text = draft.notes;
    _logFormatController.text = draft.logFormat;
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    widget.onSubmit(_draftFromControllers().normalized());
  }

  CanonicalExerciseDraft _draftFromControllers() {
    return CanonicalExerciseDraft(
      exerciseName: _exerciseNameController.text,
      description: _descriptionController.text,
      defaultSets: _defaultSetsController.text,
      defaultReps: _defaultRepsController.text,
      defaultRPE: _defaultRPEController.text,
      defaultRest: _defaultRestController.text,
      defaultTempo: _defaultTempoController.text,
      notes: _notesController.text,
      logFormat: _logFormatController.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final title = _exerciseAuthoringTitle(widget.authoringContext);
    final submitLabel = _exerciseAuthoringSubmitLabel(widget.authoringContext);

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                _exerciseAuthoringIcon(widget.authoringContext),
                color: colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextFormField(
            key: const ValueKey('exercise-authoring-name'),
            controller: _exerciseNameController,
            enabled: !widget.isBusy,
            decoration: const InputDecoration(
              labelText: 'Exercise name',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.fitness_center_outlined),
            ),
            textInputAction: TextInputAction.next,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Enter an exercise name.';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            key: const ValueKey('exercise-authoring-description'),
            controller: _descriptionController,
            enabled: !widget.isBusy,
            decoration: const InputDecoration(
              labelText: 'Description',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.short_text_outlined),
            ),
            textInputAction: TextInputAction.next,
          ),
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
                    child: _ExerciseAuthoringTextField(
                      key: const ValueKey('exercise-authoring-default-sets'),
                      controller: _defaultSetsController,
                      enabled: !widget.isBusy,
                      labelText: 'Default sets',
                      icon: Icons.format_list_numbered_outlined,
                      textInputAction: TextInputAction.next,
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  SizedBox(
                    width: fieldWidth,
                    child: _ExerciseAuthoringTextField(
                      key: const ValueKey('exercise-authoring-default-reps'),
                      controller: _defaultRepsController,
                      enabled: !widget.isBusy,
                      labelText: 'Default reps',
                      icon: Icons.repeat_outlined,
                      textInputAction: TextInputAction.next,
                    ),
                  ),
                  SizedBox(
                    width: fieldWidth,
                    child: _ExerciseAuthoringTextField(
                      key: const ValueKey('exercise-authoring-default-rpe'),
                      controller: _defaultRPEController,
                      enabled: !widget.isBusy,
                      labelText: 'Default RPE',
                      icon: Icons.speed_outlined,
                      textInputAction: TextInputAction.next,
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  SizedBox(
                    width: fieldWidth,
                    child: _ExerciseAuthoringTextField(
                      key: const ValueKey('exercise-authoring-default-rest'),
                      controller: _defaultRestController,
                      enabled: !widget.isBusy,
                      labelText: 'Default rest',
                      icon: Icons.timer_outlined,
                      textInputAction: TextInputAction.next,
                    ),
                  ),
                  SizedBox(
                    width: fieldWidth,
                    child: _ExerciseAuthoringTextField(
                      key: const ValueKey('exercise-authoring-default-tempo'),
                      controller: _defaultTempoController,
                      enabled: !widget.isBusy,
                      labelText: 'Default tempo',
                      icon: Icons.graphic_eq_outlined,
                      textInputAction: TextInputAction.next,
                    ),
                  ),
                  SizedBox(
                    width: fieldWidth,
                    child: _ExerciseAuthoringTextField(
                      key: const ValueKey('exercise-authoring-log-format'),
                      controller: _logFormatController,
                      enabled: !widget.isBusy,
                      labelText: 'Log format',
                      icon: Icons.data_object_outlined,
                      textInputAction: TextInputAction.next,
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            key: const ValueKey('exercise-authoring-notes'),
            controller: _notesController,
            enabled: !widget.isBusy,
            decoration: const InputDecoration(
              labelText: 'Notes',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.notes_outlined),
            ),
            minLines: 3,
            maxLines: 5,
            textInputAction: TextInputAction.newline,
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.end,
            children: [
              if (widget.onCancel != null)
                OutlinedButton.icon(
                  onPressed: widget.isBusy ? null : widget.onCancel,
                  icon: const Icon(Icons.close_outlined),
                  label: const Text('Cancel'),
                ),
              FilledButton.icon(
                key: const ValueKey('exercise-authoring-submit'),
                onPressed: widget.isBusy ? null : _submit,
                icon: widget.isBusy
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check_circle_outline),
                label: Text(submitLabel),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ExerciseAuthoringTextField extends StatelessWidget {
  const _ExerciseAuthoringTextField({
    super.key,
    required this.controller,
    required this.enabled,
    required this.labelText,
    required this.icon,
    required this.textInputAction,
    this.keyboardType,
  });

  final TextEditingController controller;
  final bool enabled;
  final String labelText;
  final IconData icon;
  final TextInputAction textInputAction;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      decoration: InputDecoration(
        labelText: labelText,
        border: const OutlineInputBorder(),
        prefixIcon: Icon(icon),
      ),
      textInputAction: textInputAction,
      keyboardType: keyboardType,
    );
  }
}

String _exerciseAuthoringTitle(ExerciseAuthoringContext context) {
  return switch (context) {
    ExerciseAuthoringContext.canonicalExercise => 'New exercise',
    ExerciseAuthoringContext.workoutPlacement => 'Add exercise to workout',
  };
}

String _exerciseAuthoringSubmitLabel(ExerciseAuthoringContext context) {
  return switch (context) {
    ExerciseAuthoringContext.canonicalExercise => 'Save exercise',
    ExerciseAuthoringContext.workoutPlacement => 'Continue',
  };
}

IconData _exerciseAuthoringIcon(ExerciseAuthoringContext context) {
  return switch (context) {
    ExerciseAuthoringContext.canonicalExercise => Icons.fitness_center_outlined,
    ExerciseAuthoringContext.workoutPlacement => Icons.playlist_add_outlined,
  };
}
