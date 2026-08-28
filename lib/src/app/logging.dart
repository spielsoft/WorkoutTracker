import 'dart:async';

import 'package:flutter/material.dart';
import 'package:workout_tracker/contract.dart';

import 'controller.dart';
import 'logging_flow.dart';
import 'rest_timer.dart';
import 'validation_core.dart';
import 'ui/view.dart';
import 'ui/shared/a11y.dart';
import 'ui/shared/error.dart';
import 'ui/shared/header.dart';
import 'ui/shared/next_field.dart';
import 'ui/shared/role.dart';
import 'ui/shared/status.dart';

const _segmentRadius = 8.0;
const _keyboardGap = 8.0;
const _undoWindow = Duration(seconds: 5);
const _numberKeyboard = TextInputType.numberWithOptions(decimal: true);

final class LogView extends LoadedView {
  const LogView({
    required super.isBusy,
    required this.activeSheet,
    required super.sheetLabel,
    required this.target,
    super.error,
  });

  final ParsedActiveSheet activeSheet;
  final WorkoutLoggingTarget target;
}

abstract interface class LogActions {
  Future<void> close();

  void dismissError();

  Future<void> selectRow(int sheetRow);

  Future<bool> execute(WbkCmd cmd);
}

class LogScreen extends StatefulWidget {
  const LogScreen({
    required this.view,
    required this.actions,
    this.onRest,
    super.key,
  });

  final LogView view;
  final LogActions actions;
  final ValueChanged<Duration>? onRest;

  @override
  State<LogScreen> createState() => _LogScreenSt();
}

class _LogScreenSt extends State<LogScreen> {
  late final LoggingFlow _flow;
  int? _editingSet;
  Timer? _undoTimer;

  @override
  void initState() {
    super.initState();
    _flow = _createFlow();
  }

  @override
  void didUpdateWidget(LogScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final old = oldWidget.view;
    final next = widget.view;
    if (old.target.selectedRow != next.target.selectedRow ||
        old.target.blockLabel != next.target.blockLabel ||
        old.target.primaryRow != next.target.primaryRow ||
        old.activeSheet != next.activeSheet) {
      _flow.update(
        activeSheet: next.activeSheet,
        blockLabel: next.target.blockLabel,
        primaryRow: next.target.primaryRow,
        selectedRow: next.target.selectedRow,
      );
      _editingSet = null;
    }
  }

  @override
  void dispose() {
    _undoTimer?.cancel();
    _flow.dispose();
    super.dispose();
  }

  LoggingFlow _createFlow() {
    final view = widget.view;
    return LoggingFlow(
      activeSheet: view.activeSheet,
      blockLabel: view.target.blockLabel,
      primaryRow: view.target.primaryRow,
      selectedRow: view.target.selectedRow,
    );
  }

  Future<void> _saveSet() async {
    if (widget.view.isBusy) return;
    final rest = _restAfterSave(_flow.viewModel);
    final plan = _flow.planSetSave();
    if (plan == null) return;

    final saved = await widget.actions.execute(plan);
    if (saved && mounted && rest != null) widget.onRest?.call(rest);
  }

  Future<void> _saveRawSet(RowHistoryEntry entry) async {
    if (widget.view.isBusy) return;
    final saved = await widget.actions.execute(_flow.planRawSetEdit(entry));
    if (saved && mounted) {
      setState(() => _editingSet = null);
    }
  }

  Future<void> _saveSetEdit(RowHistoryEntry entry) async {
    if (widget.view.isBusy) return;
    final plan = _flow.planSetEdit(entry);
    if (plan == null) return;
    final saved = await widget.actions.execute(plan);
    if (saved && mounted) {
      setState(() => _editingSet = null);
    }
  }

  Future<void> _clearSet(RowHistoryEntry entry) async {
    if (widget.view.isBusy) return;
    final recovery = _flow.planSetClear(entry);
    final cleared = await widget.actions.execute(recovery.clear);
    if (!mounted) return;
    if (!cleared) {
      _showMessage('${recovery.setLabel} was not cleared.');
      return;
    }

    if (_editingSet == entry.setNumber) {
      setState(() => _editingSet = null);
    }
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    final snackBar = messenger.showSnackBar(
      SnackBar(
        content: Text('${recovery.setLabel} cleared.'),
        duration: _undoWindow,
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () async => _undoSet(recovery),
        ),
      ),
    );
    _undoTimer?.cancel();
    _undoTimer = Timer(_undoWindow, snackBar.close);
  }

  Future<void> _undoSet(SetRecovery recovery) async {
    _undoTimer?.cancel();
    final restored = await widget.actions.execute(recovery.undo);
    if (!mounted) return;
    _showMessage(
      restored
          ? '${recovery.setLabel} restored.'
          : '${recovery.setLabel} was not restored.',
    );
  }

  void _editSet(RowHistoryEntry entry) {
    _flow.discardSetEdits();
    setState(() => _editingSet = entry.setNumber);
  }

  void _cancelSetEdit() {
    _flow.discardSetEdits();
    setState(() => _editingSet = null);
  }

  void _showMessage(String message) {
    _undoTimer?.cancel();
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _dismissInput() {
    FocusManager.instance.primaryFocus?.unfocus();
  }

  void _markEntered(String label) {
    if (_flow.markEntered(label)) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = _flow.viewModel;
    final loggingContext = viewModel.context;
    final selectedChoice = loggingContext.selectedChoice;
    final priorHistoryBlocks = loggingContext.recentHistoryBlocks
        .where((block) => block.label != loggingContext.selectedHistory.label)
        .toList();

    return A11yScreen(
      label: 'Log ${selectedChoice.exercise}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ScreenHeader(
            title: widget.view.sheetLabel,
            compactTitle: true,
            backTooltip: 'Back to exercises',
            onBack: () {
              _dismissInput();
              widget.actions.close();
            },
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final direction = constraints.maxWidth < 520
                  ? Axis.vertical
                  : Axis.horizontal;
              return SegmentedButton<int>(
                direction: direction,
                showSelectedIcon: false,
                style: const ButtonStyle(
                  shape: WidgetStatePropertyAll(
                    RoundedRectangleBorder(
                      borderRadius: BorderRadius.all(
                        Radius.circular(_segmentRadius),
                      ),
                    ),
                  ),
                ),
                segments: [
                  for (final choice in loggingContext.choices)
                    ButtonSegment(
                      value: choice.sheetRowNumber,
                      label: Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            choice.exercise,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                      icon: Icon(
                        choice.isBackup
                            ? backupIcon
                            : Icons.fitness_center_outlined,
                      ),
                    ),
                ],
                selected: {selectedChoice.sheetRowNumber},
                onSelectionChanged: (selection) {
                  _dismissInput();
                  widget.actions.selectRow(selection.single);
                },
              );
            },
          ),
          const SizedBox(height: 16),
          _PlanSummary(context: loggingContext),
          const SizedBox(height: 12),
          _StructuredSetEditor(
            key: ValueKey(
              '${widget.view.target.blockLabel}-'
              '${widget.view.target.selectedRow}',
            ),
            logFormat: loggingContext.logFormat,
            targets: loggingContext.targets.values,
            controllers: viewModel.newSetCtrls,
            provisional: viewModel.provisional,
            setNumber: viewModel.nextSetNumber,
            isBusy: widget.view.isBusy,
            onEntered: _markEntered,
            onSave: _saveSet,
          ),
          if (widget.view.error case final error?) ...[
            const SizedBox(height: 8),
            ErrorBanner(message: error, onDismiss: widget.actions.dismissError),
          ],
          const SizedBox(height: 16),
          Text('Logged sets', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          if (viewModel.loggedEntries.isEmpty)
            const Text('No sets logged in this block.')
          else
            for (final entry in viewModel.loggedEntries)
              if (_editingSet != entry.setNumber)
                _LoggedSetSummary(
                  entry: entry,
                  isBusy: widget.view.isBusy,
                  onEdit: () => _editSet(entry),
                  onClear: () => _clearSet(entry),
                )
              else if (entry.logEntry case FormattedLogEntry(
                :final fieldLabels,
              ))
                _LoggedSetFields(
                  entry: entry,
                  fieldLabels: fieldLabels,
                  controllers: viewModel.loggedCtrls[entry.setNumber]!,
                  isBusy: widget.view.isBusy,
                  onSave: () => _saveSetEdit(entry),
                  onCancel: _cancelSetEdit,
                  onClear: () => _clearSet(entry),
                )
              else
                _LoggedSetEditor(
                  entry: entry,
                  controller: viewModel.rawCtrls[entry.setNumber]!,
                  isBusy: widget.view.isBusy,
                  onSave: () => _saveRawSet(entry),
                  onCancel: _cancelSetEdit,
                  onClear: () => _clearSet(entry),
                ),
          const SizedBox(height: 16),
          _RecentHistoryPanel(blocks: priorHistoryBlocks),
        ],
      ),
    );
  }
}

class _PlanSummary extends StatelessWidget {
  const _PlanSummary({required this.context});

  final ExerciseLoggingContext context;

  @override
  Widget build(BuildContext context) {
    final targets = this.context.targets;
    final summaryParts = [
      if (targets.sets.trim().isNotEmpty) '${targets.sets.trim()} sets',
      if (this.context.rest.trim().isNotEmpty)
        '${_spacedSeconds(this.context.rest.trim())} Rest',
    ];
    final note = this.context.notes.trim();
    if (summaryParts.isEmpty && note.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (summaryParts.isNotEmpty) Text(summaryParts.join(' | ')),
        if (summaryParts.isNotEmpty && note.isNotEmpty)
          const SizedBox(height: 4),
        if (note.isNotEmpty)
          Text(
            note,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
      ],
    );
  }
}

String _spacedSeconds(String rest) {
  final match = RegExp(
    r'^(\d+(?:\.\d+)?)\s*s$',
    caseSensitive: false,
  ).firstMatch(rest);
  return match == null ? rest : '${match.group(1)} s';
}

Duration? _restAfterSave(LoggingVm vm) {
  final plannedSets = int.tryParse(vm.context.targets.sets.trim());
  if (plannedSets == null || vm.nextSetNumber >= plannedSets) return null;
  return restDuration(vm.context.rest);
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

class _StructuredSetEditor extends StatefulWidget {
  const _StructuredSetEditor({
    required this.logFormat,
    required this.targets,
    required this.controllers,
    required this.provisional,
    required this.setNumber,
    required this.isBusy,
    required this.onEntered,
    required this.onSave,
    super.key,
  });

  final LogFormatParseResult logFormat;
  final Map<String, String> targets;
  final Map<String, TextEditingController> controllers;
  final Set<String> provisional;
  final int setNumber;
  final bool isBusy;
  final ValueChanged<String> onEntered;
  final VoidCallback onSave;

  @override
  State<_StructuredSetEditor> createState() => _StructuredSetEditorSt();
}

class _StructuredSetEditorSt extends State<_StructuredSetEditor>
    with WidgetsBindingObserver {
  final _editorKey = GlobalKey();
  final _saveKey = GlobalKey();
  late List<String> _labels;
  late List<GlobalKey> _fieldKeys;
  late List<FocusNode> _focusNodes;
  double _bottomInset = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _labels = _fieldLabels(widget.logFormat);
    _fieldKeys = _createFieldKeys(_labels);
    _focusNodes = _createFocusNodes(_labels);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncInset();
  }

  @override
  void didChangeMetrics() {
    _syncInset();
  }

  void _syncInset() {
    if (!mounted) return;
    final view = View.of(context);
    final bottomInset = view.viewInsets.bottom / view.devicePixelRatio;
    if (bottomInset == _bottomInset) return;
    _bottomInset = bottomInset;
    if (bottomInset > 0) _showFocus();
  }

  @override
  void didUpdateWidget(_StructuredSetEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    final labels = _fieldLabels(widget.logFormat);
    if (_sameLabels(labels, _labels)) return;
    _disposeFocusNodes();
    _labels = labels;
    _fieldKeys = _createFieldKeys(labels);
    _focusNodes = _createFocusNodes(labels);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _disposeFocusNodes();
    super.dispose();
  }

  List<FocusNode> _createFocusNodes(List<String> labels) {
    final nodes = [
      for (final label in labels) FocusNode(debugLabel: 'New set $label'),
    ];
    for (final node in nodes) {
      node.addListener(_focusChanged);
    }
    return nodes;
  }

  List<GlobalKey> _createFieldKeys(List<String> labels) {
    return [for (final _ in labels) GlobalKey()];
  }

  void _disposeFocusNodes() {
    for (final node in _focusNodes) {
      node.removeListener(_focusChanged);
      node.dispose();
    }
  }

  void _focusChanged() {
    if (_bottomInset > 0) _showFocus();
  }

  void _showFocus() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _bottomInset <= 0) return;
      final index = _focusNodes.indexWhere((node) => node.hasFocus);
      if (index < 0) return;
      unawaited(_reveal(index));
    });
  }

  Future<void> _reveal(int index) async {
    final fieldContext = _fieldKeys[index].currentContext;
    final editorContext = _editorKey.currentContext;
    if (fieldContext == null || editorContext == null) return;
    final scrollable = Scrollable.maybeOf(fieldContext);
    final editorBox = editorContext.findRenderObject();
    final viewportBox = scrollable?.context.findRenderObject();
    if (scrollable == null ||
        editorBox is! RenderBox ||
        viewportBox is! RenderBox) {
      return;
    }
    final viewportTop = viewportBox.localToGlobal(Offset.zero).dy;
    final view = View.of(context);
    final screenHeight = view.physicalSize.height / view.devicePixelRatio;
    final keyboardBottom = screenHeight - _bottomInset;
    final scrollHeight = scrollable.position.viewportDimension;
    final keyboardHeight = keyboardBottom - viewportTop;
    final visibleHeight = keyboardHeight < scrollHeight
        ? keyboardHeight
        : scrollHeight;
    final showEditor = editorBox.size.height <= visibleHeight;
    await Scrollable.ensureVisible(
      showEditor ? editorContext : fieldContext,
      alignment: 0,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
    );
    if (!mounted ||
        !fieldContext.mounted ||
        !scrollable.mounted ||
        !_focusNodes[index].hasFocus) {
      return;
    }
    await _revealSave(fieldContext, scrollable);
  }

  Future<void> _revealSave(
    BuildContext fieldContext,
    ScrollableState scrollable,
  ) async {
    final saveContext = _saveKey.currentContext;
    final fieldBox = fieldContext.findRenderObject();
    final saveBox = saveContext?.findRenderObject();
    final viewportBox = scrollable.context.findRenderObject();
    if (fieldBox is! RenderBox ||
        saveBox is! RenderBox ||
        viewportBox is! RenderBox) {
      return;
    }
    final viewportTop = viewportBox.localToGlobal(Offset.zero).dy;
    final scrollBottom = viewportTop + scrollable.position.viewportDimension;
    final view = View.of(context);
    final screenHeight = view.physicalSize.height / view.devicePixelRatio;
    final keyboardBottom = screenHeight - _bottomInset;
    final viewportBottom = keyboardBottom < scrollBottom
        ? keyboardBottom
        : scrollBottom;
    final fieldTop = fieldBox.localToGlobal(Offset.zero).dy;
    final saveBottom =
        saveBox.localToGlobal(Offset.zero).dy + saveBox.size.height;
    final obstruction = saveBottom - viewportBottom;
    if (obstruction <= 0) return;
    final delta = obstruction + _keyboardGap;
    if (fieldTop - delta < viewportTop) return;
    final position = scrollable.position;
    final target = (position.pixels + delta).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    await position.animateTo(
      target,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
    );
  }

  void _dismissInput() => FocusManager.instance.primaryFocus?.unfocus();

  @override
  Widget build(BuildContext context) {
    Widget saveButton() {
      return FilledButton.icon(
        onPressed: widget.isBusy ? null : widget.onSave,
        icon: const Icon(Icons.save_outlined),
        label: Text('Save set S${widget.setNumber}'),
      );
    }

    TextField field(String label, int index) {
      final isLast = index == _labels.length - 1;
      final target = widget.targets[label] ?? '';
      final suggested = widget.provisional.contains(label);
      final visualLabel = target.trim().isEmpty ? label : '$label → $target';
      final suggestedColor = stateStyle(
        Theme.of(context).colorScheme,
        VisualSt.warning,
      ).border;
      return TextField(
        key: ValueKey('set-field-$label'),
        controller: widget.controllers[label],
        focusNode: _focusNodes[index],
        keyboardType: _numberKeyboard,
        style: suggested
            ? Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: suggestedColor)
            : null,
        textInputAction: isLast ? TextInputAction.done : TextInputAction.next,
        onChanged: (_) => widget.onEntered(label),
        onSubmitted: (_) =>
            isLast ? _dismissInput() : _focusNodes[index].nextFocus(),
        onTapOutside: (_) => _dismissInput(),
        decoration: InputDecoration(
          label: ExcludeSemantics(child: Text(visualLabel)),
          border: const OutlineInputBorder(),
          suffixIcon: isLast
              ? null
              : NextFieldButton(
                  focusNode: _focusNodes[index],
                  nextLabel: _labels[index + 1],
                ),
        ),
      );
    }

    Widget accessibleField(String label, int index) {
      return A11yTextField(
        label: 'New set $label',
        hint: widget.provisional.contains(label)
            ? 'Suggested value; edit to confirm'
            : null,
        valueListenable: widget.controllers[label],
        child: field(label, index),
      );
    }

    return KeyedSubtree(
      key: _editorKey,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final narrow = constraints.maxWidth < 520;
          final fieldWidth = narrow ? constraints.maxWidth : 112.0;
          return Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (var i = 0; i < _labels.length; i += 1)
                SizedBox(
                  key: _fieldKeys[i],
                  width: fieldWidth,
                  child: accessibleField(_labels[i], i),
                ),
              if (narrow)
                SizedBox(key: _saveKey, width: fieldWidth, child: saveButton())
              else
                KeyedSubtree(key: _saveKey, child: saveButton()),
            ],
          );
        },
      ),
    );
  }
}

List<String> _fieldLabels(LogFormatParseResult format) {
  return switch (format) {
    ParsedLogFormat(:final fieldLabels) => fieldLabels,
    InvalidLogFormat() => const <String>[],
  };
}

bool _sameLabels(List<String> left, List<String> right) {
  if (left.length != right.length) return false;
  for (var i = 0; i < left.length; i += 1) {
    if (left[i] != right[i]) return false;
  }
  return true;
}

class _LoggedSetSummary extends StatelessWidget {
  const _LoggedSetSummary({
    required this.entry,
    required this.isBusy,
    required this.onEdit,
    required this.onClear,
  });

  final RowHistoryEntry entry;
  final bool isBusy;
  final VoidCallback onEdit;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          SizedBox(
            width: 36,
            child: Text(
              entry.setLabel,
              style: Theme.of(context).textTheme.labelLarge,
            ),
          ),
          Expanded(
            child: Text(
              entry.rawValue,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            key: ValueKey('edit-${entry.setLabel}'),
            tooltip: 'Edit ${entry.setLabel}',
            onPressed: isBusy ? null : onEdit,
            icon: const Icon(Icons.edit_outlined),
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

class _LoggedSetEditor extends StatelessWidget {
  const _LoggedSetEditor({
    required this.entry,
    required this.controller,
    required this.isBusy,
    required this.onSave,
    required this.onCancel,
    required this.onClear,
  });

  final RowHistoryEntry entry;
  final TextEditingController controller;
  final bool isBusy;
  final VoidCallback onSave;
  final VoidCallback onCancel;
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
            child: A11yTextField(
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
            key: ValueKey('cancel-${entry.setLabel}'),
            tooltip: 'Cancel set edit',
            onPressed: isBusy ? null : onCancel,
            icon: const Icon(Icons.close_outlined),
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

class _LoggedSetFields extends StatelessWidget {
  const _LoggedSetFields({
    required this.entry,
    required this.fieldLabels,
    required this.controllers,
    required this.isBusy,
    required this.onSave,
    required this.onCancel,
    required this.onClear,
  });

  final RowHistoryEntry entry;
  final List<String> fieldLabels;
  final Map<String, TextEditingController> controllers;
  final bool isBusy;
  final VoidCallback onSave;
  final VoidCallback onCancel;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    Widget field(String label, int index) {
      return _LoggedSetField(
        key: ValueKey('${entry.setLabel}-$label'),
        entry: entry,
        label: label,
        controller: controllers[label]!,
        nextLabel: index < fieldLabels.length - 1
            ? '${entry.setLabel} ${fieldLabels[index + 1]}'
            : null,
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

    Widget cancelButton() {
      return IconButton(
        key: ValueKey('cancel-${entry.setLabel}'),
        tooltip: 'Cancel set edit',
        onPressed: isBusy ? null : onCancel,
        icon: const Icon(Icons.close_outlined),
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
                    cancelButton(),
                    clearButton(),
                  ],
                ),
                const SizedBox(height: 8),
                for (var index = 0; index < fieldLabels.length; index++) ...[
                  field(fieldLabels[index], index),
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
              for (var index = 0; index < fieldLabels.length; index++)
                SizedBox(width: 112, child: field(fieldLabels[index], index)),
              saveButton(),
              cancelButton(),
              clearButton(),
            ],
          );
        },
      ),
    );
  }
}

class _LoggedSetField extends StatefulWidget {
  const _LoggedSetField({
    super.key,
    required this.entry,
    required this.label,
    required this.controller,
    required this.nextLabel,
  });

  final RowHistoryEntry entry;
  final String label;
  final TextEditingController controller;
  final String? nextLabel;

  @override
  State<_LoggedSetField> createState() => _LoggedSetFieldSt();
}

class _LoggedSetFieldSt extends State<_LoggedSetField> {
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode(
      debugLabel: '${widget.entry.setLabel} ${widget.label}',
    );
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final nextLabel = widget.nextLabel;
    return A11yTextField(
      label: '${widget.entry.setLabel} ${widget.label}',
      valueListenable: widget.controller,
      child: TextField(
        key: ValueKey('logged-${widget.entry.setLabel}-field-${widget.label}'),
        controller: widget.controller,
        focusNode: _focusNode,
        keyboardType: _numberKeyboard,
        textInputAction: nextLabel == null
            ? TextInputAction.done
            : TextInputAction.next,
        onSubmitted: (_) =>
            nextLabel == null ? _focusNode.unfocus() : _focusNode.nextFocus(),
        onTapOutside: (_) => _focusNode.unfocus(),
        decoration: InputDecoration(
          labelText: widget.label,
          border: const OutlineInputBorder(),
          suffixIcon: nextLabel == null
              ? null
              : NextFieldButton(focusNode: _focusNode, nextLabel: nextLabel),
        ),
      ),
    );
  }
}
