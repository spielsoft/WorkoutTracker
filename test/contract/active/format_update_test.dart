import 'package:flutter_test/flutter_test.dart';
import 'package:workout_tracker/contract.dart';

import 'helpers.dart';

void main() {
  const oldFormat = '({Height (in)})x{Reps}@{RPE},{Pain}';
  const newFormat = '({Height (in)}, {Weight (lbs)})x{Reps}@{RPE},{Pain}';

  test(
    'owns canonical and placed Target changes in one stale-checked plan',
    () {
      final rows = [
        historyHeaderRow(['Week 1', '']),
        setLabelRow(['S1', 'S2']),
        activeRow(
          'DB Step-Up',
          logFormat: oldFormat,
          targets: '(14)x10@7,0',
          history: const ['(12)x8@8,0', 'coach note'],
        ),
        activeRow(
          'DB Step-Up',
          logFormat: oldFormat,
          targets: '(16)x6@9,1',
          workout: 'Legs',
          history: const ['', '(16)x6@9,1'],
        ),
      ];
      final exercises = [
        exercisesSheetColumns,
        _exerciseRow(oldFormat, '(12)x8@8,0'),
      ];
      final sheet = parseActiveSheet(
        ActiveSheetInput(
          rows: rows,
          exercisesRows: exercises,
          cellFormulas: const [
            CellFormula(
              sheetRowNumber: 3,
              sheetColumnNumber: 1,
              formula: '=Exercises!A2',
            ),
            CellFormula(
              sheetRowNumber: 3,
              sheetColumnNumber: 7,
              formula: '=Exercises!G2',
            ),
            CellFormula(
              sheetRowNumber: 4,
              sheetColumnNumber: 1,
              formula: '=Exercises!A2',
            ),
            CellFormula(
              sheetRowNumber: 4,
              sheetColumnNumber: 7,
              formula: '=Exercises!G2',
            ),
          ],
        ),
      );
      final selected = sheet.canonicalExercises.single;
      final exercise = ExerciseDef(
        exercise: 'DB Step-Up',
        logFormat: newFormat,
        defaultValues: const {
          'Height (in)': '12',
          'Weight (lbs)': '15',
          'Reps': '8',
          'RPE': '8',
          'Pain': '0',
        },
      );

      final impact = sheet.inspectFormatUpdate(
        selectedExercise: selected,
        exercise: exercise,
      )!;

      expect(impact.fields, [
        'Height (in)',
        'Weight (lbs)',
        'Reps',
        'RPE',
        'Pain',
      ]);
      expect(impact.rawHistoryCount, 2);
      expect(impact.placements.map((placement) => placement.sheetRowNumber), [
        3,
        4,
      ]);
      expect(impact.placements.map((placement) => placement.oldTargets), [
        '(14)x10@7,0',
        '(16)x6@9,1',
      ]);
      expect(impact.placements[0].proposedValues, {
        'Height (in)': '14',
        'Weight (lbs)': '15',
        'Reps': '10',
        'RPE': '7',
        'Pain': '0',
      });
      expect(impact.placements[1].proposedValues, {
        'Height (in)': '16',
        'Weight (lbs)': '15',
        'Reps': '6',
        'RPE': '9',
        'Pain': '1',
      });

      final plan = impact.plan({
        3: {...impact.placements[0].proposedValues, 'Weight (lbs)': '20'},
        4: {...impact.placements[1].proposedValues, 'Weight (lbs)': '25'},
      });
      expect(plan.validationRejections, isEmpty);
      expect(plan.exercises.rowUpdates, hasLength(1));
      expect(plan.active.cellUpdates.map((update) => update.value), [
        '(14, 20)x10@7,0',
        '(16, 25)x6@9,1',
      ]);

      final changed = rows.map((row) => [...row]).toList();
      changed[2][4] = '(18)x10@7,0';
      final stale = parseActiveSheet(
        ActiveSheetInput(
          rows: changed,
          exercisesRows: exercises,
          cellFormulas: const [
            CellFormula(
              sheetRowNumber: 3,
              sheetColumnNumber: 1,
              formula: '=Exercises!A2',
            ),
            CellFormula(
              sheetRowNumber: 3,
              sheetColumnNumber: 7,
              formula: '=Exercises!G2',
            ),
            CellFormula(
              sheetRowNumber: 4,
              sheetColumnNumber: 1,
              formula: '=Exercises!A2',
            ),
            CellFormula(
              sheetRowNumber: 4,
              sheetColumnNumber: 7,
              formula: '=Exercises!G2',
            ),
          ],
        ),
      );
      expect(plan.writeRejections(stale), isNotEmpty);
      expect(changed[2].skip(10), rows[2].skip(10));
    },
  );

  test('uses the canonical-only path when the exercise has no placements', () {
    final sheet = parseActiveSheet(
      ActiveSheetInput(
        rows: [historyHeaderRow([]), setLabelRow([])],
        exercisesRows: [
          exercisesSheetColumns,
          _exerciseRow(oldFormat, '(12)x8@8,0'),
        ],
      ),
    );

    expect(
      sheet.inspectFormatUpdate(
        selectedExercise: sheet.canonicalExercises.single,
        exercise: ExerciseDef(
          exercise: 'DB Step-Up',
          logFormat: newFormat,
          defaultValues: const {
            'Height (in)': '12',
            'Weight (lbs)': '15',
            'Reps': '8',
            'RPE': '8',
            'Pain': '0',
          },
        ),
      ),
      isNull,
    );
  });

  test('rejects placement values that cannot round-trip exactly', () {
    final rows = [
      historyHeaderRow([]),
      setLabelRow([]),
      activeRow('DB Step-Up', logFormat: oldFormat, targets: '(12)x8@8,0'),
    ];
    final sheet = parseActiveSheet(
      ActiveSheetInput(
        rows: rows,
        exercisesRows: [
          exercisesSheetColumns,
          _exerciseRow(oldFormat, '(12)x8@8,0'),
        ],
        cellFormulas: const [
          CellFormula(
            sheetRowNumber: 3,
            sheetColumnNumber: 1,
            formula: '=Exercises!A2',
          ),
        ],
      ),
    );
    final impact = sheet.inspectFormatUpdate(
      selectedExercise: sheet.canonicalExercises.single,
      exercise: ExerciseDef(
        exercise: 'DB Step-Up',
        logFormat: newFormat,
        defaultValues: const {
          'Height (in)': '12',
          'Weight (lbs)': '15',
          'Reps': '8',
          'RPE': '8',
          'Pain': '0',
        },
      ),
    )!;

    final plan = impact.plan({
      3: {
        ...impact.placements.single.proposedValues,
        'Weight (lbs)': '15)x999',
      },
    });

    expect(plan.validationRejections.single.message, contains('recovered'));
    expect(plan.active.cellUpdates, isEmpty);
    expect(plan.exercises.rowUpdates, isEmpty);
  });
}

List<String> _exerciseRow(String format, String values) => [
  'DB Step-Up',
  '',
  '3',
  '2 min',
  '2-1-1',
  '',
  format,
  values,
];
