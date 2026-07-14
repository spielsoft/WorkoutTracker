import 'package:flutter/material.dart';
import 'package:workout_tracker/contract.dart';

import 'exercise_form.dart';
import 'ui/shared/header.dart';
import 'ui/view.dart';

final class EditExerciseView extends LoadedView {
  const EditExerciseView({
    required super.isBusy,
    required super.sheetLabel,
    required this.exercise,
    this.formatImpact,
    this.pendingExercise,
    super.error,
  });

  final CanonicalExercise exercise;
  final ExeFormatImpact? formatImpact;
  final ExerciseDef? pendingExercise;
}

abstract interface class EditExerciseActions {
  Future<void> close();

  Future<bool> save(ExerciseDef exercise);

  Future<bool> confirmFormatUpdate(Map<int, Map<String, String>> valuesByRow);

  void cancelFormatUpdate();
}

class EditExerciseScreen extends StatelessWidget {
  const EditExerciseScreen({
    required this.view,
    required this.actions,
    super.key,
  });

  final EditExerciseView view;
  final EditExerciseActions actions;

  @override
  Widget build(BuildContext context) {
    final impact = view.formatImpact;
    if (impact != null) {
      return _FormatUpdateReview(
        impact: impact,
        isBusy: view.isBusy,
        sheetLabel: view.sheetLabel,
        onBack: actions.cancelFormatUpdate,
        onConfirm: actions.confirmFormatUpdate,
      );
    }
    final pending = view.pendingExercise;
    return ExerciseAuthoringScreen(
      a11yLabel: 'Edit exercise ${view.exercise.displayName}',
      title: 'Edit exercise',
      sheetLabel: view.sheetLabel,
      backTooltip: 'Back to edit exercises',
      mode: ExerciseFormMode.edit,
      initialDraft: pending != null
          ? CanonicalExerciseDraft(
              exerciseName: pending.exercise,
              description: pending.description,
              defaultSets: pending.defaultSets,
              defaultValues: pending.defaultValues,
              defaultRest: pending.defaultRest,
              defaultTempo: pending.defaultTempo,
              notes: pending.notes,
              logFormat: pending.logFormat,
            )
          : CanonicalExerciseDraft.fromExercise(view.exercise),
      isBusy: view.isBusy,
      onClose: actions.close,
      onSave: actions.save,
    );
  }
}

class _FormatUpdateReview extends StatefulWidget {
  const _FormatUpdateReview({
    required this.impact,
    required this.isBusy,
    required this.sheetLabel,
    required this.onBack,
    required this.onConfirm,
  });

  final ExeFormatImpact impact;
  final bool isBusy;
  final String sheetLabel;
  final VoidCallback onBack;
  final Future<bool> Function(Map<int, Map<String, String>>) onConfirm;

  @override
  State<_FormatUpdateReview> createState() => _FormatUpdateReviewSt();
}

class _FormatUpdateReviewSt extends State<_FormatUpdateReview> {
  final _formKey = GlobalKey<FormState>();
  final _ctrls = <int, Map<String, TextEditingController>>{};

  @override
  void initState() {
    super.initState();
    for (final placement in widget.impact.placements) {
      _ctrls[placement.sheetRowNumber] = {
        for (final field in widget.impact.fields)
          field: TextEditingController(text: placement.proposedValues[field]),
      };
    }
  }

  @override
  void dispose() {
    for (final row in _ctrls.values) {
      for (final ctrl in row.values) {
        ctrl.dispose();
      }
    }
    super.dispose();
  }

  Future<void> _confirm() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    await widget.onConfirm({
      for (final placement in widget.impact.placements)
        placement.sheetRowNumber: {
          for (final field in widget.impact.fields)
            field: _ctrls[placement.sheetRowNumber]![field]!.text,
        },
    });
  }

  String? _validateField(int row, String field, String? value) {
    final values = {
      for (final label in widget.impact.fields)
        label: label == field ? value ?? '' : _ctrls[row]![label]!.text,
    };
    final plan = widget.impact.plan({
      for (final placement in widget.impact.placements)
        placement.sheetRowNumber: placement.sheetRowNumber == row
            ? values
            : {
                for (final label in widget.impact.fields)
                  label: _ctrls[placement.sheetRowNumber]![label]!.text,
              },
    });
    return plan.validationRejections.isEmpty
        ? null
        : 'Value conflicts with the proposed format punctuation.';
  }

  @override
  Widget build(BuildContext context) {
    final placementCount = widget.impact.placements.length;
    final historyCount = widget.impact.rawHistoryCount;
    return Semantics(
      label: 'Review exercise format change',
      container: true,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ScreenHeader(
              title: widget.sheetLabel,
              subtitle: 'Review format change',
              compactTitle: true,
              backTooltip: 'Back to exercise fields',
              onBack: widget.onBack,
            ),
            const SizedBox(height: 16),
            Text(
              '$placementCount ${placementCount == 1 ? 'placement' : 'placements'} '
              'will receive reviewed Targets.',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              '$historyCount existing ${historyCount == 1 ? 'history entry' : 'history entries'} '
              'will become raw text. History will remain unchanged and editable.',
            ),
            const SizedBox(height: 16),
            for (final placement in widget.impact.placements) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Row ${placement.sheetRowNumber} · '
                        '${placement.workout} · '
                        '${placement.isBackup ? 'Backup' : 'Primary'}',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 4),
                      Text('Current Targets: ${placement.oldTargets}'),
                      if (placement.rawHistoryCount > 0)
                        Text(
                          '${placement.rawHistoryCount} history '
                          '${placement.rawHistoryCount == 1 ? 'entry becomes' : 'entries become'} raw.',
                        ),
                      const SizedBox(height: 12),
                      for (final field in widget.impact.fields) ...[
                        TextFormField(
                          key: ValueKey(
                            'format-update-${placement.sheetRowNumber}-$field',
                          ),
                          controller: _ctrls[placement.sheetRowNumber]![field],
                          enabled: !widget.isBusy,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                            signed: true,
                          ),
                          decoration: InputDecoration(
                            labelText: 'Row ${placement.sheetRowNumber} $field',
                            border: const OutlineInputBorder(),
                          ),
                          validator: (value) => _validateField(
                            placement.sheetRowNumber,
                            field,
                            value,
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.end,
              children: [
                OutlinedButton(
                  onPressed: widget.isBusy ? null : widget.onBack,
                  child: const Text('Back'),
                ),
                FilledButton.icon(
                  key: const ValueKey('confirm-format-update'),
                  onPressed: widget.isBusy ? null : _confirm,
                  icon: const Icon(Icons.sync_alt),
                  label: const Text('Update exercise and Targets'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
