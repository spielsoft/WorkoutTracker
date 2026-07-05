import 'package:flutter_test/flutter_test.dart';
import 'package:workout_tracker/contract.dart';

import 'helpers.dart';

void main() {
  test(
    'reports a healable issue for a missing formula-driven display cell',
    () {
      final activeSheet = parseActiveSheet(
        ActiveSheetInput(
          rows: _squatRows(),
          cellFormulas: _missingExerciseFormulaCells,
          exercisesRows: _squatExerciseRows,
        ),
      );

      expect(activeSheet.formulaHealingIssues, [
        FormulaHealingIssue(
          activeSheetRowNumber: 3,
          displayedExerciseName: 'Squat',
          preselectedRow: 2,
          needsChoice: false,
          candidateRows: const [2],
          exerciseChoices: _squatExerciseChoices,
          cells: const [
            HealingCellIssue(
              sheetRowNumber: 3,
              sheetColumnNumber: 1,
              columnName: 'Exercise',
              reason: HealingIssueReason.missingFormula,
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
        cellFormulas: _brokenLogFormatFormulaCells,
        exercisesRows: _squatExerciseRows,
      ),
    );

    expect(activeSheet.formulaHealingIssues.single.cells, const [
      HealingCellIssue(
        sheetRowNumber: 3,
        sheetColumnNumber: 8,
        columnName: 'Log Format',
        reason: HealingIssueReason.brokenFormula,
        currentFormula: '=Exercises!I99',
      ),
    ]);
  });

  test('reports and plans healing for a missing Log Format formula', () {
    final activeSheet = parseActiveSheet(
      ActiveSheetInput(
        rows: _squatRows(),
        cellFormulas: _missingLogFormatFormulaCells,
        exercisesRows: _squatExerciseRows,
      ),
    );

    expect(activeSheet.formulaHealingIssues, [
      FormulaHealingIssue(
        activeSheetRowNumber: 3,
        displayedExerciseName: 'Squat',
        preselectedRow: 2,
        needsChoice: false,
        candidateRows: const [2],
        exerciseChoices: _squatExerciseChoices,
        cells: const [
          HealingCellIssue(
            sheetRowNumber: 3,
            sheetColumnNumber: 8,
            columnName: 'Log Format',
            reason: HealingIssueReason.missingFormula,
            currentFormula: '',
          ),
        ],
      ),
    ]);

    expect(
      activeSheet.planFormulaHealing(activeSheetRowNumber: 3).cellUpdates,
      [
        const CellUpdate.formula(
          sheetRowNumber: 3,
          sheetColumnNumber: 8,
          value: '=Exercises!I2',
        ),
      ],
    );
  });

  test(
    'plans Log Format healing only after ambiguous issues get a user choice',
    () {
      final activeSheet = parseActiveSheet(
        ActiveSheetInput(
          rows: _squatRows(),
          cellFormulas: _missingLogFormatFormulaCells,
          exercisesRows: const [
            _exercisesHeader,
            [
              'Squat',
              'Back squat',
              '3',
              '5',
              '8',
              '3 min',
              '',
              'Stay braced.',
              '{Weight}[x]{Reps}[@]{RPE}',
            ],
            [
              'Squat',
              'Safety-bar squat',
              '3',
              '5',
              '8',
              '3 min',
              '',
              'Stay tall.',
              '{Reps}[@]{RPE}',
            ],
          ],
        ),
      );

      final issue = activeSheet.formulaHealingIssues.single;
      expect(issue.needsChoice, isTrue);
      expect(issue.cells.single.columnName, 'Log Format');
      expect(
        activeSheet.planFormulaHealing(activeSheetRowNumber: 3).cellUpdates,
        isEmpty,
      );

      final plan = activeSheet.planFormulaHealing(
        activeSheetRowNumber: 3,
        selectedRow: 3,
      );

      expect(plan.cellUpdates, const [
        CellUpdate.formula(
          sheetRowNumber: 3,
          sheetColumnNumber: 8,
          value: '=Exercises!I3',
        ),
      ]);
    },
  );

  test('requires user selection for ambiguous displayed-name matches', () {
    final activeSheet = parseActiveSheet(
      ActiveSheetInput(
        rows: _squatRows(),
        cellFormulas: _missingExerciseFormulaCells,
        exercisesRows: const [
          _exercisesHeader,
          [
            'Squat',
            'Back squat',
            '3',
            '5',
            '8',
            '3 min',
            '',
            'Stay braced.',
            '{Weight}[x]{Reps}[@]{RPE}',
          ],
          [
            'Squat',
            'Safety-bar squat',
            '3',
            '5',
            '8',
            '3 min',
            '',
            'Stay tall.',
            '{Weight}[x]{Reps}[@]{RPE}',
          ],
        ],
      ),
    );

    final issue = activeSheet.formulaHealingIssues.single;
    expect(issue.displayedExerciseName, 'Squat');
    expect(issue.needsChoice, isTrue);
    expect(issue.preselectedRow, isNull);
    expect(issue.candidateRows, [2, 3]);
  });

  test('reports broken formulas for ambiguous displayed-name matches', () {
    final activeSheet = parseActiveSheet(
      ActiveSheetInput(
        rows: _squatRows(),
        cellFormulas: _brokenLogFormatFormulaCells,
        exercisesRows: const [
          _exercisesHeader,
          [
            'Squat',
            'Back squat',
            '3',
            '5',
            '8',
            '3 min',
            '',
            'Stay braced.',
            '{Weight}[x]{Reps}[@]{RPE}',
          ],
          [
            'Squat',
            'Safety-bar squat',
            '3',
            '5',
            '8',
            '3 min',
            '',
            'Stay tall.',
            '{Weight}[x]{Reps}[@]{RPE}',
          ],
        ],
      ),
    );

    final issue = activeSheet.formulaHealingIssues.single;
    expect(issue.needsChoice, isTrue);
    expect(issue.cells, const [
      HealingCellIssue(
        sheetRowNumber: 3,
        sheetColumnNumber: 8,
        columnName: 'Log Format',
        reason: HealingIssueReason.brokenFormula,
        currentFormula: '=Exercises!I99',
      ),
    ]);
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
            '{Weight}[x]{Reps}[@]{RPE}',
            'Legs',
            '',
          ],
        ],
        cellFormulas: _missingExerciseFormulaCells,
        exercisesRows: _squatExerciseRows,
      ),
    );

    final issue = activeSheet.formulaHealingIssues.single;
    expect(issue.displayedExerciseName, 'Front Squat');
    expect(issue.needsChoice, isTrue);
    expect(issue.preselectedRow, isNull);
    expect(issue.candidateRows, isEmpty);
  });

  test('reports broken formulas for missing displayed-name matches', () {
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
            '{Weight}[x]{Reps}[@]{RPE}',
            'Legs',
            '',
          ],
        ],
        cellFormulas: _brokenLogFormatFormulaCells,
        exercisesRows: _squatExerciseRows,
      ),
    );

    final issue = activeSheet.formulaHealingIssues.single;
    expect(issue.needsChoice, isTrue);
    expect(issue.cells, const [
      HealingCellIssue(
        sheetRowNumber: 3,
        sheetColumnNumber: 8,
        columnName: 'Log Format',
        reason: HealingIssueReason.brokenFormula,
        currentFormula: '=Exercises!I99',
      ),
    ]);
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
      CellUpdate.formula(
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
            [
              'Squat',
              'Back squat',
              '3',
              '5',
              '8',
              '3 min',
              '',
              'Stay braced.',
              '{Weight}[x]{Reps}[@]{RPE}',
            ],
            [
              'Squat',
              'Safety-bar squat',
              '3',
              '5',
              '8',
              '3 min',
              '',
              'Stay tall.',
              '{Weight}[x]{Reps}[@]{RPE}',
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
        selectedRow: 3,
      );

      expect(plan.columnInsertions, isEmpty);
      expect(plan.cellUpdates, const [
        CellUpdate.formula(
          sheetRowNumber: 3,
          sheetColumnNumber: 1,
          value: '=Exercises!A3',
        ),
      ]);
    },
  );

  test('rejects formula healing if the active sheet row changed', () {
    final rows = _squatRows();
    final activeSheet = parseActiveSheet(
      ActiveSheetInput(
        rows: rows,
        cellFormulas: _missingExerciseFormulaCells,
        exercisesRows: _squatExerciseRows,
      ),
    );

    final plan = activeSheet.planFormulaHealing(activeSheetRowNumber: 3);

    final changedRows = rows.map((row) => [...row]).toList();
    changedRows[2][1] = '4';
    final changedSheet = parseActiveSheet(
      ActiveSheetInput(
        rows: changedRows,
        cellFormulas: _missingExerciseFormulaCells,
        exercisesRows: _squatExerciseRows,
      ),
    );

    expect(plan.writeRejections(changedSheet), [
      const WriteRejection(
        'The active sheet changed after validation. Revalidate before '
        'repairing formulas for row 3.',
      ),
    ]);
  });
}

List<List<String>> _squatRows() {
  return [
    historyHeaderRow(['Session A']),
    setLabelRow(['S1']),
    [
      'Squat',
      '3',
      '5',
      '8',
      '3 min',
      '',
      'Stay braced.',
      '{Weight}[x]{Reps}[@]{RPE}',
      'Legs',
      '',
      '',
    ],
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
  'Log Format',
];

const _squatExerciseRows = [
  _exercisesHeader,
  [
    'Squat',
    'Back squat',
    '3',
    '5',
    '8',
    '3 min',
    '',
    'Stay braced.',
    '{Weight}[x]{Reps}[@]{RPE}',
  ],
];

const _squatExerciseChoices = [
  HealingChoice(
    sheetRowNumber: 2,
    exerciseName: 'Squat',
    description: 'Back squat',
  ),
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
  CellFormula(
    sheetRowNumber: 3,
    sheetColumnNumber: 8,
    formula: '=Exercises!I2',
  ),
];

const _missingLogFormatFormulaCells = [
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

const _brokenLogFormatFormulaCells = [
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
  CellFormula(
    sheetRowNumber: 3,
    sheetColumnNumber: 8,
    formula: '=Exercises!I99',
  ),
];
