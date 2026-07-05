import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:workout_tracker/sheet_contract.dart';

const defaultExerciseAsset = 'assets/exercise_defaults/default_exercises.json';

class Workbook {
  Workbook({required this.activeSheet, required this.exercisesSheet});

  final WorkbookTab activeSheet;
  final WorkbookTab exercisesSheet;
}

class WorkbookTab {
  WorkbookTab({required this.title, required Iterable<Iterable<String>> rows})
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

Future<Workbook> loadWorkbookTemplate({
  AssetBundle? bundle,
  String exerciseDefaultsAsset = defaultExerciseAsset,
}) async {
  final defaults = await loadExerciseDefaults(
    bundle: bundle,
    assetPath: exerciseDefaultsAsset,
  );
  return workbookTemplate(exerciseDefaults: defaults);
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

Workbook workbookTemplate({required Iterable<ExerciseDef> exerciseDefaults}) {
  final sortedExerciseDefaults = [...exerciseDefaults]
    ..sort(_compareExerciseDefaults);
  final exercisesSheet = WorkbookTab(
    title: 'Exercises',
    rows: [
      exercisesSheetColumns,
      for (final exercise in sortedExerciseDefaults) _exerciseRow(exercise),
    ],
  );
  return Workbook(
    activeSheet: WorkbookTab(
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
    defaultSets: _optionalString(value, 'defaultSets'),
    defaultReps: _optionalString(value, 'defaultReps'),
    defaultRpe: _optionalString(value, 'defaultRpe'),
    defaultRest: _optionalString(value, 'defaultRest'),
    defaultTempo: _optionalString(value, 'defaultTempo'),
    notes: _optionalString(value, 'notes'),
    logFormat: _optionalString(value, 'logFormat'),
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

List<String> _exerciseRow(ExerciseDef exercise) {
  return [
    exercise.exercise,
    exercise.description,
    exercise.defaultSets,
    exercise.defaultReps,
    exercise.defaultRpe,
    exercise.defaultRest,
    exercise.defaultTempo,
    exercise.notes,
    exercise.resolvedLogFormat,
  ];
}
