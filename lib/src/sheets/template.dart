import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:workout_tracker/contract.dart';

const defaultExerciseAsset = 'assets/exercise_defaults/default_exercises.json';

class Wbk {
  Wbk({required this.activeSheet, required this.exercisesSheet});

  final WbkTab activeSheet;
  final WbkTab exercisesSheet;
}

class WbkTab {
  WbkTab({required this.title, required Iterable<Iterable<String>> rows})
    : rows = List<List<String>>.unmodifiable(
        rows.map((row) => List<String>.unmodifiable(row)),
      );

  final String title;
  final List<List<String>> rows;

  int get columnCount {
    var maxColumns = 0;
    for (final row in rows) {
      if (row.length > maxColumns) {
        maxColumns = row.length;
      }
    }
    return maxColumns;
  }
}

Future<Wbk> loadWbkTmpl({
  AssetBundle? bundle,
  String exerciseDefaultsAsset = defaultExerciseAsset,
}) async {
  final defaults = await loadExerciseDefaults(
    bundle: bundle,
    assetPath: exerciseDefaultsAsset,
  );
  return wbkTmpl(exerciseDefaults: defaults);
}

Future<List<ExerciseDef>> loadExerciseDefaults({
  AssetBundle? bundle,
  String assetPath = defaultExerciseAsset,
}) async {
  final rawJson = await (bundle ?? rootBundle).loadString(assetPath);
  final decoded = jsonDecode(rawJson);
  if (decoded is! List<Object?>) {
    throw const FormatException('Exercise defaults JSON must be a list.');
  }
  return List<ExerciseDef>.unmodifiable(decoded.map(_exerciseDefaultFromJson));
}

Wbk wbkTmpl({required Iterable<ExerciseDef> exerciseDefaults}) {
  final sortedExerciseDefaults = [...exerciseDefaults]
    ..sort(_compareExerciseDefaults);
  final exercisesSheet = WbkTab(
    title: 'Exercises',
    rows: [
      exercisesSheetColumns,
      for (final exercise in sortedExerciseDefaults) _exerciseRow(exercise),
    ],
  );
  return Wbk(
    activeSheet: WbkTab(
      title: 'Active Workout',
      rows: const [activeSheetFixedColumns],
    ),
    exercisesSheet: exercisesSheet,
  );
}

int _compareExerciseDefaults(ExerciseDef left, ExerciseDef right) {
  return left.exercise.toLowerCase().compareTo(right.exercise.toLowerCase());
}

ExerciseDef _exerciseDefaultFromJson(Object? value) {
  if (value is! Map<String, Object?>) {
    throw const FormatException('Each exercise default must be an object.');
  }
  return ExerciseDef(
    exercise: _requiredString(value, 'exercise'),
    description: _optionalString(value, 'description'),
    defaultSets: _requiredString(value, 'defaultSets'),
    defaultRest: _requiredString(value, 'defaultRest'),
    defaultTempo: _requiredString(value, 'defaultTempo'),
    notes: _optionalString(value, 'notes'),
    logFormat: _optionalString(value, 'logFormat'),
    defaultValues: _stringMap(value, 'defaultValues'),
  );
}

String _requiredString(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is String && value.trim().isNotEmpty) {
    return value;
  }
  throw FormatException('Exercise default "$key" must be a non-empty string.');
}

String _optionalString(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value == null) {
    return '';
  }
  if (value is String) {
    return value;
  }
  throw FormatException('Exercise default "$key" must be a string.');
}

Map<String, String> _stringMap(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! Map<String, Object?>) {
    throw FormatException('Exercise default "$key" must be an object.');
  }
  final strings = <String, String>{};
  for (final entry in value.entries) {
    final entryValue = entry.value;
    if (entryValue is! String) {
      throw FormatException(
        'Exercise default "$key.${entry.key}" must be a string.',
      );
    }
    strings[entry.key] = entryValue;
  }
  return strings;
}

List<String> _exerciseRow(ExerciseDef exercise) {
  return [
    exercise.exercise,
    exercise.description,
    exercise.defaultSets,
    exercise.defaultRest,
    exercise.defaultTempo,
    exercise.notes,
    exercise.resolvedLogFormat,
    exercise.renderedDefaultValues,
  ];
}
