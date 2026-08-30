/// Entry of the set the athlete is about to perform.
///
/// This module owns the whole new-set workflow behind [NewSetEditor]: the
/// Log Format fields and their responsive layout, the focus nodes and the
/// keyboard-inset avoidance that keeps the focused field and the Save button
/// clear of the keyboard, the per-field timer control, and the visual and
/// spoken presentation of where each value came from. It renders state and
/// reports intent; it never plans a write, starts rest, or decides what a
/// field should contain.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:workout_tracker/contract.dart';

import 'exercise_timer.dart';
import 'logging_flow.dart';
import 'ui/shared/a11y.dart';
import 'ui/shared/status.dart';

const _keyboardGap = 8.0;
const _timerButtonWidth = 48.0;
const _numberKeyboard = TextInputType.numberWithOptions(decimal: true);

/// Starts a countdown for the new-set field named [label].
typedef SetFieldTimerRequest = void Function(String label, Duration duration);

/// The editor for the set being entered, with its fields, timers, and Save.
///
/// The Log Format, targets, controllers, origins, timed fields, and next set
/// number all describe one set together, so the editor takes the whole [vm]
/// and reads that half of it itself rather than making the caller take it
/// apart and risk pairing the pieces wrongly. The editor reports the
/// athlete's intent through [onEntered], [onTimer], and [onSave]; it owns no
/// set state of its own beyond focus and layout.
class NewSetEditor extends StatefulWidget {
  const NewSetEditor({
    required this.vm,
    required this.isBusy,
    required this.onEntered,
    required this.onTimer,
    required this.onSave,
    super.key,
  });

  /// The logging flow's current state; only its new-set half is read.
  final LoggingVm vm;
  final bool isBusy;
  final ValueChanged<String> onEntered;
  final SetFieldTimerRequest onTimer;
  final VoidCallback onSave;

  @override
  State<NewSetEditor> createState() => _NewSetEditorSt();
}

class _NewSetEditorSt extends State<NewSetEditor> with WidgetsBindingObserver {
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
    _labels = _fieldLabels(widget.vm.context.logFormat);
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
  void didUpdateWidget(NewSetEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    final labels = _fieldLabels(widget.vm.context.logFormat);
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
    final vm = widget.vm;
    final controllers = vm.newSetCtrls;
    final targets = vm.context.targets.values;
    final timerFields = vm.timerFields;

    Widget saveButton() {
      return FilledButton.icon(
        onPressed: widget.isBusy ? null : widget.onSave,
        icon: const Icon(Icons.save_outlined),
        label: Text('Save set S${vm.nextSetNumber}'),
      );
    }

    Widget? timerButton(String label) {
      if (!timerFields.contains(label)) return null;
      return _SetFieldTimerButton(
        key: ValueKey('set-timer-$label'),
        exercise: vm.selectedChoice.exercise,
        label: label,
        controller: controllers[label]!,
        onTimer: widget.onTimer,
      );
    }

    ValueOrigin originOf(String label) {
      return vm.origins[label] ?? ValueOrigin.entered;
    }

    TextField field(String label, int index) {
      final isLast = index == _labels.length - 1;
      final target = targets[label] ?? '';
      final suggested = originOf(label) == ValueOrigin.suggested;
      final visualLabel = target.trim().isEmpty ? label : '$label → $target';
      return TextField(
        key: ValueKey('set-field-$label'),
        controller: controllers[label],
        focusNode: _focusNodes[index],
        selectAllOnFocus: true,
        keyboardType: _numberKeyboard,
        style: suggested ? _suggestedStyle(context) : null,
        textInputAction: isLast ? TextInputAction.done : TextInputAction.next,
        onTap: () => _selectAll(controllers[label]!),
        onChanged: (_) => widget.onEntered(label),
        onSubmitted: (_) =>
            isLast ? _dismissInput() : _focusNodes[index].nextFocus(),
        onTapOutside: (_) => _dismissInput(),
        decoration: InputDecoration(
          label: ExcludeSemantics(child: Text(visualLabel)),
          border: const OutlineInputBorder(),
          suffixIcon: timerButton(label),
        ),
      );
    }

    Widget accessibleField(String label, int index) {
      return A11yTextField(
        label: 'New set $label',
        hint: _originHint(originOf(label)),
        valueListenable: controllers[label],
        child: field(label, index),
      );
    }

    return KeyedSubtree(
      key: _editorKey,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final narrow = constraints.maxWidth < 520;
          final fieldWidth = narrow ? constraints.maxWidth : 112.0;
          double widthFor(String label) {
            if (narrow || !timerFields.contains(label)) {
              return fieldWidth;
            }
            // A timed field also carries a trailing control, so it keeps the
            // same room for its value as an untimed field.
            return fieldWidth + _timerButtonWidth;
          }

          return Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (var i = 0; i < _labels.length; i += 1)
                SizedBox(
                  key: _fieldKeys[i],
                  width: widthFor(_labels[i]),
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

/// Starts an exercise countdown from one timed new-set field.
///
/// The control reads its field the moment it is pressed, so the countdown
/// always uses the value the athlete can see. It never edits the field,
/// confirms a suggestion, saves a set, or starts rest.
class _SetFieldTimerButton extends StatelessWidget {
  const _SetFieldTimerButton({
    required this.exercise,
    required this.label,
    required this.controller,
    required this.onTimer,
    super.key,
  });

  final String exercise;
  final String label;
  final TextEditingController controller;
  final SetFieldTimerRequest onTimer;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        final duration = timerDuration(value.text);
        final start = duration == null ? null : _start;
        return Semantics(
          container: true,
          excludeSemantics: true,
          button: true,
          enabled: duration != null,
          label: duration == null
              ? 'Start $exercise $label timer, unavailable because $label is '
                    'not a positive number of seconds'
              : 'Start $exercise $label timer, ${value.text.trim()} seconds',
          onTap: start,
          child: IconButton(
            onPressed: start,
            icon: const Icon(Icons.timer_outlined),
          ),
        );
      },
    );
  }

  void _start() {
    final duration = timerDuration(controller.text);
    if (duration == null) return;
    onTimer(label, duration);
  }
}

/// Announces where a field's value came from.
///
/// A recorded value is real performed data, so it drops the suggestion
/// treatment entirely and instead says who measured it. Screen-reader users
/// therefore separate all three origins without seeing any styling.
String? _originHint(ValueOrigin origin) {
  return switch (origin) {
    ValueOrigin.suggested => 'Suggested value; edit to confirm',
    ValueOrigin.recorded => 'Recorded by the timer; edit to change',
    ValueOrigin.entered => null,
  };
}

/// Styles a value the athlete has not yet confirmed for the current set.
///
/// Italic carries the state alongside the color rather than relying on hue
/// alone, so the distinction survives poor gym lighting and does not depend on
/// color vision.
TextStyle? _suggestedStyle(BuildContext context) {
  return Theme.of(context).textTheme.bodyLarge?.copyWith(
    color: suggestedValueColor(Theme.of(context).colorScheme),
    fontStyle: FontStyle.italic,
  );
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

void _selectAll(TextEditingController controller) {
  controller.selection = TextSelection(
    baseOffset: 0,
    extentOffset: controller.text.length,
  );
}
