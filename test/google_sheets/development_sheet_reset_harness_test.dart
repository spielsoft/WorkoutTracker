import 'package:flutter_test/flutter_test.dart';
import 'package:workout_tracker/google_sheets_development.dart'
    show DevelopmentSheetResetHarness;
import 'package:workout_tracker/google_sheets.dart';
import 'package:workout_tracker/sheet_contract.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'resets only the known development spreadsheet to a deterministic fixture',
    () async {
      final initializer = _FakeWorkbookInitializer();
      final harness = DevelopmentSheetResetHarness(initializer: initializer);

      await harness.reset();

      expect(initializer.initializedSpreadsheetIds, [
        workoutTrackerDevelopmentSpreadsheetId,
      ]);
      final workbook = initializer.workbooks.single;
      expect(workbook.activeSheet.title, 'Active Workout');
      expect(workbook.exercisesSheet.title, 'Exercises');

      final activeRows = workbook.activeSheet.rows;
      expect(activeRows, [activeSheetFixedColumns]);
      final parsedActiveSheet = parseActiveSheet(
        ActiveSheetInput(rows: activeRows),
      );

      expect(parsedActiveSheet.schemaViolations, isEmpty);
      expect(parsedActiveSheet.primarySlots, isEmpty);
      expect(parsedActiveSheet.historyBlocks, isEmpty);

      final exercisesRows = workbook.exercisesSheet.rows;
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
      expect(
        exercisesRows.skip(1).map((row) => row.first),
        containsAll([
          'Smith Machine Reverse Lunge',
          'Lateral Step-Down',
          'Cable Face Pull',
        ]),
      );
      expect(
        exercisesRows.skip(1).map((row) => row[8]),
        containsAll([
          '{Weight}[x]{Reps}[@]{RPE}',
          '{Reps}[@]{RPE}',
          '{Height}[x]{Reps}[@]{RPE}[,]{Pain}',
          '{Seconds}[s@]{RPE}',
        ]),
      );
      expect(
        activeRows.skip(1).where((row) => row.any((cell) => cell.isNotEmpty)),
        isEmpty,
      );
    },
  );

  test('rejects non-development spreadsheet IDs by default', () async {
    final harness = DevelopmentSheetResetHarness(
      initializer: _FakeWorkbookInitializer(),
    );

    expect(
      () => harness.reset(spreadsheetId: 'unrelated-spreadsheet'),
      throwsArgumentError,
    );
  });

  test('plans workbook writes with typed cell values and text formatting', () {
    final tab = WorkoutTrackerWorkbookTab(
      title: 'Active Workout',
      rows: [
        ['Exercise', 'Tempo', 'History'],
        ['=Exercises!A2', '3-1-1', ''],
        ['Timed Drill', '45s', '12-15'],
      ],
    );

    final plan = WorkoutTrackerWorkbookTabRewritePlan(
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

class _FakeWorkbookInitializer implements WorkoutTrackerWorkbookInitializer {
  final initializedSpreadsheetIds = <String>[];
  final workbooks = <WorkoutTrackerWorkbook>[];

  @override
  Future<void> initializeWorkbook({
    required String spreadsheetId,
    required WorkoutTrackerWorkbook workbook,
  }) async {
    initializedSpreadsheetIds.add(spreadsheetId);
    workbooks.add(workbook);
  }
}
