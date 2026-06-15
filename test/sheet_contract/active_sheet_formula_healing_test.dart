import 'package:flutter_test/flutter_test.dart';
import 'package:workout_tracker/sheet_contract.dart';

import 'active_sheet_test_helpers.dart';

void main() {
  test(
    'reports a healable issue for a missing formula-driven display cell',
    () {
      final activeSheet = parseActiveSheet(
        ActiveSheetInput(
          rows: _squatRows(),
          cellFormulas: const [
            CellFormula(
              sheetRowNumber: 3,
              sheetColumnNumber: 2,
              formula: '=Exercises!C2',
            ),
            CellFormula(
              sheetRowNumber: 3,
              sheetColumnNumber: 3,
              formula: '=Exercises!D2',
            ),
            CellFormula(
              sheetRowNumber: 3,
              sheetColumnNumber: 4,
              formula: '=Exercises!E2',
            ),
            CellFormula(
              sheetRowNumber: 3,
              sheetColumnNumber: 5,
              formula: '=Exercises!F2',
            ),
            CellFormula(
              sheetRowNumber: 3,
              sheetColumnNumber: 6,
              formula: '=Exercises!G2',
            ),
            CellFormula(
              sheetRowNumber: 3,
              sheetColumnNumber: 7,
              formula: '=Exercises!H2',
            ),
          ],
          exercisesRows: _squatExerciseRows,
        ),
      );

      expect(activeSheet.formulaHealingIssues, [
        FormulaHealingIssue(
          activeSheetRowNumber: 3,
          displayedExerciseName: 'Squat',
          preselectedExerciseSheetRowNumber: 2,
          requiresUserSelection: false,
          candidateExerciseSheetRowNumbers: const [2],
          cells: const [
            FormulaHealingCellIssue(
              sheetRowNumber: 3,
              sheetColumnNumber: 1,
              columnName: 'Exercise',
              reason: FormulaHealingIssueReason.missingFormula,
              currentFormula: '',
            ),
          ],
        ),
      ]);
    },
  );

  test('reports a healable issue for a broken formula-driven cell', () {
    final activeSheet = parseActiveSheet(
      ActiveSheetInput(
        rows: _squatRows(),
        cellFormulas: const [
          CellFormula(
            sheetRowNumber: 3,
            sheetColumnNumber: 1,
            formula: '=Exercises!A2',
          ),
          CellFormula(
            sheetRowNumber: 3,
            sheetColumnNumber: 2,
            formula: '=Exercises!C2',
          ),
          CellFormula(
            sheetRowNumber: 3,
            sheetColumnNumber: 3,
            formula: '=Exercises!D99',
          ),
          CellFormula(
            sheetRowNumber: 3,
            sheetColumnNumber: 4,
            formula: '=Exercises!E2',
          ),
          CellFormula(
            sheetRowNumber: 3,
            sheetColumnNumber: 5,
            formula: '=Exercises!F2',
          ),
          CellFormula(
            sheetRowNumber: 3,
            sheetColumnNumber: 6,
            formula: '=Exercises!G2',
          ),
          CellFormula(
            sheetRowNumber: 3,
            sheetColumnNumber: 7,
            formula: '=Exercises!H2',
          ),
        ],
        exercisesRows: _squatExerciseRows,
      ),
    );

    expect(activeSheet.formulaHealingIssues.single.cells, const [
      FormulaHealingCellIssue(
        sheetRowNumber: 3,
        sheetColumnNumber: 3,
        columnName: 'Reps',
        reason: FormulaHealingIssueReason.brokenFormula,
        currentFormula: '=Exercises!D99',
      ),
    ]);
  });

  test('requires user selection for ambiguous displayed-name matches', () {
    final activeSheet = parseActiveSheet(
      ActiveSheetInput(
        rows: _squatRows(),
        cellFormulas: _missingExerciseFormulaCells,
        exercisesRows: const [
          _exercisesHeader,
          ['Squat', 'Back squat', '3', '5', '8', '3 min', '', 'Stay braced.'],
          [
            'Squat',
            'Safety-bar squat',
            '3',
            '5',
            '8',
            '3 min',
            '',
            'Stay tall.',
          ],
        ],
      ),
    );

    final issue = activeSheet.formulaHealingIssues.single;
    expect(issue.displayedExerciseName, 'Squat');
    expect(issue.requiresUserSelection, isTrue);
    expect(issue.preselectedExerciseSheetRowNumber, isNull);
    expect(issue.candidateExerciseSheetRowNumbers, [2, 3]);
  });

  test('requires user selection for missing displayed-name matches', () {
    final activeSheet = parseActiveSheet(
      ActiveSheetInput(
        rows: [
          historyHeaderRow(['Session A']),
          setLabelRow(['S1']),
          [
            'Front Squat',
            '3',
            '5',
            '8',
            '3 min',
            '',
            'Stay braced.',
            'Legs',
            '',
            '',
          ],
        ],
        cellFormulas: _missingExerciseFormulaCells,
        exercisesRows: _squatExerciseRows,
      ),
    );

    final issue = activeSheet.formulaHealingIssues.single;
    expect(issue.displayedExerciseName, 'Front Squat');
    expect(issue.requiresUserSelection, isTrue);
    expect(issue.preselectedExerciseSheetRowNumber, isNull);
    expect(issue.candidateExerciseSheetRowNumbers, isEmpty);
  });

  test('plans formula healing updates into the preselected Exercises row', () {
    final activeSheet = parseActiveSheet(
      ActiveSheetInput(
        rows: _squatRows(),
        cellFormulas: _missingExerciseFormulaCells,
        exercisesRows: _squatExerciseRows,
      ),
    );

    final plan = activeSheet.planFormulaHealing(activeSheetRowNumber: 3);

    expect(plan.columnInsertions, isEmpty);
    expect(plan.cellUpdates, const [
      CellUpdate(
        sheetRowNumber: 3,
        sheetColumnNumber: 1,
        value: '=Exercises!A2',
      ),
    ]);
  });

  test(
    'plans formula healing only after ambiguous issues get a user choice',
    () {
      final activeSheet = parseActiveSheet(
        ActiveSheetInput(
          rows: _squatRows(),
          cellFormulas: _missingExerciseFormulaCells,
          exercisesRows: const [
            _exercisesHeader,
            ['Squat', 'Back squat', '3', '5', '8', '3 min', '', 'Stay braced.'],
            [
              'Squat',
              'Safety-bar squat',
              '3',
              '5',
              '8',
              '3 min',
              '',
              'Stay tall.',
            ],
          ],
        ),
      );

      expect(
        activeSheet.planFormulaHealing(activeSheetRowNumber: 3).cellUpdates,
        isEmpty,
      );

      final plan = activeSheet.planFormulaHealing(
        activeSheetRowNumber: 3,
        selectedExerciseSheetRowNumber: 3,
      );

      expect(plan.columnInsertions, isEmpty);
      expect(plan.cellUpdates, const [
        CellUpdate(
          sheetRowNumber: 3,
          sheetColumnNumber: 1,
          value: '=Exercises!A3',
        ),
      ]);
    },
  );
}

List<List<String>> _squatRows() {
  return [
    historyHeaderRow(['Session A']),
    setLabelRow(['S1']),
    ['Squat', '3', '5', '8', '3 min', '', 'Stay braced.', 'Legs', '', ''],
  ];
}

const _exercisesHeader = [
  'Exercise',
  'Description',
  'Default Sets',
  'Default Reps',
  'Default RPE',
  'Default Rest',
  'Default Tempo',
  'Notes',
];

const _squatExerciseRows = [
  _exercisesHeader,
  ['Squat', 'Back squat', '3', '5', '8', '3 min', '', 'Stay braced.'],
];

const _missingExerciseFormulaCells = [
  CellFormula(
    sheetRowNumber: 3,
    sheetColumnNumber: 2,
    formula: '=Exercises!C2',
  ),
  CellFormula(
    sheetRowNumber: 3,
    sheetColumnNumber: 3,
    formula: '=Exercises!D2',
  ),
  CellFormula(
    sheetRowNumber: 3,
    sheetColumnNumber: 4,
    formula: '=Exercises!E2',
  ),
  CellFormula(
    sheetRowNumber: 3,
    sheetColumnNumber: 5,
    formula: '=Exercises!F2',
  ),
  CellFormula(
    sheetRowNumber: 3,
    sheetColumnNumber: 6,
    formula: '=Exercises!G2',
  ),
  CellFormula(
    sheetRowNumber: 3,
    sheetColumnNumber: 7,
    formula: '=Exercises!H2',
  ),
];
