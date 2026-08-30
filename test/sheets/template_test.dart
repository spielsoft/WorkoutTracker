import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_tracker/contract.dart';
import 'package:workout_tracker/sheets.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final numeric = RegExp(r'^\d+(?:\.\d+)?$');

  test('creates schema 1.1 workbooks with nine Exercises columns', () async {
    expect(workbookSchemaVersion, '1.1');

    final workbook = await loadWbkTmpl();

    expect(workbook.exercisesSheet.rows.first, exercisesSheetColumns);
    expect(exercisesSheetColumns.last, 'Timer Fields');
    expect(
      workbook.exercisesSheet.rows,
      everyElement(hasLength(exercisesSheetColumns.length)),
    );
    expect(workbook.activeSheet.rows.single, activeSheetFixedColumns);
  });

  test('seeds Timer Fields for duration-based exercises', () async {
    final workbook = await loadWbkTmpl();
    final timerColumn = exercisesSheetColumns.indexOf('Timer Fields');
    final timedRows = {
      for (final row in workbook.exercisesSheet.rows.skip(1))
        if (row[timerColumn].isNotEmpty) row.first: row[timerColumn],
    };

    expect(timedRows, {
      'Copenhagen Side Plank': "['Seconds']",
      'Plank': "['Seconds']",
      'Side Plank': "['Seconds']",
    });
  });

  test('every catalog record declares its Timer Fields explicitly', () async {
    final raw = jsonDecode(await rootBundle.loadString(defaultExerciseAsset));
    final records = (raw as List<Object?>).cast<Map<String, Object?>>();
    expect(records, hasLength(43));
    for (final record in records) {
      expect(
        record.containsKey('timerFields'),
        isTrue,
        reason: '${record['exercise']} must declare timerFields',
      );
    }

    final defaults = await loadExerciseDefaults();
    final timed = {
      for (final exercise in defaults)
        if (exercise.timerFields.isNotEmpty)
          exercise.exercise: exercise.timerFields,
    };
    expect(timed, {
      'Side Plank': ['Seconds'],
      'Copenhagen Side Plank': ['Seconds'],
      'Plank': ['Seconds'],
    });
    expect(
      {
        for (final exercise in defaults)
          if (exercise.timerFields.isNotEmpty)
            exercise.exercise: exercise.renderedDefaultValues,
      },
      {
        'Copenhagen Side Plank': '20s@8',
        'Plank': '90s@8',
        'Side Plank': '30s@8',
      },
    );
    expect(
      defaults.where((exercise) => exercise.timerFields.isEmpty),
      hasLength(40),
    );
    for (final exercise in defaults) {
      final format =
          parseLogFormat(exercise.resolvedLogFormat) as ParsedLogFormat;
      expect(
        format.fieldLabels,
        containsAll(exercise.timerFields),
        reason: '${exercise.exercise} times an undeclared field',
      );
    }
  });

  test(
    'catalog timerFields defaults to empty and rejects bad values',
    () async {
      Future<List<ExerciseDef>> load(String timerFields) {
        return loadExerciseDefaults(
          bundle: _JsonBundle('''
[
  {
    "exercise": "Side Plank",
    "defaultSets": "3",
    "defaultRest": "45s",
    "defaultTempo": "hold",
    "logFormat": "{Seconds}s@{RPE}",
    "defaultValues": {"Seconds": "30", "RPE": "8"}$timerFields
  }
]
'''),
          assetPath: 'memory.json',
        );
      }

      expect((await load('')).single.timerFields, isEmpty);
      expect((await load(', "timerFields": ["Seconds"]')).single.timerFields, [
        'Seconds',
      ]);
      await expectLater(
        load(', "timerFields": "Seconds"'),
        throwsA(isA<FormatException>()),
      );
      await expectLater(
        load(', "timerFields": [7]'),
        throwsA(isA<FormatException>()),
      );
    },
  );

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
          exercise.defaultValues.values.map((value) => value.trim()),
          everyElement(isNotEmpty),
          reason: exercise.exercise,
        );
        expect(
          exercise.defaultValues.values,
          everyElement(matches(numeric)),
          reason: exercise.exercise,
        );
        expect(
          format.fieldLabels,
          isNot(contains('Weight')),
          reason: '${exercise.exercise} must name weight units',
        );
        expect(
          format.fieldLabels,
          isNot(contains('Height')),
          reason: '${exercise.exercise} must name measurement units',
        );
        if (format.fieldLabels.contains('Pain')) {
          expect(
            exercise.defaultValues['Pain'],
            '0',
            reason: exercise.exercise,
          );
        }
        if (format.fieldLabels.contains('RPE')) {
          expect(
            num.parse(exercise.defaultValues['RPE']!),
            lessThanOrEqualTo(8),
            reason: '${exercise.exercise} must start conservatively',
          );
        }
        expect(
          format.parseValues(exercise.renderedDefaultValues),
          exercise.defaultValues,
          reason: exercise.exercise,
        );
      }

      final workbook = await loadWbkTmpl();
      final exerciseRows = workbook.exercisesSheet.rows.skip(1).toList();
      expect(exerciseRows, hasLength(defaults.length));
      expect(exerciseRows, everyElement(hasLength(9)));
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

  test('seeds DB Step-Up with five numeric values', () async {
    final workbook = await loadWbkTmpl();
    final row = workbook.exercisesSheet.rows.singleWhere(
      (row) => row.first == 'DB Step-Up',
    );

    expect(row[6], '({Height (in)}, {Weight (lbs)})x{Reps}@{RPE},{Pain}');
    expect(row[7], '(12, 15)x8@8,0');

    final format = parseLogFormat(row[6]) as ParsedLogFormat;
    expect(format.fieldLabels, [
      'Height (in)',
      'Weight (lbs)',
      'Reps',
      'RPE',
      'Pain',
    ]);
    expect(format.parseValues(row[7]), {
      'Height (in)': '12',
      'Weight (lbs)': '15',
      'Reps': '8',
      'RPE': '8',
      'Pain': '0',
    });
  });
}

class _JsonBundle extends CachingAssetBundle {
  _JsonBundle(this.json);

  final String json;

  @override
  Future<ByteData> load(String key) async {
    return ByteData.sublistView(Uint8List.fromList(utf8.encode(json)));
  }
}
