// ignore_for_file: prefer_initializing_formals

import 'package:flutter/widgets.dart';
import 'package:workout_tracker/contract.dart';

import 'countdown.dart';
import 'validation_core.dart';

/// Where a new-set value came from.
///
/// One origin replaces the several booleans these states would otherwise
/// need, so a value can never be suggested and recorded at once.
enum ValueOrigin {
  /// Prefilled from a target or earlier set and not yet confirmed.
  suggested,

  /// The athlete's own entry, including a field they have left empty.
  entered,

  /// Measured by a countdown this field started.
  recorded,
}

class LoggingFlow {
  LoggingFlow({
    required ParsedActiveSheet activeSheet,
    required String blockLabel,
    required int primaryRow,
    required int selectedRow,
  }) : _activeSheet = activeSheet,
       _blockLabel = blockLabel,
       _primaryRow = primaryRow,
       _selectedRow = selectedRow {
    _syncCtrls(_context, prefillNewSet: true);
  }

  ParsedActiveSheet _activeSheet;
  String _blockLabel;
  int _primaryRow;
  int _selectedRow;

  final _newSetCtrls = <String, TextEditingController>{};
  final _loggedFieldCtrls = <int, Map<String, TextEditingController>>{};
  final _rawCtrls = <int, TextEditingController>{};
  final _origins = <String, ValueOrigin>{};
  List<String>? _resolvedTimerFields;

  LoggingVm get viewModel {
    final context = _context;
    return LoggingVm(
      context: context,
      loggedEntries: _loggedEntries(context),
      nextSetNumber: _nextSetNumber(context.selectedHistory),
      newSetCtrls: Map<String, TextEditingController>.unmodifiable(
        _newSetCtrls,
      ),
      loggedCtrls: Map<int, Map<String, TextEditingController>>.unmodifiable({
        for (final entry in _loggedFieldCtrls.entries)
          entry.key: Map<String, TextEditingController>.unmodifiable(
            entry.value,
          ),
      }),
      rawCtrls: Map<int, TextEditingController>.unmodifiable(_rawCtrls),
      origins: Map<String, ValueOrigin>.unmodifiable(_origins),
      timerFields: _timerFields(context),
    );
  }

  void update({
    required ParsedActiveSheet activeSheet,
    required String blockLabel,
    required int primaryRow,
    required int selectedRow,
  }) {
    final currentSet = _nextSetNumber(_context.selectedHistory);
    final targetChanged =
        _blockLabel != blockLabel ||
        _primaryRow != primaryRow ||
        _selectedRow != selectedRow;
    _activeSheet = activeSheet;
    _blockLabel = blockLabel;
    _primaryRow = primaryRow;
    _selectedRow = selectedRow;
    _resolvedTimerFields = null;
    final context = _context;
    final setAdvanced = currentSet != _nextSetNumber(context.selectedHistory);
    _syncCtrls(context, prefillNewSet: targetChanged || setAdvanced);
  }

  /// Claims a field as the athlete's own entry, whatever it held before.
  ///
  /// Returns whether the origin actually changed, so a screen only rebuilds
  /// for the keystroke that confirms a suggested or recorded value.
  bool markEntered(String label) {
    if (!_origins.containsKey(label) ||
        _origins[label] == ValueOrigin.entered) {
      return false;
    }
    _origins[label] = ValueOrigin.entered;
    return true;
  }

  /// Writes the duration a countdown measured into the field that started it.
  ///
  /// The value is rounded exactly as the countdown the athlete watched, and
  /// the field stops reading as an unconfirmed suggestion. Nothing else is
  /// touched: no other field, no saved set, and no workbook.
  bool markRecorded(String label, Duration elapsed) {
    final controller = _newSetCtrls[label];
    if (controller == null) return false;
    controller.text = '${countdownSeconds(elapsed)}';
    _origins[label] = ValueOrigin.recorded;
    return true;
  }

  SaveSetCmd? planSetSave() {
    final fieldValues = {
      for (final entry in _newSetCtrls.entries)
        entry.key: entry.value.text.trim(),
    };
    if (fieldValues.values.every((value) => value.isEmpty)) {
      return null;
    }

    return SaveSetCmd(
      blockLabel: _blockLabel,
      sheetRow: _context.selectedChoice.sheetRowNumber,
      fields: fieldValues,
    );
  }

  EditSetCmd? planSetEdit(RowHistoryEntry entry) {
    final controllers = _loggedFieldCtrls[entry.setNumber];
    if (controllers == null) {
      return null;
    }

    return EditSetCmd(
      blockLabel: _blockLabel,
      sheetRow: _context.selectedChoice.sheetRowNumber,
      setNumber: entry.setNumber,
      fields: {
        for (final controllerEntry in controllers.entries)
          controllerEntry.key: controllerEntry.value.text.trim(),
      },
    );
  }

  EditRawSetCmd planRawSetEdit(RowHistoryEntry entry) {
    return EditRawSetCmd(
      blockLabel: _blockLabel,
      sheetRow: _context.selectedChoice.sheetRowNumber,
      setNumber: entry.setNumber,
      rawText: _rawCtrls[entry.setNumber]?.text ?? '',
    );
  }

  SetRecovery planSetClear(RowHistoryEntry entry) {
    final sheetRow = _context.selectedChoice.sheetRowNumber;
    return SetRecovery(
      setLabel: entry.setLabel,
      clear: ClearSetCmd(
        blockLabel: _blockLabel,
        sheetRow: sheetRow,
        setNumber: entry.setNumber,
      ),
      undo: EditRawSetCmd(
        blockLabel: _blockLabel,
        sheetRow: sheetRow,
        setNumber: entry.setNumber,
        rawText: entry.rawValue,
      ),
    );
  }

  void discardSetEdits() => _syncLoggedCtrls(_context);

  void dispose() {
    for (final controller in _newSetCtrls.values) {
      controller.dispose();
    }
    for (final controllers in _loggedFieldCtrls.values) {
      for (final controller in controllers.values) {
        controller.dispose();
      }
    }
    for (final controller in _rawCtrls.values) {
      controller.dispose();
    }
  }

  ExerciseLoggingContext get _context {
    return _activeSheet.buildLoggingContext(
      primaryRow: _primaryRow,
      selectedRow: _selectedRow,
      blockLabel: _blockLabel,
    );
  }

  /// Timer Fields the canonical Exercises row declares for this placement.
  ///
  /// The workbook's Exercises tab is the only source of timer configuration;
  /// a placement never carries its own copy and no field label, unit, or
  /// value implies timing.
  ///
  /// Resolving this rereads every canonical row, so the answer is held until
  /// [update] supplies a different sheet or placement rather than recomputed
  /// on each build.
  List<String> _timerFields(ExerciseLoggingContext context) {
    final name = context.selectedChoice.exercise;
    return _resolvedTimerFields ??= () {
      for (final exercise in _activeSheet.canonicalExercises.reversed) {
        if (exercise.exercise == name) return exercise.timerFields;
      }
      return const <String>[];
    }();
  }

  void _syncCtrls(
    ExerciseLoggingContext context, {
    required bool prefillNewSet,
  }) {
    _syncNewSetCtrls(context, prefill: prefillNewSet);
    _syncLoggedCtrls(context);
  }

  void _syncNewSetCtrls(
    ExerciseLoggingContext context, {
    required bool prefill,
  }) {
    final labels = switch (context.logFormat) {
      ParsedLogFormat(:final fieldLabels) => fieldLabels.toSet(),
      InvalidLogFormat() => <String>{},
    };
    final removedLabels = _newSetCtrls.keys
        .where((label) => !labels.contains(label))
        .toList();
    for (final label in removedLabels) {
      _newSetCtrls.remove(label)?.dispose();
      _origins.remove(label);
    }
    for (final label in labels) {
      _newSetCtrls.putIfAbsent(label, TextEditingController.new);
      _origins.putIfAbsent(label, () => ValueOrigin.entered);
    }
    if (prefill) {
      _prefillNewSet(context);
    }
  }

  void _prefillNewSet(ExerciseLoggingContext context) {
    final entry = _prefillEntry(context);
    final values = switch (entry?.logEntry) {
      FormattedLogEntry(:final fieldValues) => fieldValues,
      _ => context.targets.values,
    };
    for (final MapEntry(key: label, value: controller)
        in _newSetCtrls.entries) {
      controller.text = values[label] ?? '';
      _origins[label] = controller.text.trim().isEmpty
          ? ValueOrigin.entered
          : ValueOrigin.suggested;
    }
  }

  RowHistoryEntry? _prefillEntry(ExerciseLoggingContext context) {
    final current = _lastNonEmpty(context.selectedHistory);
    if (current != null) {
      return current;
    }
    for (final block in context.recentHistoryBlocks) {
      if (block.label == context.selectedHistory.label) {
        continue;
      }
      final entry = _usableFirstSet(block);
      if (entry != null) {
        return entry;
      }
    }
    return null;
  }

  RowHistoryEntry? _lastNonEmpty(RowHistoryBlock block) {
    for (final entry in block.entries.reversed) {
      if (entry.rawValue.trim().isNotEmpty) {
        return entry;
      }
    }
    return null;
  }

  RowHistoryEntry? _usableFirstSet(RowHistoryBlock block) {
    for (final entry in block.entries) {
      if (entry.setNumber == 1 &&
          entry.rawValue.trim().isNotEmpty &&
          entry.logEntry is FormattedLogEntry) {
        return entry;
      }
    }
    return null;
  }

  void _syncLoggedCtrls(ExerciseLoggingContext context) {
    final nonEmptyEntries = _nonEmptyEntries(context);
    final activeSetNumbers = {
      for (final entry in nonEmptyEntries) entry.setNumber,
    };
    final rawSetNumbers = {
      for (final entry in nonEmptyEntries)
        if (entry.logEntry is RawLogEntry) entry.setNumber,
    };

    final removedLoggedSets = _loggedFieldCtrls.keys
        .where((setNumber) => !activeSetNumbers.contains(setNumber))
        .toList();
    for (final setNumber in removedLoggedSets) {
      _disposeSetCtrls(setNumber);
    }

    final removedRawSetNumbers = _rawCtrls.keys
        .where((setNumber) => !rawSetNumbers.contains(setNumber))
        .toList();
    for (final setNumber in removedRawSetNumbers) {
      _rawCtrls.remove(setNumber)?.dispose();
    }

    for (final setNumber in rawSetNumbers) {
      _disposeSetCtrls(setNumber);
    }

    for (final entry in nonEmptyEntries) {
      final logEntry = entry.logEntry;
      if (logEntry is FormattedLogEntry) {
        _syncSetCtrls(entry.setNumber, logEntry);
        continue;
      }
      final controller = _rawCtrls.putIfAbsent(
        entry.setNumber,
        TextEditingController.new,
      );
      if (controller.text != entry.rawValue) {
        controller.text = entry.rawValue;
      }
    }
  }

  void _syncSetCtrls(int setNumber, FormattedLogEntry logEntry) {
    _rawCtrls.remove(setNumber)?.dispose();
    final controllers = _loggedFieldCtrls.putIfAbsent(
      setNumber,
      () => <String, TextEditingController>{},
    );
    final labels = logEntry.fieldLabels.toSet();
    final removedLabels = controllers.keys
        .where((label) => !labels.contains(label))
        .toList();
    for (final label in removedLabels) {
      controllers.remove(label)?.dispose();
    }
    for (final label in logEntry.fieldLabels) {
      final controller = controllers.putIfAbsent(
        label,
        TextEditingController.new,
      );
      final value = logEntry.fieldValues[label] ?? '';
      if (controller.text != value) {
        controller.text = value;
      }
    }
  }

  void _disposeSetCtrls(int setNumber) {
    final controllers = _loggedFieldCtrls.remove(setNumber);
    if (controllers == null) {
      return;
    }
    for (final controller in controllers.values) {
      controller.dispose();
    }
  }

  List<RowHistoryEntry> _loggedEntries(ExerciseLoggingContext context) {
    return _nonEmptyEntries(context)
      ..sort((left, right) => right.setNumber.compareTo(left.setNumber));
  }

  List<RowHistoryEntry> _nonEmptyEntries(ExerciseLoggingContext context) {
    return context.selectedHistory.entries
        .where((entry) => entry.rawValue.trim().isNotEmpty)
        .toList();
  }

  int _nextSetNumber(RowHistoryBlock block) {
    for (final entry in block.entries) {
      if (entry.rawValue.trim().isEmpty) {
        return entry.setNumber;
      }
    }
    return block.entries.length + 1;
  }
}

final class SetRecovery {
  const SetRecovery({
    required this.setLabel,
    required this.clear,
    required this.undo,
  });

  final String setLabel;
  final ClearSetCmd clear;
  final EditRawSetCmd undo;
}

class LoggingVm {
  LoggingVm({
    required this.context,
    required Iterable<RowHistoryEntry> loggedEntries,
    required this.nextSetNumber,
    required this.newSetCtrls,
    required this.loggedCtrls,
    required this.rawCtrls,
    required this.origins,
    Iterable<String> timerFields = const [],
  }) : loggedEntries = List<RowHistoryEntry>.unmodifiable(loggedEntries),
       timerFields = List<String>.unmodifiable(timerFields);

  final ExerciseLoggingContext context;
  final List<RowHistoryEntry> loggedEntries;
  final int nextSetNumber;
  final Map<String, TextEditingController> newSetCtrls;
  final Map<int, Map<String, TextEditingController>> loggedCtrls;
  final Map<int, TextEditingController> rawCtrls;

  /// Where each new-set field's current value came from.
  final Map<String, ValueOrigin> origins;

  /// New-set field labels this exercise times, in Log Format order.
  final List<String> timerFields;

  WorkoutChoice get selectedChoice => context.selectedChoice;
}
