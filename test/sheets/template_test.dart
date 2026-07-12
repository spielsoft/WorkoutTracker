import 'package:flutter_test/flutter_test.dart';
import 'package:workout_tracker/sheets.dart';
import 'package:workout_tracker/format.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'seeds app-created workbooks from editable default exercises JSON',
    () async {
      expect(defaultExerciseAsset, endsWith('default_exercises.json'));

      final defaults = await loadExerciseDefaults();
      expect(defaults, isNotEmpty);
      expect(
        defaults.map((exercise) => exercise.exercise),
        everyElement(allOf(isA<String>(), isNotEmpty)),
      );
      expect(
        defaults.map((exercise) => exercise.exercise.trim()),
        unorderedEquals(defaults.map((exercise) => exercise.exercise)),
      );
      expect(
        defaults.map((exercise) => exercise.exercise).toSet(),
        hasLength(defaults.length),
      );
      expect(
        defaults.map((exercise) => parseLogFormat(exercise.resolvedLogFormat)),
        everyElement(isA<ParsedLogFormat>()),
      );
      for (final exercise in defaults) {
        expect(
          exercise.defaultSets.trim(),
          isNotEmpty,
          reason: exercise.exercise,
        );
        expect(
          exercise.defaultRest.trim(),
          isNotEmpty,
          reason: exercise.exercise,
        );
        expect(
          exercise.defaultTempo.trim(),
          isNotEmpty,
          reason: exercise.exercise,
        );
        final format =
            parseLogFormat(exercise.resolvedLogFormat) as ParsedLogFormat;
        expect(
          exercise.defaultValues.keys,
          format.fieldLabels,
          reason: exercise.exercise,
        );
        expect(
          format.parseValues(exercise.renderedDefaultValues),
          exercise.defaultValues,
          reason: exercise.exercise,
        );
      }

      final workbook = await loadWbkTmpl();
      final exerciseRows = workbook.exercisesSheet.rows.skip(1).toList();
      expect(exerciseRows, hasLength(defaults.length));
      expect(exerciseRows, everyElement(hasLength(8)));
      final sortedDefaultNames =
          [for (final exercise in defaults) exercise.exercise]..sort(
            (left, right) => left.toLowerCase().compareTo(right.toLowerCase()),
          );
      expect(exerciseRows.map((row) => row.first), sortedDefaultNames);
      expect(
        exerciseRows.map((row) => parseLogFormat(row[6])),
        everyElement(isA<ParsedLogFormat>()),
      );
    },
  );

  test('orders app-created workbook exercises alphabetically', () async {
    final workbook = await loadWbkTmpl();
    final exerciseNames = [
      for (final row in workbook.exercisesSheet.rows.skip(1)) row.first,
    ];
    final sortedExerciseNames = [
      ...exerciseNames,
    ]..sort((left, right) => left.toLowerCase().compareTo(right.toLowerCase()));

    expect(exerciseNames, sortedExerciseNames);
  });
}
