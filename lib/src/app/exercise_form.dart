import 'package:flutter/material.dart';
import 'package:workout_tracker/contract.dart';

import 'ui/shared/a11y.dart';
import 'ui/shared/header.dart';
import 'ui/shared/next_field.dart';

enum ExerciseFormMode { create, edit }

class ExerciseAuthoringScreen extends StatefulWidget {
  const ExerciseAuthoringScreen({
    required this.a11yLabel,
    required this.title,
    required this.sheetLabel,
    required this.backTooltip,
    required this.mode,
    required this.initialDraft,
    required this.isBusy,
    required this.onClose,
    required this.onSave,
    super.key,
  });

  final String a11yLabel;
  final String title;
  final String sheetLabel;
  final String backTooltip;
  final ExerciseFormMode mode;
  final CanonicalExerciseDraft initialDraft;
  final bool isBusy;
  final Future<void> Function() onClose;
  final Future<bool> Function(ExerciseDef exercise) onSave;

  @override
  State<ExerciseAuthoringScreen> createState() => _AuthoringScreenSt();
}

class _AuthoringScreenSt extends State<ExerciseAuthoringScreen> {
  late CanonicalExerciseDraft _initial;
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    _initial = widget.initialDraft.normalized();
  }

  @override
  void didUpdateWidget(ExerciseAuthoringScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialDraft == widget.initialDraft) {
      return;
    }
    _initial = widget.initialDraft.normalized();
    _dirty = false;
  }

  void _draftChanged(CanonicalExerciseDraft draft) {
    final dirty = draft.normalized() != _initial;
    if (dirty == _dirty) {
      return;
    }
    setState(() => _dirty = dirty);
  }

  Future<void> _close() async {
    if (!_dirty) {
      await widget.onClose();
      return;
    }
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard changes?'),
        content: const Text('Your unsaved exercise changes will be lost.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep editing'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    if (discard == true) {
      await widget.onClose();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<Object?>(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _close();
        }
      },
      child: A11yScreen(
        label: widget.a11yLabel,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ScreenHeader(
              title: widget.sheetLabel,
              subtitle: widget.title,
              compactTitle: true,
              backTooltip: widget.backTooltip,
              onBack: _close,
            ),
            const SizedBox(height: 16),
            ExerciseAuthoringForm(
              mode: widget.mode,
              initialDraft: widget.initialDraft,
              onCancel: _close,
              onChanged: _draftChanged,
              onSubmit: (draft) => widget.onSave(draft.toDef()),
              isBusy: widget.isBusy,
            ),
          ],
        ),
      ),
    );
  }
}

class CanonicalExerciseDraft {
  CanonicalExerciseDraft({
    required this.exerciseName,
    required this.description,
    required this.defaultSets,
    required Map<String, String> defaultValues,
    required this.defaultRest,
    required this.defaultTempo,
    required this.notes,
    required this.logFormat,
    Iterable<String> timerFields = const [],
  }) : defaultValues = Map<String, String>.unmodifiable(defaultValues),
       timerFields = List<String>.unmodifiable(timerFields);

  static final defaults = CanonicalExerciseDraft(
    exerciseName: '',
    description: '',
    defaultSets: '3',
    defaultValues: const {'Weight': '', 'Reps': '10', 'RPE': '8'},
    defaultRest: '2 min',
    defaultTempo: '2-1-1',
    notes: '',
    logFormat: defaultExerciseLogFormat,
  );

  factory CanonicalExerciseDraft.fromExercise(CanonicalExercise exercise) {
    return CanonicalExerciseDraft(
      exerciseName: exercise.exercise,
      description: exercise.description,
      defaultSets: exercise.defaultSets,
      defaultValues: exercise.defaultValues,
      defaultRest: exercise.defaultRest,
      defaultTempo: exercise.defaultTempo,
      notes: exercise.notes,
      logFormat: exercise.logFormat,
      timerFields: exercise.timerFields,
    );
  }

  final String exerciseName;
  final String description;
  final String defaultSets;
  final Map<String, String> defaultValues;
  final String defaultRest;
  final String defaultTempo;
  final String notes;
  final String logFormat;

  /// Log Format labels this exercise times, in declaration order.
  final List<String> timerFields;

  CanonicalExerciseDraft normalized() {
    final trimmedLogFormat = logFormat.trim();
    return CanonicalExerciseDraft(
      exerciseName: exerciseName.trim(),
      description: description.trim(),
      defaultSets: defaultSets.trim(),
      defaultValues: {
        for (final entry in defaultValues.entries)
          entry.key: entry.value.trim(),
      },
      defaultRest: defaultRest.trim(),
      defaultTempo: defaultTempo.trim(),
      notes: notes.trim(),
      logFormat: trimmedLogFormat.isEmpty
          ? defaultExerciseLogFormat
          : trimmedLogFormat,
      timerFields: timerFields,
    );
  }

  ExerciseDef toDef() {
    final draft = normalized();
    return ExerciseDef(
      exercise: draft.exerciseName,
      description: draft.description,
      defaultSets: draft.defaultSets,
      defaultValues: draft.defaultValues,
      defaultRest: draft.defaultRest,
      defaultTempo: draft.defaultTempo,
      notes: draft.notes,
      logFormat: draft.logFormat,
      timerFields: draft.timerFields,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is CanonicalExerciseDraft &&
            exerciseName == other.exerciseName &&
            description == other.description &&
            defaultSets == other.defaultSets &&
            _sameStringMap(defaultValues, other.defaultValues) &&
            defaultRest == other.defaultRest &&
            defaultTempo == other.defaultTempo &&
            notes == other.notes &&
            logFormat == other.logFormat &&
            _sameStringList(timerFields, other.timerFields);
  }

  @override
  int get hashCode {
    return Object.hash(
      exerciseName,
      description,
      defaultSets,
      Object.hashAll(defaultValues.entries),
      defaultRest,
      defaultTempo,
      notes,
      logFormat,
      Object.hashAll(timerFields),
    );
  }
}

class ExerciseAuthoringForm extends StatefulWidget {
  const ExerciseAuthoringForm({
    required this.onSubmit,
    required this.mode,
    required this.initialDraft,
    this.onCancel,
    this.onChanged,
    this.isBusy = false,
    super.key,
  });

  final ExerciseFormMode mode;
  final CanonicalExerciseDraft initialDraft;
  final ValueChanged<CanonicalExerciseDraft> onSubmit;
  final VoidCallback? onCancel;
  final ValueChanged<CanonicalExerciseDraft>? onChanged;
  final bool isBusy;

  @override
  State<ExerciseAuthoringForm> createState() => _AuthoringFormSt();
}

class _AuthoringFormSt extends State<ExerciseAuthoringForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _setsCtrl;
  final _valueCtrls = <String, TextEditingController>{};
  List<String> _fieldLabels = const [];
  final _timedLabels = <String>{};
  late final TextEditingController _restCtrl;
  late final TextEditingController _tempoCtrl;
  late final TextEditingController _notesCtrl;
  late final TextEditingController _formatCtrl;
  late final FocusNode _notesFocus;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController();
    _descCtrl = TextEditingController();
    _setsCtrl = TextEditingController();
    _restCtrl = TextEditingController();
    _tempoCtrl = TextEditingController();
    _notesCtrl = TextEditingController();
    _formatCtrl = TextEditingController();
    _notesFocus = FocusNode(debugLabel: 'Notes');
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
    for (final controller in _valueCtrls.values) {
      controller.dispose();
    }
    _restCtrl.dispose();
    _tempoCtrl.dispose();
    _notesCtrl.dispose();
    _formatCtrl.dispose();
    _notesFocus.dispose();
    super.dispose();
  }

  void _loadDraft(CanonicalExerciseDraft draft) {
    _nameCtrl.text = draft.exerciseName;
    _descCtrl.text = draft.description;
    _setsCtrl.text = draft.defaultSets;
    _restCtrl.text = draft.defaultRest;
    _tempoCtrl.text = draft.defaultTempo;
    _notesCtrl.text = draft.notes;
    _formatCtrl.text = draft.logFormat;
    _timedLabels
      ..clear()
      ..addAll(draft.timerFields);
    _syncValueCtrls(draft.logFormat, values: draft.defaultValues);
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
      defaultValues: {
        for (final label in _fieldLabels) label: _valueCtrls[label]?.text ?? '',
      },
      defaultRest: _restCtrl.text,
      defaultTempo: _tempoCtrl.text,
      notes: _notesCtrl.text,
      logFormat: _formatCtrl.text,
      timerFields: [
        for (final label in _fieldLabels)
          if (_timedLabels.contains(label)) label,
      ],
    );
  }

  void _changed(String _) {
    widget.onChanged?.call(_draft());
    setState(() {});
  }

  void _timerChanged(String label, bool timed) {
    setState(() {
      if (timed) {
        _timedLabels.add(label);
      } else {
        _timedLabels.remove(label);
      }
    });
    widget.onChanged?.call(_draft());
  }

  void _formatChanged(String value) {
    _syncValueCtrls(value);
    _changed(value);
  }

  void _syncValueCtrls(String format, {Map<String, String> values = const {}}) {
    final parsed = parseLogFormat(format);
    if (parsed is! ParsedLogFormat) {
      return;
    }
    _fieldLabels = parsed.fieldLabels;
    for (final label in _fieldLabels) {
      final controller = _valueCtrls.putIfAbsent(
        label,
        TextEditingController.new,
      );
      if (values.containsKey(label)) {
        controller.text = values[label] ?? '';
      }
    }
  }

  String? _formatError(String? value) {
    return switch (parseLogFormat(value ?? '')) {
      InvalidLogFormat(:final errors) => errors.join(' '),
      ParsedLogFormat() => null,
    };
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final title = switch (widget.mode) {
      ExerciseFormMode.create => 'New exercise',
      ExerciseFormMode.edit => 'Edit exercise',
    };
    final parsedFormat = parseLogFormat(_formatCtrl.text);
    final valueLabels = parsedFormat is ParsedLogFormat
        ? parsedFormat.fieldLabels
        : const <String>[];

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.fitness_center_outlined, color: colorScheme.primary),
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
          _AuthoringField(
            key: const ValueKey('exercise-authoring-name'),
            controller: _nameCtrl,
            enabled: !widget.isBusy,
            semanticsIdentifier: 'exercise-authoring-name',
            labelText: 'Exercise name',
            icon: Icons.fitness_center_outlined,
            nextLabel: 'Description',
            textInputAction: TextInputAction.next,
            selectAllOnFocus: false,
            onChanged: _changed,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Enter an exercise name.';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          _AuthoringField(
            key: const ValueKey('exercise-authoring-description'),
            controller: _descCtrl,
            enabled: !widget.isBusy,
            semanticsIdentifier: 'exercise-authoring-description',
            labelText: 'Description',
            icon: Icons.short_text_outlined,
            nextLabel: 'Default sets',
            textInputAction: TextInputAction.next,
            selectAllOnFocus: false,
            onChanged: _changed,
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
                      nextLabel: 'Default tempo',
                      textInputAction: TextInputAction.next,
                      keyboardType: TextInputType.number,
                      onChanged: _changed,
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
                      nextLabel: 'Default rest',
                      textInputAction: TextInputAction.next,
                      onChanged: _changed,
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
                      nextLabel: 'Log format',
                      textInputAction: TextInputAction.next,
                      onChanged: _changed,
                    ),
                  ),
                  SizedBox(
                    width: fieldWidth,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _AuthoringField(
                          key: const ValueKey('exercise-authoring-log-format'),
                          controller: _formatCtrl,
                          enabled: !widget.isBusy,
                          semanticsIdentifier: 'exercise-authoring-log-format',
                          labelText: 'Log format',
                          icon: Icons.data_object_outlined,
                          nextLabel: valueLabels.isEmpty
                              ? 'Notes'
                              : 'Default ${valueLabels.first}',
                          textInputAction: TextInputAction.next,
                          helperText:
                              'Use {Field}, such as {Weight (lbs)}, for 1–5 '
                              'values; all other text is literal. Enter '
                              'numeric defaults; units belong in field names.',
                          validator: _formatError,
                          autovalidateMode: AutovalidateMode.onUserInteraction,
                          onChanged: _formatChanged,
                        ),
                        if (parsedFormat case ParsedLogFormat()) ...[
                          const SizedBox(height: 6),
                          Text(
                            'Preview: ${parsedFormat.renderValues({for (final label in parsedFormat.fieldLabels) label: _valueCtrls[label]?.text ?? ''})}',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: colorScheme.onSurfaceVariant),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
          if (parsedFormat case ParsedLogFormat(:final fieldLabels)) ...[
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
                    for (var index = 0; index < fieldLabels.length; index += 1)
                      SizedBox(
                        width: fieldWidth,
                        child: _AuthoringField(
                          key: ValueKey(
                            'exercise-authoring-default-${fieldLabels[index]}',
                          ),
                          controller: _valueCtrls[fieldLabels[index]]!,
                          enabled: !widget.isBusy,
                          semanticsIdentifier:
                              'exercise-authoring-default-${fieldLabels[index]}',
                          labelText: 'Default ${fieldLabels[index]}',
                          icon: Icons.tune_outlined,
                          nextLabel: index < fieldLabels.length - 1
                              ? 'Default ${fieldLabels[index + 1]}'
                              : 'Notes',
                          nextFocusNode: index < fieldLabels.length - 1
                              ? null
                              : _notesFocus,
                          textInputAction: TextInputAction.next,
                          onChanged: _changed,
                        ),
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: 12),
            A11yHeader(
              label: 'Timer',
              child: ExcludeSemantics(
                child: Text(
                  'Timer',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Timed fields count down in seconds while you log a set.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            LayoutBuilder(
              builder: (context, constraints) {
                final twoColumn = constraints.maxWidth >= 620;
                final fieldWidth = twoColumn
                    ? (constraints.maxWidth - 12) / 2
                    : constraints.maxWidth;
                return Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  children: [
                    for (final label in fieldLabels)
                      SizedBox(
                        width: fieldWidth,
                        child: _TimerCheckbox(
                          key: ValueKey('exercise-authoring-timer-$label'),
                          label: label,
                          timed: _timedLabels.contains(label),
                          enabled: !widget.isBusy,
                          onChanged: (timed) => _timerChanged(label, timed),
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
          const SizedBox(height: 12),
          A11yTextField(
            identifier: 'exercise-authoring-notes',
            label: 'Notes',
            valueListenable: _notesCtrl,
            child: TextFormField(
              key: const ValueKey('exercise-authoring-notes'),
              controller: _notesCtrl,
              focusNode: _notesFocus,
              enabled: !widget.isBusy,
              decoration: const InputDecoration(
                labelText: 'Notes',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.notes_outlined),
              ),
              minLines: 3,
              maxLines: 5,
              textInputAction: TextInputAction.newline,
              onChanged: _changed,
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
                label: const Text('Save exercise'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

bool _sameStringMap(Map<String, String> left, Map<String, String> right) {
  if (left.length != right.length) {
    return false;
  }
  return left.entries.every((entry) => right[entry.key] == entry.value);
}

bool _sameStringList(List<String> left, List<String> right) {
  if (left.length != right.length) {
    return false;
  }
  for (var index = 0; index < left.length; index += 1) {
    if (left[index] != right[index]) {
      return false;
    }
  }
  return true;
}

/// One `Timer` column checkbox for a single Log Format field.
class _TimerCheckbox extends StatelessWidget {
  const _TimerCheckbox({
    super.key,
    required this.label,
    required this.timed,
    required this.enabled,
    required this.onChanged,
  });

  final String label;
  final bool timed;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return CheckboxListTile(
      value: timed,
      onChanged: enabled ? (value) => onChanged(value ?? false) : null,
      controlAffinity: ListTileControlAffinity.leading,
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      title: Text(label, semanticsLabel: 'Timer $label'),
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
    this.nextLabel,
    this.nextFocusNode,
    this.keyboardType,
    this.helperText,
    this.validator,
    this.autovalidateMode,
    this.onChanged,
    this.selectAllOnFocus = true,
  });

  final TextEditingController controller;
  final bool enabled;
  final String semanticsIdentifier;
  final String labelText;
  final IconData icon;
  final TextInputAction textInputAction;
  final String? nextLabel;

  /// The field [nextLabel] names, when it is not the next node in traversal.
  final FocusNode? nextFocusNode;
  final TextInputType? keyboardType;
  final String? helperText;
  final FormFieldValidator<String>? validator;
  final AutovalidateMode? autovalidateMode;
  final ValueChanged<String>? onChanged;
  final bool selectAllOnFocus;

  @override
  State<_AuthoringField> createState() => _AuthoringFieldSt();
}

class _AuthoringFieldSt extends State<_AuthoringField> {
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    if (widget.selectAllOnFocus) {
      _focusNode.addListener(_selectTextAfterFocus);
    }
  }

  @override
  void dispose() {
    if (widget.selectAllOnFocus) {
      _focusNode.removeListener(_selectTextAfterFocus);
    }
    _focusNode.dispose();
    super.dispose();
  }

  void _advance() {
    final target = widget.nextFocusNode;
    if (target != null) {
      target.requestFocus();
      return;
    }
    _focusNode.nextFocus();
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
    final nextLabel = widget.nextLabel;
    return A11yTextField(
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
          suffixIcon: nextLabel == null
              ? null
              : NextFieldButton(
                  focusNode: _focusNode,
                  nextLabel: nextLabel,
                  onNext: _advance,
                ),
          helperText: widget.helperText,
        ),
        textInputAction: widget.textInputAction,
        keyboardType: widget.keyboardType,
        selectAllOnFocus: widget.selectAllOnFocus,
        onFieldSubmitted: (_) =>
            nextLabel == null ? _focusNode.unfocus() : _advance(),
        onTapOutside: (_) => _focusNode.unfocus(),
        validator: widget.validator,
        autovalidateMode: widget.autovalidateMode,
        onChanged: widget.onChanged,
      ),
    );
  }
}
