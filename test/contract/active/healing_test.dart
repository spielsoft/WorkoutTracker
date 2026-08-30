import 'package:flutter_test/flutter_test.dart';
import 'package:workout_tracker/contract.dart';

import 'helpers.dart';

void main() {
  test('repairs a missing canonical exercise formula after validation', () {
    final sheet = _sheet();
    expect(sheet.healingIssues, hasLength(1));
    expect(sheet.healingIssues.single.exerciseName, 'Squat');

    final plan = sheet.planFormulaHealing(
      activeSheetRowNumber: 3,
      selectedRow: 2,
    );
    expect(plan.cellUpdates, [
      const CellUpdate.formula(
        sheetRowNumber: 3,
        sheetColumnNumber: 1,
        value: '=Exercises!A2',
      ),
    ]);
  });

  test('rejects formula healing when the visible row becomes stale', () {
    final sheet = _sheet();
    final plan = sheet.planFormulaHealing(
      activeSheetRowNumber: 3,
      selectedRow: 2,
    );
    final changed = parseActiveSheet(
      ActiveSheetInput(
        rows: [
          historyHeaderRow([]),
          setLabelRow([]),
          activeRow('Front Squat', targets: 'x5@8'),
        ],
        exercisesRows: [_exerciseHeader, _exerciseRow],
        cellFormulas: const [
          CellFormula(
            sheetRowNumber: 3,
            sheetColumnNumber: 7,
            formula: '=Exercises!G2',
          ),
        ],
      ),
    );

    expect(plan.writeRejections(changed), isNotEmpty);
  });

  test('reports a placement split across two Exercises rows', () {
    final sheet = _twinSheet(
      cellFormulas: const [
        CellFormula(
          sheetRowNumber: 3,
          sheetColumnNumber: 1,
          formula: '=Exercises!A2',
        ),
        CellFormula(
          sheetRowNumber: 3,
          sheetColumnNumber: 7,
          formula: '=Exercises!G3',
        ),
      ],
    );

    final issue = sheet.healingIssues.single;
    expect(issue.activeSheetRowNumber, 3);
    expect(
      issue.cells.map((cell) => (cell.columnName, cell.reason)),
      [('Log Format', HealingIssueReason.mismatchedRow)],
      reason: 'the Exercise formula binds row 2, so Log Format may not name 3',
    );
    expect(issue.preselectedRow, 2);
    expect(
      issue.needsChoice,
      isFalse,
      reason: 'a readable Exercise formula leaves nothing to choose',
    );
    expect(sheet.planFormulaRepair().cellUpdates, const [
      CellUpdate.formula(
        sheetRowNumber: 3,
        sheetColumnNumber: 7,
        value: '=Exercises!G2',
      ),
    ]);
  });

  test('a placement with no Exercise formula rebinds every formula cell', () {
    final sheet = _twinSheet(
      cellFormulas: const [
        CellFormula(
          sheetRowNumber: 3,
          sheetColumnNumber: 7,
          formula: '=Exercises!G3',
        ),
      ],
    );

    final issue = sheet.healingIssues.single;
    expect(issue.preselectedRow, isNull);
    expect(issue.needsChoice, isTrue);
    expect(issue.candidateRows, [2, 3]);
    expect(issue.cells.map((cell) => (cell.columnName, cell.reason)), [
      ('Exercise', HealingIssueReason.missingFormula),
      ('Log Format', HealingIssueReason.mismatchedRow),
    ]);
    expect(
      sheet.planFormulaRepair().cellUpdates,
      isEmpty,
      reason: 'no anchor and twin names leave the row for a person to choose',
    );
    expect(
      sheet
          .planFormulaHealing(activeSheetRowNumber: 3, selectedRow: 3)
          .cellUpdates,
      const [
        CellUpdate.formula(
          sheetRowNumber: 3,
          sheetColumnNumber: 1,
          value: '=Exercises!A3',
        ),
        CellUpdate.formula(
          sheetRowNumber: 3,
          sheetColumnNumber: 7,
          value: '=Exercises!G3',
        ),
      ],
      reason: 'one repair binds the whole row to the chosen Exercises row',
    );
  });
}

ParsedActiveSheet _sheet() {
  return parseActiveSheet(
    ActiveSheetInput(
      rows: [
        historyHeaderRow([]),
        setLabelRow([]),
        activeRow('Squat', targets: 'x5@8'),
      ],
      exercisesRows: [_exerciseHeader, _exerciseRow],
      cellFormulas: const [
        CellFormula(
          sheetRowNumber: 3,
          sheetColumnNumber: 7,
          formula: '=Exercises!G2',
        ),
      ],
    ),
  );
}

/// One placement whose visible name matches two canonical rows.
///
/// Duplicate names are permitted, so only the direct formulas say which row
/// row 3 of the active sheet is bound to. The visible cells show row 3 of
/// `Exercises`, the twin the athlete is logging against.
ParsedActiveSheet _twinSheet({required List<CellFormula> cellFormulas}) {
  return parseActiveSheet(
    ActiveSheetInput(
      rows: [
        historyHeaderRow([]),
        setLabelRow([]),
        activeRow(
          'Plank',
          targets: '40@8',
          logFormat: '{Hold}@{RPE}',
          workout: 'Core',
        ),
      ],
      exercisesRows: const [_exerciseHeader, _frontPlankRow, _sidePlankRow],
      cellFormulas: cellFormulas,
    ),
  );
}

const _exerciseHeader = exercisesSheetColumns;
const _exerciseRow = [
  'Squat',
  'Back squat',
  '3',
  '2 min',
  '2-1-1',
  '',
  defaultExerciseLogFormat,
  'x5@8',
];
const _frontPlankRow = [
  'Plank',
  'Front plank hold',
  '3',
  '45s',
  '',
  '',
  '{Seconds}s@{RPE}',
  '30s@8',
  "['Seconds']",
];
const _sidePlankRow = [
  'Plank',
  'Side plank hold',
  '3',
  '45s',
  '',
  '',
  '{Hold}@{RPE}',
  '40@8',
  "['Hold']",
];
