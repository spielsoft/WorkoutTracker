part of 'workout_tracker_shell.dart';

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
    final plan = _flow.planStructuredSetSave();
    if (plan == null) {
      return;
    }

    final saved = await widget.onApplyWritePlan(plan);
    if (!saved) {
      return;
    }
    _flow.clearNewSetControllers();
  }

  Future<void> _saveRawSet(RowHistoryEntry entry) async {
    await widget.onApplyWritePlan(_flow.planRawSetEdit(entry));
  }

  Future<void> _saveStructuredSetEdit(RowHistoryEntry entry) async {
    final plan = _flow.planStructuredSetEdit(entry);
    if (plan == null) {
      return;
    }
    await widget.onApplyWritePlan(plan);
  }

  Future<void> _clearSet(RowHistoryEntry entry) async {
    await widget.onApplyWritePlan(_flow.planSetClear(entry));
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = _flow.viewModel;
    final loggingContext = viewModel.context;
    final selectedChoice = loggingContext.selectedChoice;

    return Column(
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
                    label: Text(
                      choice.exercise,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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
        _ExerciseContextPanel(
          context: loggingContext,
          latestHistoryValue: viewModel.latestHistoryValue,
        ),
        const SizedBox(height: 16),
        Text(
          'Next set S${viewModel.nextSetNumber}',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        _StructuredSetEditor(
          logFormat: loggingContext.logFormat,
          controllers: viewModel.newSetControllers,
          onSave: _saveStructuredSet,
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
                onSave: () => _saveStructuredSetEdit(entry),
                onClear: () => _clearSet(entry),
              )
            else
              _LoggedSetEditor(
                entry: entry,
                controller: viewModel.rawControllers[entry.setNumber]!,
                onSave: () => _saveRawSet(entry),
                onClear: () => _clearSet(entry),
              ),
        const SizedBox(height: 16),
        Text('Recent history', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        if (loggingContext.recentHistoryBlocks.isEmpty)
          const Text('No row-local history yet.')
        else
          for (final block in loggingContext.recentHistoryBlocks)
            _RecentHistoryBlock(block: block),
      ],
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
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Target: ${targets.sets} sets x ${targets.reps} @ ${targets.rpe}',
            ),
            Text('Rest: ${this.context.rest}'),
            if (targets.tempo.trim().isNotEmpty)
              Text('Tempo: ${targets.tempo}'),
            if (this.context.notes.trim().isNotEmpty) Text(this.context.notes),
            if (latestHistoryValue != null)
              Text('Latest history: $latestHistoryValue'),
          ],
        ),
      ),
    );
  }
}

class _StructuredSetEditor extends StatelessWidget {
  const _StructuredSetEditor({
    required this.logFormat,
    required this.controllers,
    required this.onSave,
  });

  final LogFormatParseResult logFormat;
  final Map<String, TextEditingController> controllers;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final fieldLabels = switch (logFormat) {
      ParsedLogFormat(:final fieldLabels) => fieldLabels,
      InvalidLogFormat() => const <String>[],
    };
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final label in fieldLabels)
          SizedBox(
            width: 112,
            child: TextField(
              key: ValueKey('set-field-$label'),
              controller: controllers[label],
              decoration: InputDecoration(
                labelText: label,
                border: const OutlineInputBorder(),
              ),
            ),
          ),
        FilledButton.icon(
          onPressed: onSave,
          icon: const Icon(Icons.save_outlined),
          label: const Text('Save set'),
        ),
      ],
    );
  }
}

class _LoggedSetEditor extends StatelessWidget {
  const _LoggedSetEditor({
    required this.entry,
    required this.controller,
    required this.onSave,
    required this.onClear,
  });

  final RowHistoryEntry entry;
  final TextEditingController controller;
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
            child: TextField(
              key: ValueKey('raw-${entry.setLabel}'),
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Raw set text',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            key: ValueKey('save-${entry.setLabel}'),
            tooltip: 'Save raw set text',
            onPressed: onSave,
            icon: const Icon(Icons.check_outlined),
          ),
          IconButton(
            key: ValueKey('clear-${entry.setLabel}'),
            tooltip: 'Clear set',
            onPressed: onClear,
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
    required this.onSave,
    required this.onClear,
  });

  final RowHistoryEntry entry;
  final List<String> fieldLabels;
  final Map<String, TextEditingController> controllers;
  final VoidCallback onSave;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(width: 36, child: Text(entry.setLabel)),
          for (final label in fieldLabels)
            SizedBox(
              width: 112,
              child: TextField(
                key: ValueKey('logged-${entry.setLabel}-field-$label'),
                controller: controllers[label],
                decoration: InputDecoration(
                  labelText: label,
                  border: const OutlineInputBorder(),
                ),
              ),
            ),
          IconButton(
            key: ValueKey('save-${entry.setLabel}'),
            tooltip: 'Save structured set',
            onPressed: onSave,
            icon: const Icon(Icons.check_outlined),
          ),
          IconButton(
            key: ValueKey('clear-${entry.setLabel}'),
            tooltip: 'Clear set',
            onPressed: onClear,
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
    );
  }
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
