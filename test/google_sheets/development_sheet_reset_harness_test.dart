import 'package:flutter_test/flutter_test.dart';
import 'package:workout_tracker/google_sheets.dart';
import 'package:workout_tracker/sheet_contract.dart';

void main() {
  test(
    'resets only the known development spreadsheet to a deterministic fixture',
    () async {
      final client = _FakeDevelopmentSheetResetClient();
      final harness = DevelopmentSheetResetHarness(client: client);

      await harness.reset();

      expect(client.resetSpreadsheetIds, [
        workoutTrackerDevelopmentSpreadsheetId,
      ]);
      final fixture = client.fixtures.single;
      expect(fixture.activeSheet.title, 'Active Workout');
      expect(fixture.exercisesSheet.title, 'Exercises');

      final activeRows = fixture.activeSheet.rows;
      expect(
        activeRows.first.take(activeSheetFixedColumns.length),
        activeSheetFixedColumns,
      );
      expect(activeRows[0].skip(activeSheetFixedColumns.length), [
        'Week 2',
        '',
        'Week 1',
      ]);
      expect(activeRows[1].skip(activeSheetFixedColumns.length), [
        'S1',
        'S2',
        'S1',
      ]);

      final displayRows = _activeRowsWithExerciseDisplayValues(fixture);
      final parsedActiveSheet = parseActiveSheet(
        ActiveSheetInput(rows: displayRows),
      );
      final primarySlots = parsedActiveSheet.primarySlots;

      expect(parsedActiveSheet.schemaViolations, isEmpty);
      expect(
        primarySlots.where((slot) => slot.workout == 'Legs'),
        hasLength(greaterThanOrEqualTo(2)),
      );
      expect(
        primarySlots.where((slot) => slot.workout == 'Upper'),
        hasLength(greaterThanOrEqualTo(2)),
      );
      expect(
        primarySlots,
        anyElement(
          predicate<WorkoutSlot>(
            (slot) =>
                slot.exercise == 'Plank' &&
                slot.workout == 'Upper' &&
                !slot.isBackup,
            'contains Plank as an Upper primary',
          ),
        ),
      );
      expect(primarySlots.any((slot) => slot.backups.length > 2), isTrue);
      expect(
        primarySlots.any((slot) => slot.workout == defaultWorkoutName),
        isTrue,
      );

      final formulaRows = activeRows.where(
        (row) => row.length > 8 && row.first.startsWith('=Exercises!A'),
      );
      expect(formulaRows, isNotEmpty);
      expect(formulaRows.every(_usesDirectExerciseDisplayFormulas), isTrue);

      final exercisesRows = fixture.exercisesSheet.rows;
      expect(exercisesRows.first, [
        'Exercise',
        'Description',
        'Default Sets',
        'Default Reps',
        'Default RPE',
        'Default Rest',
        'Default Tempo',
        'Notes',
        'Log Format',
      ]);
      final exerciseFormats = exercisesRows.skip(1).map((row) => row[8]);
      expect(
        exerciseFormats,
        containsAll([
          '{Weight}[x]{Reps}[@]{RPE}',
          '{Reps}[@]{RPE}',
          '{Height}[x]{Reps}[@]{RPE}',
          '{Seconds}[s@]{RPE}',
          '{Weight}[x]{Reps}[@]{RPE}[,]{Pain}',
        ]),
      );
      final exerciseLibraryNames = exercisesRows
          .skip(1)
          .map((row) => row.first);
      expect(
        displayRows
            .skip(2)
            .where((row) => row.length > 8 && row.first.isNotEmpty)
            .every((row) => exerciseLibraryNames.contains(row.first)),
        isTrue,
      );
      expect(exerciseLibraryNames, containsAll(['Plank', 'Farmer Carry']));
    },
  );

  test('rejects non-development spreadsheet IDs by default', () async {
    final harness = DevelopmentSheetResetHarness(
      client: _FakeDevelopmentSheetResetClient(),
    );

    expect(
      () => harness.reset(spreadsheetId: 'unrelated-spreadsheet'),
      throwsArgumentError,
    );
  });

  test('plans reset writes with typed cell values and text formatting', () {
    final tab = DevelopmentSheetResetTab(
      title: 'Active Workout',
      rows: [
        ['Exercise', 'Tempo', 'History'],
        ['=Exercises!A2', '3-1-1', ''],
        ['Timed Drill', '45s', '12-15'],
      ],
    );

    final plan = DevelopmentSheetResetTabRewritePlan(
      sheetId: 42,
      tab: tab,
      frozenRowCount: 1,
    );

    final textFormatRequest = plan.requests.singleWhere(
      (request) =>
          request.repeatCell?.fields == 'userEnteredFormat.numberFormat',
    );
    expect(
      textFormatRequest.repeatCell?.cell?.userEnteredFormat?.numberFormat?.type,
      'TEXT',
    );
    expect(textFormatRequest.repeatCell?.range?.sheetId, 42);
    expect(textFormatRequest.repeatCell?.range?.startRowIndex, 0);
    expect(textFormatRequest.repeatCell?.range?.endRowIndex, 50);
    expect(textFormatRequest.repeatCell?.range?.startColumnIndex, 0);
    expect(textFormatRequest.repeatCell?.range?.endColumnIndex, 3);

    final writeRequest = plan.requests.singleWhere(
      (request) => request.updateCells != null,
    );
    expect(writeRequest.updateCells?.fields, 'userEnteredValue');

    final rows = writeRequest.updateCells!.rows!;
    expect(rows[1].values![0].userEnteredValue?.formulaValue, '=Exercises!A2');
    expect(rows[1].values![0].userEnteredValue?.stringValue, isNull);
    expect(rows[1].values![1].userEnteredValue?.stringValue, '3-1-1');
    expect(rows[1].values![2].userEnteredValue, isNull);
    expect(rows[2].values![0].userEnteredValue?.stringValue, 'Timed Drill');
    expect(rows[2].values![1].userEnteredValue?.stringValue, '45s');
    expect(rows[2].values![2].userEnteredValue?.stringValue, '12-15');
  });
}

class _FakeDevelopmentSheetResetClient implements DevelopmentSheetResetClient {
  final resetSpreadsheetIds = <String>[];
  final fixtures = <DevelopmentSheetResetFixture>[];

  @override
  Future<void> resetSpreadsheet({
    required String spreadsheetId,
    required DevelopmentSheetResetFixture fixture,
  }) async {
    resetSpreadsheetIds.add(spreadsheetId);
    fixtures.add(fixture);
  }
}

List<List<String>> _activeRowsWithExerciseDisplayValues(
  DevelopmentSheetResetFixture fixture,
) {
  return fixture.activeSheet.rows
      .map(
        (row) => row
            .map((cell) => _exerciseDisplayValue(cell, fixture.exercisesSheet))
            .toList(),
      )
      .toList();
}

String _exerciseDisplayValue(String cell, DevelopmentSheetResetTab exercises) {
  final formula = _exerciseFormula(cell);
  if (formula == null) {
    return cell;
  }

  final rowIndex = formula.rowNumber - 1;
  final columnIndex = _columnNumber(formula.columnLetters) - 1;
  if (rowIndex < 0 ||
      rowIndex >= exercises.rows.length ||
      columnIndex < 0 ||
      columnIndex >= exercises.rows[rowIndex].length) {
    return cell;
  }
  return exercises.rows[rowIndex][columnIndex];
}

bool _usesDirectExerciseDisplayFormulas(List<String> row) {
  final firstFormula = _exerciseFormula(row.first);
  if (firstFormula == null || firstFormula.columnLetters != 'A') {
    return false;
  }

  final expectedColumns = ['A', 'C', 'D', 'E', 'F', 'G', 'H', 'I'];
  for (var index = 0; index < expectedColumns.length; index += 1) {
    final formula = _exerciseFormula(row[index]);
    if (formula == null ||
        formula.columnLetters != expectedColumns[index] ||
        formula.rowNumber != firstFormula.rowNumber) {
      return false;
    }
  }
  return true;
}

_ExerciseFormula? _exerciseFormula(String value) {
  final match = RegExp(r'^=Exercises!([A-Z]+)(\d+)$').firstMatch(value);
  if (match == null) {
    return null;
  }
  return _ExerciseFormula(
    columnLetters: match.group(1)!,
    rowNumber: int.parse(match.group(2)!),
  );
}

int _columnNumber(String letters) {
  var number = 0;
  for (final codeUnit in letters.codeUnits) {
    number = number * 26 + codeUnit - 64;
  }
  return number;
}

class _ExerciseFormula {
  const _ExerciseFormula({
    required this.columnLetters,
    required this.rowNumber,
  });

  final String columnLetters;
  final int rowNumber;
}
