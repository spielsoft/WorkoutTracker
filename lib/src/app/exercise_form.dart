part of 'shell.dart';

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
    logFormat: defaultExerciseLogFormat,
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
          ? defaultExerciseLogFormat
          : trimmedLogFormat,
    );
  }

  ExerciseDef toDef() {
    final draft = normalized();
    return ExerciseDef(
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
    final title = _authoringTitle(authoringContext);
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
  State<ExerciseAuthoringForm> createState() => _AuthoringFormSt();
}

class _AuthoringFormSt extends State<ExerciseAuthoringForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _setsCtrl;
  late final TextEditingController _repsCtrl;
  late final TextEditingController _rpeCtrl;
  late final TextEditingController _restCtrl;
  late final TextEditingController _tempoCtrl;
  late final TextEditingController _notesCtrl;
  late final TextEditingController _formatCtrl;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController();
    _descCtrl = TextEditingController();
    _setsCtrl = TextEditingController();
    _repsCtrl = TextEditingController();
    _rpeCtrl = TextEditingController();
    _restCtrl = TextEditingController();
    _tempoCtrl = TextEditingController();
    _notesCtrl = TextEditingController();
    _formatCtrl = TextEditingController();
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
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _setsCtrl.dispose();
    _repsCtrl.dispose();
    _rpeCtrl.dispose();
    _restCtrl.dispose();
    _tempoCtrl.dispose();
    _notesCtrl.dispose();
    _formatCtrl.dispose();
    super.dispose();
  }

  void _loadDraft(CanonicalExerciseDraft draft) {
    _nameCtrl.text = draft.exerciseName;
    _descCtrl.text = draft.description;
    _setsCtrl.text = draft.defaultSets;
    _repsCtrl.text = draft.defaultReps;
    _rpeCtrl.text = draft.defaultRPE;
    _restCtrl.text = draft.defaultRest;
    _tempoCtrl.text = draft.defaultTempo;
    _notesCtrl.text = draft.notes;
    _formatCtrl.text = draft.logFormat;
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    widget.onSubmit(_draft().normalized());
  }

  CanonicalExerciseDraft _draft() {
    return CanonicalExerciseDraft(
      exerciseName: _nameCtrl.text,
      description: _descCtrl.text,
      defaultSets: _setsCtrl.text,
      defaultReps: _repsCtrl.text,
      defaultRPE: _rpeCtrl.text,
      defaultRest: _restCtrl.text,
      defaultTempo: _tempoCtrl.text,
      notes: _notesCtrl.text,
      logFormat: _formatCtrl.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final title = _authoringTitle(widget.authoringContext);
    final submitText = _submitLabelText(widget.authoringContext);

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                _authoringIcon(widget.authoringContext),
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
          _A11yTextField(
            identifier: 'exercise-authoring-name',
            label: 'Exercise name',
            valueListenable: _nameCtrl,
            child: TextFormField(
              key: const ValueKey('exercise-authoring-name'),
              controller: _nameCtrl,
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
          ),
          const SizedBox(height: 12),
          _A11yTextField(
            identifier: 'exercise-authoring-description',
            label: 'Description',
            valueListenable: _descCtrl,
            child: TextFormField(
              key: const ValueKey('exercise-authoring-description'),
              controller: _descCtrl,
              enabled: !widget.isBusy,
              decoration: const InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.short_text_outlined),
              ),
              textInputAction: TextInputAction.next,
            ),
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
                    child: _AuthoringField(
                      key: const ValueKey('exercise-authoring-default-sets'),
                      controller: _setsCtrl,
                      enabled: !widget.isBusy,
                      semanticsIdentifier: 'exercise-authoring-default-sets',
                      labelText: 'Default sets',
                      icon: Icons.format_list_numbered_outlined,
                      textInputAction: TextInputAction.next,
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  SizedBox(
                    width: fieldWidth,
                    child: _AuthoringField(
                      key: const ValueKey('exercise-authoring-default-reps'),
                      controller: _repsCtrl,
                      enabled: !widget.isBusy,
                      semanticsIdentifier: 'exercise-authoring-default-reps',
                      labelText: 'Default reps',
                      icon: Icons.repeat_outlined,
                      textInputAction: TextInputAction.next,
                    ),
                  ),
                  SizedBox(
                    width: fieldWidth,
                    child: _AuthoringField(
                      key: const ValueKey('exercise-authoring-default-rpe'),
                      controller: _rpeCtrl,
                      enabled: !widget.isBusy,
                      semanticsIdentifier: 'exercise-authoring-default-rpe',
                      labelText: 'Default RPE',
                      icon: Icons.speed_outlined,
                      textInputAction: TextInputAction.next,
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  SizedBox(
                    width: fieldWidth,
                    child: _AuthoringField(
                      key: const ValueKey('exercise-authoring-default-rest'),
                      controller: _restCtrl,
                      enabled: !widget.isBusy,
                      semanticsIdentifier: 'exercise-authoring-default-rest',
                      labelText: 'Default rest',
                      icon: Icons.timer_outlined,
                      textInputAction: TextInputAction.next,
                    ),
                  ),
                  SizedBox(
                    width: fieldWidth,
                    child: _AuthoringField(
                      key: const ValueKey('exercise-authoring-default-tempo'),
                      controller: _tempoCtrl,
                      enabled: !widget.isBusy,
                      semanticsIdentifier: 'exercise-authoring-default-tempo',
                      labelText: 'Default tempo',
                      icon: Icons.graphic_eq_outlined,
                      textInputAction: TextInputAction.next,
                    ),
                  ),
                  SizedBox(
                    width: fieldWidth,
                    child: _AuthoringField(
                      key: const ValueKey('exercise-authoring-log-format'),
                      controller: _formatCtrl,
                      enabled: !widget.isBusy,
                      semanticsIdentifier: 'exercise-authoring-log-format',
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
          _A11yTextField(
            identifier: 'exercise-authoring-notes',
            label: 'Notes',
            valueListenable: _notesCtrl,
            child: TextFormField(
              key: const ValueKey('exercise-authoring-notes'),
              controller: _notesCtrl,
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
                label: Text(submitText),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AuthoringField extends StatefulWidget {
  const _AuthoringField({
    super.key,
    required this.controller,
    required this.enabled,
    required this.semanticsIdentifier,
    required this.labelText,
    required this.icon,
    required this.textInputAction,
    this.keyboardType,
  });

  final TextEditingController controller;
  final bool enabled;
  final String semanticsIdentifier;
  final String labelText;
  final IconData icon;
  final TextInputAction textInputAction;
  final TextInputType? keyboardType;

  @override
  State<_AuthoringField> createState() => _AuthoringFieldSt();
}

class _AuthoringFieldSt extends State<_AuthoringField> {
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _focusNode.addListener(_selectTextAfterFocus);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_selectTextAfterFocus);
    _focusNode.dispose();
    super.dispose();
  }

  void _selectTextAfterFocus() {
    if (!_focusNode.hasFocus) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_focusNode.hasFocus) {
        return;
      }
      widget.controller.selection = TextSelection(
        baseOffset: 0,
        extentOffset: widget.controller.text.length,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return _A11yTextField(
      identifier: widget.semanticsIdentifier,
      label: widget.labelText,
      valueListenable: widget.controller,
      child: TextFormField(
        controller: widget.controller,
        enabled: widget.enabled,
        focusNode: _focusNode,
        decoration: InputDecoration(
          labelText: widget.labelText,
          border: const OutlineInputBorder(),
          prefixIcon: Icon(widget.icon),
        ),
        textInputAction: widget.textInputAction,
        keyboardType: widget.keyboardType,
        selectAllOnFocus: true,
      ),
    );
  }
}

String _authoringTitle(ExerciseAuthoringContext context) {
  return switch (context) {
    ExerciseAuthoringContext.canonicalExercise => 'New exercise',
    ExerciseAuthoringContext.workoutPlacement => 'Add exercise to workout',
  };
}

String _submitLabelText(ExerciseAuthoringContext context) {
  return switch (context) {
    ExerciseAuthoringContext.canonicalExercise => 'Save exercise',
    ExerciseAuthoringContext.workoutPlacement => 'Continue',
  };
}

IconData _authoringIcon(ExerciseAuthoringContext context) {
  return switch (context) {
    ExerciseAuthoringContext.canonicalExercise => Icons.fitness_center_outlined,
    ExerciseAuthoringContext.workoutPlacement => Icons.playlist_add_outlined,
  };
}
