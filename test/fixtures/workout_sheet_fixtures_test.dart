import 'package:flutter_test/flutter_test.dart';
import 'package:workout_tracker/sheet_contract.dart';

import 'workout_sheet_fixtures.dart';

void main() {
  test('loads the local workbook fixture deterministically', () {
    final first = loadLocalWorkoutWorkbookFixture();
    final second = loadLocalWorkoutWorkbookFixture();

    expect(first.toSnapshot(), equals(second.toSnapshot()));
    expect(first.activeSheet.name, 'Active Workout');
    expect(first.exercisesSheet.name, 'Exercises');

    expect(
      first.activeSheet.rows.first,
      equals([
        'Exercise',
        'Sets',
        'Reps',
        'RPE',
        'Rest',
        'Tempo',
        'Notes',
        'Log Format',
        'Workout',
        'is_backup',
        'Week 2',
        '',
        'Week 1',
        '',
        '',
      ]),
    );
    expect(first.activeSheet.mergedFirstColumnRows, contains(2));
    expect(first.activeSheet.rows[1].first, isEmpty);

    final exerciseRows = first.activeSheet.rows.where(_isExerciseRow).toList();
    final legsRows = exerciseRows.where((row) => row[8] == 'Legs').toList();
    final upperRows = exerciseRows.where((row) => row[8] == 'Upper').toList();
    final defaultWorkoutRows = exerciseRows
        .where((row) => row[8].isEmpty)
        .toList();
    final backupRows = exerciseRows.where((row) => row[9] == 'TRUE').toList();

    expect(
      legsRows.where((row) => row[9] != 'TRUE'),
      hasLength(greaterThanOrEqualTo(2)),
    );
    expect(
      upperRows.where((row) => row[9] != 'TRUE'),
      hasLength(greaterThanOrEqualTo(2)),
    );
    expect(backupRows, isNotEmpty);
    expect(defaultWorkoutRows, isNotEmpty);
    expect(
      exerciseRows,
      anyElement(
        predicate<List<String>>(
          (row) => row[0] == 'Plank' && row[8] == 'Upper' && row[9] != 'TRUE',
          'contains Plank as a primary Upper row',
        ),
      ),
    );

    final exerciseLibraryNames = first.exercisesSheet.rows
        .skip(1)
        .map((row) => row.first)
        .toSet();
    expect(exerciseLibraryNames, containsAll(['Plank', 'Farmer Carry']));
    expect(
      exerciseRows.every((row) => exerciseLibraryNames.contains(row.first)),
      isTrue,
    );
  });

  test('names the writable development Google Sheet fixture', () {
    final first = writableDevelopmentSheetFixture();
    final second = writableDevelopmentSheetFixture();

    expect(first.toSnapshot(), equals(second.toSnapshot()));
    expect(first.name, 'WorkoutTracker development sheet');
    expect(first.isWritable, isTrue);
    expect(
      first.url,
      'https://docs.google.com/spreadsheets/d/'
      '1zQrmCYelrNqRMv4WtJcOrtezSxoaVniXzXi4XgKva_E/edit?gid=0#gid=0',
    );
  });

  test('fixed-column damage fixture exposes schema violations', () {
    final fixture = loadFixedColumnDamageFixture();
    final activeSheet = parseActiveSheet(
      ActiveSheetInput(rows: fixture.activeSheet.rows),
    );

    expect(
      fixture.toSnapshot(),
      equals(loadFixedColumnDamageFixture().toSnapshot()),
    );
    expect(
      activeSheet.schemaViolations.map((violation) => violation.message),
      containsAll([
        'Fixed column 1 must be "Exercise".',
        'Fixed column 8 must be "Log Format".',
      ]),
    );
  });

  test('malformed history damage fixture exposes schema violations', () {
    final fixture = loadMalformedHistoryDamageFixture();
    final activeSheet = parseActiveSheet(
      ActiveSheetInput(rows: fixture.activeSheet.rows),
    );

    expect(
      fixture.toSnapshot(),
      equals(loadMalformedHistoryDamageFixture().toSnapshot()),
    );
    expect(
      activeSheet.schemaViolations.map((violation) => violation.message),
      containsAll([
        'History set column S1 has no history block label.',
        'Duplicate history block label: Week 1.',
        'History block Week 1 skips set label S2 before S3.',
        'History block Empty Block has no set columns.',
      ]),
    );
  });

  test('invalid log format damage fixture exposes schema violations', () {
    final fixture = loadInvalidLogFormatDamageFixture();
    final activeSheet = parseActiveSheet(
      ActiveSheetInput(rows: fixture.activeSheet.rows),
    );

    expect(
      fixture.toSnapshot(),
      equals(loadInvalidLogFormatDamageFixture().toSnapshot()),
    );
    expect(activeSheet.slots.single.logFormat, isA<InvalidLogFormat>());
    expect(
      activeSheet.schemaViolations.single.message,
      startsWith('Invalid Log Format:'),
    );
  });

  test('backup grouping damage fixture exposes schema violations', () {
    final fixture = loadBackupGroupingDamageFixture();
    final activeSheet = parseActiveSheet(
      ActiveSheetInput(rows: fixture.activeSheet.rows),
    );

    expect(
      fixture.toSnapshot(),
      equals(loadBackupGroupingDamageFixture().toSnapshot()),
    );
    expect(activeSheet.schemaViolations, [
      SchemaViolation(
        sheetRowNumber: 3,
        workout: 'Legs',
        message: 'Backup row has no preceding primary row in the same workout.',
      ),
    ]);
  });

  test('missing and broken formula damage fixture exposes healing issues', () {
    final fixture = loadFormulaDamageFixture();
    final activeSheet = _parseWorkbookFixture(fixture);

    expect(
      fixture.toSnapshot(),
      equals(loadFormulaDamageFixture().toSnapshot()),
    );
    expect(activeSheet.schemaViolations, isEmpty);
    expect(activeSheet.formulaHealingIssues.single.cells, [
      HealingCellIssue(
        sheetRowNumber: 3,
        sheetColumnNumber: 1,
        columnName: 'Exercise',
        reason: HealingIssueReason.missingFormula,
        currentFormula: '',
      ),
      HealingCellIssue(
        sheetRowNumber: 3,
        sheetColumnNumber: 8,
        columnName: 'Log Format',
        reason: HealingIssueReason.brokenFormula,
        currentFormula: '=Exercises!I99',
      ),
    ]);
  });

  test('ambiguous formula repair fixture requires user selection', () {
    final fixture = loadAmbiguousFormulaRepairDamageFixture();
    final activeSheet = _parseWorkbookFixture(fixture);
    final issue = activeSheet.formulaHealingIssues.single;

    expect(
      fixture.toSnapshot(),
      equals(loadAmbiguousFormulaRepairDamageFixture().toSnapshot()),
    );
    expect(issue.displayedExerciseName, 'Squat');
    expect(issue.needsChoice, isTrue);
    expect(issue.preselectedRow, isNull);
    expect(issue.candidateRows, [2, 3]);
  });

  test('no-exact-match formula repair fixture requires user selection', () {
    final fixture = loadNoExactMatchFormulaRepairDamageFixture();
    final activeSheet = _parseWorkbookFixture(fixture);
    final issue = activeSheet.formulaHealingIssues.single;

    expect(
      fixture.toSnapshot(),
      equals(loadNoExactMatchFormulaRepairDamageFixture().toSnapshot()),
    );
    expect(issue.displayedExerciseName, 'Front Squat');
    expect(issue.needsChoice, isTrue);
    expect(issue.preselectedRow, isNull);
    expect(issue.candidateRows, isEmpty);
  });
}

ParsedActiveSheet _parseWorkbookFixture(WorkoutWorkbookFixture fixture) {
  return parseActiveSheet(
    ActiveSheetInput(
      rows: fixture.activeSheet.rows,
      mergedFirstColumnRows: fixture.activeSheet.mergedFirstColumnRows,
      cellFormulas: fixture.activeSheet.cellFormulas.map(
        (formula) => CellFormula(
          sheetRowNumber: formula.sheetRowNumber,
          sheetColumnNumber: formula.sheetColumnNumber,
          formula: formula.formula,
        ),
      ),
      exercisesRows: fixture.exercisesSheet.rows,
    ),
  );
}

bool _isExerciseRow(List<String> row) =>
    row.length > 8 && row.first.isNotEmpty && row.first != 'Exercise';
