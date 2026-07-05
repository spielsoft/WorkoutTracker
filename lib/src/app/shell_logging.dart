part of 'shell.dart';

class _ExerciseLoggingScreen extends StatefulWidget {
  const _ExerciseLoggingScreen({
    required this.sheetLabel,
    required this.activeSheet,
    required this.historyBlockLabel,
    required this.primarySheetRowNumber,
    required this.selectedSheetRowNumber,
    required this.onChoiceChanged,
    required this.onClose,
    required this.onApplyWritePlan,
  });

  final String sheetLabel;
  final ParsedActiveSheet activeSheet;
  final String historyBlockLabel;
  final int primarySheetRowNumber;
  final int selectedSheetRowNumber;
  final ValueChanged<int> onChoiceChanged;
  final VoidCallback onClose;
  final Future<bool> Function(ActiveSheetWritePlan plan) onApplyWritePlan;

  @override
  State<_ExerciseLoggingScreen> createState() => _ExerciseLoggingScreenState();
}

class _ExerciseLoggingScreenState extends State<_ExerciseLoggingScreen> {
  late final ExerciseLoggingFlow _flow;
  bool _isWriting = false;
  String? _writeError;

  @override
  void initState() {
    super.initState();
    _flow = _createFlow();
  }

  @override
  void didUpdateWidget(_ExerciseLoggingScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedSheetRowNumber != widget.selectedSheetRowNumber ||
        oldWidget.historyBlockLabel != widget.historyBlockLabel ||
        oldWidget.primarySheetRowNumber != widget.primarySheetRowNumber ||
        oldWidget.activeSheet != widget.activeSheet) {
      _flow.update(
        activeSheet: widget.activeSheet,
        historyBlockLabel: widget.historyBlockLabel,
        primarySheetRowNumber: widget.primarySheetRowNumber,
        selectedSheetRowNumber: widget.selectedSheetRowNumber,
      );
    }
  }

  @override
  void dispose() {
    _flow.dispose();
    super.dispose();
  }

  ExerciseLoggingFlow _createFlow() {
    return ExerciseLoggingFlow(
      activeSheet: widget.activeSheet,
      historyBlockLabel: widget.historyBlockLabel,
      primarySheetRowNumber: widget.primarySheetRowNumber,
      selectedSheetRowNumber: widget.selectedSheetRowNumber,
    );
  }

  Future<void> _saveStructuredSet() async {
    if (_isWriting) {
      return;
    }
    final plan = _flow.planStructuredSetSave();
    if (plan == null) {
      return;
    }

    await _runWrite(() async {
      final saved = await widget.onApplyWritePlan(plan);
      if (!saved) {
        return false;
      }
      _flow.clearNewSetControllers();
      return true;
    });
  }

  Future<bool> _runWrite(Future<bool> Function() action) async {
    if (_isWriting) {
      return false;
    }
    setState(() {
      _isWriting = true;
      _writeError = null;
    });
    var saved = false;
    try {
      saved = await action();
      return saved;
    } on Object {
      return false;
    } finally {
      if (mounted) {
        setState(() {
          _isWriting = false;
          _writeError = saved ? null : 'Unable to save set. Try again.';
        });
      }
    }
  }

  Future<void> _saveRawSet(RowHistoryEntry entry) async {
    await _runWrite(() async {
      return widget.onApplyWritePlan(_flow.planRawSetEdit(entry));
    });
  }

  Future<void> _saveStructuredSetEdit(RowHistoryEntry entry) async {
    if (_isWriting) {
      return;
    }
    final plan = _flow.planStructuredSetEdit(entry);
    if (plan == null) {
      return;
    }
    await _runWrite(() async {
      return widget.onApplyWritePlan(plan);
    });
  }

  Future<void> _clearSet(RowHistoryEntry entry) async {
    await _runWrite(() async {
      return widget.onApplyWritePlan(_flow.planSetClear(entry));
    });
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = _flow.viewModel;
    final loggingContext = viewModel.context;
    final selectedChoice = loggingContext.selectedChoice;
    final loggedSetNumbers = {
      for (final entry in viewModel.loggedEntries) entry.setNumber,
    };
    final priorHistoryBlocks = loggingContext.recentHistoryBlocks
        .where((block) => block.label != loggingContext.selectedHistory.label)
        .toList();
    final plannedSetCount = int.tryParse(loggingContext.targets.sets.trim());
    final visibleSetCount = loggingContext.selectedHistory.entries.length;
    final totalSetCount = plannedSetCount != null && plannedSetCount > 0
        ? plannedSetCount
        : visibleSetCount < viewModel.nextSetNumber
        ? viewModel.nextSetNumber
        : visibleSetCount;

    return _A11yScreen(
      label: 'Log ${selectedChoice.exercise}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ScreenHeader(
            title: widget.sheetLabel,
            subtitle: selectedChoice.exercise,
            compactTitle: true,
            backTooltip: 'Back to exercises',
            onBack: widget.onClose,
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final direction = constraints.maxWidth < 520
                  ? Axis.vertical
                  : Axis.horizontal;
              return SegmentedButton<int>(
                direction: direction,
                style: const ButtonStyle(
                  shape: WidgetStatePropertyAll(
                    RoundedRectangleBorder(
                      borderRadius: BorderRadius.all(
                        Radius.circular(_compactSegmentedButtonRadius),
                      ),
                    ),
                  ),
                ),
                segments: [
                  for (final choice in loggingContext.choices)
                    ButtonSegment(
                      value: choice.sheetRowNumber,
                      label: Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            choice.exercise,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (choice.isBackup)
                            const _StateChip(
                              state: _WorkoutVisualState.backup,
                              label: 'Backup',
                            ),
                        ],
                      ),
                      icon: Icon(
                        choice.isBackup
                            ? Icons.alt_route_outlined
                            : Icons.fitness_center_outlined,
                      ),
                    ),
                ],
                selected: {selectedChoice.sheetRowNumber},
                onSelectionChanged: (selection) {
                  widget.onChoiceChanged(selection.single);
                },
              );
            },
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Icon(
                selectedChoice.isBackup
                    ? Icons.alt_route_outlined
                    : Icons.fitness_center_outlined,
                size: 20,
                color: Theme.of(context).colorScheme.primary,
              ),
              Text(
                selectedChoice.exercise,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              if (selectedChoice.isBackup)
                const _StateChip(
                  state: _WorkoutVisualState.backup,
                  label: 'Backup',
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Next set S${viewModel.nextSetNumber}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          _StructuredSetEditor(
            logFormat: loggingContext.logFormat,
            controllers: viewModel.newSetControllers,
            isBusy: _isWriting,
            onSave: _saveStructuredSet,
          ),
          if (_writeError != null) ...[
            const SizedBox(height: 8),
            _InlineLoggingError(message: _writeError!),
          ],
          const SizedBox(height: 16),
          _SetProgressStrip(
            loggedSetNumbers: loggedSetNumbers,
            currentSetNumber: viewModel.nextSetNumber,
            totalSetCount: totalSetCount,
          ),
          const SizedBox(height: 16),
          Text('Logged sets', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          if (viewModel.loggedEntries.isEmpty)
            const Text('No sets logged in this block.')
          else
            for (final entry in viewModel.loggedEntries)
              if (entry.logEntry case FormattedLogEntry(:final fieldLabels))
                _LoggedFormattedSetEditor(
                  entry: entry,
                  fieldLabels: fieldLabels,
                  controllers:
                      viewModel.loggedFormattedControllers[entry.setNumber]!,
                  isBusy: _isWriting,
                  onSave: () => _saveStructuredSetEdit(entry),
                  onClear: () => _clearSet(entry),
                )
              else
                _LoggedSetEditor(
                  entry: entry,
                  controller: viewModel.rawControllers[entry.setNumber]!,
                  isBusy: _isWriting,
                  onSave: () => _saveRawSet(entry),
                  onClear: () => _clearSet(entry),
                ),
          const SizedBox(height: 16),
          _ExerciseContextPanel(
            context: loggingContext,
            latestHistoryValue: _latestHistoryValue(priorHistoryBlocks),
          ),
          const SizedBox(height: 16),
          _RecentHistoryPanel(blocks: priorHistoryBlocks),
        ],
      ),
    );
  }
}

String? _latestHistoryValue(List<RowHistoryBlock> blocks) {
  for (final block in blocks) {
    for (final entry in block.entries) {
      if (entry.rawValue.trim().isNotEmpty) {
        return entry.rawValue;
      }
    }
  }
  return null;
}

class _InlineLoggingError extends StatelessWidget {
  const _InlineLoggingError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      key: const ValueKey('logging-write-error'),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Icon(Icons.error_outline, color: colorScheme.onErrorContainer),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: TextStyle(color: colorScheme.onErrorContainer),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExerciseContextPanel extends StatelessWidget {
  const _ExerciseContextPanel({
    required this.context,
    required this.latestHistoryValue,
  });

  final ExerciseLoggingContext context;
  final String? latestHistoryValue;

  @override
  Widget build(BuildContext context) {
    final targets = this.context.targets;
    final summaryParts = [
      if (this.context.rest.trim().isNotEmpty) 'Rest ${this.context.rest}',
      if (targets.tempo.trim().isNotEmpty) 'Tempo ${targets.tempo}',
    ];
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: _CompactExpansionSection(
        title: 'Training details',
        summaryLines: [
          'Plan ${targets.sets} x ${targets.reps} @ ${targets.rpe}',
          if (summaryParts.isNotEmpty) summaryParts.join(' | '),
        ],
        children: [
          Text(
            'Target: ${targets.sets} sets x ${targets.reps} @ ${targets.rpe}',
          ),
          if (this.context.rest.trim().isNotEmpty)
            Text('Rest: ${this.context.rest}'),
          if (targets.tempo.trim().isNotEmpty) Text('Tempo: ${targets.tempo}'),
          if (this.context.notes.trim().isNotEmpty)
            Text('Notes: ${this.context.notes}'),
          if (latestHistoryValue != null)
            Text('Latest history: $latestHistoryValue'),
        ],
      ),
    );
  }
}

class _RecentHistoryPanel extends StatelessWidget {
  const _RecentHistoryPanel({required this.blocks});

  final List<RowHistoryBlock> blocks;

  @override
  Widget build(BuildContext context) {
    if (blocks.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Recent history',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          const Text('No row-local history yet.'),
        ],
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: _CompactExpansionSection(
        title: 'Recent history',
        summaryLines: _historySummaryLines(blocks),
        children: [
          for (final block in blocks) _RecentHistoryBlock(block: block),
        ],
      ),
    );
  }
}

class _CompactExpansionSection extends StatelessWidget {
  const _CompactExpansionSection({
    required this.title,
    required this.summaryLines,
    required this.children,
  });

  final String title;
  final List<String> summaryLines;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 12),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        title: Text(title, style: Theme.of(context).textTheme.titleMedium),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final line in summaryLines)
                Text(line, maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ],
      ),
    );
  }
}

List<String> _historySummaryLines(List<RowHistoryBlock> blocks) {
  final lines = <String>[];
  for (final block in blocks) {
    final values = block.entries
        .where((entry) => entry.rawValue.trim().isNotEmpty)
        .map((entry) => entry.rawValue.trim())
        .toList();
    if (values.isEmpty) {
      continue;
    }
    lines.add('${block.label}: ${values.join(', ')}');
  }
  if (lines.isEmpty) {
    return const ['No row-local history yet.'];
  }
  return lines;
}

class _RecentHistoryBlock extends StatelessWidget {
  const _RecentHistoryBlock({required this.block});

  final RowHistoryBlock block;

  @override
  Widget build(BuildContext context) {
    final entries = block.entries
        .where((entry) => entry.rawValue.trim().isNotEmpty)
        .toList();
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(block.label, style: Theme.of(context).textTheme.labelLarge),
          Wrap(
            spacing: 16,
            runSpacing: 4,
            children: [
              for (final entry in entries)
                Text('${entry.setLabel}: ${entry.rawValue}'),
            ],
          ),
        ],
      ),
    );
  }
}

class _StructuredSetEditor extends StatelessWidget {
  const _StructuredSetEditor({
    required this.logFormat,
    required this.controllers,
    required this.isBusy,
    required this.onSave,
  });

  final LogFormatParseResult logFormat;
  final Map<String, TextEditingController> controllers;
  final bool isBusy;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final fieldLabels = switch (logFormat) {
      ParsedLogFormat(:final fieldLabels) => fieldLabels,
      InvalidLogFormat() => const <String>[],
    };
    Widget saveButton() {
      return FilledButton.icon(
        onPressed: isBusy ? null : onSave,
        icon: const Icon(Icons.save_outlined),
        label: const Text('Save set'),
      );
    }

    TextField field(String label) {
      return TextField(
        key: ValueKey('set-field-$label'),
        controller: controllers[label],
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      );
    }

    Widget accessibleField(String label) {
      return _A11yTextField(
        label: 'New set $label',
        valueListenable: controllers[label],
        child: field(label),
      );
    }

    List<Widget> compactFields() {
      return [for (final label in fieldLabels) accessibleField(label)];
    }

    List<Widget> wideFields() {
      return [
        for (final label in fieldLabels)
          SizedBox(width: 112, child: accessibleField(label)),
      ];
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 520) {
          final compactFieldWidgets = compactFields();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              saveButton(),
              const SizedBox(height: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (
                    var index = 0;
                    index < compactFieldWidgets.length;
                    index++
                  ) ...[
                    compactFieldWidgets[index],
                    if (index < compactFieldWidgets.length - 1)
                      const SizedBox(height: 12),
                  ],
                ],
              ),
            ],
          );
        }

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [...wideFields(), saveButton()],
        );
      },
    );
  }
}

class _LoggedSetEditor extends StatelessWidget {
  const _LoggedSetEditor({
    required this.entry,
    required this.controller,
    required this.isBusy,
    required this.onSave,
    required this.onClear,
  });

  final RowHistoryEntry entry;
  final TextEditingController controller;
  final bool isBusy;
  final VoidCallback onSave;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 36, child: Text(entry.setLabel)),
          Expanded(
            child: _A11yTextField(
              label: '${entry.setLabel} raw set text',
              valueListenable: controller,
              child: TextField(
                key: ValueKey('raw-${entry.setLabel}'),
                controller: controller,
                decoration: const InputDecoration(
                  labelText: 'Raw set text',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            key: ValueKey('save-${entry.setLabel}'),
            tooltip: 'Save raw set text',
            onPressed: isBusy ? null : onSave,
            icon: const Icon(Icons.check_outlined),
          ),
          IconButton(
            key: ValueKey('clear-${entry.setLabel}'),
            tooltip: 'Clear set',
            onPressed: isBusy ? null : onClear,
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
    );
  }
}

class _LoggedFormattedSetEditor extends StatelessWidget {
  const _LoggedFormattedSetEditor({
    required this.entry,
    required this.fieldLabels,
    required this.controllers,
    required this.isBusy,
    required this.onSave,
    required this.onClear,
  });

  final RowHistoryEntry entry;
  final List<String> fieldLabels;
  final Map<String, TextEditingController> controllers;
  final bool isBusy;
  final VoidCallback onSave;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    Widget field(String label) {
      return _A11yTextField(
        label: '${entry.setLabel} $label',
        valueListenable: controllers[label],
        child: TextField(
          key: ValueKey('logged-${entry.setLabel}-field-$label'),
          controller: controllers[label],
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
          ),
        ),
      );
    }

    Widget saveButton() {
      return IconButton(
        key: ValueKey('save-${entry.setLabel}'),
        tooltip: 'Save structured set',
        onPressed: isBusy ? null : onSave,
        icon: const Icon(Icons.check_outlined),
      );
    }

    Widget clearButton() {
      return IconButton(
        key: ValueKey('clear-${entry.setLabel}'),
        tooltip: 'Clear set',
        onPressed: isBusy ? null : onClear,
        icon: const Icon(Icons.delete_outline),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 520) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    SizedBox(width: 36, child: Text(entry.setLabel)),
                    const Spacer(),
                    saveButton(),
                    clearButton(),
                  ],
                ),
                const SizedBox(height: 8),
                for (var index = 0; index < fieldLabels.length; index++) ...[
                  field(fieldLabels[index]),
                  if (index < fieldLabels.length - 1) const SizedBox(height: 8),
                ],
              ],
            );
          }
          return Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(width: 36, child: Text(entry.setLabel)),
              for (final label in fieldLabels)
                SizedBox(width: 112, child: field(label)),
              saveButton(),
              clearButton(),
            ],
          );
        },
      ),
    );
  }
}
