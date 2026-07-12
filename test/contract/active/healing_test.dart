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
