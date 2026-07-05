// ignore_for_file: prefer_initializing_formals

import 'package:flutter/widgets.dart';
import 'package:workout_tracker/contract.dart';

class LoggingFlow {
  LoggingFlow({
    required ParsedActiveSheet activeSheet,
    required String historyBlockLabel,
    required int primaryRow,
    required int selectedRow,
  }) : _activeSheet = activeSheet,
       _historyBlockLabel = historyBlockLabel,
       _primaryRow = primaryRow,
       _selectedRow = selectedRow {
    _syncControllers(_context);
  }

  ParsedActiveSheet _activeSheet;
  String _historyBlockLabel;
  int _primaryRow;
  int _selectedRow;

  final _newSetControllers = <String, TextEditingController>{};
  final _loggedFieldControllers = <int, Map<String, TextEditingController>>{};
  final _rawControllers = <int, TextEditingController>{};

  LoggingVm get viewModel {
    final context = _context;
    return LoggingVm(
      context: context,
      loggedEntries: _loggedEntries(context),
      nextSetNumber: _nextSetNumber(context.selectedHistory),
      latestHistoryValue: _latestHistoryValue(context),
      newSetControllers: Map<String, TextEditingController>.unmodifiable(
        _newSetControllers,
      ),
      loggedControllers:
          Map<int, Map<String, TextEditingController>>.unmodifiable({
            for (final entry in _loggedFieldControllers.entries)
              entry.key: Map<String, TextEditingController>.unmodifiable(
                entry.value,
              ),
          }),
      rawControllers: Map<int, TextEditingController>.unmodifiable(
        _rawControllers,
      ),
    );
  }

  void update({
    required ParsedActiveSheet activeSheet,
    required String historyBlockLabel,
    required int primaryRow,
    required int selectedRow,
  }) {
    _activeSheet = activeSheet;
    _historyBlockLabel = historyBlockLabel;
    _primaryRow = primaryRow;
    _selectedRow = selectedRow;
    _syncControllers(_context);
  }

  ActiveSheetWritePlan? planSetSave() {
    final fieldValues = {
      for (final entry in _newSetControllers.entries)
        entry.key: entry.value.text.trim(),
    };
    if (fieldValues.values.every((value) => value.isEmpty)) {
      return null;
    }

    return _activeSheet.planSetLoggingWrite(
      historyBlockLabel: _historyBlockLabel,
      sheetRowNumber: _context.selectedChoice.sheetRowNumber,
      fieldValues: fieldValues,
    );
  }

  ActiveSheetWritePlan? planSetEdit(RowHistoryEntry entry) {
    final controllers = _loggedFieldControllers[entry.setNumber];
    if (controllers == null) {
      return null;
    }

    return _activeSheet.planSetEdit(
      historyBlockLabel: _historyBlockLabel,
      sheetRowNumber: _context.selectedChoice.sheetRowNumber,
      setNumber: entry.setNumber,
      fieldValues: {
        for (final controllerEntry in controllers.entries)
          controllerEntry.key: controllerEntry.value.text.trim(),
      },
    );
  }

  ActiveSheetWritePlan planRawSetEdit(RowHistoryEntry entry) {
    return _activeSheet.planRawSetEdit(
      historyBlockLabel: _historyBlockLabel,
      sheetRowNumber: _context.selectedChoice.sheetRowNumber,
      setNumber: entry.setNumber,
      rawText: _rawControllers[entry.setNumber]?.text ?? '',
    );
  }

  ActiveSheetWritePlan planSetClear(RowHistoryEntry entry) {
    return _activeSheet.planSetClear(
      historyBlockLabel: _historyBlockLabel,
      sheetRowNumber: _context.selectedChoice.sheetRowNumber,
      setNumber: entry.setNumber,
    );
  }

  void clearNewSets() {
    for (final controller in _newSetControllers.values) {
      controller.clear();
    }
  }

  void dispose() {
    for (final controller in _newSetControllers.values) {
      controller.dispose();
    }
    for (final controllers in _loggedFieldControllers.values) {
      for (final controller in controllers.values) {
        controller.dispose();
      }
    }
    for (final controller in _rawControllers.values) {
      controller.dispose();
    }
  }

  ExerciseLoggingContext get _context {
    return _activeSheet.buildLoggingContext(
      primarySheetRowNumber: _primaryRow,
      selectedSheetRowNumber: _selectedRow,
      historyBlockLabel: _historyBlockLabel,
    );
  }

  void _syncControllers(ExerciseLoggingContext context) {
    _syncNewSetControllers(context);
    _syncLoggedControllers(context);
  }

  void _syncNewSetControllers(ExerciseLoggingContext context) {
    final labels = switch (context.logFormat) {
      ParsedLogFormat(:final fieldLabels) => fieldLabels.toSet(),
      InvalidLogFormat() => <String>{},
    };
    final removedLabels = _newSetControllers.keys
        .where((label) => !labels.contains(label))
        .toList();
    for (final label in removedLabels) {
      _newSetControllers.remove(label)?.dispose();
    }
    for (final label in labels) {
      _newSetControllers.putIfAbsent(label, TextEditingController.new);
    }
  }

  void _syncLoggedControllers(ExerciseLoggingContext context) {
    final nonEmptyEntries = _nonEmptyEntries(context);
    final activeSetNumbers = {
      for (final entry in nonEmptyEntries) entry.setNumber,
    };
    final rawSetNumbers = {
      for (final entry in nonEmptyEntries)
        if (entry.logEntry is RawLogEntry) entry.setNumber,
    };

    final removedLoggedSets = _loggedFieldControllers.keys
        .where((setNumber) => !activeSetNumbers.contains(setNumber))
        .toList();
    for (final setNumber in removedLoggedSets) {
      _disposeSetControllers(setNumber);
    }

    final removedRawSetNumbers = _rawControllers.keys
        .where((setNumber) => !rawSetNumbers.contains(setNumber))
        .toList();
    for (final setNumber in removedRawSetNumbers) {
      _rawControllers.remove(setNumber)?.dispose();
    }

    for (final setNumber in rawSetNumbers) {
      _disposeSetControllers(setNumber);
    }

    for (final entry in nonEmptyEntries) {
      final logEntry = entry.logEntry;
      if (logEntry is FormattedLogEntry) {
        _syncSetControllers(entry.setNumber, logEntry);
        continue;
      }
      final controller = _rawControllers.putIfAbsent(
        entry.setNumber,
        TextEditingController.new,
      );
      if (controller.text != entry.rawValue) {
        controller.text = entry.rawValue;
      }
    }
  }

  void _syncSetControllers(int setNumber, FormattedLogEntry logEntry) {
    _rawControllers.remove(setNumber)?.dispose();
    final controllers = _loggedFieldControllers.putIfAbsent(
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

  void _disposeSetControllers(int setNumber) {
    final controllers = _loggedFieldControllers.remove(setNumber);
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

  String? _latestHistoryValue(ExerciseLoggingContext context) {
    for (final block in context.recentHistoryBlocks) {
      for (final entry in block.entries) {
        if (entry.rawValue.trim().isNotEmpty) {
          return entry.rawValue;
        }
      }
    }
    return null;
  }
}

class LoggingVm {
  LoggingVm({
    required this.context,
    required Iterable<RowHistoryEntry> loggedEntries,
    required this.nextSetNumber,
    required this.latestHistoryValue,
    required this.newSetControllers,
    required this.loggedControllers,
    required this.rawControllers,
  }) : loggedEntries = List<RowHistoryEntry>.unmodifiable(loggedEntries);

  final ExerciseLoggingContext context;
  final List<RowHistoryEntry> loggedEntries;
  final int nextSetNumber;
  final String? latestHistoryValue;
  final Map<String, TextEditingController> newSetControllers;
  final Map<int, Map<String, TextEditingController>> loggedControllers;
  final Map<int, TextEditingController> rawControllers;

  WorkoutChoice get selectedChoice => context.selectedChoice;
}
