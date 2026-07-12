import 'package:flutter_test/flutter_test.dart';
import 'package:workout_tracker/contract.dart';

import 'workbook.dart';

void main() {
  test('local workbook fixture satisfies the current workbook contract', () {
    final fixture = loadLocalWorkoutWorkbookFixture();
    final sheet = _parse(fixture);

    expect(fixture.activeSheet.rows.first.take(10), activeSheetFixedColumns);
    expect(fixture.exercisesSheet.rows.first.take(8), exercisesSheetColumns);
    expect(sheet.schemaViolations, isEmpty);
    expect(sheet.selectableWorkouts, containsAll(['Legs', 'Upper', 'Default']));
    expect(sheet.canonicalExercises, isNotEmpty);
  });

  test('damage fixtures surface schema and grouping failures', () {
    expect(
      parseActiveSheet(
        ActiveSheetInput(rows: loadFixedColumnDamageFixture().activeSheet.rows),
      ).schemaViolations,
      isNotEmpty,
    );
    expect(
      parseActiveSheet(
        ActiveSheetInput(
          rows: loadInvalidLogFormatDamageFixture().activeSheet.rows,
        ),
      ).schemaViolations.map((violation) => violation.message),
      contains(startsWith('Invalid Log Format:')),
    );
    expect(
      parseActiveSheet(
        ActiveSheetInput(
          rows: loadBackupGroupingDamageFixture().activeSheet.rows,
        ),
      ).schemaViolations.map((violation) => violation.message),
      contains('Backup row has no preceding primary row in the same workout.'),
    );
  });

  test('development fixture remains explicitly writable and stable', () {
    final fixture = writableDevelopmentSheetFixture();
    expect(fixture.isWritable, isTrue);
    expect(fixture.url, contains('/spreadsheets/d/'));
    expect(
      fixture.toSnapshot(),
      writableDevelopmentSheetFixture().toSnapshot(),
    );
  });
}

ParsedActiveSheet _parse(WorkoutWorkbookFixture fixture) {
  return parseActiveSheet(
    ActiveSheetInput(
      rows: fixture.activeSheet.rows,
      exercisesRows: fixture.exercisesSheet.rows,
      cellFormulas: [
        for (final formula in fixture.activeSheet.cellFormulas)
          CellFormula(
            sheetRowNumber: formula.sheetRowNumber,
            sheetColumnNumber: formula.sheetColumnNumber,
            formula: formula.formula,
          ),
      ],
      validateWorkbook: true,
      mergedFirstColumnRows: fixture.activeSheet.mergedFirstColumnRows,
    ),
  );
}
